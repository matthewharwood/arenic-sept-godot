import { test, expect } from '@playwright/test';
import { createHash } from 'node:crypto';
import { watch, enterProbeWorld, clickLogical, clickHudMenuAction, attachResults } from './helpers.mjs';

test.use({ viewport: { width: 640, height: 360 }, deviceScaleFactor: 1 });
test.describe.configure({ timeout: 120_000 });

// Observe narrow progress/contact transitions at the probe's real cadence.
// No input repetition, simulation clock changes, or production mutation hooks.
async function until(log, predicate, message, timeout = 15_000) {
  await expect.poll(() => Boolean(predicate(log.latest())),
    { message, timeout, intervals: [10, 20, 50] }).toBe(true);
  return log.latest();
}

async function walk(page, log, target) {
  for (const axis of [0, 1]) {
    while (log.latest().hero.cell[axis] !== target[axis]) {
      const next = [...log.latest().hero.cell];
      const direction = Math.sign(target[axis] - next[axis]);
      next[axis] += direction;
      await page.keyboard.press(axis === 0
        ? direction > 0 ? 'ArrowRight' : 'ArrowLeft'
        : direction > 0 ? 'ArrowUp' : 'ArrowDown');
      await until(log, s => s?.hero?.cell.every((value, index) => value === next[index]),
        `A real movement press reaches ${next}`, 5_000);
    }
  }
  return log.latest();
}

const offset = ([x, y], dx, dy) => [x + dx, y + dy];

function gatheringRoute(state) {
  const sites = state.gathering.sites;
  const sources = kind => sites.filter(site => site.role === 'source' && site.kind === kind);
  const bank = kind => {
    const matches = sites.filter(site => site.role === 'dropoff' && site.kind === kind);
    expect(matches).toHaveLength(1);
    return matches[0].cell;
  };
  expect(sources('wood')).toHaveLength(2);
  expect(sources('gold')).toHaveLength(2);
  expect(new Set(sites.map(site => site.id)).size).toBe(sites.length);
  // Use the southern wood stand and eastern mine from the actual authored
  // definition. The real route follows their two-tile interaction perimeter.
  const wood = sources('wood').sort((a, b) => a.cell[1] - b.cell[1])[0].cell;
  const gold = sources('gold').sort((a, b) => b.cell[0] - a.cell[0])[0].cell;
  const woodBank = bank('wood'), goldBank = bank('gold');
  const radius = state.gathering.radius_tiles;
  expect(radius).toBe(2);
  return { woodStart: offset(wood, radius, 0), goldStart: offset(gold, -radius, 0),
    woodStop: offset(woodBank, -radius, 0), woodSouth: offset(woodBank, 0, -radius),
    goldStop: offset(goldBank, radius, 0), wrongBank: offset(goldBank, -radius, 0),
    // Stay below the Keeper's entrance cell as well as both drop-off radii.
    safeY: Math.min(woodBank[1], goldBank[1]) - radius - 2 };
}

function expectOutdoorClearing(state) {
  const clearing = state.guild_clearing;
  expect(clearing.indoor_props, 'The indoor decoration layer is replaced').toBe(false);
  expect(clearing.trees.length, 'The field has a surrounding forest').toBeGreaterThan(20);
  expect(clearing.trees.length).toBeLessThanOrEqual(96);
  expect([...new Set(clearing.trees.map(tree => tree.variant))].sort()).toEqual([0, 1, 2, 3, 4]);
  expect([...new Set(clearing.trees.map(tree => tree.facing))].sort()).toEqual([0, 1, 2, 3]);
  for (const tree of clearing.trees) {
    // _rect exposes [x, y, width, height] from the actual Sprite3D texture.
    expect(tree.region).toEqual([tree.facing * 76, tree.variant * 76, 76, 76]);
    expect(tree.pixel_size).toBeCloseTo(0.25 / 19, 6);
    expect(tree.cell[0]).toBeGreaterThanOrEqual(2);
    expect(tree.cell[0]).toBeLessThanOrEqual(63);
    expect(tree.cell[1]).toBeGreaterThanOrEqual(2);
    expect(tree.cell[1]).toBeLessThanOrEqual(28);
  }
  expect(clearing.path_count, 'Dirt paths are mounted across the clearing').toBeGreaterThan(0);
  expect(clearing.tavern_texture).toBe('res://assets/environment/guild_clearing/tavern/tavern.png');
  expect(clearing.tavern_pixel_size).toBeCloseTo(0.25 / 19, 6);
  expect(Math.abs(clearing.tavern_position[0])).toBeLessThan(0.25);
  expect(clearing.tavern_position[2], 'The tavern anchors the northern side').toBeLessThan(0);
  expect(clearing.keeper_frames).toBe('res://assets/npcs/keeper/seated/keeper_seated.tres');
  expect(clearing.keeper_animation).toBe('idle_s');
  const mines = state.gathering.sites.filter(site => site.kind === 'gold' && site.role === 'source');
  expect(mines.map(mine => mine.cell).sort((a, b) => a[0] - b[0])).toEqual([[7, 24], [56, 7]]);
  expect(state.gathering.site_readouts, 'No gathering labels or bank text clutter the field').toEqual([]);
  const dropoffs = state.gathering.sites.filter(site => site.role === 'dropoff');
  expect(dropoffs.find(site => site.kind === 'wood').cell).toEqual([23, 21]);
  expect(dropoffs.find(site => site.kind === 'gold').cell).toEqual([42, 21]);
}

async function fullBag(log, kind) {
  const state = await until(log, s => s?.gathering?.hero.kind === kind
    && s.gathering.hero.phase === 'full', `The ${kind} source fills the real bag`);
  expect(state.gathering.hero).toMatchObject({ amount: 10, capacity_units: 10, progress: 1 });
  expect(state.gathering.visual).toMatchObject({ visible: true, text: `${kind === 'wood' ? 'Wood' : 'Gold'} full` });
  return state;
}

async function deposit(log, kind, total) {
  const unloading = await until(log, s => s?.gathering?.hero.phase === 'unloading'
    && s.gathering.hero.kind === kind && s.gathering.hero.progress > 0,
  `Only the matching ${kind} drop-off starts unloading`);
  expect(unloading.gathering.visual).toMatchObject({ visible: true, text: `Unloading ${kind}` });
  const state = await until(log, s => s?.gathering?.[`${kind}_total`] === total
    && s.gathering.hero.phase === 'idle', `A completed unload banks ${total} ${kind}`);
  expect(state.gathering.visual.visible).toBe(false);
  expect(state.gathering.site_readouts).toEqual([]);
  return state;
}

test('founder gathers wood and gold, then its recorded route deposits on ghost replay', async ({ page }, testInfo) => {
  // Real onboarding, three live loads and one replay can exceed two minutes
  // under software WebGL. Keep every individual progress deadline unchanged.
  test.setTimeout(180_000);
  const log = watch(page);
  try {
    await enterProbeWorld(page, log, 0);
    await page.keyboard.press('Tab');
    let state = await until(log, s => s?.zoomed && s.hero.selected && !s.motion_active,
      'Tab focuses the real founder for gathering');
    expectOutdoorClearing(state);
    const route = gatheringRoute(state);
    expect(state.gathering).toMatchObject({ wood_total: 0, gold_total: 0 });

    await walk(page, log, [state.hero.cell[0], route.woodStart[1]]);
    await walk(page, log, route.woodStart);
    state = await until(log, s => s?.gathering?.hero.phase === 'gathering'
      && s.gathering.hero.progress > 0 && s.gathering.hero.progress < 1,
    'Standing in source range visibly advances the partial bag');
    expect(state.gathering.visual.visible).toBe(true);
    expect(state.gathering.visual.text).toMatch(/^Wood \d+\/10$/);
    await fullBag(log, 'wood');
    await page.screenshot({ path: testInfo.outputPath('wood-bag-full.png') });

    // Approach the wrong bank along a row outside both drop-off radii.
    await walk(page, log, [route.woodStart[0], route.safeY]);
    await walk(page, log, [route.wrongBank[0], route.safeY]);
    state = await walk(page, log, route.wrongBank);
    const wrongBankTick = state.recording.cycle;
    state = await until(log, s => s?.recording?.cycle >= wrongBankTick + 65,
      'A complete unload interval passes at the wrong resource bank');
    expect(state.gathering).toMatchObject({ wood_total: 0, gold_total: 0,
      hero: { kind: 'wood', phase: 'full', unload_ticks: 0 } });
    await walk(page, log, [route.wrongBank[0], route.safeY]);
    await walk(page, log, [route.woodSouth[0], route.safeY]);
    await walk(page, log, route.woodSouth);
    await deposit(log, 'wood', 10);

    await walk(page, log, [route.goldStart[0], route.woodSouth[1]]);
    await walk(page, log, route.goldStart);
    await fullBag(log, 'gold');
    await walk(page, log, [route.goldStop[0], route.goldStart[1]]);
    await walk(page, log, route.goldStop);
    state = await deposit(log, 'gold', 10);
    expect(state.gathering.wood_total).toBe(10);

    await walk(page, log, [route.woodStart[0], route.goldStop[1]]);
    await walk(page, log, route.woodStart);
    await page.keyboard.press('r');
    await until(log, s => s?.recording?.state === 'countdown', 'R starts the real recording countdown');
    await until(log, s => s?.recording?.state === 'recording', 'Countdown begins a new gathering take');
    await fullBag(log, 'wood');
    await walk(page, log, [route.woodStop[0], route.woodStart[1]]);
    await walk(page, log, route.woodStop);
    state = await deposit(log, 'wood', 20);
    expect(state.recording.captured).toBe(route.woodStop.reduce((count, value, axis) =>
      count + Math.abs(value - route.woodStart[axis]), 0));
    await page.keyboard.press('r');
    await until(log, s => s?.recording?.modal_open, 'R offers the actual recording decision');
    await page.keyboard.press('1'); // The real first option is Commit.
    state = await until(log, s => s?.recording?.state === 'idle' && !s.recording.modal_open
      && s.recording.ghosts.some(ghost => ghost.identity === s.hero.identity),
    'Commit folds the founder and restarts the recorded route');
    const identity = state.hero.identity;
    expect(state.gathering).toMatchObject({ wood_total: 20, gold_total: 10 });
    await until(log, s => s?.recording?.ghosts.some(ghost => ghost.identity === identity
      && ghost.cell.every((value, axis) => value === route.woodStart[axis])) && s.gathering.hero.phase === 'gathering',
    'The ghost gathers at its saved start without further movement input');
    state = await until(log, s => s?.gathering?.wood_total === 30, 'Replayed movement deposits a second real wood load', 25_000);
    expect(state.gathering.gold_total).toBe(10);
    expect(state.gathering.site_readouts).toEqual([]);
    expect(state.recording.ghosts.find(ghost => ghost.identity === identity))
      .toMatchObject({ cell: route.woodStop, defeated: false });
    await page.screenshot({ path: testInfo.outputPath('ghost-route-banked-wood.png') });
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

async function readSave(page) {
  const raw = await page.evaluate(() => new Promise((resolve, reject) => {
    const request = indexedDB.open('arenic-saves', 1);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const db = request.result;
      const tx = db.transaction('slots', 'readonly');
      const read = tx.objectStore('slots').get(0);
      tx.oncomplete = () => { db.close(); resolve(read.result); };
      tx.onabort = () => { db.close(); reject(tx.error); };
    };
  }));
  const document = JSON.parse(raw);
  return { document, payload: JSON.parse(document.payload_json) };
}

async function saveAndTitle(page, log) {
  await clickHudMenuAction(page, log, 'save_title');
  return until(log, s => s?.scene === 'title' && s.saves.ready && !s.saves.busy
    && !s.controls.start.disabled, 'Save & Title commits before leaving the run');
}

async function continueSlot(page, log) {
  let state = await until(log, s => s?.scene === 'title' && s.saves.ready && !s.saves.busy
    && s.controls.continue.visible, 'Hydrated title offers the committed run');
  await clickLogical(page, state, state.controls.continue.center);
  state = await until(log, s => s?.picker?.visible && !s.picker.working, 'Continue opens the real slot picker');
  expect(state.picker.rows[0].choose.disabled).toBe(false);
  await clickLogical(page, state, state.picker.rows[0].choose.center);
  return until(log, s => s?.scene === 'world' && !s.motion_active, 'The codec restores the selected slot');
}

// Bounded setup at the real persistence boundary: clone an actual committed
// founder, with distinct living cells, stable identities and frozen bag rules.
function contactFixture(saved, simultaneous) {
  const fixture = structuredClone(saved);
  const { payload } = fixture;
  expect(payload.schema_version).toBe(11);
  const founder = payload.run.heroes[0];
  const cells = simultaneous ? [[19, 9], [21, 9], [30, 15]] : [[19, 9], [20, 9], [30, 15]];
  payload.run.heroes = cells.map((cell, identity) => ({ ...structuredClone(founder),
    identity, cell, selected: identity === 0, recordings: {} }));
  payload.run.selected_identity = 0;
  payload.run.next_identity = 3;
  payload.run.arena_selection = { guild_house: 0 };
  const originalAlly = payload.run.combat.arenas.guild_house.allies['hero:0'];
  payload.run.combat.arenas.guild_house.allies = Object.fromEntries(cells.map((cell, identity) =>
    [`hero:${identity}`, { ...structuredClone(originalAlly), cell }]));
  payload.run.gathering = { wood_total: '40', gold_total: '20', bags: [0, 1].map(hero_id => ({
    hero_id, kind: hero_id === 0 ? 'gold' : 'wood', fill_ticks: 300, fill_duration_ticks: 300,
    unload_ticks: 0, unload_duration_ticks: 60, capacity_units: 10,
  })) };
  payload.world.selected_index = 1;
  payload.world.zoomed = true;
  const arena = payload.world.arenas.guild_house;
  arena.tick = 0;
  arena.paused = false;
  arena.active = simultaneous ? ['hero:0', 'hero:1'] : ['hero:1'];
  for (const actor of arena.active) {
    const identity = Number(actor.slice(5));
    payload.run.heroes[identity].recordings.guild_house = { start_cell: cells[identity],
      events: simultaneous ? [{ tick: 180, action: 'move', delta: [identity === 0 ? 1 : -1, 0], slot: 0 }] : [] };
    arena.orders[actor] = arena.next_order++;
  }
  return fixture;
}

async function loadFixture(page, log, fixture) {
  fixture.document.payload_json = JSON.stringify(fixture.payload);
  fixture.document.checksum = createHash('sha256').update(fixture.document.payload_json).digest('hex');
  await page.evaluate(raw => new Promise((resolve, reject) => {
    const request = indexedDB.open('arenic-saves', 1);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const db = request.result;
      const tx = db.transaction('slots', 'readwrite');
      tx.objectStore('slots').put(raw, 0);
      tx.oncomplete = () => { db.close(); resolve(); };
      tx.onabort = () => { db.close(); reject(tx.error); };
    };
  }), JSON.stringify(fixture.document));
  log.events.length = 0;
  log.ready = false;
  await page.reload();
  await until(log, s => s?.scene === 'title' && s.saves.ready && !s.saves.busy,
    'A fresh browser boot validates the complete fixture', 45_000);
  log.downloads = await page.evaluate(() => window.__arenicDownloads);
  log.ready = true;
  return continueSlot(page, log);
}

function expectSafeLivingCells(state) {
  const cells = state.heroes.filter(hero => !hero.defeated).map(hero => `${hero.arena}:${hero.cell}`);
  expect(new Set(cells).size, 'Every living hero has a distinct physical cell').toBe(cells.length);
}

test('hero contact drops saved bags and safely revives the selected simultaneous victim', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await enterProbeWorld(page, log, 0);
    await saveAndTitle(page, log);
    const original = await readSave(page);
    let state = await loadFixture(page, log, contactFixture(original, false));
    expect(state.gathering.bags.map(bag => bag.hero_id)).toEqual([0, 1]);
    expectSafeLivingCells(state);
    await page.keyboard.press('ArrowRight');
    state = await until(log, s => s?.heroes?.find(hero => hero.identity === 1)?.defeated,
      'A real arriving founder defeats the stationary ghost');
    expect(state.heroes.find(hero => hero.identity === 0)).toMatchObject({ cell: [20, 9], defeated: false });
    expect(state.heroes.find(hero => hero.identity === 1)).toMatchObject({ cell: [20, 9], ghost: true, defeated: true });
    expect(state.gathering).toMatchObject({ wood_total: 40, gold_total: 20 });
    expect(state.gathering.bags.map(bag => bag.hero_id)).toEqual([0]);
    expectSafeLivingCells(state);
    await saveAndTitle(page, log);
    const stationary = await readSave(page);
    expect(stationary.payload.run.gathering.bags.map(bag => bag.hero_id)).toEqual([0]);
    expect(stationary.payload.run.combat.arenas.guild_house.allies['hero:1'].health).toBe('0');

    state = await loadFixture(page, log, contactFixture(original, true));
    expect(state.recording.ghosts.map(ghost => ghost.identity)).toEqual([0, 1]);
    expect(state.gathering.bags.map(bag => bag.hero_id)).toEqual([0, 1]);
    expectSafeLivingCells(state);
    state = await until(log, s => s?.heroes?.find(hero => hero.identity === 0)?.ghost === false
      && s.heroes.find(hero => hero.identity === 1)?.cell[0] === 20,
    'Two recorded arrivals resolve together and recover the selected victim');
    const recovered = state.heroes.find(hero => hero.identity === 0);
    expect(recovered).toMatchObject({ arena: 'guild_house', selected: true, ghost: false, defeated: false });
    expect(recovered.cell, 'The occupied default respawn tile is skipped').not.toEqual([30, 15]);
    expect(recovered.cell, 'The defeated hero cannot remain on its contact cell').not.toEqual([20, 9]);
    expect(state.heroes.find(hero => hero.identity === 1)).toMatchObject({ cell: [20, 9], ghost: true, defeated: false });
    expect(state.gathering).toMatchObject({ wood_total: 40, gold_total: 20 });
    expect(state.gathering.bags.map(bag => bag.hero_id)).toEqual([1]);
    expect(state.gathering.visual.visible).toBe(false);
    expectSafeLivingCells(state);
    await page.screenshot({ path: testInfo.outputPath('selected-contact-safe-respawn.png') });
    await saveAndTitle(page, log);
    const saved = await readSave(page);
    expect(saved.document.run_id).toBe(original.document.run_id);
    expect(saved.payload.run.gathering).toMatchObject({ wood_total: '40', gold_total: '20' });
    expect(saved.payload.run.gathering.bags.map(bag => bag.hero_id)).toEqual([1]);
    expect(saved.payload.world.arenas.guild_house.active).toEqual(['hero:1']);
    state = await continueSlot(page, log);
    expect(state.heroes.find(hero => hero.identity === 0)).toMatchObject(recovered);
    expect(state.gathering.bags.map(bag => bag.hero_id)).toEqual([1]);
    expectSafeLivingCells(state);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});
