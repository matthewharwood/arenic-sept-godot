import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { test, expect } from '@playwright/test';

const script = await readFile(new URL('../../arenic-game/scripts/persistence/browser_store.gd', import.meta.url), 'utf8');
const bridge = script.match(/const BRIDGE_SOURCE: String = """([\s\S]*?)"""/)[1];

function record(revision, value, run_id) {
  const payload_json = JSON.stringify({ value });
  return JSON.stringify({ revision, run_id, payload_json, checksum: createHash('sha256').update(payload_json).digest('hex') });
}

async function open(page) {
  // An ordinary same-origin document keeps these storage tests independent of
  // renderer timing. End-to-end game saves are covered separately.
  await page.route('**/save-backend-contract', route => route.fulfill({ contentType: 'text/html', body: '<!doctype html><title>Save storage contract</title>' }));
  await page.goto('save-backend-contract');
  await page.addScriptTag({ content: bridge });
}

async function operation(page, name, method, slot = 0, expected = 0, value = '', expectedRunId = '') {
  return page.evaluate(({ name, method, slot, expected, value, expectedRunId }) => new Promise(resolve => {
    window.ArenicIndexedSaveStore.run(1, name, method, slot, expected, value, expectedRunId,
      (_id, result) => resolve(JSON.parse(result)));
  }), { name, method, slot, expected, value, expectedRunId });
}

async function putRaw(page, name, slot, value) {
  await page.evaluate(({ name, slot, value }) => new Promise((resolve, reject) => {
    const request = indexedDB.open(name, 1);
    request.onupgradeneeded = () => request.result.createObjectStore('slots');
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const db = request.result;
      const transaction = db.transaction('slots', 'readwrite');
      transaction.objectStore('slots').put(value, slot);
      transaction.oncomplete = () => { db.close(); resolve(); };
      transaction.onabort = () => { db.close(); reject(transaction.error); };
    };
  }), { name, slot, value });
}

test('IndexedDB storage survives reload and enforces revision commits for eight slots', async ({ page }) => {
  await open(page);
  const name = 'arenic-backend-reload';
  expect(await operation(page, name, 'read')).toMatchObject({ ok: true, records: {} });
  for (let slot = 0; slot < 8; slot++) {
    expect(await operation(page, name, 'write', slot, 0, record(1, `slot-${slot}`))).toMatchObject({ ok: true });
  }
  await page.reload();
  await page.addScriptTag({ content: bridge });
  const restored = await operation(page, name, 'read');
  expect(restored.ok).toBe(true);
  expect(Object.keys(restored.records)).toHaveLength(8);
  for (let slot = 0; slot < 8; slot++) expect(restored.records[slot]).toBe(record(1, `slot-${slot}`));
  expect((await operation(page, name, 'write', 0, 0, record(1, 'stale'))).ok).toBe(false);
  expect((await operation(page, name, 'write', 0, 1, record(2, 'newer'))).ok).toBe(true);
  expect((await operation(page, name, 'delete', 0, 1)).ok).toBe(false);
  expect((await operation(page, name, 'read')).records[0]).toBe(record(2, 'newer'));
  expect((await operation(page, name, 'delete', 0, 2)).ok).toBe(true);
  expect((await operation(page, name, 'read')).records[0]).toBeUndefined();
});

test('IndexedDB two-tab race commits exactly one next revision', async ({ page, context }) => {
  await open(page);
  const second = await context.newPage();
  await open(second);
  const name = 'arenic-backend-concurrent';
  await operation(page, name, 'read');
  const outcomes = await Promise.all([
    operation(page, name, 'write', 0, 0, record(1, 'first')),
    operation(second, name, 'write', 0, 0, record(1, 'second')),
  ]);
  expect(outcomes.filter(result => result.ok)).toHaveLength(1);
  const winner = (await operation(page, name, 'read')).records[0];
  expect([record(1, 'first'), record(1, 'second')]).toContain(winner);
  const updates = await Promise.all([
    operation(page, name, 'write', 0, 1, record(2, 'first')),
    operation(second, name, 'write', 0, 1, record(2, 'second')),
  ]);
  expect(updates.filter(result => result.ok)).toHaveLength(1);
  expect(JSON.parse((await operation(second, name, 'read')).records[0]).revision).toBe(2);
});

test('IndexedDB stale game cannot overwrite a replacement using the same revision', async ({ page, context }) => {
  await open(page);
  const second = await context.newPage();
  await open(second);
  const name = 'arenic-backend-aba-write';
  const originalId = 'a'.repeat(64);
  const replacementId = 'b'.repeat(64);
  expect((await operation(page, name, 'write', 0, 0, record(1, 'original', originalId))).ok).toBe(true);
  expect((await operation(second, name, 'delete', 0, 1, '', originalId)).ok).toBe(true);
  const replacement = record(1, 'replacement', replacementId);
  expect((await operation(second, name, 'write', 0, 0, replacement)).ok).toBe(true);
  expect((await operation(page, name, 'write', 0, 1, record(2, 'stale autosave', originalId))).ok).toBe(false);
  expect((await operation(second, name, 'read')).records[0]).toBe(replacement);
  expect((await operation(second, name, 'write', 0, 1, record(2, 'continued', replacementId))).ok).toBe(true);
});

test('IndexedDB stale delete confirmation cannot remove a replacement using the same revision', async ({ page, context }) => {
  await open(page);
  const second = await context.newPage();
  await open(second);
  const name = 'arenic-backend-aba-delete';
  const originalId = 'a'.repeat(64);
  const replacementId = 'b'.repeat(64);
  expect((await operation(page, name, 'write', 0, 0, record(1, 'original', originalId))).ok).toBe(true);
  expect((await operation(second, name, 'delete', 0, 1, '', originalId)).ok).toBe(true);
  const replacement = record(1, 'replacement', replacementId);
  expect((await operation(second, name, 'write', 0, 0, replacement)).ok).toBe(true);
  expect((await operation(page, name, 'delete', 0, 1, '', originalId)).ok).toBe(false);
  expect((await operation(page, name, 'delete', 0, 1)).ok).toBe(false);
  expect((await operation(second, name, 'read')).records[0]).toBe(replacement);
  expect((await operation(second, name, 'delete', 0, 1, '', replacementId)).ok).toBe(true);
});

test('IndexedDB corrupted records are explicit and reset cannot erase a valid replacement', async ({ page }) => {
  await open(page);
  const name = 'arenic-backend-corrupt';
  for (const damaged of ['{broken', JSON.stringify({ revision: 1, payload_json: 'bad', checksum: 'wrong' }), { unexpected: true }]) {
    await putRaw(page, name, 0, damaged);
    expect((await operation(page, name, 'read')).records[0]).toBeTruthy();
    expect((await operation(page, name, 'write', 0, 0, record(1, 'overwrite'))).ok).toBe(false);
    expect((await operation(page, name, 'delete', 0, -1)).ok).toBe(true);
  }
  await putRaw(page, name, 0, record(41, 'valid replacement'));
  expect((await operation(page, name, 'delete', 0, -1)).ok).toBe(false);
  expect((await operation(page, name, 'read')).records[0]).toBe(record(41, 'valid replacement'));
  expect((await operation(page, name, 'delete', 0, 41)).ok).toBe(true);
});

test('IndexedDB refuses an unsupported physical database version without fallback', async ({ page }) => {
  await open(page);
  const name = 'arenic-backend-future';
  await page.evaluate(name => new Promise((resolve, reject) => {
    const request = indexedDB.open(name, 2);
    request.onupgradeneeded = () => request.result.createObjectStore('slots');
    request.onerror = () => reject(request.error);
    request.onsuccess = () => { request.result.close(); resolve(); };
  }), name);
  const result = await operation(page, name, 'read');
  expect(result.ok).toBe(false);
  expect(result.error).toContain('Cannot use browser save storage');
  expect((await operation(page, name, 'write', 0, 0, record(1, 'lost'))).ok).toBe(false);
});

test('IndexedDB quota failure preserves the previous committed save', async ({ page, context, browserName }) => {
  test.skip(browserName !== 'chromium', 'The real quota override uses Chromium DevTools Protocol.');
  await open(page);
  const name = 'arenic-backend-quota';
  const original = record(1, 'keep this progress');
  const session = await context.newCDPSession(page);
  const origin = new URL(page.url()).origin;
  try {
    // Set the quota before opening IDB; Chromium reserves write space per open
    // database, so shrinking a quota after a successful write can retain credit.
    await session.send('Storage.overrideQuotaForOrigin', { origin, quotaSize: 1024 * 1024 });
    expect((await session.send('Storage.getUsageAndQuota', { origin })).overrideActive).toBe(true);
    expect((await operation(page, name, 'write', 0, 0, original)).ok).toBe(true);
    const result = await operation(page, name, 'write', 0, 1, record(2, 'x'.repeat(2 * 1024 * 1024)));
    expect(result.ok).toBe(false);
    expect(result.error).toContain('Browser storage is full');
    expect((await operation(page, name, 'read')).records[0]).toBe(original);
  } finally {
    await session.send('Storage.overrideQuotaForOrigin', { origin });
    await session.detach();
  }
  expect((await operation(page, name, 'write', 0, 1, record(2, 'retry'))).ok).toBe(true);
});
