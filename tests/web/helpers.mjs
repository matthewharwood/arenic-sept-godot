import { expect } from '@playwright/test';
import { writeFile } from 'node:fs/promises';

export const GAME = process.env.ARENIC_GAME_URL ?? 'play/';
export const PROBE = process.env.ARENIC_PROBE_URL ?? '__probe__/';
export const CLASSES = [
  ['hunter', 'Dean'], ['bard', 'Marcus'], ['merchant', 'Calvin'], ['warrior', 'King'],
  ['cardinal', 'Pius'], ['alchemist', 'Giuseppe'], ['forager', 'Daisy'], ['thief', 'Ginger'],
];
export const ARENAS = [
  ['l', 'labyrinth'], ['g', 'guild_house'], ['s', 'sanctum'], ['f', 'mountain'],
  ['w', 'bastion'], ['t', 'pawnshop'], ['a', 'crucible'], ['m', 'casino'], ['b', 'gala'],
];

export function watch(page) {
  const failures = [];
  const log = { events: [], console: [], requests: [], downloads: [], ready: false };
  Object.defineProperty(log, 'errors', { get: () => [
    ...failures,
    ...log.requests.filter(row => !(log.ready && row.error === 'net::ERR_ABORTED' && /\.(pck|wasm)$/.test(new URL(row.url).pathname)
      && log.downloads.some(download => download.url === row.url && download.status === 200 && download.done
        && download.expected > 0 && download.bytes === download.expected)))
      .map(row => `${row.method} ${row.url}: ${row.error}`),
  ] });
  page.on('console', message => {
    const text = message.text();
    log.console.push({ type: message.type(), text });
    if (text.startsWith('ARENIC_CI ')) {
      try { log.events.push(JSON.parse(text.slice(10))); }
      catch (error) { failures.push(String(error)); }
    } else if (message.type() === 'error' || /SCRIPT ERROR:|SHADER ERROR:|^ERROR:/.test(text)) failures.push(text);
  });
  page.on('pageerror', error => failures.push(String(error)));
  page.on('requestfailed', request => log.requests.push({ method: request.method(), url: request.url(), error: request.failure()?.errorText }));
  page.on('response', response => {
    if (response.status() >= 400 && !response.url().endsWith('/favicon.ico')) failures.push(`HTTP ${response.status()}: ${response.url()}`);
  });
  log.latest = () => log.events.findLast(event => event.kind === 'state')?.data;
  log.wait = async (predicate, message, options = {}) => {
    await expect.poll(() => Boolean(predicate(log.latest())), { ...options, message }).toBe(true);
    return log.latest();
  };
  log.event = async (kind, after = 0, timeout = 90_000) => {
    await expect.poll(() => log.events.find(event => event.kind === kind && event.sequence > after), { timeout, message: `Godot ${kind} result` }).toBeTruthy();
    return log.events.find(event => event.kind === kind && event.sequence > after);
  };
  return log;
}

// Browser-only passive output tap. It neither unlocks audio nor bypasses autoplay.
// Analyser outputs remain unconnected; the original connection is kept unchanged.
export async function installAudioMeter(page) {
  await page.addInitScript(() => {
    const nativeConnect = AudioNode.prototype.connect;
    const meters = new Map();
    AudioNode.prototype.connect = function (...args) {
      const result = nativeConnect.apply(this, args);
      if (args[0] === this.context.destination) {
        let meter = meters.get(this.context);
        if (!meter) {
          const analyser = this.context.createAnalyser();
          analyser.fftSize = 2048;
          meter = { analyser, sources: new WeakSet(), data: new Float32Array(2048), peak: 0, samples: 0 };
          meters.set(this.context, meter);
        }
        if (!meter.sources.has(this)) {
          nativeConnect.call(this, meter.analyser);
          meter.sources.add(this);
        }
      }
      return result;
    };
    setInterval(() => {
      for (const meter of meters.values()) {
        meter.analyser.getFloatTimeDomainData(meter.data);
        for (const value of meter.data) meter.peak = Math.max(meter.peak, Math.abs(value));
        meter.samples += meter.data.length;
      }
    }, 50);
    window.__arenicAudioReadback = () => [...meters].map(([context, meter]) => ({
      state: context.state, currentTime: context.currentTime, sampleRate: context.sampleRate,
      peak: meter.peak, samples: meter.samples,
    }));
    window.__arenicAudioReset = () => { for (const meter of meters.values()) { meter.peak = 0; meter.samples = 0; } };
  });
}

export async function loadGame(page, path, log) {
  // Observe the reader Godot actually consumes. No cloned response, replacement
  // stream, retries or extra downloads: successful cancellation needs exact proof.
  await page.addInitScript(() => {
    const nativeFetch = window.fetch;
    window.__arenicDownloads = [];
    window.fetch = async function (...args) {
      const response = await nativeFetch.apply(this, args);
      if (!/\.(pck|wasm)$/.test(new URL(response.url).pathname) || !response.body) return response;
      const encoding = (response.headers.get('content-encoding') ?? '').trim().toLowerCase();
      const contentLength = Number(response.headers.get('content-length'));
      let expected = !encoding || encoding === 'identity' ? contentLength : 0;
      let expectedSource = !encoding || encoding === 'identity' ? 'content-length' : 'unverified-content-encoding';
      // Fetch readers yield decoded bytes. For explicitly compressed responses,
      // trust only the matching asset declared by this exported Godot page.
      // Unknown encodings, undeclared paths and missing sizes remain failures.
      if ((encoding === 'gzip' || encoding === 'br') && typeof GODOT_CONFIG !== 'undefined') {
        const contract = Object.entries(GODOT_CONFIG.fileSizes ?? {}).find(([name, size]) =>
          new URL(name, document.baseURI).href === response.url && Number.isSafeInteger(size) && size > 0);
        if (contract) { expected = contract[1]; expectedSource = 'godot-config-decoded-size'; }
      }
      const row = { url: response.url, status: response.status, expected, expected_source: expectedSource,
        content_length: contentLength, content_encoding: encoding, bytes: 0, done: false };
      window.__arenicDownloads.push(row);
      const nativeGetReader = response.body.getReader;
      response.body.getReader = function (...readerArgs) {
        const reader = nativeGetReader.apply(this, readerArgs);
        const nativeRead = reader.read;
        reader.read = async function (...readArgs) {
          const result = await nativeRead.apply(this, readArgs);
          row.bytes += result.value?.byteLength ?? 0;
          row.done ||= result.done;
          return result;
        };
        return reader;
      };
      return response;
    };
  });
  await page.goto(path);
  await expect(page.locator('#canvas')).toBeVisible();
  await expect.poll(() => log.console.some(item => item.text.startsWith('Build configuration:')), { timeout: 60_000 }).toBe(true);
  await expect(page.locator('#status')).toBeHidden();
  // Chromium can report ERR_ABORTED for a completed Godot streaming load. Accept
  // only the exact asset whose real reader consumed its proven decoded size and reached EOF.
  log.downloads = await page.evaluate(() => window.__arenicDownloads);
  log.ready = true;
}

// Read browser-rendered pixels, never Godot state or a production test hook.
// Screenshot decoding uses browser image/canvas APIs, with no extra dependency.
export async function renderedPixels(page, points) {
  const png = await page.locator('#canvas').screenshot({ scale: 'css' });
  return page.evaluate(async ({ encoded, points }) => {
    const bytes = Uint8Array.from(atob(encoded), character => character.charCodeAt(0));
    const image = await createImageBitmap(new Blob([bytes], { type: 'image/png' }));
    const canvas = new OffscreenCanvas(image.width, image.height);
    const context = canvas.getContext('2d');
    context.drawImage(image, 0, 0);
    const result = points.map(([x, y]) => Array.from(context.getImageData(
      Math.floor(x * canvas.width), Math.floor(y * canvas.height), 1, 1).data));
    image.close();
    return result;
  }, { encoded: png.toString('base64'), points });
}

// Shipping title buttons have centered authored geometry. Read only their
// interior: dark label ink on light paper distinguishes an enabled button from
// disabled Start or hidden Continue without relying on an engine/test hook.
export async function readTitleButton(page, name) {
  const authored = { start: { x: -119, width: 144 }, continue: { x: 88.5, width: 205 } }[name];
  if (!authored) throw new Error(`Unknown title button: ${name}`);
  const box = await page.locator('#canvas').boundingBox();
  expect(box).toBeTruthy();
  const scale = Math.min(box.width / 1440, box.height / 1024);
  const center = [box.width / 2 + authored.x * scale, box.height / 2 + 237.5 * scale];
  const png = await page.locator('#canvas').screenshot({ scale: 'css' });
  const sample = await page.evaluate(async ({ encoded, center, width, scale }) => {
    const bytes = Uint8Array.from(atob(encoded), character => character.charCodeAt(0));
    const image = await createImageBitmap(new Blob([bytes], { type: 'image/png' }));
    const canvas = new OffscreenCanvas(image.width, image.height);
    const context = canvas.getContext('2d');
    context.drawImage(image, 0, 0);
    const data = context.getImageData(Math.round(center[0] - (width - 28) * scale / 2),
      Math.round(center[1] - 21 * scale), Math.max(1, Math.round((width - 28) * scale)),
      Math.max(1, Math.round(42 * scale))).data;
    let ink = 0, paper = 0;
    for (let i = 0; i < data.length; i += 4) {
      if (data[i] < 100 && data[i + 1] < 100 && data[i + 2] < 100) ink++;
      if (data[i] > 200 && data[i + 1] > 200 && data[i + 2] > 200) paper++;
    }
    image.close();
    const pixels = data.length / 4;
    return { ready: ink >= Math.max(6, pixels * 0.0075) && paper > pixels * 0.55, ink, paper, pixels };
  }, { encoded: png.toString('base64'), center, width: authored.width, scale });
  return { ...sample, center: [box.x + center[0], box.y + center[1]] };
}

export async function clickTitleButton(page, name) {
  let state;
  await expect.poll(async () => { state = await readTitleButton(page, name); return state.ready; },
    { timeout: 30_000, message: `Rendered ${name} button is visible and enabled after hydration` }).toBe(true);
  await page.mouse.click(...state.center);
}

export async function clickLogical(page, state, point, options = {}) {
  const box = await page.locator('#canvas').boundingBox();
  expect(box).toBeTruthy();
  const [width, height] = state.logical;
  const scale = Math.min(box.width / width, box.height / height);
  await page.mouse.click(box.x + (box.width - width * scale) / 2 + point[0] * scale,
    box.y + (box.height - height * scale) / 2 + point[1] * scale, options);
}

export async function openControlsGuide(page, log) {
  let state = await log.wait(value => value?.scene === 'world' && value.hud?.guide,
    'The game exposes its real controls menu');
  if (!state.hud.guide.visible) {
    await page.keyboard.press('h');
    state = await log.wait(value => value?.hud?.guide.visible
      && value.controls.toggle.visible && value.controls.save_title.visible,
    'H reveals the Overview and Save/Title actions');
  }
  return state;
}

export async function clickHudMenuAction(page, log, action) {
  if (!['toggle', 'save_title'].includes(action)) throw new Error(`Unknown HUD menu action: ${action}`);
  const state = await openControlsGuide(page, log);
  expect(state.controls[action].disabled).toBe(false);
  await clickLogical(page, state, state.controls[action].center);
}

export async function enterProbeWorld(page, log, classIndex = 3, options = {}) {
  await loadGame(page, PROBE, log);
  let state = await log.wait(value => value?.scene === 'title' && value.saves?.ready && !value.controls.start.disabled,
    'Title enables Start after save storage hydration');
  await clickLogical(page, state, state.controls.start.center);
  state = await log.wait(value => value?.scene === 'classes', 'Actual Start opens class selection');
  await clickLogical(page, state, state.cards[classIndex].center);
  state = await log.wait(value => value?.selected_index === classIndex, 'Actual card selection');
  await clickLogical(page, state, state.controls.confirm.center);
  state = await log.wait(value => value?.scene === 'world' && !value.motion_active, 'Actual confirmation opens world');
  if (options.introduction === false) return state;
  await completeIntroduction(page, log);
  // These existing gameplay checks begin at the established training position.
  // Reach it through real controls after completing the actual introduction.
  for (let i = 0; i < 3; i++) {
    await page.keyboard.press('ArrowLeft');
    await log.wait(value => value?.hero?.cell[0] === 32 - i, 'Walk away from the Keeper');
  }
  await page.keyboard.press('ArrowDown');
  await log.wait(value => value?.hero?.cell[1] === 14);
  await page.keyboard.press('ArrowUp');
  await log.wait(value => value?.hero?.cell[1] === 15 && value.hero.facing === 'n');
  await page.keyboard.press('p');
  return log.wait(value => value?.introduction?.step === 6 && !value.zoomed && !value.motion_active, 'Prologue hands off to ordinary navigation');
}

export async function attachResults(testInfo, log, extra = {}) {
  const path = testInfo.outputPath('browser-godot-results.json');
  await writeFile(path, JSON.stringify({ ...extra, events: log.events, errors: log.errors, requests: log.requests, downloads: log.downloads, console: log.console }, null, 2));
  await testInfo.attach('browser-godot-results.json', {
    path,
    contentType: 'application/json',
  });
}

export async function completeIntroduction(page, log) {
  // At Retina density, software rendering can need over 20 wall seconds for
  // 2.75 seconds of the real reading clock. Keep exact state/timer assertions
  // and a bounded allowance; the enclosing gameplay test still has its cap.
  let state = await log.wait(value => value?.introduction, 'Prologue is mounted');
  if (state.introduction.step === 0) {
    state = await log.wait(value => value?.introduction?.elapsed >= 2, 'Opening quote can be read', { timeout: 60_000 });
    await clickLogical(page, state, state.introduction.begin_center);
    state = await log.wait(value => value?.introduction?.step === 1, 'Quote gives way to Guild House');
  }
  if (state.introduction.step === 1) {
    await page.keyboard.press('Space');
    state = await log.wait(value => value?.introduction?.step === 2, 'Space speaks to the Keeper');
  }
  for (let step = state.introduction.step; step <= 5; step++) {
    state = await log.wait(value => value?.introduction?.step === step && value.introduction.elapsed >= 2.75, 'Dialogue beat is readable', { timeout: 60_000 });
    await clickLogical(page, state, state.introduction.next_center);
    await log.wait(value => value?.introduction?.step > step || value?.introduction?.opening, 'Dialogue advances');
  }
  return log.wait(value => value?.introduction?.step === 6 && !value.introduction.opening, 'All Guild House doors finish opening', { timeout: 60_000 });
}
