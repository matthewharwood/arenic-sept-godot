import { test, expect } from '@playwright/test';
import { createHash } from 'node:crypto';
import { watch, loadGame, renderedPixels, readTitleButton, clickTitleButton, clickLogical, openControlsGuide, clickHudMenuAction, attachResults, completeIntroduction, enterProbeWorld, GAME, PROBE } from './helpers.mjs';

test.use({ viewport: { width: 640, height: 360 }, deviceScaleFactor: 1 });
test.describe.configure({ timeout: 240_000 });

const DATABASE = 'arenic-saves';
const MARGINS = [[0.995, 0.1], [0.995, 0.9]];

// Read the application's real browser store. No game state or clock mutation.
async function records(page, name = DATABASE) {
  return page.evaluate(name => new Promise((resolve, reject) => {
    const request = indexedDB.open(name, 1);
    request.onupgradeneeded = () => request.result.createObjectStore('slots');
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const db = request.result;
      const tx = db.transaction('slots', 'readonly');
      const store = tx.objectStore('slots');
      const keys = store.getAllKeys();
      const values = store.getAll();
      tx.oncomplete = () => { db.close(); resolve(Object.fromEntries(keys.result.map((key, i) => [key, values.result[i]]))); };
      tx.onabort = () => { db.close(); reject(tx.error); };
    };
  }), name);
}

// Explicit fault/legacy fixture boundary; normal save flows use actual controls.
async function putRecords(page, entries, name = DATABASE) {
  await page.evaluate(({ name, entries }) => new Promise((resolve, reject) => {
    const request = indexedDB.open(name, 1);
    request.onupgradeneeded = () => request.result.createObjectStore('slots');
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const db = request.result;
      const tx = db.transaction('slots', 'readwrite');
      for (const [slot, value] of entries) tx.objectStore('slots').put(value, slot);
      tx.oncomplete = () => { db.close(); resolve(); };
      tx.onabort = () => { db.close(); reject(tx.error); };
    };
  }), { name, entries });
}

function decode(raw) {
  const document = JSON.parse(raw);
  return { document, payload: JSON.parse(document.payload_json) };
}

function encodeFixture({ document, payload }) {
  document.payload_json = JSON.stringify(payload);
  document.checksum = createHash('sha256').update(document.payload_json).digest('hex');
  return JSON.stringify(document);
}

// Relocate a real committed founder through the normal save-validation boundary.
// Simulation, harvesting and commits after loading still use the actual game.
function gatheringFounderAt(saved, cell) {
  const fixture = structuredClone(saved);
  const hero = fixture.payload.run.heroes[0];
  const actor = `hero:${hero.identity}`;
  const ally = fixture.payload.run.combat.arenas[hero.arena_id].allies[actor];
  delete fixture.payload.run.combat.arenas[hero.arena_id].allies[actor];
  Object.assign(hero, { arena_id: 'guild_house', cell: [...cell], selected: true });
  fixture.payload.run.combat.arenas.guild_house.allies[actor] = {
    ...ally, cell: [...cell], health: ally.max_health,
  };
  fixture.payload.run.selected_identity = hero.identity;
  fixture.payload.run.arena_selection = { guild_house: hero.identity };
  fixture.payload.world.selected_index = 1;
  fixture.payload.world.zoomed = true;
  return fixture;
}

async function reload(page, log) {
  const consoleStart = log.console.length;
  log.events.length = 0;
  log.ready = false;
  await page.reload();
  await expect(page.locator('#canvas')).toBeVisible();
  await expect.poll(() => log.console.slice(consoleStart).some(row => row.text.startsWith('Build configuration:')), { timeout: 60_000 }).toBe(true);
  await expect(page.locator('#status')).toBeHidden();
  log.downloads = await page.evaluate(() => window.__arenicDownloads);
  log.ready = true;
}

async function readyTitle(log) {
  return log.wait(state => state?.scene === 'title' && !state.picker?.visible && state.saves.ready && !state.saves.busy && !state.controls.start.disabled,
    'Title waits for save storage hydration');
}

async function newPending(page, log) {
  const title = await readyTitle(log);
  await clickLogical(page, title, title.controls.start.center);
  return log.wait(state => state?.scene === 'classes' && state.saves.active_slot >= 0 && !state.saves.busy,
    'Start commits a pending character-creation slot');
}

async function openPicker(page, log, control = 'continue') {
  let state = await readyTitle(log);
  expect(state.controls[control].visible).toBe(true);
  await clickLogical(page, state, state.controls[control].center);
  state = await log.wait(value => value?.picker?.visible && value.picker.rows.length === 8 && !value.picker.working,
    'Save picker exposes all eight slots');
  return state;
}

async function chooseSlot(page, log, slot = 0) {
  const state = await openPicker(page, log);
  const row = state.picker.rows.find(row => row.slot === slot);
  expect(row.choose.disabled).toBe(false);
  await clickLogical(page, state, row.choose.center);
}

async function paper(page, classes = false) {
  await expect.poll(async () => (await renderedPixels(page, MARGINS)).every(pixel =>
    pixel.slice(0, 3).every(value => classes ? value >= 253 : value >= 215 && value <= 250)),
  { timeout: 60_000, message: classes ? 'Class selection is visibly rendered' : 'Title is visibly rendered' }).toBe(true);
}

// Hold the first real app read completion on each navigation. This exposes the
// actual loading UI deterministically, without slowing rendering or faking IDB.
async function holdInitialHydration(page) {
  await page.addInitScript(() => {
    const completion = Object.getOwnPropertyDescriptor(IDBTransaction.prototype, 'oncomplete');
    let held = false;
    Object.defineProperty(IDBTransaction.prototype, 'oncomplete', {
      ...completion,
      set(callback) {
        if (!held && this.db.name === 'arenic-saves' && this.mode === 'readonly') {
          held = true;
          completion.set.call(this, event => {
            window.__releaseHydrationRead = () => {
              delete window.__releaseHydrationRead;
              callback.call(this, event);
            };
          });
        } else completion.set.call(this, callback);
      },
    });
  });
}

async function releaseObservedHydration(page) {
  await page.waitForFunction(() => typeof window.__releaseHydrationRead === 'function');
  expect((await readTitleButton(page, 'start')).ready, 'Pending hydration renders disabled Start').toBe(false);
  expect((await readTitleButton(page, 'continue')).ready, 'Pending hydration hides Continue').toBe(false);
  await page.evaluate(() => window.__releaseHydrationRead());
}

test('clean production: saved run survives reload and Continue opens its slot', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await holdInitialHydration(page);
    await loadGame(page, GAME, log);
    await paper(page);
    await releaseObservedHydration(page);
    expect(await records(page)).toEqual({});
    await clickTitleButton(page, 'start');
    await paper(page, true);
    await expect.poll(async () => Object.keys(await records(page))).toEqual(['0']);
    const original = decode((await records(page))[0]);
    expect(original.document.run_id).toMatch(/^[0-9a-f]{64}$/);
    expect(original.payload.scene).toBe('class_selection');
    await reload(page, log);
    await paper(page);
    await releaseObservedHydration(page);
    await clickTitleButton(page, 'continue');
    await expect.poll(async () => (await renderedPixels(page, MARGINS)).every(pixel =>
      pixel.slice(0, 3).every(value => value > 20 && value < 110)),
    { timeout: 20_000, message: 'Continue visibly opens the shaded save picker' }).toBe(true);
    // Shipping picker is centered with a 660-wide panel. The first Choose
    // row is at this authored offset, confirmed by the rendered picker.
    const box = await page.locator('#canvas').boundingBox();
    const scale = Math.min(box.width / 1440, box.height / 1024);
    await page.mouse.click(box.x + box.width / 2 - 52 * scale, box.y + box.height / 2 - 176 * scale);
    await paper(page, true);
    const resumed = decode((await records(page))[0]);
    expect(resumed.document.run_id).toBe(original.document.run_id);
    expect(resumed.payload.run).toEqual(original.payload.run);
    await page.screenshot({ path: testInfo.outputPath('clean-continued-save.png') });
    expect(log.events, 'Production contains no private probe').toHaveLength(0);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

test('saved world and in-flight recording resume through title and browser restart', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await loadGame(page, PROBE, log);
    const title = await readyTitle(log);
    expect(title.controls.continue.visible).toBe(false);
    let state = await newPending(page, log);
    const identity = decode((await records(page))[0]).document.run_id;
    await clickLogical(page, state, state.cards[3].center);
    state = await log.wait(value => value?.selected_index === 3 && value.scene === 'classes');
    await clickLogical(page, state, state.controls.confirm.center);
    state = await log.wait(value => value?.scene === 'world' && !value.motion_active);
    await completeIntroduction(page, log);
    for (let i = 0; i < 3; i++) {
      await page.keyboard.press('ArrowLeft');
      await log.wait(value => value?.hero?.cell[0] === 32 - i);
    }
    await page.keyboard.press('Tab');
    await log.wait(value => value?.zoomed && !value.motion_active);
    await page.keyboard.press('ArrowRight');
    await log.wait(value => value?.hero.cell[0] === 31);
    await page.keyboard.press('r');
    await log.wait(value => value?.recording.state === 'recording');
    await page.keyboard.press('ArrowRight');
    state = await log.wait(value => value?.hero.cell[0] === 32 && value.recording.captured > 0);
    const revision = state.saves.revision;
    // Continuous simulation and a running draft must still reach a periodic checkpoint.
    await expect.poll(async () => decode((await records(page))[0]).document.revision,
      { timeout: 30_000 }).toBeGreaterThan(revision);
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const saved = decode((await records(page))[0]);
    expect(saved.payload.run.heroes[0]).toMatchObject({ class_id: 'warrior', cell: [32, 15] });
    expect(saved.payload.world.session.events.length).toBeGreaterThan(0);
    await chooseSlot(page, log);
    state = await log.wait(value => value?.scene === 'world' && value.recording.state === 'recording' && !value.motion_active);
    expect(state.hero).toMatchObject({ class_id: 'warrior', cell: [32, 15], identity: 0 });
    expect(state.recording.captured).toBe(saved.payload.world.session.events.length);
    expect(state.saves.run_id).toBe(identity);
    expect(state.zoomed).toBe(true);
    await reload(page, log);
    await chooseSlot(page, log);
    state = await log.wait(value => value?.scene === 'world' && value.recording.state === 'recording');
    expect(state.hero.cell).toEqual([32, 15]);
    expect(state.recording.captured).toBe(saved.payload.world.session.events.length);
    expect(state.saves.run_id).toBe(identity);
    await page.screenshot({ path: testInfo.outputPath('continued-recording.png') });
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

test('active Auto Shot reload retains its frozen flight and migrates the legacy duration', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    let state = await enterProbeWorld(page, log, 0);
    await page.keyboard.press('Tab');
    state = await log.wait(value => value?.zoomed && value.hero.selected && !value.motion_active);
    const caster = `hero:${state.hero.identity}`;
    state = await openControlsGuide(page, log);
    // Resolve layout before firing: tracing a bounding-box lookup took 424ms
    // on software WebGL, longer than the released arrow's remaining flight.
    const canvas = await page.locator('#canvas').boundingBox();
    expect(canvas).toBeTruthy();
    const [width, height] = state.logical;
    const scale = Math.min(canvas.width / width, canvas.height / height);
    const savePoint = [
      canvas.x + (canvas.width - width * scale) / 2 + state.controls.save_title.center[0] * scale,
      canvas.y + (canvas.height - height * scale) / 2 + state.controls.save_title.center[1] * scale,
    ];
    await page.mouse.move(...savePoint);
    // Observe the first released-shot snapshot directly. A polling interval
    // could consume the entire flight before the real Save/Title click arrives.
    const released = page.waitForEvent('console', {
      timeout: 20_000,
      predicate: message => {
        if (!message.text().startsWith('ARENIC_CI ')) return false;
        const event = JSON.parse(message.text().slice(10));
        return event.kind === 'state' && event.data?.combat?.active_cast?.released
          && event.data.combat.starter_ability_id === 'auto_shot';
      },
    });
    await page.keyboard.press('1');
    await released;
    await page.mouse.click(...savePoint);
    await readyTitle(log);
    const saved = decode((await records(page))[0]);
    const shot = saved.payload.run.combat.casts[caster];
    expect(saved.payload.schema_version).toBe(11);
    expect(shot).toMatchObject({ ability_id: 'auto_shot', origin: [30, 15], target_cell: [30, 22], released: true });
    expect(shot.resolve_seconds).toBeCloseTo(0.26 + 7 / 16, 6);
    expect(shot.elapsed).toBeGreaterThanOrEqual(shot.release_seconds);
    expect(shot.elapsed).toBeLessThan(shot.resolve_seconds);
    expect(saved.payload.run.combat.arenas.guild_house.damage).toBe('0');

    const assertResumedFlight = async duration => {
      await reload(page, log);
      await chooseSlot(page, log);
      const observed = () => log.events.find(event => event.kind === 'state'
        && event.data?.scene === 'world' && event.data.combat?.active_cast?.id === Number(shot.cast_id));
      await expect.poll(observed, { message: 'Continue exposes the restored cast before its hit' }).toBeTruthy();
      const resumed = observed().data;
      expect(resumed.saves.run_id).toBe(saved.document.run_id);
      expect(resumed.combat.active_cast).toMatchObject({ origin: shot.origin, target: shot.target_cell, released: true });
      expect(resumed.combat.active_cast.resolve_seconds).toBeCloseTo(duration, 6);
      expect(resumed.combat.active_elapsed).toBeGreaterThanOrEqual(shot.elapsed);
      state = await log.wait(value => value?.combat && !value.combat.active && value.combat.totals.guild_house === 1,
        'The restored shot lands exactly once without another attack');
      await clickHudMenuAction(page, log, 'save_title');
      await readyTitle(log);
      const committed = decode((await records(page))[0]);
      expect(committed.payload.schema_version).toBe(11);
      expect(committed.document.run_id).toBe(saved.document.run_id);
      expect(committed.payload.run.combat.casts).toEqual({});
      expect(committed.payload.run.combat.arenas.guild_house.damage).toBe('1');
    };
    await assertResumedFlight(shot.resolve_seconds);

    // Schema 3 froze elapsed/release but had a fixed 0.75-second total. Keep
    // the real accepted shot and remove only the field that did not yet exist.
    for (const arena of Object.values(saved.payload.world.arenas ?? {})) delete arena.restart_pending;
    saved.payload.schema_version = 3;
    delete saved.payload.run.loot;
    delete saved.payload.run.combat.encounter;
    delete saved.payload.run.gathering;
    delete saved.payload.run.combat.enemy_dots;
    for (const cast of Object.values(saved.payload.run.combat.casts)) delete cast.resolve_seconds;
    saved.document.payload_json = JSON.stringify(saved.payload);
    saved.document.checksum = createHash('sha256').update(saved.document.payload_json).digest('hex');
    await putRecords(page, [[0, JSON.stringify(saved.document)]]);
    await assertResumedFlight(0.75);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

test('saved Acid Flask retains its caster, while a legacy pool stays honestly unknown', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    let state = await enterProbeWorld(page, log, 5);
    expect(state.hero.class_id).toBe('alchemist');
    const owner = { identity: state.hero.identity, name: state.hero.name };
    await page.keyboard.press('Tab');
    state = await log.wait(value => value?.zoomed && value.hero.selected && !value.motion_active);
    // The construct begins at row 22. A real north-facing flask from row 19
    // lands on its footprint; use slot 1 while near the Keeper's Space prompt.
    for (let y = 16; y <= 19; y++) {
      await page.keyboard.press('ArrowUp');
      await log.wait(value => value?.hero?.cell[1] === y, `Walk Alchemist to row ${y}`);
    }
    await page.keyboard.press('1');
    state = await log.wait(value => value?.combat?.totals.guild_house > 0,
      'The actual thrown flask leaves a damaging pool');
    expect(state.combat.boss_effects).toEqual(expect.arrayContaining([
      expect.objectContaining({ id: 'acid', name: 'Acid', stacks: 1, beneficial: false }),
    ]));
    expect(state.hud.top.effects.text).toContain('Acid');
    // Save at the first burn so the eight-second pool has time left on reload.
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const saved = decode((await records(page))[0]);
    expect(saved.payload.schema_version).toBe(11);
    expect(saved.payload.world.arenas.guild_house.pools).toHaveLength(1);
    const pool = saved.payload.world.arenas.guild_house.pools[0];
    expect(pool).toMatchObject({ caster_id: `hero:${owner.identity}` });
    expect(pool.ticks_left).toBeGreaterThan(0);
    const runId = saved.document.run_id;

    await reload(page, log);
    await chooseSlot(page, log);
    state = await log.wait(value => value?.scene === 'world' && value.hud.chat.entries.some(entry =>
      entry.kind === 'damage' && entry.ability_id === 'acid_flask'),
      'The restored pool burns without another cast or injected game input');
    expect(state.hero).toMatchObject(owner);
    expect(state.saves.run_id).toBe(runId);
    const attributed = state.hud.chat.entries.find(entry => entry.kind === 'damage' && entry.ability_id === 'acid_flask');
    expect(attributed).toMatchObject({ hero_id: owner.identity, hero_name: owner.name,
      ability_id: 'acid_flask', ability_name: 'Acid Flask', arena_id: 'guild_house' });
    expect(attributed.amount).toBeGreaterThan(0);
    expect(attributed.text).toBe(`${owner.name} · Acid Flask · ${attributed.amount} damage · Guild House`);
    await page.screenshot({ path: testInfo.outputPath('restored-owned-acid-flask.png') });
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);

    // Compatibility fixture uses the earlier real commit, including its live
    // hazard debt and remaining lifetime. Only schema-3 ownership is removed.
    for (const arena of Object.values(saved.payload.world.arenas ?? {})) delete arena.restart_pending;
    saved.payload.schema_version = 2;
    delete saved.payload.run.loot;
    delete saved.payload.run.combat.encounter;
    delete saved.payload.run.gathering;
    delete saved.payload.run.combat.enemy_dots;
    for (const cast of Object.values(saved.payload.run.combat.casts)) delete cast.resolve_seconds;
    for (const arena of Object.values(saved.payload.world.arenas)) {
      arena.ground.dug = arena.ground.dug.map(entry => entry.slice(0, 2));
      for (const hazard of arena.pools) delete hazard.caster_id;
    }
    saved.document.payload_json = JSON.stringify(saved.payload);
    saved.document.checksum = createHash('sha256').update(saved.document.payload_json).digest('hex');
    await putRecords(page, [[0, JSON.stringify(saved.document)]]);
    await reload(page, log);
    await chooseSlot(page, log);
    state = await log.wait(value => value?.scene === 'world' && value.hud.chat.entries.some(entry =>
      entry.kind === 'damage' && entry.ability_id === 'acid_flask'),
      'A migrated pool still burns with its missing historical owner explicit');
    expect(state.hero).toMatchObject(owner);
    expect(state.saves.run_id).toBe(runId);
    const unknown = state.hud.chat.entries.find(entry => entry.kind === 'damage' && entry.ability_id === 'acid_flask');
    expect(unknown).toMatchObject({ hero_id: -1, hero_name: '',
      ability_id: 'acid_flask', ability_name: 'Acid Flask', arena_id: 'guild_house' });
    expect(unknown.amount).toBeGreaterThan(0);
    expect(unknown.text).toBe(`Unknown hero · Acid Flask · ${unknown.amount} damage · Guild House`);
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const migrated = decode((await records(page))[0]);
    expect(migrated.payload.schema_version).toBe(11);
    expect(migrated.document.run_id).toBe(runId);
    expect(migrated.payload.world.arenas.guild_house.pools).toHaveLength(1);
    expect(migrated.payload.world.arenas.guild_house.pools.every(hazard => hazard.caster_id === '')).toBe(true);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

test('gathering bags preserve real fill and paused unloading through IndexedDB reload', async ({ page }, testInfo) => {
  const log = watch(page);
  const bag = state => state?.gathering?.bags?.find(value => value.hero_id === state.hero.identity);
  try {
    await enterProbeWorld(page, log, 3);
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const initial = decode((await records(page))[0]);
    // One step outside the authored radius leaves time to prepare a real
    // Save/Title click without losing the five-second fill window to UI layout.
    const atSource = gatheringFounderAt(initial, [15, 9]);
    atSource.payload.run.gathering = { wood_total: '17', gold_total: '23', bags: [] };
    await putRecords(page, [[0, encodeFixture(atSource)]]);
    await reload(page, log);
    await chooseSlot(page, log);
    let state = await log.wait(s => s?.scene === 'world' && s.hero.cell[0] === 15 && !s.motion_active);
    expect(state.gathering).toMatchObject({ wood_total: 17, gold_total: 23, bags: [] });
    expect(state.gathering.sites.filter(site => site.role === 'source' && site.kind === 'wood')).toHaveLength(2);
    expect(state.gathering.sites.filter(site => site.role === 'source' && site.kind === 'gold')).toHaveLength(2);
    state = await openControlsGuide(page, log);
    const canvas = await page.locator('#canvas').boundingBox();
    expect(canvas).toBeTruthy();
    const scale = Math.min(canvas.width / state.logical[0], canvas.height / state.logical[1]);
    const savePoint = [
      canvas.x + (canvas.width - state.logical[0] * scale) / 2 + state.controls.save_title.center[0] * scale,
      canvas.y + (canvas.height - state.logical[1] * scale) / 2 + state.controls.save_title.center[1] * scale,
    ];
    await page.mouse.move(...savePoint);
    await page.keyboard.press('ArrowLeft');
    await expect.poll(() => bag(log.latest())?.fill_ticks ?? 0,
      { intervals: [20, 50, 100], message: 'Real proximity work advances the founder’s partial bag' }).toBeGreaterThanOrEqual(60);
    await page.mouse.click(...savePoint);
    await readyTitle(log);
    const partial = decode((await records(page))[0]);
    const partialBag = partial.payload.run.gathering.bags[0];
    expect(partialBag).toMatchObject({ hero_id: 0, kind: 'wood', fill_duration_ticks: 300,
      unload_ticks: 0, unload_duration_ticks: 60, capacity_units: 10 });
    expect(partialBag.fill_ticks).toBeGreaterThanOrEqual(60);
    expect(partialBag.fill_ticks).toBeLessThan(300);
    expect(partial.payload.run.gathering).toMatchObject({ wood_total: '17', gold_total: '23' });
    await reload(page, log);
    await chooseSlot(page, log);
    state = await log.wait(s => s?.scene === 'world' && bag(s));
    expect(bag(state)).toMatchObject({ kind: 'wood', fill_duration_ticks: partialBag.fill_duration_ticks,
      unload_duration_ticks: partialBag.unload_duration_ticks, capacity_units: partialBag.capacity_units });
    expect(bag(state).fill_ticks).toBeGreaterThanOrEqual(partialBag.fill_ticks);
    await log.wait(s => s?.gathering?.hero.phase === 'full' && bag(s)?.fill_ticks === 300,
      'Reload resumes the remaining real gathering work until the bag is full');
    expect(log.latest().gathering).toMatchObject({ wood_total: 17, gold_total: 23 });
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const full = decode((await records(page))[0]);
    expect(full.payload.run.gathering.bags[0]).toMatchObject({ ...partialBag, fill_ticks: 300 });

    // A valid saved decision freezes a legitimate halfway unload. This isolates
    // the short remaining half-second from browser/export startup and observes
    // the production autosave before reloading that exact checkpoint.
    const woodDropoff = state.gathering.sites.find(site => site.role === 'dropoff' && site.kind === 'wood').cell;
    const unloading = gatheringFounderAt(full, woodDropoff);
    unloading.payload.run.gathering.bags[0].unload_ticks = 30;
    unloading.payload.world.arenas.guild_house.paused = true;
    unloading.payload.world.modal = { arena_id: 'guild_house', title: 'Resume unloading?',
      detail: 'Continue this saved Guild House work.', options: [['Continue', 'cancel']], focused: 0, context: {} };
    await putRecords(page, [[0, encodeFixture(unloading)]]);
    await reload(page, log);
    await chooseSlot(page, log);
    state = await log.wait(s => s?.scene === 'world' && s.recording.modal_open && s.gathering.hero.phase === 'unloading');
    expect(bag(state)).toMatchObject({ ...full.payload.run.gathering.bags[0], unload_ticks: 30 });
    await expect.poll(async () => decode((await records(page))[0]).document.revision,
      { timeout: 30_000, message: 'Production autosave commits the paused unload checkpoint' }).toBeGreaterThan(unloading.document.revision);
    const paused = decode((await records(page))[0]);
    expect(paused.payload.run.gathering).toEqual(unloading.payload.run.gathering);
    expect(paused.payload.world.arenas.guild_house.paused).toBe(true);
    await reload(page, log);
    await chooseSlot(page, log);
    state = await log.wait(s => s?.scene === 'world' && s.recording.modal_open);
    expect(state.gathering).toMatchObject({ wood_total: 17, gold_total: 23 });
    expect(bag(state)).toEqual(paused.payload.run.gathering.bags[0]);
    expect(state.gathering.hero).toMatchObject({ phase: 'unloading', progress: 0.5, amount: 10 });
    const resumedAt = state.recording.cycle;
    const sequence = log.events.at(-1).sequence;
    await page.keyboard.press('Enter');
    await log.wait(s => s?.gathering?.wood_total === 27 && s.gathering.bags.length === 0,
      'The real Continue action resumes and deposits the saved bag exactly once');
    await log.wait(s => s?.recording?.cycle >= resumedAt + 90);
    const observations = log.events.filter(event => event.kind === 'state' && event.sequence > sequence
      && event.data.scene === 'world' && event.data.recording.cycle > resumedAt).map(event => event.data);
    expect(observations.some(s => s.recording.cycle < resumedAt + 30)).toBe(true);
    expect(observations.some(s => s.recording.cycle >= resumedAt + 30)).toBe(true);
    for (const observed of observations) {
      const elapsed = observed.recording.cycle - resumedAt;
      if (elapsed < 30) {
        expect(observed.gathering.wood_total).toBe(17);
        expect(bag(observed).unload_ticks).toBe(30 + elapsed);
      } else {
        expect(observed.gathering).toMatchObject({ wood_total: 27, gold_total: 23, bags: [] });
      }
    }
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const deposited = decode((await records(page))[0]);
    expect(deposited.document.run_id).toBe(initial.document.run_id);
    expect(deposited.payload.run.gathering).toEqual({ wood_total: '27', gold_total: '23', bags: [] });
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

test('schema-five guild migrates empty gathering and separates overlapping living heroes', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await enterProbeWorld(page, log, 3);
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const saved = decode((await records(page))[0]);
    const legacy = gatheringFounderAt(saved, [18, 6]);
    const founder = legacy.payload.run.heroes[0];
    const recruit = { ...structuredClone(founder), identity: 1, selected: false };
    legacy.payload.run.heroes.push(recruit);
    legacy.payload.run.next_identity = 2;
    legacy.payload.run.combat.arenas.guild_house.allies['hero:1'] =
      structuredClone(legacy.payload.run.combat.arenas.guild_house.allies[`hero:${founder.identity}`]);
    for (const arena of Object.values(legacy.payload.world.arenas ?? {})) delete arena.restart_pending;
    legacy.payload.schema_version = 5;
    delete legacy.payload.run.loot;
    delete legacy.payload.run.combat.encounter;
    delete legacy.payload.run.gathering;
    await putRecords(page, [[0, encodeFixture(legacy)]]);
    await reload(page, log);
    await chooseSlot(page, log);
    let state = await log.wait(s => s?.scene === 'world' && s.heroes?.length === 2 && !s.motion_active,
      'A released schema-five record hydrates through normal migration');
    expect(state.heroes.every(hero => !hero.defeated)).toBe(true);
    expect(state.heroes.find(hero => hero.identity === founder.identity).cell).toEqual([18, 6]);
    expect(new Set(state.heroes.map(hero => `${hero.arena}:${hero.cell.join(',')}`)).size).toBe(2);
    expect(state.gathering).toMatchObject({ wood_total: 0, gold_total: 0, bags: [] });
    const resumedAt = state.recording.cycle;
    await log.wait(s => s?.recording?.cycle >= resumedAt + 90);
    expect(log.latest().gathering).toMatchObject({ wood_total: 0, gold_total: 0, bags: [] });
    expect(log.latest().heroes.every(hero => !hero.defeated)).toBe(true);
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const migrated = decode((await records(page))[0]);
    expect(migrated.document.run_id).toBe(saved.document.run_id);
    expect(migrated.payload.schema_version).toBe(11);
    expect(migrated.payload.run.gathering).toEqual({ wood_total: '0', gold_total: '0', bags: [] });
    expect(migrated.payload.run.prospected).toBe(saved.payload.run.prospected);
    expect(migrated.payload.run.combat.arenas.guild_house.damage).toBe(saved.payload.run.combat.arenas.guild_house.damage);
    expect(migrated.payload.run.heroes.map(hero => hero.identity)).toEqual([0, 1]);
    expect(migrated.payload.run.heroes.every(hero => JSON.stringify(hero.recordings) === JSON.stringify(founder.recordings))).toBe(true);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

test('eight unique slots enforce capacity and require deletion confirmation', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await loadGame(page, PROBE, log);
    for (let slot = 0; slot < 8; slot++) {
      const state = await newPending(page, log);
      expect(state.saves.active_slot).toBe(slot);
      await clickLogical(page, state, state.controls.back.center);
      await readyTitle(log);
    }
    const full = await records(page);
    expect(Object.keys(full)).toHaveLength(8);
    expect(new Set(Object.values(full).map(raw => decode(raw).document.run_id)).size).toBe(8);
    let state = await readyTitle(log);
    await clickLogical(page, state, state.controls.start.center);
    state = await log.wait(value => value?.picker?.visible && value.saves.error.includes('eight'));
    expect(await records(page)).toEqual(full);
    await page.screenshot({ path: testInfo.outputPath('eight-save-slots.png') });
    await clickLogical(page, state, state.picker.rows[3].remove.center);
    state = await log.wait(value => value?.picker?.confirm.visible);
    expect(await records(page)).toEqual(full);
    await clickLogical(page, state, state.picker.back.center);
    state = await log.wait(value => value?.picker?.visible && !value.picker.confirm.visible);
    expect(await records(page)).toEqual(full);
    await clickLogical(page, state, state.picker.rows[3].remove.center);
    state = await log.wait(value => value?.picker?.confirm.visible);
    await clickLogical(page, state, state.picker.confirm.center);
    await expect.poll(async () => Object.keys(await records(page))).toHaveLength(7);
    state = await log.wait(value => value?.picker?.rows[3].choose.disabled && value.picker.rows[3].remove.disabled);
    await clickLogical(page, state, state.picker.back.center);
    const replacement = await newPending(page, log);
    expect(replacement.saves.active_slot).toBe(3);
    expect(decode((await records(page))[3]).document.run_id).not.toBe(decode(full[3]).document.run_id);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

test('malformed and future-version records survive hydration and can be deliberately removed', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await loadGame(page, PROBE, log);
    const pending = await newPending(page, log);
    await clickLogical(page, pending, pending.controls.back.center);
    await readyTitle(log);
    const future = decode((await records(page))[0]).document;
    future.slot = 1;
    future.format_version = 999;
    const fixtures = [[0, '{damaged-save'], [1, JSON.stringify(future)]];
    await putRecords(page, fixtures);
    await reload(page, log);
    let state = await readyTitle(log);
    expect(state.controls.continue.visible).toBe(false);
    expect(await records(page)).toEqual(Object.fromEntries(fixtures));
    state = await openPicker(page, log, 'manage');
    expect(state.picker.rows.slice(0, 2).every(row => row.choose.disabled && !row.remove.disabled)).toBe(true);
    await clickLogical(page, state, state.picker.rows[0].remove.center);
    state = await log.wait(value => value?.picker?.confirm.visible);
    await clickLogical(page, state, state.picker.confirm.center);
    await expect.poll(async () => records(page)).toEqual({ 1: fixtures[1][1] });
    state = await log.wait(value => value?.picker?.rows[0].remove.disabled);
    await clickLogical(page, state, state.picker.back.center);
    const created = await newPending(page, log);
    expect(created.saves.active_slot).toBe(0);
    expect((await records(page))[1]).toBe(fixtures[1][1]);
    const supported = (await records(page))[0];
    await clickLogical(page, created, created.controls.back.center);
    state = await openPicker(page, log);
    await clickLogical(page, state, state.picker.rows[1].remove.center);
    state = await log.wait(value => value?.picker?.confirm.visible);
    expect((await records(page))[1]).toBe(fixtures[1][1]);
    await clickLogical(page, state, state.picker.confirm.center);
    await expect.poll(() => records(page)).toEqual({ 0: supported });
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

test('localhost development seed is deterministic and isolated from player saves', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await loadGame(page, `${PROBE}?dev_seed=42`, log);
    await readyTitle(log);
    const before = await records(page, 'arenic-saves-dev');
    expect(Object.keys(before)).toEqual(['0']);
    const fixture = decode(before[0]);
    expect(fixture.document.seed).toBe(42);
    expect(fixture.payload.run.heroes).toHaveLength(3);
    expect(fixture.payload.run.prospected).toBe('120');
    expect(await records(page)).toEqual({});
    await chooseSlot(page, log);
    const state = await log.wait(value => value?.scene === 'world');
    expect(state.saves.run_id).toBe(fixture.document.run_id);
    await reload(page, log);
    await readyTitle(log);
    const continued = decode((await records(page, 'arenic-saves-dev'))[0]);
    expect(continued.document.run_id).toBe(fixture.document.run_id);
    expect(continued.payload.run.heroes.map(hero => hero.class_id)).toEqual(fixture.payload.run.heroes.map(hero => hero.class_id));
    let picker = await openPicker(page, log);
    await clickLogical(page, picker, picker.picker.rows[0].remove.center);
    picker = await log.wait(value => value?.picker?.confirm.visible);
    await clickLogical(page, picker, picker.picker.confirm.center);
    await expect.poll(() => records(page, 'arenic-saves-dev')).toEqual({});
    await reload(page, log);
    await readyTitle(log);
    const regenerated = decode((await records(page, 'arenic-saves-dev'))[0]);
    expect(regenerated.document.run_id).not.toBe(fixture.document.run_id);
    expect(regenerated.payload.run.heroes).toEqual(fixture.payload.run.heroes);
    expect(regenerated.payload.run.prospected).toBe('120');
    expect(await records(page)).toEqual({});
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

test('recruitment counter remains visible while banked rolls are claimed', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await loadGame(page, `${PROBE}?dev_seed=42`, log);
    await chooseSlot(page, log);
    let state = await log.wait(value => value?.scene === 'world' && value.hud?.recruitment?.ready.visible);
    const assertCounter = (state, rolls) => {
      const { counter, ready } = state.hud.recruitment;
      expect(counter.visible).toBe(true);
      expect(counter.text).toBe('Next hero 16/102');
      expect(counter.tooltip).toContain('Next hero 16 / 102');
      expect(counter.rect[1]).toBeGreaterThanOrEqual(0);
      expect(counter.rect[0]).toBeGreaterThan(state.logical[0] / 2);
      expect(counter.rect[1] + counter.rect[3]).toBeLessThanOrEqual(state.world_rect[1]);
      expect(ready.visible).toBe(rolls > 0);
      expect(ready.disabled).toBe(rolls === 0);
      if (rolls > 0) {
        expect(ready.text).toBe(`${rolls} [N]`);
        const [cx, cy, cw, ch] = counter.rect;
        const [rx, ry, rw, rh] = ready.rect;
        expect(cx + cw <= rx || rx + rw <= cx || cy + ch <= ry || ry + rh <= cy,
          'Compact counter and recruitment action remain separate hitboxes').toBe(true);
        expect(ry).toBeGreaterThanOrEqual(0);
        expect(ry + rh).toBeLessThanOrEqual(state.world_rect[1]);
      }
    };
    assertCounter(state, 2);
    await page.screenshot({ path: testInfo.outputPath('recruitment-counter-and-rolls.png') });
    for (const remaining of [1, 0]) {
      await clickLogical(page, state, state.hud.recruitment.ready.center);
      state = await log.wait(value => value?.rewards?.mode === 'heroes' && value.rewards.cards.every(card => card.revealed && card.enabled));
      await clickLogical(page, state, state.rewards.cards[0].center);
      state = await log.wait(value => value?.scene === 'world' && !value.rewards.open
        && (remaining > 0 ? value.hud.recruitment.ready.text === `${remaining} [N]` : !value.hud.recruitment.ready.visible));
      assertCounter(state, remaining);
    }
    expect(state.hud.roster.count).toBe(5);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

test('failed storage and a competing revision preserve the committed save', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await loadGame(page, PROBE, log);
    let state = await newPending(page, log);
    const before = (await records(page))[0];
    await page.evaluate(() => {
      const original = IDBDatabase.prototype.transaction;
      IDBDatabase.prototype.transaction = function (stores, mode, ...rest) {
        if (this.name === 'arenic-saves' && mode === 'readwrite') throw new DOMException('Injected quota exhaustion', 'QuotaExceededError');
        return original.call(this, stores, mode, ...rest);
      };
      window.__restoreSaveTransactions = () => { IDBDatabase.prototype.transaction = original; };
    });
    await clickLogical(page, state, state.cards[2].center);
    state = await log.wait(value => value?.selected_index === 2 && value.scene === 'classes');
    await clickLogical(page, state, state.controls.back.center);
    state = await log.wait(value => value?.saves.error.includes('full'));
    expect(state.scene).toBe('classes');
    expect((await records(page))[0]).toBe(before);
    await page.evaluate(() => window.__restoreSaveTransactions());
    // Model another tab's successful commit; the running game's revision is stale.
    const newer = decode(before).document;
    newer.revision += 1;
    const replacement = JSON.stringify(newer);
    await putRecords(page, [[0, replacement]]);
    await clickLogical(page, state, state.controls.back.center);
    await log.wait(value => value?.saves.error.includes('another'));
    expect((await records(page))[0]).toBe(replacement);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});


test('introduction resumes its current beat and never replays after completion', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    let state = await enterProbeWorld(page, log, 0, { introduction: false });
    expect(state.introduction).toMatchObject({ step: 0, quote_visible: true, locked: true });
    expect(state.introduction.marker).toMatchObject({ state: 'hidden', visible: false });
    expect(state.hero.cell).toEqual([33, 15]);
    expect(state.zoomed).toBe(true);
    await page.keyboard.press('l');
    await page.keyboard.press('Escape');
    await page.keyboard.press('r');
    expect(log.latest().selected_index).toBe(1);
    expect(log.latest().recording.state).toBe('idle');
    state = await log.wait(value => value?.introduction?.elapsed >= 2);
    await clickLogical(page, state, state.introduction.begin_center);
    state = await log.wait(value => value?.introduction?.step === 1 && value.introduction.marker.visible);
    expect(state.introduction.marker).toMatchObject({ state: 'available', glyph: '!', actionable: true, kind: 'campaign' });
    await page.screenshot({ path: testInfo.outputPath('keeper-calling.png') });
    await clickLogical(page, state, state.introduction.marker.center, { delay: 350 });
    state = await log.wait(value => value?.introduction?.step === 2 && value.introduction.elapsed >= 2.75);
    expect(state.introduction.marker).toMatchObject({ state: 'accepted', glyph: '?', visible: true, actionable: false });
    await page.keyboard.press('Space');
    state = await log.wait(value => value?.introduction?.step === 3);
    expect(state.introduction.line).toContain('Move. Attack.');
    const savedLine = state.introduction.line;
    const runId = state.saves.run_id;
    await page.screenshot({ path: testInfo.outputPath('keeper-dialogue.png') });
    state = await openControlsGuide(page, log);
    expect(state.introduction).toMatchObject({ step: 3, dialogue_visible: true, locked: true });
    await clickHudMenuAction(page, log, 'toggle');
    state = await log.wait(value => value?.hud && !value.hud.guide.visible,
      'The menu Overview action closes the menu while the lesson keeps navigation locked');
    expect(state).toMatchObject({ selected_index: 1, zoomed: true });
    expect(state.introduction).toMatchObject({ step: 3, line: savedLine, dialogue_visible: true, locked: true });
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const savedBeat = decode((await records(page))[0]);
    expect(savedBeat.document.run_id).toBe(runId);
    expect(savedBeat.payload.run.intro_step).toBe(3);
    await chooseSlot(page, log);
    state = await log.wait(value => value?.scene === 'world' && value.introduction?.step === 3,
      'Continue resumes the exact dialogue beat saved through the visible H menu');
    expect(state.introduction).toMatchObject({ line: savedLine, dialogue_visible: true, quote_visible: false, locked: true });
    expect(state.introduction.marker).toMatchObject({ state: 'accepted', glyph: '?', visible: true });
    expect(state.saves.run_id).toBe(runId);
    expect(state.hud.guide.visible).toBe(false);
    await expect.poll(async () => decode((await records(page))[0]).payload.run.intro_step).toBe(3);
    await reload(page, log);
    await chooseSlot(page, log);
    state = await log.wait(value => value?.scene === 'world' && value.introduction?.step === 3);
    expect(state.introduction).toMatchObject({ quote_visible: false, locked: true });
    expect(state.zoomed).toBe(true);
    expect(state.introduction.marker).toMatchObject({ state: 'accepted', glyph: '?' });
    for (let step = 3; step <= 4; step++) {
      state = await log.wait(value => value?.introduction?.step === step && value.introduction.elapsed >= 2.75);
      await page.keyboard.press('Space');
      await log.wait(value => value?.introduction?.step === step + 1);
    }
    state = await log.wait(value => value?.introduction?.marker.state === 'ready');
    expect(state.introduction.marker).toMatchObject({ glyph: '?', visible: true });
    await page.screenshot({ path: testInfo.outputPath('keeper-ready.png') });
    await completeIntroduction(page, log);
    await expect.poll(async () => decode((await records(page))[0]).payload.run.intro_step).toBe(6);
    state = log.latest();
    expect(state.introduction.gate_animations).toEqual(['open', 'open', 'open']);
    expect(state.introduction.marker).toMatchObject({ state: 'hidden', visible: false });
    expect(state.introduction.talk_target_visible).toBe(true);
    await clickLogical(page, state, state.introduction.talk_center, { delay: 350 });
    state = await log.wait(value => value?.introduction?.dialogue_visible);
    expect(state.introduction.marker).toMatchObject({ state: 'hidden', visible: false });
    await page.keyboard.press('Space');
    state = await log.wait(value => value?.introduction && !value.introduction.dialogue_visible);
    await page.screenshot({ path: testInfo.outputPath('guild-doors-open.png') });
    await reload(page, log);
    await chooseSlot(page, log);
    state = await log.wait(value => value?.scene === 'world');
    expect(state.introduction).toMatchObject({ step: 6, quote_visible: false, locked: false });
    expect(state.introduction.marker).toMatchObject({ state: 'hidden', visible: false });
    await page.keyboard.press('l');
    await log.wait(value => value?.selected_index === 0);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

test('schema-one saved guild migrates with its introduction already complete', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    let state = await enterProbeWorld(page, log, 3);
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const current = decode((await records(page))[0]);
    for (const arena of Object.values(current.payload.world.arenas ?? {})) delete arena.restart_pending;
    current.payload.schema_version = 1;
    delete current.payload.run.loot;
    delete current.payload.run.combat.encounter;
    delete current.payload.run.gathering;
    delete current.payload.run.combat.enemy_dots;
    for (const cast of Object.values(current.payload.run.combat.casts)) delete cast.resolve_seconds;
    delete current.payload.run.intro_step;
    current.document.payload_json = JSON.stringify(current.payload);
    current.document.checksum = createHash('sha256').update(current.document.payload_json).digest('hex');
    const legacy = JSON.stringify(current.document);
    await putRecords(page, [[0, legacy]]);
    await reload(page, log);
    await chooseSlot(page, log);
    state = await log.wait(value => value?.scene === 'world');
    expect(state.introduction).toMatchObject({ step: 6, quote_visible: false, locked: false });
    expect(state.hero.class_id).toBe('warrior');
    expect(state.saves.run_id).toBe(current.document.run_id);
    await page.keyboard.press('l');
    await log.wait(value => value?.selected_index === 0);
    await expect.poll(async () => decode((await records(page))[0]).payload.schema_version).toBe(11);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

// Encounter fixture comes from a real schema-8 checkpoint and enters through
// the ordinary IndexedDB hydration/validation boundary. Once loaded, all
// channeling, damage, save/continue and restart actions use normal gameplay.
function labyrinthFixture(saved, ghost) {
  const fixture = structuredClone(saved);
  const { payload, document } = fixture;
  const hero = payload.run.heroes[0];
  const actor = `hero:${hero.identity}`;
  const cell = ghost ? [31, 24] : [22, 18];
  const ally = payload.run.combat.arenas.guild_house.allies[actor];
  delete payload.run.combat.arenas.guild_house.allies[actor];
  payload.run.combat.arenas.labyrinth.allies[actor] = { ...ally, cell, health: ally.max_health };
  Object.assign(hero, { arena_id: 'labyrinth', cell, selected: true, facing: 'e' });
  payload.run.arena_selection = { labyrinth: hero.identity };
  payload.run.combat.casts = {};
  payload.run.combat.cooldowns = {};
  payload.world.selected_index = 0;
  payload.world.zoomed = true;
  const arena = payload.world.arenas.labyrinth;
  arena.tick = ghost ? 390 : 240;
  if (ghost) {
    hero.recordings.labyrinth = { start_cell: cell, events: [] };
    arena.active = [actor];
    arena.orders[actor] = arena.next_order++;
  }
  document.payload_json = JSON.stringify(payload);
  document.checksum = createHash('sha256').update(document.payload_json).digest('hex');
  return JSON.stringify(document);
}

test('Sacrifice follows jumping boss; fallen ghost bursts, persists through save and revives', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await enterProbeWorld(page, log, 4);
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const saved = decode((await records(page))[0]);
    await putRecords(page, [[0, labyrinthFixture(saved, false)]]);
    await reload(page, log);
    await chooseSlot(page, log);
    let state = await log.wait(s => s?.scene === 'world' && s.arena === 'labyrinth' && !s.motion_active,
      'Validated encounter fixture loads in Labyrinth');
    await page.keyboard.down('Space');
    state = await log.wait(s => s?.combat?.channel.visible && s.combat.is_channeling,
      'Sacrifice connects to the authored Hunter boss');
    expect(state.combat.channel.target_id).toBe('boss:labyrinth');
    const connected = log.events.at(-1).sequence;
    await expect.poll(() => log.events.find(e => e.sequence > connected && e.data?.combat?.channel.visible
      && e.data.combat.boss_pose.airborne && e.data.combat.boss_pose.lift > 3),
    { timeout: 30_000, message: 'Beam is visible while the boss is high in its real jump' }).toBeTruthy();
    const flying = log.events.filter(e => e.sequence > connected && e.data?.combat?.channel.visible
      && e.data.combat.boss_pose.airborne && e.data.combat.boss_pose.lift > 1);
    expect(flying.length).toBeGreaterThan(1);
    for (const { data } of flying) {
      data.combat.channel.target.forEach((value, axis) =>
        expect(value).toBeCloseTo(data.combat.boss_pose.beam_endpoint[axis], 3));
    }
    await page.screenshot({ path: testInfo.outputPath('sacrifice-following-jump.png') });
    state = await log.wait(s => s?.combat?.channel.visible && !s.combat.boss_pose.airborne
      && s.recording.cycle >= 480, 'The tether reaches the newly landed boss');
    expect(state.combat.boss_pose.center).toEqual([32.5, 22.5]);
    state.combat.channel.target.forEach((value, axis) =>
      expect(value).toBeCloseTo(state.combat.boss_pose.beam_endpoint[axis], 3));
    await page.keyboard.up('Space');
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);

    await putRecords(page, [[0, labyrinthFixture(saved, true)]]);
    await reload(page, log);
    await chooseSlot(page, log);
    state = await log.wait(s => s?.scene === 'world' && s.recording.ghosts.length === 1,
      'A living folded ghost loads before the boss lands');
    expect(state.recording.ghosts[0].defeated).toBe(false);
    const beforeDeath = log.events.at(-1).sequence;
    await expect.poll(() => log.events.find(e => e.sequence > beforeDeath
      && e.data?.recording?.ghosts[0]?.fx_animation === 'burst'),
    { timeout: 30_000, message: 'Actual boss landing starts the ghost death burst' }).toBeTruthy();
    const burst = log.events.find(e => e.sequence > beforeDeath && e.data?.recording?.ghosts[0]?.fx_animation === 'burst').data;
    expect(burst.recording.ghosts[0]).toMatchObject({ defeated: true, body_visible: false,
      selection_visible: false, fx_visible: true, cell: [31, 24] });
    state = await log.wait(s => s?.recording?.ghosts[0]?.fx_animation === 'spirit',
      'The one-shot finishes into lingering smoke');
    const spiritStart = log.events.at(-1).sequence;
    await expect.poll(() => new Set(log.events.filter(e => e.sequence > spiritStart
      && e.data?.recording?.ghosts[0]?.fx_animation === 'spirit')
      .map(e => e.data.recording.ghosts[0].fx_frame)).size,
    { timeout: 10_000, message: 'The lingering smoke really animates' }).toBeGreaterThan(5);
    await page.screenshot({ path: testInfo.outputPath('fallen-ghost-smoke.png') });
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const fallen = decode((await records(page))[0]);
    expect(fallen.payload.run.combat.arenas.labyrinth.allies['hero:0'].health).toBe('0');
    expect(fallen.payload.schema_version).toBe(11);
    await reload(page, log);
    await chooseSlot(page, log);
    state = await log.wait(s => s?.scene === 'world' && s.recording.ghosts[0]?.defeated,
      'The dead ghost resumes through real IndexedDB hydration');
    expect(state.recording.ghosts[0]).toMatchObject({ fx_animation: 'spirit', body_visible: false,
      selection_visible: false, fx_visible: true, cell: [31, 24] });
    expect(log.events.filter(e => e.data?.scene === 'world')
      .some(e => e.data.recording.ghosts[0]?.fx_animation === 'burst')).toBe(false);
    await page.keyboard.press('ArrowLeft');
    await log.wait(s => s?.recording?.modal_open, 'A ghost movement opens its real control/restart choice');
    await page.keyboard.press('2');
    state = await log.wait(s => s?.scene === 'world' && !s.recording.modal_open
      && s.recording.ghosts[0] && !s.recording.ghosts[0].defeated,
      'Restart arena revives the existing folded hero');
    expect(state.recording.ghosts[0]).toMatchObject({ body_visible: true, fx_visible: false, cell: [31, 24] });
    await log.wait(s => s?.recording?.ghosts[0]?.defeated, 'The same staff falls again on the next real landing');
    await page.keyboard.press('ArrowLeft');
    await log.wait(s => s?.recording?.modal_open);
    await page.keyboard.press('1');
    state = await log.wait(s => s?.scene === 'world' && s.hero.arena === 'guild_house'
      && s.recording.ghosts.length === 0, 'Taking control of a fallen ghost uses normal Guild House recovery');
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const recovered = decode((await records(page))[0]);
    const recoveredAlly = recovered.payload.run.combat.arenas.guild_house.allies['hero:0'];
    expect(recoveredAlly.health).toBe(recoveredAlly.max_health);
    expect(recoveredAlly.health).not.toBe('0');

    await putRecords(page, [[0, JSON.stringify(fallen.document)]]);
    await reload(page, log);
    await chooseSlot(page, log);
    await log.wait(s => s?.scene === 'world' && s.recording.ghosts[0]?.defeated);
    await page.keyboard.press('r');
    await log.wait(s => s?.recording?.modal_open);
    await page.keyboard.press('1');
    state = await log.wait(s => s?.scene === 'world' && s.recording.state === 'countdown'
      && s.recording.ghosts.length === 0, 'Record new recovers the fallen performer for a new take');
    expect(state.hero.arena).toBe('labyrinth');
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const rerecording = decode((await records(page))[0]);
    const rerecordingAlly = rerecording.payload.run.combat.arenas.labyrinth.allies['hero:0'];
    expect(rerecordingAlly.health).toBe(rerecordingAlly.max_health);
    expect(rerecordingAlly.health).not.toBe('0');
    expect(log.errors).toEqual([]);
  } finally {
    await page.keyboard.up('Space');
    await attachResults(testInfo, log);
  }
});


test('Cleanse stacks tick independently, appear above damage progress, and survive IndexedDB reload', async ({ page }, testInfo) => {
  const log = watch(page);
  const cleanse = state => state?.combat?.enemy_dots?.filter(dot => dot.ability_id === 'cleanse') ?? [];
  try {
    let state = await enterProbeWorld(page, log, 1);
    expect(state.hero.class_id).toBe('bard');
    await page.keyboard.press('Tab');
    await log.wait(s => s?.zoomed && s.hero.selected && !s.motion_active);
    for (let row = 16; row <= 20; row++) {
      await page.keyboard.press('ArrowUp');
      await log.wait(s => s?.hero?.cell[1] === row);
    }
    await page.keyboard.press('1');
    state = await log.wait(s => cleanse(s).length === 1 && s.hud.top.effects.text.includes('Cleanse'));
    expect(state.combat.boss_effects[0]).toMatchObject({ id: 'cleanse', stacks: 1, beneficial: false });
    expect(state.hud.top.effects.text).toMatch(/Cleanse.*\[\d+s\]/);
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const saved = decode((await records(page))[0]);
    expect(saved.payload.schema_version).toBe(11);
    const dot = saved.payload.run.combat.enemy_dots[0];
    expect(dot).toMatchObject({ ability_id: 'cleanse', caster_id: `hero:${state.hero.identity}`,
      arena: 'guild_house', enemy_id: 'boss:guild_house', interval_ticks: 60, damage: 1 });
    expect(dot.remaining_ticks).toBeGreaterThan(0);
    expect(dot.remaining_ticks).toBeLessThan(300);
    const savedDamage = Number(saved.payload.run.combat.arenas.guild_house.damage);
    expect(savedDamage + Math.floor((dot.remaining_ticks + dot.tick_debt) / 60)).toBe(6);
    await reload(page, log);
    await chooseSlot(page, log);
    state = await log.wait(s => s?.scene === 'world' && cleanse(s).length === 1 && s.hud.top.effects.text.includes('Cleanse'));
    expect(cleanse(state)[0].remaining_ticks).toBeLessThanOrEqual(dot.remaining_ticks);
    expect(cleanse(state)[0].remaining_ticks).toBeGreaterThan(dot.remaining_ticks - 60);
    await log.wait(s => s?.combat?.totals.guild_house === 6 && cleanse(s).length === 0 && !s.hud.top.effects.text.includes('Cleanse'),
      'Restored Cleanse completes only its remaining ticks and clears the actual HUD');
    await log.wait(s => s?.combat?.cooldown === 0);
    await page.keyboard.press('1');
    await log.wait(s => cleanse(s).length === 1);
    // The overlap window is one second; react to the actual cooldown with
    // tight polling instead of the shared helper's one-second backoff.
    await expect.poll(() => log.latest()?.combat?.cooldown === 0 && cleanse(log.latest()).length === 1,
      { intervals: [20, 50, 100], message: 'Recast as soon as the four-second cooldown ends' }).toBe(true);
    await page.keyboard.press('1');
    state = await log.wait(s => cleanse(s).length === 2 && s.hud.top.effects.text.includes('Cleanse ×2'),
      'Recasting shows two independent stacks above the arena damage bar');
    const stacks = cleanse(state);
    expect(stacks[0].remaining_ticks).toBeLessThan(stacks[1].remaining_ticks);
    expect(state.combat.boss_effects[0].remaining_seconds).toBeCloseTo(stacks[0].remaining_ticks / 60, 5);
    await page.screenshot({ path: testInfo.outputPath('cleanse-stacks-and-countdown.png') });
    await log.wait(s => cleanse(s).length === 1 && !s.hud.top.effects.text.includes('×2'),
      'The older stack expires without refreshing or removing the younger one');
    await log.wait(s => s?.combat?.totals.guild_house === 18 && cleanse(s).length === 0 && !s.hud.top.effects.text.includes('Cleanse'),
      'Two casts each contribute one initial hit and five delayed ticks');
    expect(log.events.some(event => event.kind === 'state' && event.data?.hud?.chat?.entries?.some(entry =>
      entry.ability_id === 'cleanse' && entry.hero_id === state.hero.identity))).toBe(true);
    // A schema-4 checkpoint has no DOT collection. Loading it must not turn
    // its historical Cleanse hits into fresh stacks or extra damage.
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    for (const arena of Object.values(saved.payload.world.arenas ?? {})) delete arena.restart_pending;
    saved.payload.schema_version = 4;
    delete saved.payload.run.loot;
    delete saved.payload.run.combat.encounter;
    delete saved.payload.run.gathering;
    delete saved.payload.run.combat.enemy_dots;
    saved.document.payload_json = JSON.stringify(saved.payload);
    saved.document.checksum = createHash('sha256').update(saved.document.payload_json).digest('hex');
    await putRecords(page, [[0, JSON.stringify(saved.document)]]);
    await reload(page, log);
    await chooseSlot(page, log);
    state = await log.wait(s => s?.scene === 'world');
    expect(cleanse(state)).toEqual([]);
    const restoredCycle = state.recording.cycle;
    await log.wait(s => s?.recording?.cycle >= restoredCycle + 90);
    expect(log.latest().combat.totals.guild_house).toBe(savedDamage);
    await expect.poll(async () => decode((await records(page))[0]).payload.schema_version).toBe(11);
    expect(decode((await records(page))[0]).payload.run.combat.enemy_dots).toEqual([]);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

test('Commit rewinds observed movement, keeps earnings, then counts 3–2–1 into the next loop', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await enterProbeWorld(page, log, 0);
    await page.keyboard.press('Tab');
    let state = await log.wait(s => s?.zoomed && s.hero.selected);
    await page.keyboard.press('r');
    await log.wait(s => s?.recording?.state === 'recording');
    await page.keyboard.press('1');
    await log.wait(s => s?.combat?.totals.guild_house > 0, 'The recorded shot earns real damage');
    await page.keyboard.press('ArrowLeft');
    await log.wait(s => s?.hero?.cell[0] === 29);
    await page.keyboard.press('ArrowLeft');
    await log.wait(s => s?.hero?.cell[0] === 28);
    state = await log.wait(s => s?.recording?.cycle >= 300,
      'Observe a short rendered history; native rewind checks simulate full cycles');
    await page.keyboard.press('r');
    state = await log.wait(s => s?.recording?.modal_open);
    const earned = state.combat.totals.guild_house;
    const banks = [state.gathering.wood_total, state.gathering.gold_total];
    const otherTick = state.arena_ticks.labyrinth;
    const commitSequence = log.events.at(-1).sequence;
    await page.keyboard.press('1');
    const reverse = await log.wait(s => s?.restart?.phase === 'rewind' && s.restart.pending,
      'Commit enters the visual reverse while its canonical clock holds zero', { intervals: [25, 50, 100] });
    expect(reverse.recording.cycle).toBe(0);
    await log.wait(s => s?.restart?.phase === 'countdown',
      'The visible countdown contains real keyboard input', { intervals: [25, 50, 100] });
    await page.keyboard.press('ArrowRight');
    await page.keyboard.press('1');
    await page.keyboard.press('r');
    state = await log.wait(s => s?.restart?.pending === false && s.recording.cycle > 0);
    expect(state.recording.state).toBe('idle');
    // Verify every observed state after the real commit. A screenshot can take
    // longer than a countdown beat on software WebGL, so never block sampling
    // or input behind capture, then wait for an already-finished beat.
    const observed = log.events.filter(e => e.sequence > commitSequence && e.kind === 'state').map(e => e.data);
    const countdown = observed.filter(s => s.restart?.phase === 'countdown');
    expect([...new Set(countdown.map(s => s.restart.countdown))]).toEqual([3, 2, 1]);
    for (const sample of countdown) {
      expect(sample.recording.modal_open).toBe(false);
      expect(sample.recording.cycle).toBe(0);
      expect(sample.combat.totals.guild_house).toBe(earned);
      expect([sample.gathering.wood_total, sample.gathering.gold_total]).toEqual(banks);
      expect(sample.arena_ticks.labyrinth).toBeGreaterThan(otherTick);
    }
    const rewindTicks = observed.filter(s => s.restart?.phase === 'rewind').map(s => s.restart.display_tick);
    expect(rewindTicks.length).toBeGreaterThan(1);
    expect(rewindTicks.at(-1)).toBeLessThan(rewindTicks[0]);
    await page.screenshot({ path: testInfo.outputPath('restarted-recording.png') });
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

test('Observed cycle rewinds automatically and IndexedDB reload resumes its pending countdown without losing progress', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await enterProbeWorld(page, log, 0);
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const fixture = decode((await records(page))[0]);
    const hero = fixture.payload.run.heroes[0];
    hero.selected = true;
    hero.recordings.guild_house = { start_cell: [30, 15], events: [
      { tick: 6630, action: 'move', delta: [1, 0], slot: 0 },
      { tick: 6720, action: 'move', delta: [1, 0], slot: 0 },
      { tick: 6900, action: 'move', delta: [1, 0], slot: 0 },
    ] };
    fixture.payload.world.zoomed = true;
    fixture.payload.world.selected_index = 1;
    const arena = fixture.payload.world.arenas.guild_house;
    arena.tick = 6600;
    arena.active = ['hero:0'];
    arena.orders['hero:0'] = arena.next_order++;
    fixture.payload.run.gathering.wood_total = '23';
    fixture.payload.run.gathering.gold_total = '17';
    // The lifetime totals were earned before this replay; reverse must retain them.
    fixture.payload.run.prospected = '140';
    await putRecords(page, [[0, encodeFixture(fixture)]]);
    await reload(page, log);
    await chooseSlot(page, log);
    await log.wait(s => s?.scene === 'world' && s.hero.cell[0] === 33);
    let state = await log.wait(s => s?.restart?.phase === 'rewind', 'Observed cycle crosses 7200 and reverses without a recording decision');
    expect(state.recording.state).toBe('idle');
    expect(state.recording.cycle).toBe(0);
    const oldCycle = state.gathering.cycle;
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const saved = decode((await records(page))[0]);
    expect(saved.payload.world.arenas.guild_house).toMatchObject({ tick: 0, restart_pending: true });
    expect(saved.payload.run.prospected).toBe('140');
    expect(saved.payload.run.gathering).toMatchObject({ wood_total: '23', gold_total: '17' });
    await reload(page, log);
    await chooseSlot(page, log);
    state = await log.wait(s => s?.scene === 'world' && s.restart?.phase === 'countdown');
    expect(state.restart.pending).toBe(true);
    expect(state.recording.cycle).toBe(0);
    expect(state.gathering).toMatchObject({ wood_total: 23, gold_total: 17 });
    if (oldCycle !== undefined) expect(state.gathering.cycle).toBe(oldCycle);
    expect(state.recording.ghosts[0].cell).toEqual([30, 15]);
    await log.wait(s => s?.restart?.pending === false && s.recording.cycle > 0);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});


test('Cardinal recording death discards the draft while an existing ghost and clock continue through reload', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await enterProbeWorld(page, log, 0);
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const fixture = decode((await records(page))[0]);
    const { run, world } = fixture.payload;
    const hero = run.heroes[0];
    const actor = `hero:${hero.identity}`;
    const ally = run.combat.arenas.guild_house.allies[actor];
    delete run.combat.arenas.guild_house.allies[actor];
    Object.assign(hero, { arena_id: 'sanctum', cell: [14, 8], selected: true });
    run.combat.arenas.sanctum.allies[actor] = { ...ally, cell: [14, 8], health: '1', max_health: '4' };
    const resident = structuredClone(hero);
    Object.assign(resident, { identity: run.next_identity++, cell: [37, 4], selected: false });
    const ghost = `hero:${resident.identity}`;
    resident.recordings = { sanctum: { start_cell: [37, 4], events: [
      { tick: 390, action: 'move', delta: [0, 1], slot: 0 },
      { tick: 480, action: 'move', delta: [0, 1], slot: 0 },
    ] } };
    run.heroes.push(resident);
    run.combat.arenas.sanctum.allies[ghost] = { ...ally, cell: [37, 4], health: '4', max_health: '4' };
    run.arena_selection = { sanctum: hero.identity };
    Object.assign(world, { selected_index: 2, zoomed: true, modal: {}, session: {
      state: 2, countdown_left: 0, identity: hero.identity, arena_id: 'sanctum', start_cell: [14, 8],
      events: [{ tick: 120, action: 'ability', delta: [0, 0], slot: 1 }],
    } });
    const arena = world.arenas.sanctum;
    Object.assign(arena, { tick: 350, paused: false, restart_pending: false, active: [ghost] });
    arena.orders[ghost] = arena.next_order++;
    await putRecords(page, [[0, encodeFixture(fixture)]]);
    await reload(page, log);
    await chooseSlot(page, log);
    let state = await log.wait(s => s?.scene === 'world' && s.hero.arena === 'guild_house',
      'The real Sun Seal kills the recorder and returns it home automatically');
    expect(state.recording.state).toBe('idle');
    expect(state.recording.captured).toBe(0);
    expect(state.recording.modal_open).toBe(false);
    expect(state.arena_clocks.sanctum.paused).toBe(false);
    expect(state.arena_clocks.sanctum.tick).toBeGreaterThanOrEqual(391);
    expect(state.arena_clocks.sanctum.tick).toBeLessThan(900);
    state = await log.wait(s => s?.heroes?.find(h => h.identity === resident.identity)?.cell[1] === 6,
      'The surviving ghost continues its original staff after the recorder dies');
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const saved = decode((await records(page))[0]);
    expect(saved.payload.world.session.state).toBe(0);
    expect(saved.payload.world.session.events).toEqual([]);
    expect(saved.payload.world.arenas.sanctum.active).toEqual([ghost]);
    expect(saved.payload.world.arenas.sanctum.tick).toBeGreaterThanOrEqual(481);
    expect(saved.payload.world.arenas.sanctum.paused).toBe(false);
    const tick = saved.payload.world.arenas.sanctum.tick;
    await reload(page, log);
    await chooseSlot(page, log);
    state = await log.wait(s => s?.scene === 'world' && s.hero.arena === 'guild_house');
    expect(state.recording.state).toBe('idle');
    expect(state.recording.modal_open).toBe(false);
    expect(state.arena_clocks.sanctum.tick).toBeGreaterThanOrEqual(tick);
    expect(state.arena_clocks.sanctum.tick).toBeLessThan(tick + 180);
    expect(state.heroes.find(h => h.identity === resident.identity).cell).toEqual([37, 6]);
    await page.screenshot({ path: testInfo.outputPath('cardinal-cancelled-recording.png') });
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

test('arena-scoped selection and recording music stay synchronized through real controls and reload', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await enterProbeWorld(page, log, 0);
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const fixture = decode(labyrinthFixture(decode((await records(page))[0]), false));
    fixture.payload.schema_version = 8;
    delete fixture.payload.run.loot; // Real legacy normalization, including old remote selection.
    delete fixture.payload.run.combat.encounter;
    fixture.payload.world.selected_index = 1;
    fixture.payload.world.arenas.guild_house.tick = 1800;
    fixture.payload.world.music.guild_house.position = 95;
    fixture.payload.run.prospected = '10000';
    await putRecords(page, [[0, encodeFixture(fixture)]]);
    await reload(page, log);
    await chooseSlot(page, log);
    let state = await log.wait(s => s?.scene === 'world' && s.arena === 'guild_house' && !s.motion_active);
    const remote = state.heroes[0];
    expect(state.selected_heroes).toEqual([]);
    const assertSync = s => {
      for (const [id, clock] of Object.entries(s.arena_clocks)) {
        const expected = clock.tick / clock.ticks * s.music.durations[id];
        expect(Math.abs(s.music.clocks[id] - expected), `${id} follows its own simulation clock`).toBeLessThan(0.05);
      }
    };
    assertSync(state);
    await page.screenshot({ path: testInfo.outputPath('empty-arena-no-remote-selection.png') });
    for (const key of ['Tab', 'ArrowRight', 'Space', 'r']) await page.keyboard.press(key);
    state = await log.wait(s => s?.arena_clocks?.guild_house.tick > state.arena_clocks.guild_house.tick + 30);
    expect(state.arena).toBe('guild_house');
    expect(state.selected_heroes).toEqual([]);
    expect(state.heroes[0].cell).toEqual(remote.cell);
    expect(state.recording.modal_open).toBe(false);
    await page.keyboard.press('n');
    state = await log.wait(s => s?.rewards?.mode === 'heroes' && s.rewards.cards.every(card => card.revealed && card.enabled));
    await clickLogical(page, state, state.rewards.cards[0].center);
    state = await log.wait(s => s?.heroes?.length === 2 && !s.rewards.open && s.hero.selected);
    expect(state.hero.identity).toBe(1);
    expect(state.hero.arena).toBe('guild_house');
    await clickLogical(page, state, state.hud.previous.center);
    state = await log.wait(s => s?.arena === 'labyrinth' && s.hero.identity === 0 && s.hero.selected);
    await clickLogical(page, state, state.hud.next.center);
    state = await log.wait(s => s?.arena === 'guild_house' && s.hero.identity === 1 && s.hero.selected && !s.motion_active);
    const before = state.music.clocks.labyrinth;
    await page.keyboard.press('r');
    state = await log.wait(s => s?.recording?.state === 'countdown');
    expect(state.music.clocks.guild_house).toBe(0);
    expect(state.music.running.guild_house).toBe(false);
    expect(state.music.clocks.labyrinth).toBeGreaterThanOrEqual(before);
    state = await log.wait(s => s?.recording?.state === 'recording' && s.arena_clocks.guild_house.tick > 60);
    assertSync(state);
    await log.wait(s => s?.music?.voices.some(v => v.arena_id === 'guild_house' && v.playing && Math.abs(v.position - s.music.clocks.guild_house) < 0.3), 'The actual decoder follows the restarted loop');
    await page.keyboard.press('r');
    state = await log.wait(s => s?.recording?.modal_open && !s.music.running.guild_house);
    assertSync(state);
    await expect.poll(async () => decode((await records(page))[0]).payload.world.modal.title, { timeout: 30_000 }).toBe('Like the recording?');
    await reload(page, log);
    await chooseSlot(page, log);
    state = await log.wait(s => s?.recording?.modal_open && !s.music.running.guild_house);
    expect(state.hero.identity).toBe(1);
    expect(state.hero.selected).toBe(true);
    assertSync(state);
    await page.keyboard.press('2');
    state = await log.wait(s => s?.recording?.state === 'recording' && !s.recording.modal_open && s.music.running.guild_house);
    assertSync(state);
    await page.screenshot({ path: testInfo.outputPath('scoped-recording-music.png') });
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

test('Cardinal revision survives IndexedDB reload with attunement, Exposure and a consumed window', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await enterProbeWorld(page, log, 0);
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const saved = decode((await records(page))[0]);
    expect(saved.payload.run.combat.encounter.ruleset).toBe('cardinal-1');
    const hero = saved.payload.run.heroes[0];
    const actor = `hero:${hero.identity}`;
    const ally = saved.payload.run.combat.arenas[hero.arena_id].allies[actor];
    delete saved.payload.run.combat.arenas[hero.arena_id].allies[actor];
    Object.assign(hero, { arena_id: 'sanctum', cell: [29, 12], selected: true });
    saved.payload.run.combat.arenas.sanctum.allies[actor] = { ...ally, cell: [...hero.cell], health: '3', max_health: '4' };
    saved.payload.run.arena_selection = { sanctum: hero.identity };
    saved.payload.world.selected_index = 2;
    saved.payload.world.zoomed = true;
    saved.payload.world.arenas.sanctum.tick = 3100;
    saved.payload.world.arenas.sanctum.restart_pending = false;
    saved.payload.world.arenas.sanctum.paused = false;
    saved.payload.run.combat.encounter.actors = { sanctum: { [actor]: {
      attunement: 'moon', claims: ['cardinal.1.6'],
      exposures: [{ event_id: 'cardinal.2.4', due_tick: 3210, damage: 1 }],
    } } };
    await putRecords(page, [[0, encodeFixture(saved)]]);
    await reload(page, log);
    await chooseSlot(page, log);
    let state = await log.wait(value => value?.arena === 'sanctum' && value.combat?.encounter_ruleset === 'cardinal-1');
    expect(state.combat.encounter_state.sanctum[actor].attunement).toBe('moon');
    expect(state.combat.encounter_state.sanctum[actor].claims).toEqual(['cardinal.1.6']);
    expect(state.combat.encounter_readout).toContain('The Twofold Witness');
    await testInfo.attach('cardinal-warning', { body: await page.screenshot(), contentType: 'image/png' });
    state = await log.wait(value => value?.combat?.ally_health === 2,
      'The restored Exposure deals exactly one wound at its source deadline');
    await log.wait(value => value?.combat?.encounter_state?.sanctum?.[actor]?.exposures.length === 0);
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    const after = decode((await records(page))[0]);
    expect(after.document.run_id).toBe(saved.document.run_id);
    expect(after.payload.run.combat.encounter.fingerprint).toBe(saved.payload.run.combat.encounter.fingerprint);
    expect(after.payload.run.combat.encounter.actors.sanctum[actor]).toMatchObject({ attunement: 'moon', claims: ['cardinal.1.6'], exposures: [] });
    expect(after.payload.run.combat.arenas.sanctum.allies[actor].health).toBe('2');
    await reload(page, log);
    await chooseSlot(page, log);
    state = await log.wait(value => value?.arena === 'sanctum' && value.combat?.ally_health === 2);
    expect(state.combat.encounter_state.sanctum[actor].exposures).toEqual([]);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});


test('a remote restart cannot lock a free Cardinal or show a countdown at home across reload and clock wrap', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await enterProbeWorld(page, log, 4);
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    let fixture = decode((await records(page))[0]);
    fixture.payload.run.prospected = '10000';
    await putRecords(page, [[0, encodeFixture(fixture)]]);
    await reload(page, log);
    await chooseSlot(page, log);
    await log.wait(s => s?.scene === 'world' && !s.motion_active);
    await page.keyboard.press('n');
    const rewardState = await log.wait(s => s?.rewards?.mode === 'heroes' && s.rewards.cards.every(card => card.revealed && card.enabled));
    await clickLogical(page, rewardState, rewardState.rewards.cards[0].center);
    await log.wait(s => s?.heroes?.length === 2 && !s.rewards.open);
    await clickHudMenuAction(page, log, 'save_title');
    await readyTitle(log);
    fixture = decode((await records(page))[0]);
    const resident = fixture.payload.run.heroes[1];
    const actor = `hero:${resident.identity}`;
    const ally = fixture.payload.run.combat.arenas.guild_house.allies[actor];
    delete fixture.payload.run.combat.arenas.guild_house.allies[actor];
    Object.assign(resident, { arena_id: 'labyrinth', cell: [10, 10], selected: false });
    fixture.payload.run.combat.arenas.labyrinth.allies[actor] = { ...ally, cell: [10, 10] };
    fixture.payload.run.arena_selection = { guild_house: 0, labyrinth: resident.identity };
    fixture.payload.run.selected_identity = 0;
    fixture.payload.run.heroes[0].selected = true;
    fixture.payload.world.selected_index = 1;
    fixture.payload.world.zoomed = true;
    fixture.payload.world.arenas.guild_house.tick = 7140;
    fixture.payload.world.arenas.labyrinth.tick = 0;
    fixture.payload.world.arenas.labyrinth.restart_pending = true;
    fixture.payload.world.arenas.sanctum.tick = 0;
    fixture.payload.world.arenas.sanctum.restart_pending = true;
    await putRecords(page, [[0, encodeFixture(fixture)]]);
    await reload(page, log);
    await chooseSlot(page, log);
    let state = await log.wait(s => s?.scene === 'world' && !s.motion_active);
    expect(state.hero.class_id).toBe('cardinal');
    expect(state.hero.arena).toBe('guild_house');
    expect(state.arena_clocks.labyrinth.paused).toBe(true);
    expect(state.arena_clocks.sanctum.paused).toBe(false);
    expect(state.restart.phase).toBe('');
    const cell = [...state.hero.cell];
    await page.keyboard.press('ArrowRight');
    await log.wait(s => s?.hero?.cell[0] === cell[0] + 1);
    state = await log.wait(s => s?.arena_clocks?.guild_house.tick < 120,
      'The unrecorded home clock wraps while Hunter still counts in');
    expect(state.arena_clocks.labyrinth.paused).toBe(true);
    expect(state.restart.pending).toBe(false);
    expect(state.restart.phase).toBe('');
    await page.keyboard.press('ArrowRight');
    state = await log.wait(s => s?.hero?.cell[0] === cell[0] + 2);
    expect(state.heroes[1].cell).toEqual([10, 10]);
    await page.screenshot({ path: testInfo.outputPath('remote-restart-free-cardinal.png') });
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});


for (const exit of ['portal', 'navigation', 'countdown']) {
  test(`leaving a recording via ${exit} discards immediately and preserves its arena timestamp`, async ({ page }, testInfo) => {
    const log = watch(page);
    try {
      await enterProbeWorld(page, log, 0);
      await clickHudMenuAction(page, log, 'save_title');
      await readyTitle(log);
      const fixture = decode((await records(page))[0]);
      const { run, world } = fixture.payload;
      const hero = run.heroes[0];
      const actor = `hero:${hero.identity}`;
      const ally = run.combat.arenas.guild_house.allies[actor];
      delete run.combat.arenas.guild_house.allies[actor];
      Object.assign(hero, { arena_id: 'sanctum', cell: [0, 15], selected: true });
      run.combat.arenas.sanctum.allies[actor] = { ...ally, cell: [0, 15] };
      run.arena_selection = { sanctum: hero.identity };
      Object.assign(world, { selected_index: 2, zoomed: true, modal: {}, session: {
        state: exit === 'countdown' ? 1 : 2, countdown_left: exit === 'countdown' ? 180 : 0,
        identity: hero.identity, arena_id: 'sanctum', start_cell: [0, 15], events: [],
      } });
      Object.assign(world.arenas.sanctum, { tick: exit === 'countdown' ? 0 : 3600, paused: exit === 'countdown', restart_pending: false });
      await putRecords(page, [[0, encodeFixture(fixture)]]);
      await reload(page, log);
      await chooseSlot(page, log);
      let state = await log.wait(s => s?.scene === 'world' && s.arena === 'sanctum' && !s.motion_active);
      if (exit === 'portal') await page.keyboard.press('ArrowLeft');
      else await clickLogical(page, state, state.hud.previous.center);
      state = await log.wait(s => s?.arena === 'guild_house' && s.recording.state === 'idle');
      expect(state.recording.captured).toBe(0);
      expect(state.recording.modal_open).toBe(false);
      expect(state.arena_clocks.sanctum.paused).toBe(false);
      const tick = state.arena_clocks.sanctum.tick;
      expect(tick).toBeGreaterThanOrEqual(exit === 'countdown' ? 0 : 3600);
      expect(tick).toBeLessThan(exit === 'countdown' ? 180 : 3780);
      await log.wait(s => s?.arena_clocks?.sanctum.tick > tick + 15, 'The arena keeps ticking after departure');
      expect(log.latest().hero.arena).toBe(exit === 'portal' ? 'guild_house' : 'sanctum');
      expect(log.errors).toEqual([]);
    } finally { await attachResults(testInfo, log); }
  });
}
