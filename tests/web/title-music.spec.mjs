import { test, expect } from '@playwright/test';
import { watch, installAudioMeter, loadGame, renderedPixels, attachResults, GAME } from './helpers.mjs';

test.use({ viewport: { width: 640, height: 360 }, deviceScaleFactor: 1 });
test.describe.configure({ timeout: 180_000 });

test('clean production: title theme plays after a gesture and stops on Start', async ({ page }, testInfo) => {
  const log = watch(page);
  await installAudioMeter(page);
  const margins = [[0.995, 0.1], [0.995, 0.9]];
  try {
    await loadGame(page, GAME, log);
    await expect.poll(async () => (await renderedPixels(page, margins))
      .every(pixel => pixel.slice(0, 3).every(value => value >= 215 && value <= 250)),
    { timeout: 60_000, message: 'Title is visibly ready' }).toBe(true);
    // A real click on blank title paper unlocks audio without navigating away.
    const box = await page.locator('#canvas').boundingBox();
    await page.mouse.click(box.x + box.width * 0.9, box.y + box.height * 0.1);
    await expect.poll(() => page.evaluate(() => window.__arenicAudioReadback()
      .some(row => row.state === 'running' && row.peak > 0.00001)),
    { timeout: 30_000, message: 'Title song emits decoded browser audio' }).toBe(true);
    await page.screenshot({ path: testInfo.outputPath('title-music.png') });
    const scale = Math.min(box.width / 1440, box.height / 1024);
    await page.mouse.click(box.x + box.width / 2 - 119 * scale, box.y + box.height / 2 + 237.5 * scale);
    await expect.poll(async () => (await renderedPixels(page, margins))
      .every(pixel => pixel.slice(0, 3).every(value => value >= 253)),
    { timeout: 60_000, message: 'Start opens class selection' }).toBe(true);
    // Let the browser drain already-buffered audio, then measure a fresh second.
    const audioTime = () => page.evaluate(() => Math.max(0, ...window.__arenicAudioReadback().map(row => row.currentTime)));
    let start = await audioTime();
    await expect.poll(audioTime).toBeGreaterThan(start + 1);
    await page.evaluate(() => window.__arenicAudioReset());
    start = await audioTime();
    await expect.poll(audioTime).toBeGreaterThan(start + 1);
    const output = await page.evaluate(() => window.__arenicAudioReadback());
    expect(output.some(row => row.state === 'running' && row.samples > 0)).toBe(true);
    expect(output.every(row => row.peak < 0.000001), 'Title song does not leak into class selection').toBe(true);
    expect(log.events).toHaveLength(0);
    expect(log.errors).toEqual([]);
  } finally {
    await attachResults(testInfo, log, { outputAudio: await page.evaluate(() => window.__arenicAudioReadback?.() ?? []) });
  }
});
