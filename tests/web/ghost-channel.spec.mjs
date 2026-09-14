import { test, expect } from '@playwright/test';
import { createHash } from 'node:crypto';
import { watch, enterProbeWorld, clickHudMenuAction, clickLogical, attachResults } from './helpers.mjs';

test.use({ viewport: { width: 640, height: 360 }, deviceScaleFactor: 1 });
test.describe.configure({ timeout: 180_000 });

// A versioned recording fixture enters through the real IndexedDB/codec path.
// There is no shipping mutation probe; subsequent input and replay are real.
async function channelGuildFixture(page, multi = false) {
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
  const payload = JSON.parse(document.payload_json);
  const founder = payload.run.heroes[0];
  founder.selected = false;
  founder.cell = [30, 15];
  founder.recordings.guild_house = { start_cell: [30, 15], events: [
    { tick: 120, action: 'ability', delta: [0, 0], slot: 1 },
    { tick: 600, action: 'move', delta: [1, 0], slot: 0 },
  ] };
  payload.run.heroes.push(
    { ...structuredClone(founder), identity: 1, class_id: 'warrior', selected: true, cell: [28, 15], recordings: {} },
    { ...structuredClone(founder), identity: 2, class_id: 'hunter', cell: [29, 15], recordings: {} },
  );
  payload.run.selected_identity = 1;
  payload.run.next_identity = 3;
  payload.run.arena_selection = { guild_house: 1 };
  const allies = payload.run.combat.arenas.guild_house.allies;
  allies['hero:0'].cell = [30, 15];
  allies['hero:1'] = { ...structuredClone(allies['hero:0']), cell: [28, 15] };
  allies['hero:2'] = { ...structuredClone(allies['hero:0']), cell: [29, 15] };
  payload.world.selected_index = 1;
  payload.world.zoomed = true;
  const arena = payload.world.arenas.guild_house;
  arena.tick = 0;
  arena.active = ['hero:0'];
  arena.orders['hero:0'] = arena.next_order++;
  if (multi === true) {
    for (const [index, hero] of payload.run.heroes.entries()) {
      const cell = [22 + index, 15 + index * 2];
      Object.assign(hero, { class_id: 'cardinal', arena_id: 'labyrinth', cell, selected: index === 2,
        recordings: index < 2 ? { labyrinth: { start_cell: cell, events: [
          { tick: 30 + index * 30, action: 'ability', delta: [0, 0], slot: 1 },
          { tick: 1800, action: 'move', delta: [1, 0], slot: 0 },
        ] } } : {} });
      const key = `hero:${index}`;
      payload.run.combat.arenas.labyrinth.allies[key] = { ...structuredClone(allies[key]), cell };
      delete allies[key];
    }
    payload.run.selected_identity = 2;
    payload.run.arena_selection = { labyrinth: 2 };
    payload.world.selected_index = 0;
    arena.active = [];
    delete arena.orders['hero:0'];
    arena.next_order = 1;
    const hunter = payload.world.arenas.labyrinth;
    hunter.tick = 0;
    hunter.active = ['hero:0', 'hero:1'];
    for (const actor of hunter.active) hunter.orders[actor] = hunter.next_order++;
  }
  if (multi === 'abilities') {
    const classes = ['merchant', 'merchant', 'hunter', 'hunter', 'alchemist', 'alchemist', 'bard'];
    const cells = [[28,16], [28,18], [24,16], [25,16], [30,14], [32,14], [28,20]];
    const template = structuredClone(payload.run.heroes[0]);
    const ally = structuredClone(allies['hero:0']);
    payload.run.heroes = classes.map((class_id, identity) => ({ ...structuredClone(template),
      identity, class_id, arena_id: 'guild_house', selected: identity === 6, cell: cells[identity], facing: 'n',
      recordings: identity < 6 ? { guild_house: { start_cell: cells[identity], events: [
        { tick: identity < 2 ? 30 : 120, action: 'ability', delta: [0,0], slot: 1 },
        { tick: 3600, action: 'move', delta: [1,0], slot: 0 },
      ] } } : {},
    }));
    payload.run.selected_class = 'merchant';
    payload.run.selected_identity = 6;
    payload.run.next_identity = 7;
    payload.run.arena_selection = { guild_house: 6 };
    payload.run.combat.arenas.guild_house.allies = Object.fromEntries(cells.map((cell, i) => [`hero:${i}`, { ...structuredClone(ally), cell }]));
    arena.active = classes.slice(0,6).map((_, i) => `hero:${i}`);
    arena.orders = Object.fromEntries(arena.active.map((actor, i) => [actor, i + 1]));
    arena.next_order = 7;
  }
  document.payload_json = JSON.stringify(payload);
  document.checksum = createHash('sha256').update(document.payload_json).digest('hex');
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
  }), JSON.stringify(document));
}

test('recorded Sacrifice survives Tab and key release until its own recorded move', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await enterProbeWorld(page, log, 4);
    await clickHudMenuAction(page, log, 'save_title');
    await log.wait(s => s?.scene === 'title' && s.saves.ready && !s.saves.busy);
    await channelGuildFixture(page);
    log.events.length = 0;
    log.ready = false;
    await page.reload();
    let state = await log.wait(s => s?.scene === 'title' && s.saves.ready && !s.saves.busy);
    log.downloads = await page.evaluate(() => window.__arenicDownloads);
    log.ready = true;
    await clickLogical(page, state, state.controls.continue.center);
    state = await log.wait(s => s?.picker?.visible && !s.picker.working);
    await clickLogical(page, state, state.picker.rows[0].choose.center);
    state = await log.wait(s => s?.scene === 'world' && s.hero.identity === 1 && s.combat.channel.visible,
      'A third guild member starts Sacrifice through its recorded ability event');
    const firstDamage = state.combat.totals.guild_house;
    const expectGhostChannel = () => log.wait(s => s?.combat?.channel.visible
      && s.combat.channel.caster === 0 && s.combat.channel.target_id === 'boss:guild_house',
    'The recorded Cardinal retains its own beam');
    await page.keyboard.press('Tab');
    state = await log.wait(s => s?.hero?.identity === 2);
    expect(state.combat.channel).toMatchObject({ visible: true, caster: 0 });
    await expectGhostChannel();
    await page.keyboard.press('Tab');
    state = await log.wait(s => s?.hero?.identity === 0 && s.combat.is_channeling,
      'Selecting the ghost preserves the recorded channel');
    await page.keyboard.press('Space');
    state = await expectGhostChannel();
    expect(state.combat.is_channeling).toBe(true);
    await page.keyboard.press('Tab');
    state = await log.wait(s => s?.hero?.identity === 1 && s.combat.channel.visible,
      'Leaving the ghost also preserves its channel');
    await log.wait(s => s?.combat?.channel.visible && s.combat.totals.guild_house > firstDamage,
      'Recorded damage continues across focus and keyboard release changes');
    await page.screenshot({ path: testInfo.outputPath('ghost-owned-sacrifice.png') });
    state = await log.wait(s => s?.recording?.ghosts[0]?.cell[0] === 31 && !s.combat.channel.visible,
      'The actual recorded movement cancels its channel and clears the beam');
    expect(state.recording.ghosts[0].defeated).toBe(false);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});


async function reloadChannelWorld(page, log) {
  log.events.length = 0;
  log.ready = false;
  await page.reload();
  let state = await log.wait(s => s?.scene === 'title' && s.saves.ready && !s.saves.busy);
  log.downloads = await page.evaluate(() => window.__arenicDownloads);
  log.ready = true;
  await clickLogical(page, state, state.controls.continue.center);
  state = await log.wait(s => s?.picker?.visible && !s.picker.working);
  await clickLogical(page, state, state.picker.rows[0].choose.center);
  return log.wait(s => s?.scene === 'world' && !s.motion_active);
}

async function storedChannels(page) {
  return page.evaluate(() => new Promise((resolve, reject) => {
    const request = indexedDB.open('arenic-saves', 1);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const db = request.result;
      const tx = db.transaction('slots', 'readonly');
      const read = tx.objectStore('slots').get(0);
      tx.oncomplete = () => {
        db.close();
        const payload = JSON.parse(JSON.parse(read.result).payload_json);
        resolve({ casters: Object.keys(payload.run.combat.casts).sort(), modal: payload.world.modal.title ?? '' });
      };
      tx.onabort = () => { db.close(); reject(tx.error); };
    };
  }));
}

test('two recorded Cardinals and a recording Cardinal keep independent animated Sacrifice beams, including reload', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await enterProbeWorld(page, log, 4);
    await clickHudMenuAction(page, log, 'save_title');
    await log.wait(s => s?.scene === 'title' && s.saves.ready && !s.saves.busy);
    await channelGuildFixture(page, true);
    const ready = await reloadChannelWorld(page, log);
    expect(ready.hero.arena).toBe('labyrinth');
    await page.keyboard.press('r');
    await log.wait(s => s?.recording?.state === 'recording' && s.combat.channels.length === 2,
      'Both ghosts begin their own Sacrifice during the new recording');
    const before = log.latest().combat.channels;
    await page.keyboard.down('Space');
    let state = await log.wait(s => s?.combat?.channels.length === 3 && s.recording.captured > 0,
      'The selected recording Cardinal adds a third beam without replacing either ghost');
    const start = log.events.at(-1).sequence;
    const damage = state.combat.totals.labyrinth;
    await log.wait(s => s?.combat?.channels.length === 3 && s.combat.channels.every(c => c.age > 1.5)
      && s.combat.totals.labyrinth >= damage + 3, 'All three channels keep animating and damaging the same boss');
    const samples = log.events.filter(e => e.sequence >= start && e.data?.combat?.channels.length === 3);
    expect(samples.length).toBeGreaterThan(3);
    for (const identity of [0, 1, 2]) {
      const channels = samples.map(e => e.data.combat.channels.find(c => c.caster === identity));
      expect(channels.every(c => c.visible && c.segments > 0 && c.target_id === 'boss:labyrinth')).toBe(true);
      expect(new Set(channels.map(c => c.frames.join(','))).size).toBeGreaterThan(1);
    }
    for (const old of before) expect(log.latest().combat.channels.find(c => c.caster === old.caster).age).toBeGreaterThan(old.age);
    await page.screenshot({ path: testInfo.outputPath('three-cardinal-sacrifice.png') });
    await page.keyboard.up('Space');
    state = await log.wait(s => s?.combat?.channels.length === 2 && !s.combat.is_channeling,
      'Releasing only the recorder leaves both ghost beams alive');
    expect(state.combat.channels.map(c => c.caster)).toEqual([0, 1]);
    await page.keyboard.press('r');
    await log.wait(s => s?.recording?.modal_open);
    await expect.poll(() => storedChannels(page), { timeout: 30_000 }).toEqual({ casters: ['hero:0', 'hero:1'], modal: 'Like the recording?' });
    state = await reloadChannelWorld(page, log);
    expect(state.combat.channels.map(c => c.caster)).toEqual([0, 1]);
    expect(state.combat.channels.every(c => c.visible && c.segments > 0)).toBe(true);
    expect(state.recording.modal_open).toBe(true);
    await page.screenshot({ path: testInfo.outputPath('restored-cardinal-sacrifice.png') });
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});


test('mixed recorded abilities keep independent Fortune auras, projectiles and hit ownership through recording and reload', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await enterProbeWorld(page, log, 7);
    await clickHudMenuAction(page, log, 'save_title');
    await log.wait(s => s?.scene === 'title' && s.saves.ready && !s.saves.busy);
    await channelGuildFixture(page, 'abilities');
    await reloadChannelWorld(page, log);
    await page.keyboard.press('r');
    await log.wait(s => s?.recording?.state === 'recording');
    const start = log.events.at(-1).sequence;
    // Flights are shorter than expect.poll's default backoff. Inspect the
    // durable read-only event history so a real observed flight cannot be missed.
    let flight;
    await expect.poll(() => {
      flight = log.events.find(e => e.sequence >= start && e.data?.combat?.cast_effects.filter(fx => ['auto_shot','acid_flask'].includes(fx.ability)).length === 4);
      return Boolean(flight);
    }, { timeout: 20_000 }).toBe(true);
    let state = flight.data;
    expect(state.combat.cast_effects.filter(e => e.ability === 'fortune').map(e => e.caster)).toEqual([0,1]);
    await page.keyboard.press('Space');
    await log.wait(s => s?.recording?.captured > 0 && s.combat.cast_effects.some(e => e.caster === 6 && e.ability === 'cleanse'),
      'The selected Bard records Cleanse beside both Fortune auras');
    state = await log.wait(s => s?.combat?.cast_effects.filter(e => e.ability === 'fortune').length === 2
      && s.combat.cast_effects.filter(e => e.ability === 'fortune').every(e => e.age > 4),
      'Other classes and their impacts cannot remove either Merchant aura');
    const samples = log.events.filter(e => e.sequence >= start && e.data?.combat?.cast_effects);
    for (const caster of [0,1]) {
      const auras = samples.map(e => e.data.combat.cast_effects.find(fx => fx.caster === caster)).filter(Boolean);
      expect(auras.length).toBeGreaterThan(3);
      expect(auras.every(fx => fx.ability === 'fortune' && fx.visible)).toBe(true);
      expect(new Set(auras.map(fx => fx.frame)).size).toBeGreaterThan(1);
    }
    const hitEffects = samples.flatMap(e => e.data.combat.hit_effects);
    expect(hitEffects.some(fx => fx.caster === 2 && fx.ability === 'auto_shot')).toBe(true);
    expect(hitEffects.some(fx => fx.caster === 6 && fx.ability === 'cleanse')).toBe(true);
    expect(hitEffects.every(fx => fx.caster < 0 || fx.ability === ['fortune','fortune','auto_shot','auto_shot','acid_flask','acid_flask','cleanse'][fx.caster])).toBe(true);
    await page.screenshot({ path: testInfo.outputPath('mixed-ability-recording.png') });
    await page.keyboard.press('r');
    await log.wait(s => s?.recording?.modal_open);
    await expect.poll(() => storedChannels(page), { timeout: 30_000 }).toEqual({ casters: ['hero:0','hero:1'], modal: 'Like the recording?' });
    state = await reloadChannelWorld(page, log);
    expect(state.combat.cast_effects.map(e => [e.caster,e.ability,e.visible])).toEqual([[0,'fortune',true],[1,'fortune',true]]);
    expect(state.hero.identity).toBe(6);
    await page.screenshot({ path: testInfo.outputPath('restored-fortune-auras.png') });
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});
