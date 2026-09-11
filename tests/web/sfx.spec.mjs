import { test, expect } from '@playwright/test';
import { watch, enterProbeWorld, attachResults } from './helpers.mjs';

test.use({ viewport: { width: 640, height: 360 }, deviceScaleFactor: 1 });
test.describe.configure({ timeout: 180_000 });

async function until(log, predicate, message) {
  await expect.poll(() => Boolean(log.latest()?.sound && predicate(log.latest())),
    { message, timeout: 60_000, intervals: [100, 200] }).toBe(true);
  return log.latest();
}
async function heard(log, after, phase) {
  const matching = () => log.events.filter(e => e.sequence > after && e.kind === 'state' && e.data?.sound);
  await expect.poll(() => matching().some(e => e.data.sound.pcm.peak > 0.00001),
    { message: `Actual SFX PCM after ${phase}`, timeout: 20_000 }).toBe(true);
  await expect.poll(() => matching().some(e => e.data.sound.voices.some(v => v.phase === phase)),
    { message: `Real ${phase} voice`, timeout: 20_000 }).toBe(true);
  expect(matching().every(e => e.data.sound.active <= 12 && e.data.sound.pending <= 12)).toBe(true);
  expect(matching().every(e => e.data.sound.pcm.peak < 0.95)).toBe(true);
}
async function focus(page, log, classIndex) {
  await enterProbeWorld(page, log, classIndex);
  await page.keyboard.press('Tab');
  const state = await until(log, s => s.zoomed && !s.motion_active, 'Hero arena focused');
  expect(state.sound.cues).toMatchObject({ count: 22, errors: [] });
  expect(state.sound.cues.move_seconds).toBeCloseTo(0.5, 5);
  return state;
}

test('sfx: movement, blocked collision and projectile impact produce bounded browser audio', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await focus(page, log, 0);
    let after = log.events.at(-1).sequence;
    await page.keyboard.press('ArrowRight');
    await until(log, s => s.hero.cell[0] === 31, 'Actual movement succeeds');
    await heard(log, after, 'move');
    await until(log, s => s.sound.active === 0 && s.sound.pcm.peak < 0.000001,
      'Footstep ends while independent arena music continues');
    // Walk to the target edge, then try to enter its occupied footprint.
    for (let y = 16; y <= 21; y++) {
      await page.keyboard.press('ArrowUp');
      await until(log, s => s.hero.cell[1] === y, `Real walk to row ${y}`);
    }
    after = log.events.at(-1).sequence;
    await page.keyboard.press('ArrowUp');
    await heard(log, after, 'blocked');
    expect(log.latest().hero.cell).toEqual([31, 21]);
    after = log.events.at(-1).sequence;
    await page.keyboard.press('Space');
    await heard(log, after, 'cast');
    await heard(log, after, 'impact');
    await until(log, s => s.combat.totals.guild_house === 1 && s.sound.active === 0, 'Hit and its sound finish');
    expect(log.latest().sound.peak).toBeLessThanOrEqual(12);
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});

test('sfx: held channel mixes a loop and release leaves no orphan sound', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    await focus(page, log, 4);
    const after = log.events.at(-1).sequence;
    await page.keyboard.down('Space');
    await heard(log, after, 'sustain');
    await heard(log, after, 'impact');
    await until(log, s => s.combat.is_channeling && s.sound.voices.some(v => v.loop && v.playing), 'Channel owns a real looping player');
    await page.keyboard.up('Space');
    const stopped = await until(log, s => !s.combat.is_channeling && s.sound.active === 0
      && s.sound.pcm.peak < 0.000001, 'Release fades loop and lets one-shot hit tail finish');
    expect(stopped.sound.pending).toBe(0);
    await page.keyboard.press('p');
    await until(log, s => !s.zoomed && s.sound.active === 0, 'Overview remains free of stale channel audio');
    expect(log.errors).toEqual([]);
  } finally {
    await page.keyboard.up('Space').catch(() => {});
    await attachResults(testInfo, log);
  }
});
