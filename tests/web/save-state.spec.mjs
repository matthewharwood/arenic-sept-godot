import { test, expect } from '@playwright/test';
import { watch, loadGame, renderedPixels, readTitleButton, clickTitleButton, clickLogical, attachResults, GAME, PROBE } from './helpers.mjs';

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
    await clickLogical(page, state, state.controls.save_title.center);
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
