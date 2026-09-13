import { test, expect } from '@playwright/test';
import { watch, installAudioMeter, loadGame, renderedPixels, clickTitleButton, clickLogical, enterProbeWorld, attachResults, GAME, PROBE, CLASSES, ARENAS } from './helpers.mjs';

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
    // The audio context unlocks on the title click, so it cannot prove world
    // readiness. Wait for the dark, nonblack HUD bands before sending game keys.
    await expect.poll(async () => (await renderedPixels(page, [[0.48, 0.02], [0.78, 0.02], [0.78, 0.99]]))
      .every(pixel => pixel.slice(0, 3).every(channel => channel > 5 && channel < 100)),
    { message: 'Rendered world HUD is ready', timeout: 60_000 }).toBe(true);
    await expect.poll(() => page.evaluate(() => window.__arenicAudioReadback().some(row => row.state === 'running' && row.samples > 0)), { timeout: 30_000 }).toBe(true);
    await page.keyboard.press('p');
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
    expect(state.hero).toMatchObject({ class_id: 'warrior', arena: 'guild_house', cell: [30, 15] });
    expect(state.arena).toBe('guild_house');
    expect(state.zoomed).toBe(false);
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
    await clickLogical(page, state, state.controls.toggle.center);
    await log.wait(value => value?.zoomed && !value.motion_active);
    await page.keyboard.press('Escape');
    await log.wait(value => value?.zoomed === false && !value.motion_active);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

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
      await clickLogical(page, state, state.controls.toggle.center);
      await log.wait(value => value?.zoomed === false && !value.motion_active);
      await page.setViewportSize({ width: 1440, height: 900 });
      state = await log.wait(value => value?.window[0] >= 1440 * dimensions.dpr - 1);
      await clickLogical(page, state, state.controls.toggle.center);
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
