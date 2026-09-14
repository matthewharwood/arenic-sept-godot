import { test, expect } from '@playwright/test';
import { watch, installAudioMeter, loadGame, renderedPixels, clickTitleButton, clickLogical, clickHudMenuAction, enterProbeWorld, completeIntroduction, attachResults, GAME, PROBE, CLASSES, ARENAS } from './helpers.mjs';

// Software WebGL in CI can take seconds per frame. These are bounded correctness
// checks; native-density rendering remains covered independently of mixer timing.
test.describe.configure({ timeout: 300_000 });

test('clean production: real pointer flow and browser output samples', async ({ page }, testInfo) => {
  // Single-threaded Web audio shares the main thread with rendering. Software
  // WebGL at full density can starve its mixer even while the context runs.
  // Match the dedicated mixer/SFX lane; viewport tests below retain full density.
  await page.setViewportSize({ width: 640, height: 360 });
  const log = watch(page);
  await installAudioMeter(page);
  try {
    await loadGame(page, GAME, log);
    // Wait for actual paper pixels: loader completion precedes the first game
    // frame on slow machines. These outer margins contain no text or animation.
    const marginPoints = [[0.995, 0.1], [0.995, 0.9]];
    await expect.poll(async () => (await renderedPixels(page, marginPoints))
      .every(pixel => pixel.slice(0, 3).every(channel => channel >= 215 && channel <= 250)),
    { message: 'Rendered title paper is ready', timeout: 60_000 }).toBe(true);
    await page.screenshot({ path: testInfo.outputPath('clean-title.png') });
    await clickTitleButton(page, 'start');
    // Class selection has white outer margins. Observe the real rendered scene
    // instead of assuming a fixed delay is enough for loading and layout.
    await expect.poll(async () => (await renderedPixels(page, marginPoints))
      .every(pixel => pixel.slice(0, 3).every(channel => channel >= 253)),
    { message: 'Rendered class selection is ready', timeout: 60_000 }).toBe(true);
    await page.screenshot({ path: testInfo.outputPath('clean-classes.png') });
    const box = await page.locator('#canvas').boundingBox();
    const scale = Math.min(box.width / 1280, box.height / 768);
    const width = box.width / scale;
    const height = box.height / scale;
    const cell = (width - 64 - 11 * 12) / 12;
    const confirmX = 32 + 10 * (cell + 12) + (2 * cell + 12) / 2;
    await page.mouse.click(box.x + confirmX * scale, box.y + (height - 61) * scale);
    // Shipping prologue is driven only through visible pixels and real keys.
    // Authored reading intervals deliberately reject rapid input.
    await expect.poll(async () => (await renderedPixels(page, marginPoints))
      .every(pixel => pixel.slice(0, 3).every(channel => channel >= 215 && channel <= 250)),
    { message: 'Opening quote is rendered', timeout: 60_000 }).toBe(true);
    await page.screenshot({ path: testInfo.outputPath('clean-opening-quote.png') });
    const worldHudVisible = async () => (await renderedPixels(page, [[0.48, 0.02], [0.78, 0.02], [0.78, 0.99]]))
      .every(pixel => pixel.slice(0, 3).every(channel => channel > 5 && channel < 100));
    // The HUD is already visible behind dialogue. Its appearance proves only
    // that the quote closed, not that the introduction released gameplay/audio.
    await expect.poll(async () => {
      await page.keyboard.press('Space');
      return worldHudVisible();
    }, { message: 'Opening quote closes through real input', intervals: [1000], timeout: 60_000 }).toBe(true);
    // These blank footer interiors are paper only while the Keeper card is up.
    // Observe the card arriving before waiting for it to leave, so the brief
    // invitation step cannot be mistaken for a completed introduction.
    const dialogueVisible = async () => (await renderedPixels(page, [[0.55, 0.77], [0.65, 0.77]]))
      .every(pixel => pixel.slice(0, 3).every(channel => channel >= 215 && channel <= 250));
    await expect.poll(async () => {
      if (await dialogueVisible()) return true;
      await page.keyboard.press('Space');
      return false;
    }, { message: 'Keeper dialogue opens through real input', intervals: [1000], timeout: 60_000 }).toBe(true);
    await expect.poll(async () => {
      if (!await dialogueVisible()) return true;
      await page.keyboard.press('Space');
      return false;
    }, { message: 'Keeper finishes every reading beat and opens the doors', intervals: [1000], timeout: 90_000 }).toBe(true);
    await expect.poll(worldHudVisible, { message: 'Rendered world HUD is ready', timeout: 60_000 }).toBe(true);
    await expect.poll(() => page.evaluate(() => window.__arenicAudioReadback().some(row => row.state === 'running' && row.samples > 0)), { timeout: 30_000 }).toBe(true);
    // The final gate animation still holds the music after the card leaves.
    // Fresh audible output proves it released before arena navigation is sent.
    await page.evaluate(() => window.__arenicAudioReset());
    await expect.poll(() => page.evaluate(() => window.__arenicAudioReadback().some(row => row.peak > 0.00001))).toBe(true);
    await page.keyboard.press('l');
    await page.evaluate(() => window.__arenicAudioReset());
    await expect.poll(() => page.evaluate(() => window.__arenicAudioReadback().some(row => row.peak > 0.00001))).toBe(true);
    await page.screenshot({ path: testInfo.outputPath('clean-world.png') });
    expect(log.events, 'No test autoload may ship in production').toHaveLength(0);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log, { outputAudio: await page.evaluate(() => window.__arenicAudioReadback?.() ?? []) }); }
});

test('actual cards, selected hero, movement, arena hotkeys and bracket navigation', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await loadGame(page, PROBE, log);
    let state = await log.wait(value => value?.scene === 'title' && value.saves?.ready && !value.controls.start.disabled,
      'Title enables Start after save storage hydration');
    await clickLogical(page, state, state.controls.start.center);
    state = await log.wait(value => value?.scene === 'classes');
    expect(state.cards.map(card => [card.id, card.character])).toEqual(CLASSES);
    for (let index = 0; index < CLASSES.length; index++) {
      expect(state.cards[index].portrait && state.cards[index].frames).toBe(true);
      await clickLogical(page, state, state.cards[index].center);
      state = await log.wait(value => value?.scene === 'classes' && value.selected_index === index);
      expect(state.character).toBe(CLASSES[index][1]);
    }
    await clickLogical(page, state, state.cards[3].center);
    state = await log.wait(value => value?.selected_index === 3);
    await clickLogical(page, state, state.controls.confirm.center);
    state = await log.wait(value => value?.scene === 'world' && !value.motion_active);
    expect(state.hero).toMatchObject({ class_id: 'warrior', arena: 'guild_house', cell: [33, 15] });
    expect(state.arena).toBe('guild_house');
    expect(state.zoomed).toBe(true);
    expect(state.introduction).toMatchObject({ step: 0, quote_visible: true });
    await completeIntroduction(page, log);
    for (let i = 0; i < 3; i++) {
      await page.keyboard.press('ArrowLeft');
      await log.wait(value => value?.hero?.cell[0] === 32 - i);
    }
    await page.keyboard.press('Tab');
    state = await log.wait(value => value?.zoomed && value.hero.selected && !value.motion_active);
    await page.keyboard.press('ArrowRight');
    state = await log.wait(value => value?.hero.cell[0] === 31);
    expect(state.hero.facing).toBe('e');
    expect(state.arena).toBe('guild_house');
    await page.keyboard.press('ArrowLeft');
    await log.wait(value => value?.hero.cell[0] === 30);
    for (const [key, arena] of ARENAS) {
      await page.keyboard.press(key);
      state = await log.wait(value => value?.arena === arena && value.zoomed && !value.motion_active);
      expect(state.span).toEqual([16.5, 7.75]);
      expect(state.tile_pixels).toBeCloseTo(19, 2);
      expect(state.hero.arena).toBe('guild_house');
    }
    await page.keyboard.press(']');
    await log.wait(value => value?.arena === 'labyrinth' && !value.motion_active);
    await page.keyboard.press('[');
    await log.wait(value => value?.arena === 'gala' && !value.motion_active);
    await page.keyboard.press('p');
    state = await log.wait(value => value?.zoomed === false && !value.motion_active);
    expect(state.span).toEqual([49.5, 23.25]);
    await clickHudMenuAction(page, log, 'toggle');
    await log.wait(value => value?.zoomed && !value.motion_active);
    await page.keyboard.press('Escape');
    await log.wait(value => value?.zoomed === false && !value.motion_active);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

for (const choice of [
  { key: 'Space', method: 'pointer', index: 6, checkRepeat: true },
  { key: 'Enter', method: 'pointer', index: 5 },
  { key: 'Space', method: 'arrow navigation', index: 2 },
  { key: 'Enter', method: 'arrow navigation', index: 3 },
]) {
  test(`class confirmation: ${choice.key} confirms the card selected by ${choice.method}`, async ({ page }, testInfo) => {
    await page.setViewportSize({ width: 640, height: 360 });
    const log = watch(page);
    try {
      await loadGame(page, PROBE, log);
      let state = await openClassSelection(page, log);
      const clickedIndex = choice.method === 'pointer' ? choice.index : choice.index - 2;
      await clickLogical(page, state, state.cards[clickedIndex].center);
      state = await log.wait(value => value?.scene === 'classes' && value.selected_index === clickedIndex
        && value.cards[clickedIndex].focused, 'The pointer-selected class card owns keyboard focus');
      if (choice.method === 'arrow navigation') {
        await page.keyboard.press('ArrowDown');
        state = await log.wait(value => value?.scene === 'classes' && value.selected_index === choice.index
          && value.cards[choice.index].focused, 'ArrowDown selects and focuses the next class card');
      }
      expect(state.character).toBe(CLASSES[choice.index][1]);
      expect(state.controls.confirm.disabled).toBe(false);
      await page.keyboard.down(choice.key);
      state = await log.wait(value => value?.scene === 'world' && value.introduction?.quote_visible,
        `${choice.key} on the focused card opens the selected hero's quote`);
      expect(state.hero).toMatchObject({ class_id: CLASSES[choice.index][0], arena: 'guild_house', cell: [33, 15] });
      expect(state.introduction).toMatchObject({ step: 0, quote_visible: true });
      if (choice.checkRepeat) {
        // A second keydown without keyup is a real browser repeat. Wait until
        // the quote could advance, so its reading guard cannot mask an echo bug.
        state = await log.wait(value => value?.introduction?.elapsed >= 2.1,
          'The opening quote has finished its minimum reading interval');
        const beforeRepeat = state.introduction.elapsed;
        await page.keyboard.down(choice.key);
        state = await log.wait(value => value?.introduction?.elapsed > beforeRepeat + 0.2,
          'The quote continues ticking after a held confirmation key repeats');
        expect(state.introduction).toMatchObject({ step: 0, quote_visible: true });
      }
      await page.keyboard.up(choice.key);
      expect(log.errors).toEqual([]);
    } finally {
      await page.keyboard.up(choice.key).catch(() => {});
      await attachResults(testInfo, log);
    }
  });
}

test('class selection: focused Back retains normal Space and Enter activation', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 640, height: 360 });
  const log = watch(page);
  try {
    await loadGame(page, PROBE, log);
    for (const key of ['Space', 'Enter']) {
      let state = await openClassSelection(page, log);
      await clickLogical(page, state, state.cards[0].center);
      await log.wait(value => value?.scene === 'classes' && value.cards[0].focused,
        'The first card owns focus before navigating back');
      await page.keyboard.press('Shift+Tab');
      state = await log.wait(value => value?.scene === 'classes' && value.controls.back.focused,
        'Shift-Tab gives the actual Back button focus');
      expect(state.controls.confirm.disabled).toBe(false);
      await page.keyboard.press(key);
      await log.wait(value => value?.scene === 'title', `${key} activates focused Back instead of confirming a class`);
    }
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

async function openClassSelection(page, log) {
  const title = await log.wait(value => value?.scene === 'title' && value.saves?.ready && !value.controls.start.disabled,
    'Title enables Start after save storage hydration');
  await clickLogical(page, title, title.controls.start.center);
  return log.wait(value => value?.scene === 'classes', 'Title Start opens class selection');
}

for (const dimensions of [{ width: 1280, height: 720, dpr: 1 }, { width: 1280, height: 720, dpr: 2 }, { width: 1200, height: 900, dpr: 1 }]) {
  test(`viewport and pointer mapping ${dimensions.width}x${dimensions.height} DPR${dimensions.dpr}`, async ({ browser }, testInfo) => {
    const context = await browser.newContext({ viewport: { width: dimensions.width, height: dimensions.height }, deviceScaleFactor: dimensions.dpr });
    const page = await context.newPage();
    const log = watch(page);
    try {
      await enterProbeWorld(page, log);
      await page.keyboard.press('p');
      let state = await log.wait(value => value?.zoomed && !value.motion_active);
      expect(state.logical).toEqual([1280, 720]);
      expect(state.world_rect).toEqual([13, 35, 1254, 589]);
      expect(state.projected_center[0]).toBeCloseTo(640, 2);
      expect(state.projected_center[1]).toBeCloseTo(329.5, 2);
      expect(state.tile_pixels).toBeCloseTo(19, 2);
      await page.keyboard.press('F9');
      const image = (await log.event('framebuffer')).data;
      const canvas = await page.locator('#canvas').evaluate(node => ({ width: node.width, height: node.height }));
      expect(Math.abs(state.window[0] - canvas.width)).toBeLessThanOrEqual(1);
      expect(Math.abs(state.window[1] - canvas.height)).toBeLessThanOrEqual(1);
      const fit = Math.min(canvas.width / 1280, canvas.height / 720);
      expect(Math.abs(image.framebuffer[0] - Math.round(1280 * fit))).toBeLessThanOrEqual(2);
      expect(Math.abs(image.framebuffer[1] - Math.round(720 * fit))).toBeLessThanOrEqual(2);
      expect(image.nonblack_samples).toBe(9);
      await clickHudMenuAction(page, log, 'toggle');
      await log.wait(value => value?.zoomed === false && !value.motion_active);
      await page.setViewportSize({ width: 1440, height: 900 });
      state = await log.wait(value => value?.window[0] >= 1440 * dimensions.dpr - 1);
      await clickHudMenuAction(page, log, 'toggle');
      await log.wait(value => value?.zoomed && !value.motion_active);
      await page.screenshot({ path: testInfo.outputPath('viewport.png') });
      expect(log.errors).toEqual([]);
    } finally { await attachResults(testInfo, log); await context.close(); }
  });
}

test('browser mixer: nine PCM tracks, loops, independent clocks, crossfades, panning and hum', async ({ page }, testInfo) => {
  // Audio correctness does not need a Retina framebuffer. Keep the real game,
  // normal input and engine mixer while bounding unrelated software GPU cost.
  await page.setViewportSize({ width: 640, height: 360 });
  const log = watch(page);
  await installAudioMeter(page);
  try {
    await enterProbeWorld(page, log);
    await page.keyboard.press('F8');
    const result = (await log.event('audio', 0, 240_000)).data;
    expect(result.tracks).toHaveLength(9);
    expect(result.tracks.map(row => row.arena)).toEqual(ARENAS.map(row => row[1]));
    for (const track of result.tracks) {
      expect(track.frames).toBeGreaterThan(0);
      expect(track.passed, `${track.arena} emits PCM`).toBe(true);
      expect(track.loop_passed, `${track.arena} loops after seeking`).toBe(true);
    }
    expect(result.independent_pause_seek).toEqual({ paused: true, resumed: true });
    expect(result.crossfade.overlap_count).toBe(2);
    expect(result.panning.passed).toBe(true);
    expect(result.final.voices.filter(voice => voice.playing)).toHaveLength(0);
    expect(result.final.hum_weight).toBe(1);
    expect(result.passed).toBe(true);
    const output = await page.evaluate(() => window.__arenicAudioReadback());
    expect(output.some(row => row.state === 'running' && row.samples > 0)).toBe(true);
    expect(log.errors).toEqual([]);
    await testInfo.attach('mixer-results.json', { body: Buffer.from(JSON.stringify({ result, output }, null, 2)), contentType: 'application/json' });
  } finally { await attachResults(testInfo, log); }
});
