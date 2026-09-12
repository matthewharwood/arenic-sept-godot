import { test, expect } from '@playwright/test';
import { watch, enterProbeWorld, clickLogical, attachResults } from './helpers.mjs';

test.use({ viewport: { width: 640, height: 360 }, deviceScaleFactor: 1 });
test.describe.configure({ timeout: 180_000 });

test('HUD: real roster, nine arenas, fixed slots and independent keyboard holds', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    let state = await enterProbeWorld(page, log, 4);
    expect(state.hero.class_id).toBe('cardinal');
    expect(state.world_rect).toEqual([13, 35, 1254, 589]);
    expect(state.hud.roster).toMatchObject({ capacity: 40, count: 1, hidden_count: 0 });
    expect(state.hud.roster.entries).toHaveLength(1);
    expect(state.hud.roster.entries[0]).toMatchObject({ identity: state.hero.identity, name: state.hero.name, dead: false });
    expect(state.hud.arenas).toHaveLength(9);
    expect(state.hud.arenas.filter(arena => arena.active).map(arena => arena.index)).toEqual([1]);
    expect(state.hud.raid).toBe('Raid: Normal');
    expect(state.hud.slots.map(slot => slot.slot)).toEqual([1, 2, 3, 4]);
    expect(state.hud.slots[0].text).toBe('Sacrifice\n1');
    expect(state.hud.slots.slice(1).map(slot => [slot.text, slot.disabled])).toEqual([
      ['—\n2', true], ['—\n3', true], ['—\n4', true],
    ]);

    await page.keyboard.press(']');
    state = await log.wait(value => value?.selected_index === 2 && value.hud?.roster.count === 0,
      'Right bracket selects the real empty Sanctum arena');
    expect(state.hero.arena).toBe('guild_house');
    expect(state.hud.arenas.filter(arena => arena.active).map(arena => arena.index)).toEqual([2]);
    await page.keyboard.press('[');
    state = await log.wait(value => value?.selected_index === 1 && value.hud?.roster.count === 1,
      'Left bracket restores the actual Guild House hero');
    await clickLogical(page, state, state.hud.arenas[4].center);
    state = await log.wait(value => value?.selected_index === 4, 'Minimap pointer selects Bastion');
    await clickLogical(page, state, state.hud.previous.center);
    state = await log.wait(value => value?.selected_index === 3, 'Previous button matches bracket selection');
    await clickLogical(page, state, state.hud.next.center);
    state = await log.wait(value => value?.selected_index === 4, 'Next button matches bracket selection');
    await clickLogical(page, state, state.hud.arenas[1].center);
    state = await log.wait(value => value?.selected_index === 1 && value.hud?.roster.count === 1,
      'Minimap returns to the hero arena');
    await clickLogical(page, state, state.hud.roster.entries[0].center);
    state = await log.wait(value => value?.hero.selected && value.zoomed && !value.motion_active,
      'Roster pointer selects and focuses the real hero');
    expect(state.hud.roster.selected_identity).toBe(state.hero.identity);

    await page.keyboard.press('h');
    state = await log.wait(value => value?.hud?.guide.visible, 'H opens the controls guide');
    expect(state.hud.guide.text).toContain('[ / ]');
    await page.keyboard.press('h');
    state = await log.wait(value => value?.hud && !value.hud.guide.visible, 'H closes the guide');
    const beforeReserved = state.combat.totals.guild_house;
    for (const key of ['2', '3', '4']) await page.keyboard.press(key);
    // R arms a real recording; slots 2-4 stay inert.
    await page.keyboard.press('r');
    state = await log.wait(value => value?.recording?.state === 'countdown',
      'R arms the recording countdown');
    expect(state.combat.is_channeling).toBe(false);
    expect(state.combat.totals.guild_house).toBe(beforeReserved);
    await page.keyboard.press('r');
    state = await log.wait(value => value?.recording?.state === 'idle',
      'R again aborts the countdown');

    await page.keyboard.down('1');
    state = await log.wait(value => value?.combat?.is_channeling && value.combat.totals.guild_house > beforeReserved,
      'Slot 1 produces a real timed channel hit');
    await page.keyboard.down('Space');
    await page.keyboard.up('1');
    const overlapClock = state.combat.physics_seconds;
    state = await log.wait(value => value?.combat?.physics_seconds > overlapClock + 0.25,
      'Physics advances after releasing only slot 1');
    expect(state.combat.is_channeling).toBe(true);
    await page.keyboard.up('Space');
    state = await log.wait(value => value?.combat && !value.combat.is_channeling,
      'The final held binding release stops the channel');
    state = await log.wait(value => value?.combat?.cooldown === 0, 'Starter cooldown ends');
    await page.keyboard.down('Space');
    await log.wait(value => value?.combat?.is_channeling, 'Space still starts the same starter independently');
    await page.keyboard.up('Space');
    state = await log.wait(value => value?.combat && !value.combat.is_channeling, 'Space release stops the channel');
    expect(state.hud.roster.count).toBe(1);
    expect(state.hud.roster.hidden_count).toBe(0);
    expect(state.hud.slots).toHaveLength(4);
    expect(log.errors).toEqual([]);
  } finally {
    await page.keyboard.up('1');
    await page.keyboard.up('Space');
    await attachResults(testInfo, log);
  }
});
