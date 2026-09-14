import { test, expect } from '@playwright/test';
import { createHash } from 'node:crypto';
import { watch, clickLogical, clickHudMenuAction, enterProbeWorld, attachResults } from './helpers.mjs';

test.use({ viewport: { width: 960, height: 540 }, deviceScaleFactor: 1 });
test.describe.configure({ timeout: 240_000 });

// Only authored save fixtures enter here. Every award, dismissal, claim and
// subsequent save uses the real game and actual browser controls.
async function stored(page) {
  return page.evaluate(() => new Promise((resolve, reject) => {
    const request = indexedDB.open('arenic-saves', 1);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const db = request.result;
      const tx = db.transaction('slots', 'readonly');
      const get = tx.objectStore('slots').get(0);
      tx.oncomplete = () => { db.close(); resolve(get.result); };
      tx.onabort = () => { db.close(); reject(tx.error); };
    };
  }));
}
function decode(raw) {
  const document = JSON.parse(raw);
  return { document, payload: JSON.parse(document.payload_json) };
}
async function fixture(page, saved) {
  saved.document.payload_json = JSON.stringify(saved.payload);
  saved.document.checksum = createHash('sha256').update(saved.document.payload_json).digest('hex');
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
  }), JSON.stringify(saved.document));
}
async function title(log) {
  return log.wait(s => s?.scene === 'title' && s.saves.ready && !s.saves.busy && !s.picker?.visible);
}
async function continueRun(page, log) {
  const start = log.console.length;
  log.events.length = 0;
  log.ready = false;
  await page.reload();
  await expect(page.locator('#canvas')).toBeVisible();
  await expect.poll(() => log.console.slice(start).some(row => row.text.startsWith('Build configuration:')), { timeout: 60_000 }).toBe(true);
  await expect(page.locator('#status')).toBeHidden();
  log.downloads = await page.evaluate(() => window.__arenicDownloads);
  log.ready = true;
  let state = await title(log);
  await clickLogical(page, state, state.controls.continue.center);
  state = await log.wait(s => s?.picker?.visible && !s.picker.working);
  await clickLogical(page, state, state.picker.rows.find(row => row.slot === 0).choose.center);
  return log.wait(s => s?.scene === 'world' && !s.motion_active);
}
async function saveTitle(page, log) {
  await clickHudMenuAction(page, log, 'save_title');
  await title(log);
  return decode(await stored(page));
}
const readyCards = (state, mode) => state?.rewards?.open && state.rewards.mode === mode
  && state.rewards.cards.length === 3 && state.rewards.cards.every(card => card.visible && card.enabled);
const classIds = state => state.rewards.cards.map(card => card.class_id);
const owned = state => state.loot.inventory.reduce((sum, row) => sum + row.count, 0);
const center = rect => [rect.x + rect.width / 2, rect.y + rect.height / 2];

function assertStagger(events, mode) {
  const frames = events.filter(event => event.kind === 'state' && event.data?.rewards?.mode === mode)
    .map(event => event.data.rewards.cards.filter(card => card.alpha >= 0.99).length);
  expect(frames.some(count => count > 0 && count < 3), 'Actual rendered reward frames show the stagger before all three cards appear').toBe(true);
}

test('earned hero opens three staggered cards; Later and N preserve offers through reload', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await enterProbeWorld(page, log, 0);
    const saved = await saveTitle(page, log);
    saved.payload.run.prospected = '39';
    saved.payload.world.zoomed = true;
    saved.payload.run.heroes[0].selected = true;
    await fixture(page, saved);
    let state = await continueRun(page, log);
    expect(state.rewards.open).toBe(false);
    expect(state.hud.recruitment.ready.visible).toBe(false);
    const before = log.events.length;
    await page.keyboard.press('1'); // The real Hunter shot crosses 40 total damage.
    state = await log.wait(s => readyCards(s, 'heroes'), 'The newly earned hero opens automatically after the actual hit');
    const offers = classIds(state);
    expect(new Set(offers).size).toBe(3);
    expect(state.rewards.arena_id).toBe(state.arena);
    expect(state.rewards.cards.every(card => card.revealed && card.item_id === '')).toBe(true);
    assertStagger(log.events.slice(before), 'heroes');
    expect(state.hud.recruitment.counter.rect[0]).toBeGreaterThan(state.logical[0] / 2);
    expect(state.hud.recruitment.counter.rect[1] + state.hud.recruitment.counter.rect[3]).toBeLessThanOrEqual(state.world_rect[1]);
    const tick = state.arena_clocks.guild_house.tick;
    state = await log.wait(s => readyCards(s, 'heroes') && s.arena_clocks.guild_house.tick > tick + 20);
    expect(state.arena_clocks.guild_house.paused).toBe(false);
    await page.screenshot({ path: testInfo.outputPath('hero-three-revealed-cards.png') });
    await clickLogical(page, state, center(state.rewards.later_rect));
    state = await log.wait(s => s?.rewards && !s.rewards.open);
    expect(state.heroes).toHaveLength(1);
    expect(state.hud.recruitment.ready.text).toBe('1 [N]');
    await page.keyboard.press('n');
    state = await log.wait(s => readyCards(s, 'heroes'));
    expect(classIds(state)).toEqual(offers);
    await page.keyboard.press('Escape');
    await log.wait(s => s?.rewards && !s.rewards.open);
    const deferred = await saveTitle(page, log);
    expect(deferred.payload.schema_version).toBe(11);
    expect(deferred.payload.world.modal).toEqual({});
    state = await continueRun(page, log);
    expect(state.rewards.open).toBe(false);
    expect(state.heroes).toHaveLength(1);
    await page.keyboard.press('n');
    state = await log.wait(s => readyCards(s, 'heroes'));
    expect(classIds(state)).toEqual(offers);
    await clickLogical(page, state, state.rewards.cards[1].center);
    state = await log.wait(s => s?.heroes?.length === 2 && !s.rewards.open);
    expect(state.hud.recruitment.ready.visible).toBe(false);
    const claimed = await saveTitle(page, log);
    expect(claimed.payload.run.heroes[1].class_id).toBe(offers[1]);
    state = await continueRun(page, log);
    expect(state.heroes).toHaveLength(2);
    await page.keyboard.press('n');
    await page.waitForTimeout(600);
    expect(log.latest().rewards.open).toBe(false);
    expect(log.latest().heroes).toHaveLength(2);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

test('natural arena completion banks three sealed cards; one flip grants one persistent equipment item', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await enterProbeWorld(page, log, 0);
    const saved = await saveTitle(page, log);
    const { run, world } = saved.payload;
    const hero = run.heroes[0];
    const actor = `hero:${hero.identity}`;
    const ally = run.combat.arenas[hero.arena_id].allies[actor];
    delete run.combat.arenas[hero.arena_id].allies[actor];
    Object.assign(hero, { arena_id: 'sanctum', cell: [37, 4], selected: true,
      recordings: { sanctum: { start_cell: [37, 4], events: [{ tick: 120, action: 'move', delta: [0, 1], slot: 0 }] } } });
    run.combat.arenas.sanctum.allies[actor] = { ...ally, cell: [37, 4] };
    run.combat.arenas.sanctum.damage = '12';
    run.combat.arenas.sanctum.enemies['boss:sanctum'].damage = '12';
    run.selected_identity = hero.identity;
    run.arena_selection = { sanctum: hero.identity };
    Object.assign(world, { selected_index: 2, zoomed: true, modal: {} });
    Object.assign(world.arenas.sanctum, { tick: 7198, paused: false, restart_pending: false,
      active: [actor], orders: { 'boss:sanctum': 0, [actor]: 1 }, next_order: 2 });
    // The baseline remains zero from the real fresh run: this fixture represents
    // twelve damage in the outgoing cycle, never a retrospective load award.
    await fixture(page, saved);
    await continueRun(page, log);
    let state = await log.wait(s => s?.loot?.pending === 1, 'Only the actual last forward tick earns the cycle reward');
    if (!state.rewards.open) await clickLogical(page, state, state.hud.loot.center);
    state = await log.wait(s => readyCards(s, 'loot'));
    expect(state.rewards.arena_id).toBe('sanctum');
    expect(state.rewards.cards.every(card => !card.revealed && card.item_id === '' && card.class_id === '' && card.title === 'Sealed reward')).toBe(true);
    assertStagger(log.events, 'loot');
    expect(owned(state)).toBe(0);
    await page.screenshot({ path: testInfo.outputPath('sanctum-three-sealed-rewards.png') });
    // The ordinary rewind/countdown may briefly hold a completed fight. The
    // reward overlay itself must never prevent its next cycle from advancing.
    state = await log.wait(s => readyCards(s, 'loot') && !s.arena_clocks.sanctum.paused && s.arena_clocks.sanctum.tick > 10);
    const tick = state.arena_clocks.sanctum.tick;
    await log.wait(s => readyCards(s, 'loot') && s.arena_clocks.sanctum.tick > tick + 20);
    await page.keyboard.press('Escape');
    await log.wait(s => s?.rewards && !s.rewards.open && s.loot.pending === 1);
    const pending = await saveTitle(page, log);
    expect(pending.payload.schema_version).toBe(11);
    state = await continueRun(page, log);
    expect(state.rewards.open).toBe(false);
    expect(state.loot.pending).toBe(1);
    await clickLogical(page, state, state.hud.loot.center);
    state = await log.wait(s => readyCards(s, 'loot'));
    await clickLogical(page, state, state.rewards.cards[1].center);
    state = await log.wait(s => s?.rewards?.result_visible && owned(s) === 1);
    expect(state.loot.pending).toBe(0);
    expect(state.rewards.cards.filter(card => card.revealed)).toHaveLength(1);
    const won = state.rewards.cards[1].item_id;
    expect(won).not.toBe('');
    expect(state.loot.inventory[0].id).toBe(won);
    await clickLogical(page, state, state.rewards.cards[0].center);
    await page.keyboard.press('3');
    await page.waitForTimeout(400);
    expect(owned(log.latest())).toBe(1);
    await page.screenshot({ path: testInfo.outputPath('sanctum-equipment-flip.png') });
    await page.keyboard.press('Enter');
    await log.wait(s => s?.rewards && !s.rewards.open);
    const committed = await saveTitle(page, log);
    const inventory = committed.payload.run.loot.inventory;
    state = await continueRun(page, log);
    expect(state.rewards.open).toBe(false);
    expect(state.loot.pending).toBe(0);
    expect(owned(state)).toBe(1);
    expect(state.loot.inventory[0].id).toBe(won);
    await page.keyboard.press('p');
    await log.wait(s => s?.scene === 'world' && !s.zoomed && !s.motion_active);
    await page.keyboard.press('3');
    state = await log.wait(s => s?.overworld_menu?.active === 'loot');
    expect(state.overworld_menu.body_text).toContain(state.loot.inventory[0].name);
    await page.screenshot({ path: testInfo.outputPath('owned-equipment-inventory.png') });
    await page.keyboard.press('Escape');
    await log.wait(s => s?.overworld_menu && !s.overworld_menu.open);
    const afterReload = await saveTitle(page, log);
    expect(afterReload.payload.run.loot.inventory).toEqual(inventory);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});
