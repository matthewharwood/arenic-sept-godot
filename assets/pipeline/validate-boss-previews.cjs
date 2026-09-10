/* Validate saved boss previews without claiming browser rendering or native art quality. */
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');

const assets = path.resolve(__dirname, '..');
const repository = path.dirname(assets);
const preview = path.join(assets, 'previews');
const javascript = fs.readFileSync(path.join(__dirname, 'boss-preview.js'), 'utf8');
const expected = {
  hunter: ['cycle', 'quiet', 'sorrow', 'startled', 'wrath', 'elation'],
  warrior: ['idle'],
  thief: ['cycle', 'obsidian', 'crimson', 'indigo'],
  alchemist: ['cycle', 'bomb', 'skull', 'potion'],
  cardinal: ['idle'], bard: ['idle'], forager: ['idle'], merchant: ['idle'],
};
const readJSON = filename => JSON.parse(fs.readFileSync(filename, 'utf8'));

function pngSize(buffer) {
  assert.equal(buffer.subarray(0, 8).toString('hex'), '89504e470d0a1a0a', 'Image is a PNG.');
  assert.equal(buffer.toString('ascii', 12, 16), 'IHDR');
  return [buffer.readUInt32BE(16), buffer.readUInt32BE(20)];
}

function checkLinks(filename) {
  const html = fs.readFileSync(filename, 'utf8');
  for (const [, target] of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
    if (/^(data:|https?:|#)/.test(target)) continue;
    assert(fs.existsSync(path.resolve(path.dirname(filename), target)), `${filename}: missing link ${target}`);
  }
}

async function check(identifier) {
  const folder = path.join(preview, 'bosses', identifier);
  const filename = path.join(folder, 'attacks.html');
  const html = fs.readFileSync(filename, 'utf8');
  const match = html.match(/<script>const PAGE=(.*?);<\/script>/s);
  assert(match, `${identifier}: embedded page data exists`);
  const PAGE = JSON.parse(match[1]);
  const manifest = readJSON(path.join(assets, 'bosses', identifier, 'boss.json'));
  const metadata = readJSON(path.join(folder, `${identifier}.json`));
  assert.equal(PAGE.boss.id, identifier);
  assert.deepEqual(PAGE.boss.visual_states.map(state => state.id), expected[identifier]);
  assert.equal(PAGE.boss.default_state, expected[identifier][0]);
  assert.deepEqual(PAGE.roster, Object.keys(expected));
  assert.deepEqual(PAGE.boss.canvas, [114, 114]);
  assert.deepEqual(PAGE.boss.pivot, [57, 57]);
  assert.deepEqual(PAGE.sprite.pivot, [57, 57]);
  assert.deepEqual(PAGE.hero.pivot, [9, 9]);
  assert.deepEqual(PAGE.sprite.frames, metadata.frames);
  assert.deepEqual(PAGE.sprite.tags, metadata.meta.frameTags);
  for (const [key, value] of Object.entries(manifest)) assert.deepEqual(PAGE.boss[key], value, `${identifier}: manifest field ${key}`);
  assert(html.includes(javascript), `${identifier}: embedded code matches the current preview script`);
  assert(!html.includes('__PAGE_DATA__') && !html.includes('__PREVIEW_JS__'));
  const native = fs.readFileSync(path.join(repository, manifest.source));
  const digest = crypto.createHash('sha256').update(native).digest('hex');
  assert.equal(fs.readFileSync(path.join(folder, 'source.sha256'), 'utf8'), digest, `${identifier}: preview reflects current native source`);
  const png = fs.readFileSync(path.join(folder, `${identifier}.png`));
  assert.deepEqual(pngSize(png), [metadata.meta.size.w, metadata.meta.size.h]);
  assert.equal(PAGE.sprite.image, 'data:image/png;base64,' + png.toString('base64'));
  const runtime = path.join(repository, 'arenic-game', 'assets', 'bosses', identifier);
  assert.deepEqual(fs.readFileSync(path.join(runtime, `${identifier}.png`)), png);
  assert.deepEqual(readJSON(path.join(runtime, `${identifier}.json`)), metadata);
  assert(fs.existsSync(path.join(runtime, `${identifier}_frames.tres`)));
  checkLinks(filename);

  const nodes = new Map(), listeners = new Map();
  const ids = new Set([...html.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]));
  let drawing = 0, nextFrame;
  class Element {
    constructor(tag = 'div') {
      this.tagName = tag; this.children = []; this.style = {}; this.value = '';
      this.width = this.height = 209; this.clientWidth = this.clientHeight = 300;
      this.cache = {}; this.checked = true; this.textContent = '';
    }
    append(child) { child.parentElement = this; this.children.push(child); }
    setAttribute(name, value) { this[name] = value; }
    querySelector(query) {
      if (!this.cache[query]) {
        const child = new Element(query === 'canvas' ? 'canvas' : 'div');
        child.parentElement = new Element();
        this.cache[query] = child;
      }
      return this.cache[query];
    }
    getContext() {
      return this.context ??= new Proxy({
        canvas: this,
        drawImage(image, sx, sy, sw, sh, dx, dy, dw, dh) {
          assert([sx, sy, sw, sh, dx, dy, dw, dh].every(Number.isFinite));
          assert(sx >= 0 && sy >= 0 && sw > 0 && sh > 0);
          assert(sx + sw <= image.naturalWidth && sy + sh <= image.naturalHeight, 'Source crop remains inside its sheet.');
          assert.equal(dw, sw, 'Native frame width is preserved.');
          assert.equal(dh, sh, 'Native frame height is preserved.');
          assert(Number.isInteger(dx) && Number.isInteger(dy), 'Frame placement is pixel aligned.');
          drawing++;
        },
      }, {get: (object, key) => object[key] ?? (() => {}), set: (object, key, value) => (object[key] = value, true)});
    }
  }
  const defaults = {direction: 'e', speed: '1', scale: '2', mode: 'scene', 'arena-scale': 'fit', time: '0'};
  const document = {
    hidden: false,
    addEventListener(name, callback) { listeners.set(name, callback); },
    createElement: tag => new Element(tag),
    getElementById(id) {
      assert(ids.has(id), `${identifier}: HTML contains #${id}`);
      if (!nodes.has(id)) {
        const node = new Element(id === 'arena' ? 'canvas' : 'div');
        node.value = defaults[id] ?? '';
        if (id === 'arena') { node.width = 1280; node.height = 720; }
        nodes.set(id, node);
      }
      return nodes.get(id);
    },
  };
  class Image {
    set src(value) {
      assert(value.startsWith('data:image/png;base64,'));
      [this.naturalWidth, this.naturalHeight] = pngSize(Buffer.from(value.split(',')[1], 'base64'));
      this.onload?.();
    }
  }
  const context = {
    PAGE, document, Image, performance: {now: () => 0}, console,
    requestAnimationFrame(callback) { nextFrame = callback; },
    assert(value, message) { assert(value, `${identifier}: ${message}`); },
    stepFrame(time) { assert(nextFrame, 'Animation loop started.'); nextFrame(time); },
  };
  vm.createContext(context);
  vm.runInContext(javascript, context, {filename: 'boss-preview.js'});
  await new Promise(resolve => setImmediate(resolve));
  const report = vm.runInContext(`(() => {
    assert(ready, 'both sprite sheets loaded');
    let samples = 0, boundaryChecks = 0;
    for (const state of boss.visual_states) {
      $('state').value = state.id; now = 99; $('state').onchange();
      assert(now === 0, 'state changes restart the appearance loop');
      for (const dir of ['n', 'e', 's', 'w']) {
        $('direction').value = dir; $('direction').onchange();
        const name = state.tag + '_' + dir, tag = tagFor(sprite, name), total = duration(sprite, name);
        assert(total > 0, 'loop has positive duration');
        const times = new Set([-1, 0, 1, total - 1, total, total + 1, total * 2]);
        let elapsed = 0;
        for (let index = tag.from; index <= tag.to; index++) {
          assert(frameAt(sprite, name, elapsed) === index, 'exact frame boundary chooses the next frame');
          assert(frameAt(sprite, name, elapsed + sprite.frames[index].duration - 1) === index, 'frame holds until its final millisecond');
          times.add(elapsed); times.add(elapsed + sprite.frames[index].duration - 1);
          elapsed += sprite.frames[index].duration; boundaryChecks += 2;
        }
        assert(frameAt(sprite, name, total) === tag.from, 'exact loop boundary returns to the first frame');
        assert(frameAt(sprite, name, -1) === tag.to, 'negative sample wraps to final frame');
        for (const mode of ['scene', 'actor']) {
          $('mode').value = mode;
          for (const scale of ['1', '2', '4', '8']) {
            $('scale').value = scale; $('mode').onchange();
            for (const card of cards) {
              assert(card.canvas.width === (mode === 'actor' ? 114 : 209), 'canvas matches selected view');
              assert(card.canvas.style.width === card.canvas.width * Number(scale) + 'px', 'CSS scale preserves native canvas');
              assert(card.c.imageSmoothingEnabled === false, 'closeups use nearest-neighbor scaling');
            }
            for (const time of times) { now = Math.max(0, time); render(); samples++; }
          }
        }
      }
    }
    $('bounds').checked = false; $('bounds').onchange(); $('bounds').checked = true;
    for (const scale of ['fit', '1', '2']) {
      $('arena-scale').value = scale; $('arena-scale').onchange();
      assert(arena.style.width === (scale === 'fit' ? '100%' : 1280 * Number(scale) + 'px'), 'arena display scale is correct');
    }
    for (const speed of ['0.25', '0.5', '1']) {
      $('speed').value = speed; running = true; now = 0; last = 1000; stepFrame(1020);
      assert(now === 20 * Number(speed), 'playback speed scales elapsed time');
    }
    running = false; now = 125; last = 2000; stepFrame(2020);
    assert(now === 125, 'paused playback does not advance');
    $('play').onclick(); assert(running, 'play button resumes');
    $('play').onclick(); assert(!running, 'play button pauses');
    $('time').value = '137'; $('time').oninput();
    assert(now === 137 && !running, 'scrubbing sets a paused time');
    $('restart').onclick(); assert(now === 0, 'restart resets time');
    assert(!$('load-error').textContent, 'no preview loading or render errors');
    return {boss: boss.id, states: boss.visual_states.length, directions: 4, samples, boundary_checks: boundaryChecks};
  })()`, context);
  document.hidden = true; listeners.get('visibilitychange')();
  assert.equal(vm.runInContext('running', context), false);
  assert(drawing > 0, `${identifier}: native frames were drawn`);
  return {...report, frame_draws: drawing};
}

(async () => {
  const gallery = readJSON(path.join(preview, 'bosses', 'gallery.json'));
  assert.deepEqual(gallery.map(boss => boss.id), Object.keys(expected));
  checkLinks(path.join(preview, 'index.html'));
  checkLinks(path.join(preview, 'bosses', 'index.html'));
  const reports = [];
  for (const identifier of Object.keys(expected)) {
    const report = await check(identifier);
    reports.push(report); console.log(JSON.stringify(report));
  }
  console.log(JSON.stringify({kind: 'Boss preview execution, native export freshness, and tag timing', bosses: reports.length,
    samples: reports.reduce((sum, report) => sum + report.samples, 0),
    boundary_checks: reports.reduce((sum, report) => sum + report.boundary_checks, 0)}));
})().catch(error => { console.error(error); process.exitCode = 1; });
