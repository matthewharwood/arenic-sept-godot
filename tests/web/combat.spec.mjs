import { test, expect } from '@playwright/test';
import { watch, enterProbeWorld, clickLogical, renderedPixels, attachResults } from './helpers.mjs';

// Keep continuous combat practical on software WebGL. Input still uses the
// game's reported logical coordinates; no teleport, damage or timer hooks exist.
test.use({ viewport: { width: 640, height: 360 }, deviceScaleFactor: 1 });
test.describe.configure({ timeout: 300_000 });
const ARENA_IDS = ['labyrinth', 'guild_house', 'sanctum', 'mountain', 'bastion', 'pawnshop', 'crucible', 'casino', 'gala'];

async function waitCombat(log, predicate, message, timeout = 60_000) {
  await expect.poll(() => {
    const state = log.latest();
    return Boolean(state?.scene === 'world' && state.combat && predicate(state));
  }, { message, timeout, intervals: [100, 250, 500] }).toBe(true);
  return log.latest();
}

async function seenCombat(log, after, predicate, message, timeout = 60_000) {
  const match = () => log.events.find(event => event.sequence > after && event.kind === 'state'
    && event.data?.scene === 'world' && event.data.combat && predicate(event.data));
  await expect.poll(match, { message, timeout, intervals: [100, 250, 500] }).toBeTruthy();
  return match().data;
}

async function focusHero(page, log, classIndex) {
  const initial = await enterProbeWorld(page, log, classIndex);
  expect(initial.arena).toBe('guild_house');
  expect(initial.hero.cell).toEqual([30, 15]);
  expect(Object.keys(initial.combat.totals).sort()).toEqual([...ARENA_IDS].sort());
  expect(Object.values(initial.combat.totals)).toEqual(ARENA_IDS.map(() => 0));
  expect(initial.combat.assets.errors).toEqual([]);
  expect(Object.keys(initial.combat.assets.actors)).toHaveLength(8);
  expect(Object.values(initial.combat.assets.actors).every(Boolean)).toBe(true);
  expect(initial.combat.assets.effects_checked).toBe(14);
  expect(initial.combat.hero_animation_ready).toBe(true);
  await page.keyboard.press('Tab');
  return waitCombat(log, value => value.zoomed && value.hero.selected && !value.motion_active
    && !value.controls.ability.disabled, 'Tab focuses the selected hero and enables the real ability control');
}

function expectOnlyGuildDamage(state, total) {
  expect(state.combat.totals).toEqual(Object.fromEntries(ARENA_IDS.map(id => [id, id === 'guild_house' ? total : 0])));
  expect(state.combat.targets).toEqual(Object.fromEntries(ARENA_IDS.map(id => [id, id === 'guild_house' ? total : 0])));
}

async function waitGameSeconds(log, start, duration, message) {
  return waitCombat(log, value => value.combat.physics_seconds >= start + duration, message);
}

test('combat: Hunter real cast, cooldown and echo rejection, independent arena progress', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    let state = await focusHero(page, log, 0);
    expect(state.combat.starter_ability_id).toBe('auto_shot');
    expect(state.combat.bar).toMatchObject({ total: 0, current: 0, completed: 0, phase_damage: 20, foundation: false });
    const beforeCast = log.events.at(-1)?.sequence ?? 0;
    await page.keyboard.down('Space');
    state = await seenCombat(log, beforeCast, value => value.combat.active && value.combat.cooldown > 0,
      'Space starts a real Hunter cast');
    expect(state.combat.active_fx_count).toBeGreaterThan(0);
    expect(state.combat.hero_animation_ready).toBe(true);
    // Repeated down events are actual browser key-repeat events, not model calls.
    for (let echo = 0; echo < 5; echo++) await page.keyboard.down('Space');
    state = await waitCombat(log, value => value.combat.totals.guild_house === 1
      && value.combat.bar.total === 1, 'The in-range shot applies one target/arena/HUD hit');
    expectOnlyGuildDamage(state, 1);
    expect(state.combat.bar).toMatchObject({ current: 1, completed: 0, foundation: false });
    expect(state.combat.bar.fill).toBeCloseTo(0.05, 5);
    // The disabled real control must not queue another cast during cooldown.
    expect(state.combat.cooldown).toBeGreaterThan(0);
    expect(state.controls.ability.disabled).toBe(true);
    await clickLogical(page, state, state.controls.ability.center);
    state = await waitCombat(log, value => value.combat.cooldown === 0 && !value.combat.active,
      'Hunter cooldown ends on the actual simulation clock');
    // Space is still held from the original press. Do not synthesize another
    // keydown here: Playwright treats it as a fresh physical press, whereas an
    // operating-system key-repeat is represented by the game's echo path.
    state = await waitGameSeconds(log, state.combat.physics_seconds, 1.0, 'Held Space does not auto-recast after cooldown');
    expectOnlyGuildDamage(state, 1);
    expect(state.combat.active_fx_count).toBe(0);
    await page.keyboard.up('Space');
    await page.keyboard.press('p');
    await waitCombat(log, value => !value.zoomed && !value.motion_active, 'P returns to overview');
    await page.keyboard.press(']');
    state = await waitCombat(log, value => value.arena === 'sanctum' && !value.motion_active,
      'Bracket navigation selects an untouched arena in overview');
    expect(state.zoomed).toBe(false);
    expect(state.combat.bar).toMatchObject({ total: 0, current: 0, completed: 0, foundation: false });
    expectOnlyGuildDamage(state, 1);
    await page.keyboard.press('[');
    state = await waitCombat(log, value => value.arena === 'guild_house' && value.combat.bar.total === 1,
      'Returning to Guild restores its independent progress');
    expectOnlyGuildDamage(state, 1);
    await page.screenshot({ path: testInfo.outputPath('hunter-guild-progress.png') });
    expect(log.errors).toEqual([]);
  } finally {
    await page.keyboard.up('Space').catch(() => {});
    await attachResults(testInfo, log);
  }
});

test('combat: Cardinal held Space deals timed damage and release or movement stops it', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    let state = await focusHero(page, log, 4);
    expect(state.combat.starter_ability_id).toBe('heal');
    await page.keyboard.down('Space');
    state = await waitCombat(log, value => value.combat.is_channeling && value.combat.active_elapsed >= 1.0
      && value.combat.totals.guild_house >= 1, 'Holding Space reaches a real one-second channel tick');
    expect(state.combat.active_remaining).toBeNull();
    expect(state.combat.hero_ability_id).toBe('heal');
    expect(state.combat.hero_animation_ready).toBe(true);
    expect(state.combat.active_fx_count).toBeGreaterThan(0);
    expect(state.controls.ability.disabled).toBe(false);
    expect(state.combat.ability_status).toBe('Channeling · release to stop');
    expectOnlyGuildDamage(state, state.combat.totals.guild_house);
    await page.keyboard.up('Space');
    state = await waitCombat(log, value => !value.combat.is_channeling && !value.combat.active,
      'Releasing Space cancels the channel');
    const releasedDamage = state.combat.totals.guild_house;
    state = await waitGameSeconds(log, state.combat.physics_seconds, 1.25, 'Release remains stopped across another possible damage tick');
    expectOnlyGuildDamage(state, releasedDamage);
    expect(state.combat.active_fx_count).toBe(0);
    await page.keyboard.down('Space');
    state = await waitCombat(log, value => value.combat.is_channeling && value.combat.totals.guild_house > releasedDamage,
      'A new press can start a new channel after cooldown');
    await page.keyboard.press('ArrowRight');
    state = await waitCombat(log, value => value.hero.cell[0] === 31 && !value.combat.is_channeling,
      'A real movement key cancels the held channel');
    const movedDamage = state.combat.totals.guild_house;
    state = await waitGameSeconds(log, state.combat.physics_seconds, 1.25, 'Keeping Space held does not restart the moved channel');
    expectOnlyGuildDamage(state, movedDamage);
    expect(state.combat.active).toBe(false);
    expect(state.combat.active_fx_count).toBe(0);
    await page.keyboard.up('Space');
    expect(log.errors).toEqual([]);
  } finally {
    await page.keyboard.up('Space').catch(() => {});
    await attachResults(testInfo, log);
  }
});

test('combat: Merchant real movement and twenty-second Fortune completes a visible phase', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    let state = await focusHero(page, log, 2);
    expect(state.combat.starter_ability_id).toBe('fortune');
    for (let y = 16; y <= 20; y++) {
      await page.keyboard.press('ArrowUp');
      state = await waitCombat(log, value => value.hero.cell[0] === 30 && value.hero.cell[1] === y,
        `A new Up press moves the hero to the actual cell 30,${y}`);
    }
    expect(state.hero.facing).toBe('n');
    expectOnlyGuildDamage(state, 0);
    const stripPoints = [[0.1, 4 / 720], [0.5, 4 / 720], [0.9, 4 / 720]];
    const emptyPixels = await renderedPixels(page, stripPoints);
    const beforeCast = log.events.at(-1)?.sequence ?? 0;
    await page.keyboard.press('Space');
    const firstHit = await seenCombat(log, beforeCast, value => value.combat.totals.guild_house > 0,
      'The nearby Fortune aura applies its first timed hit');
    expectOnlyGuildDamage(firstHit, 1);
    expect(firstHit.combat.active).toBe(true);
    expect(firstHit.combat.is_channeling).toBe(false);
    expect(firstHit.combat.active_remaining).toBeGreaterThan(18);
    expect(firstHit.combat.active_remaining).toBeLessThanOrEqual(19.01);
    expect(firstHit.combat.active_fx_count).toBeGreaterThan(0);
    state = await waitCombat(log, value => value.combat.active && value.combat.active_remaining < firstHit.combat.active_remaining - 1.0,
      'Fortune remaining time decreases on the real simulation clock');
    expect(state.controls.ability.disabled).toBe(true);
    // Wait for model completion, not twenty wall-clock seconds. Software WebGL
    // may advance simulation more slowly; 180s is the independent failure bound.
    state = await waitCombat(log, value => !value.combat.active && value.combat.cooldown === 0
      && value.combat.totals.guild_house >= 20 && value.combat.bar.total >= 20,
    'The complete twenty-second aura finishes without test-driven clock changes', 180_000);
    expectOnlyGuildDamage(state, 20);
    expect(state.combat.bar).toMatchObject({ total: 20, current: 0, completed: 1, phase_damage: 20, foundation: true, fill: 0 });
    expect(state.combat.bar.phase_label).toMatch(/^Phase 2\s/);
    const completedPixels = await renderedPixels(page, stripPoints);
    for (let index = 0; index < stripPoints.length; index++) {
      const colorChange = completedPixels[index].slice(0, 3)
        .reduce((sum, channel, component) => sum + Math.abs(channel - emptyPixels[index][component]), 0);
      expect(colorChange, `Completed-phase foundation remains visible across strip sample ${index}`).toBeGreaterThan(12);
    }
    await page.screenshot({ path: testInfo.outputPath('merchant-completed-phase-foundation.png') });
    state = await waitGameSeconds(log, state.combat.physics_seconds, 1.25, 'Fortune does not tick beyond its finite duration');
    expectOnlyGuildDamage(state, 20);
    expect(state.combat.active_fx_count).toBe(0);
    expect(state.controls.ability.disabled).toBe(false);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});
