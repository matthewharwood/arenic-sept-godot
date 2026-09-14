// Focused fixture proof against an already-built private browser QA export.
// This uses a new browser context and never touches an existing player database.
import { chromium, expect } from '@playwright/test';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { watch, loadGame, clickLogical } from '../../tests/web/helpers.mjs';

const [baseURL, outputArg] = process.argv.slice(2);
if (!baseURL || !outputArg) throw new Error('Usage: node scripts/fixtures/verify-hunter-browser.mjs BASE_URL OUTPUT_DIR');
const output = resolve(outputArg);
await mkdir(output, { recursive: true });
const seed = await readFile(new URL('../../tests/fixtures/hunter-full-arena-v1/save.arenic.json', import.meta.url), 'utf8');
const browser = await chromium.launch({ headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const context = await browser.newContext({ baseURL, viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
let page = await context.newPage();
const reports = [];

function observe(target) {
  const log = watch(target);
  log.wait = async (predicate, message) => {
    await expect.poll(() => Boolean(predicate(log.latest())), { timeout: 60_000, message }).toBe(true);
    return log.latest();
  };
  return log;
}

async function stored(target) {
  return target.evaluate(() => new Promise((accept, reject) => {
    const request = indexedDB.open('arenic-saves', 1);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const db = request.result;
      const tx = db.transaction('slots', 'readonly');
      const record = tx.objectStore('slots').get(0);
      tx.oncomplete = () => { db.close(); accept(record.result); };
      tx.onabort = () => { db.close(); reject(tx.error); };
    };
  }));
}

async function continueSeed(target, log) {
  let state = await log.wait(s => s?.scene === 'title' && s.saves.ready && !s.saves.busy && s.controls.continue.visible,
    'The existing SaveGames facade recognizes the full arena seed');
  await clickLogical(target, state, state.controls.continue.center);
  state = await log.wait(s => s?.picker?.visible && !s.picker.working);
  const row = state.picker.rows.find(item => item.slot === 0);
  expect(row.choose.disabled).toBe(false);
  await clickLogical(target, state, row.choose.center);
  return log.wait(s => s?.scene === 'world' && s.arena === 'labyrinth' && s.recording.ghosts.length === 40,
    'Continue restores all forty recorded heroes into the Hunter arena');
}

try {
  await page.goto(baseURL);
  await page.evaluate(record => new Promise((accept, reject) => {
    const request = indexedDB.open('arenic-saves', 1);
    request.onupgradeneeded = () => request.result.createObjectStore('slots');
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const db = request.result;
      const tx = db.transaction('slots', 'readwrite');
      tx.objectStore('slots').put(record, 0);
      tx.oncomplete = () => { db.close(); accept(); };
      tx.onabort = () => { db.close(); reject(tx.error); };
    };
  }), seed);
  let log = observe(page);
  await loadGame(page, new URL('__probe__/', baseURL).href, log);
  const initial = await continueSeed(page, log);
  expect(initial.restart.pending).toBe(true);
  expect(initial.restart.phase).toBe('countdown');
  expect(initial.recording.cycle).toBe(0);
  await page.screenshot({ path: `${output}/initial-countdown.png` });
  const active = await log.wait(s => s?.scene === 'world' && s.recording.cycle >= 900 && s.combat.totals.labyrinth > 0,
    'The forty loaded staffs advance and deal actual damage');
  await page.screenshot({ path: `${output}/full-arena-browser.png` });
  await expect.poll(async () => JSON.parse(await stored(page)).revision, { timeout: 20_000 }).toBeGreaterThan(1);
  const saved = JSON.parse(await stored(page));
  const payload = JSON.parse(saved.payload_json);
  expect(payload.schema_version).toBe(7);
  expect(payload.run.heroes).toHaveLength(40);
  expect(payload.world.arenas.labyrinth.active).toHaveLength(40);
  expect(payload.run.heroes.every(hero => hero.level === '1' && hero.recordings.labyrinth.events.at(-1).tick === 7199)).toBe(true);
  reports.push({ stage: 'first-play', cycle: active.recording.cycle, damage: active.combat.totals.labyrinth,
    revision: saved.revision, errors: log.errors });
  expect(log.errors).toEqual([]);
  await page.close();
  page = await context.newPage();
  log = observe(page);
  await loadGame(page, new URL('__probe__/', baseURL).href, log);
  const continued = await continueSeed(page, log);
  expect(continued.combat.totals.labyrinth).toBeGreaterThanOrEqual(Number(payload.run.combat.arenas.labyrinth.damage));
  expect(continued.recording.cycle).toBeGreaterThanOrEqual(payload.world.arenas.labyrinth.tick);
  expect(log.errors).toEqual([]);
  reports.push({ stage: 'continued', ghosts: continued.recording.ghosts.length,
    cycle: continued.recording.cycle, damage: continued.combat.totals.labyrinth, errors: log.errors });
  await writeFile(`${output}/results.json`, JSON.stringify({ passed: true, reports }, null, 2) + '\n');
  console.log(JSON.stringify({ passed: true, reports }));
} finally {
  await context.close();
  await browser.close();
}
