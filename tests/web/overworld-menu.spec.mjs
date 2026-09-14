import { test, expect } from '@playwright/test';
import { watch, enterProbeWorld, clickLogical, attachResults } from './helpers.mjs';

test.use({ viewport: { width: 640, height: 360 }, deviceScaleFactor: 1 });
test.describe.configure({ timeout: 240_000 });

const ACTIONS = ['rotate_selected', 'roster', 'loot', 'auction', 'craft'];
const TITLES = ['Rotate selected', 'Roster', 'Loot', 'Auction', 'Craft'];
const KEYS = ['1', '2', '3', '4', 'r'];

async function savedRun(page) {
  return page.evaluate(() => new Promise((resolve, reject) => {
    const request = indexedDB.open('arenic-saves', 1);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const db = request.result;
      const tx = db.transaction('slots', 'readonly');
      const read = tx.objectStore('slots').get(0);
      tx.oncomplete = () => {
        db.close();
        resolve(read.result ? JSON.parse(JSON.parse(read.result).payload_json) : null);
      };
      tx.onabort = () => { db.close(); reject(tx.error); };
    };
  }));
}

function overview(state) {
  expect(state.zoomed).toBe(false);
  expect(state.hero.selected).toBe(false);
  expect(state.selected_heroes).toEqual([]);
  expect(state.hud.roster.selected_identity).toBe(-1);
  const actions = [...state.hud.slots, state.hud.record];
  expect(actions.map(action => action.text)).toEqual(TITLES);
  expect(actions.every(action => !action.disabled && !action.feedback_visible)).toBe(true);
}

test('overworld actions: keyboard and pointer tabs contain input, run clocks, and restore closed', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    let state = await enterProbeWorld(page, log, 4);
    overview(state);
    const identity = state.hero.identity;
    const cell = state.hero.cell;
    const damage = state.combat.totals.guild_house;
    const arena = state.selected_index;

    // Every shipping shortcut opens its own empty tab, without casting/recording.
    for (const [index, key] of KEYS.entries()) {
      await page.keyboard.press(key);
      state = await log.wait(value => value?.overworld_menu?.active === ACTIONS[index], `${key} opens ${TITLES[index]}`);
      expect(state.overworld_menu.body_children).toBe(0);
      expect(state.overworld_menu.tabs.filter(tab => tab.selected)).toHaveLength(1);
      expect(state.recording.state).toBe('idle');
      expect(state.combat.totals.guild_house).toBe(damage);
      await page.keyboard.press('Escape');
      state = await log.wait(value => value?.overworld_menu && !value.overworld_menu.open, 'Esc closes only the tabs');
      overview(state);
    }

    for (const [index, action] of [...state.hud.slots, state.hud.record].entries()) {
      await clickLogical(page, state, action.center);
      state = await log.wait(value => value?.overworld_menu?.active === ACTIONS[index], `Pointer opens ${TITLES[index]}`);
      await clickLogical(page, state, state.overworld_menu.close.center);
      state = await log.wait(value => value?.overworld_menu && !value.overworld_menu.open, 'X closes the panel');
    }
    await page.keyboard.press('1');
    await log.wait(value => value?.overworld_menu?.active === 'rotate_selected');
    await page.keyboard.press('ArrowLeft');
    await log.wait(value => value?.overworld_menu?.active === 'craft', 'Left wraps to Craft');
    await page.keyboard.press('Tab');
    await log.wait(value => value?.overworld_menu?.active === 'rotate_selected', 'Tab wraps to the first tab');
    await page.keyboard.press('Shift+Tab');
    await log.wait(value => value?.overworld_menu?.active === 'craft', 'Shift-Tab goes backwards');
    await page.keyboard.press('ArrowRight');
    state = await log.wait(value => value?.overworld_menu?.active === 'rotate_selected');
    await clickLogical(page, state, state.overworld_menu.tabs[2].center);
    state = await log.wait(value => value?.overworld_menu?.active === 'loot', 'Pointer switches the active tab');

    const clock = state.combat.physics_seconds;
    for (const key of ['h', 'c', 'n', 'p', 'g', 'l', ']', 'Space', 'ArrowUp', 'ArrowDown']) await page.keyboard.press(key);
    await clickLogical(page, state, state.hud.next.center);
    state = await log.wait(value => value?.combat?.physics_seconds > clock + 0.5, 'Simulation continues under the tools');
    expect(state.overworld_menu.active).toBe('loot');
    expect(state.hero).toMatchObject({ identity, cell, selected: false });
    expect(state.selected_index).toBe(arena);
    expect(state.hud.guide.visible).toBe(false);
    expect(state.hud.chat.expanded).toBe(false);
    expect(state.recording.state).toBe('idle');
    expect(state.combat.totals.guild_house).toBe(damage);
    await page.screenshot({ path: testInfo.outputPath('overworld-loot-tabs-640.png') });
    await page.setViewportSize({ width: 1280, height: 720 });
    state = await log.wait(value => value?.window?.[0] === 1280 && value.overworld_menu?.open, 'The same panel remeasures after resize');
    for (const tab of state.overworld_menu.tabs) {
      expect(tab.rect[0]).toBeGreaterThanOrEqual(state.overworld_menu.panel.rect[0]);
      expect(tab.rect[0] + tab.rect[2]).toBeLessThanOrEqual(state.overworld_menu.panel.rect[0] + state.overworld_menu.panel.rect[2]);
    }
    await page.screenshot({ path: testInfo.outputPath('overworld-loot-tabs-1280.png') });

    // Autosave uses the real facade while the transient overlay is still open.
    await expect.poll(async () => {
      const payload = await savedRun(page);
      return payload?.world?.zoomed === false && payload.run.heroes.every(hero => !hero.selected);
    }, { timeout: 30_000 }).toBe(true);
    const payload = await savedRun(page);
    expect(payload.schema_version).toBe(11);
    expect(payload.run.selected_identity).toBe(identity);
    expect(JSON.stringify(payload)).not.toContain('overworld_menu');
    log.events.length = 0;
    await page.reload();
    await expect(page.locator('#status')).toBeHidden();
    log.downloads = await page.evaluate(() => window.__arenicDownloads);
    state = await log.wait(value => value?.scene === 'title' && value.saves?.ready,
      'Browser restart hydrates the saved overview');
    await clickLogical(page, state, state.controls.continue.center);
    state = await log.wait(value => value?.picker?.visible && !value.picker.working);
    await clickLogical(page, state, state.picker.rows[0].choose.center);
    state = await log.wait(value => value?.scene === 'world' && !value.motion_active, 'Continue restores the overview');
    overview(state);
    expect(state.hero.identity).toBe(identity);
    expect(state.overworld_menu.open).toBe(false);

    await page.keyboard.press('Tab');
    state = await log.wait(value => value?.zoomed && value.hero.selected && !value.motion_active, 'Tab focuses the remembered hero');
    expect(state.hud.slots[0].text).toBe('Sacrifice');
    expect(state.hud.record.text).toBe('Record');
    await page.keyboard.press('Escape');
    state = await log.wait(value => value?.scene === 'world' && !value.zoomed && !value.motion_active, 'Esc returns to overworld actions');
    overview(state);
    await page.screenshot({ path: testInfo.outputPath('overworld-actions.png') });
    expect(log.errors).toEqual([]);
  } finally { await attachResults(testInfo, log); }
});
