import { test, expect } from '@playwright/test';
import { watch, enterProbeWorld, clickLogical, attachResults } from './helpers.mjs';

test.use({ viewport: { width: 640, height: 360 }, deviceScaleFactor: 1 });
test.describe.configure({ timeout: 180_000 });

test('HUD: real roster, nine arenas, fixed slots and keyboard/pointer holds', async ({ page }, testInfo) => {
  const log = watch(page);
  try {
    let state = await enterProbeWorld(page, log, 4);
    expect(state.hero.class_id).toBe('cardinal');
    expect(state.world_rect).toEqual([13, 35, 1254, 589]);
    expect(state.hud.top.title.text).toBe('Guild House');
    expect(state.hud.top.title.visible).toBe(true);
    expect(state.hud.top.children).toEqual(expect.arrayContaining(['DamageBar', 'ArenaTitle', 'BossEffects', 'GuildRolls', 'RollsReady', 'LootReady']));
    for (const oldControl of ['Wordmark', 'DamageLabel', 'PhaseLabel',
      'ViewContext', 'ArenaHotkey', 'OverviewToggle', 'ControlsHelp', 'SaveAndTitle']) {
      expect(state.hud.top.children).not.toContain(oldControl);
    }
    expect(state.combat.boss_effects).toEqual([]);
    expect(state.hud.top.effects.text).toBe('');
    expect(state.controls.toggle.visible).toBe(false);
    expect(state.controls.save_title.visible).toBe(false);
    expect(state.hud.roster).toMatchObject({ capacity: 40, count: 1, hidden_count: 0 });
    expect(state.hud.roster.entries).toHaveLength(1);
    expect(state.hud.roster.entries[0]).toMatchObject({ identity: state.hero.identity, name: state.hero.name, dead: false });
    expect(state.hud.arenas).toHaveLength(9);
    expect(state.hud.arenas.filter(arena => arena.active).map(arena => arena.index)).toEqual([1]);
    expect(state.hud.raid).toBe('Raid: Normal');
    expect(state.hud.slots.map(slot => slot.slot)).toEqual([1, 2, 3, 4]);
    expect(state.hero.selected).toBe(false);
    expect(state.hud.roster.selected_identity).toBe(-1);
    expect(state.hud.slots.map(slot => [slot.text, slot.hotkey, slot.disabled])).toEqual([
      ['Rotate selected', '1', false], ['Roster', '2', false], ['Loot', '3', false], ['Auction', '4', false],
    ]);
    for (const action of [...state.hud.slots, state.hud.record]) {
      expect(action.rect.slice(2)).toEqual([70, 70]);
    }
    expect(state.hud.slots.slice(1).map(slot => slot.feedback)).toEqual(['', '', '']);
    expect(state.hud.record).toMatchObject({ text: 'Craft', feedback: '' });
    expect(state.hud.chat).toMatchObject({ expanded: false, visible: true });
    expect(state.hud.chat.lines).toHaveLength(4);

    await page.keyboard.press(']');
    state = await log.wait(value => value?.selected_index === 2 && value.hud?.roster.count === 0,
      'Right bracket selects the real empty Sanctum arena');
    expect(state.hero.arena).toBe('guild_house');
    expect(state.hud.top.title.text).toBe('Sanctum');
    expect(state.hud.arenas.filter(arena => arena.active).map(arena => arena.index)).toEqual([2]);
    await page.keyboard.press('[');
    state = await log.wait(value => value?.selected_index === 1 && value.hud?.roster.count === 1,
      'Left bracket restores the actual Guild House hero');
    expect(state.hud.top.title.text).toBe('Guild House');
    await clickLogical(page, state, state.hud.arenas[4].center);
    state = await log.wait(value => value?.selected_index === 4, 'Minimap pointer selects Bastion');
    expect(state.hud.top.title.text).toBe('Bastion');
    await clickLogical(page, state, state.hud.previous.center);
    state = await log.wait(value => value?.selected_index === 3, 'Previous button matches bracket selection');
    await clickLogical(page, state, state.hud.next.center);
    state = await log.wait(value => value?.selected_index === 4, 'Next button matches bracket selection');
    await clickLogical(page, state, state.hud.arenas[1].center);
    state = await log.wait(value => value?.selected_index === 1 && value.hud?.roster.count === 1,
      'Minimap returns to the hero arena');
    await clickLogical(page, state, state.hud.roster.entries[0].center);
    state = await log.wait(value => value?.hero.selected && value.zoomed && !value.motion_active,
      'Roster pointer selects and focuses the real hero');
    expect(state.hud.roster.selected_identity).toBe(state.hero.identity);
    expect(state.hud.slots[0]).toMatchObject({ text: 'Sacrifice', hotkey: '1' });
    expect(state.hud.slots.slice(1).map(slot => [slot.text, slot.hotkey, slot.disabled])).toEqual([
      ['—', '2', true], ['—', '3', true], ['—', '4', true],
    ]);
    expect(state.hud.record).toMatchObject({ text: 'Record', feedback: '' });

    await page.keyboard.press('h');
    state = await log.wait(value => value?.hud?.guide.visible, 'H opens the controls guide');
    expect(state.hud.guide.text).toContain('[ / ]');
    expect(state.controls.toggle.visible).toBe(true);
    expect(state.controls.save_title.visible).toBe(true);
    const [, legendY, legendWidth, legendHeight] = state.hud.guide.legend.rect;
    expect(legendWidth).toBeGreaterThan(0);
    for (const action of [state.controls.toggle, state.controls.save_title, state.hud.guide.close]) {
      expect(legendY + legendHeight, 'The complete controls legend ends above each footer action')
        .toBeLessThanOrEqual(action.rect[1]);
      expect(action.rect[0]).toBeGreaterThanOrEqual(state.hud.guide.rect[0]);
      expect(action.rect[0] + action.rect[2]).toBeLessThanOrEqual(state.hud.guide.rect[0] + state.hud.guide.rect[2]);
      expect(action.rect[1] + action.rect[3]).toBeLessThanOrEqual(state.hud.guide.rect[1] + state.hud.guide.rect[3]);
    }
    await clickLogical(page, state, state.hud.guide.close.center);
    state = await log.wait(value => value?.hud && !value.hud.guide.visible, 'The menu close button returns to the game');
    expect(state.controls.toggle.visible).toBe(false);
    expect(state.controls.save_title.visible).toBe(false);
    await page.keyboard.press('h');
    await log.wait(value => value?.hud?.guide.visible, 'H reopens the same menu');
    await page.keyboard.press('h');
    state = await log.wait(value => value?.hud && !value.hud.guide.visible, 'H closes the guide');
    await page.keyboard.press('c');
    state = await log.wait(value => value?.hud?.chat.expanded, 'C expands the global activity history');
    await clickLogical(page, state, state.hud.chat.header.center);
    state = await log.wait(value => value?.hud?.chat && !value.hud.chat.expanded,
      'The global activity header collapses the history');
    await clickLogical(page, state, state.hud.chat.header.center);
    state = await log.wait(value => value?.hud?.chat.expanded,
      'The global activity header expands the history');
    await page.keyboard.press('c');
    state = await log.wait(value => value?.hud?.chat && !value.hud.chat.expanded,
      'C collapses the global activity history');
    const beforeReserved = state.combat.totals.guild_house;
    const recordingNotices = state.hud.chat.entries.filter(entry => entry.kind === 'recording').length;
    for (const key of ['2', '3', '4']) await page.keyboard.press(key);
    // R arms a real recording; slots 2-4 stay inert.
    await page.keyboard.press('r');
    state = await log.wait(value => value?.recording?.state === 'countdown'
      && value.hud.chat.entries.filter(entry => entry.kind === 'recording').length > recordingNotices,
      'R arms the recording countdown and adds its real activity notice');
    expect(state.combat.is_channeling).toBe(false);
    expect(state.combat.totals.guild_house).toBe(beforeReserved);
    expect(state.hud.record.text).toBe('Record');
    expect(state.hud.record.feedback).toMatch(/^[1-3]$/);
    const armedNotices = state.hud.chat.entries.filter(entry => entry.kind === 'recording').length;
    await page.keyboard.press('r');
    state = await log.wait(value => value?.recording?.state === 'idle'
      && value.hud.chat.entries.filter(entry => entry.kind === 'recording').length > armedNotices,
      'R again aborts the countdown and records the actual cancellation');
    expect(state.hud.record).toMatchObject({ text: 'Record', feedback: '' });

    await page.keyboard.down('1');
    state = await log.wait(value => value?.combat?.is_channeling && value.combat.totals.guild_house > beforeReserved,
      'Slot 1 produces a real timed channel hit');
    expect(state.hud.slots[0]).toMatchObject({ text: 'Sacrifice', feedback: 'Channeling' });
    state = await log.wait(value => value?.hud?.chat.entries.some(entry => entry.kind === 'damage'
      && entry.hero_id === value.hero.identity && entry.ability_id === 'heal'),
      'The global feed reports actual Cardinal channel damage');
    const channelDamage = state.hud.chat.entries.find(entry => entry.kind === 'damage'
      && entry.hero_id === state.hero.identity && entry.ability_id === 'heal');
    expect(channelDamage).toMatchObject({
      hero_id: state.hero.identity, hero_name: state.hero.name,
      ability_id: 'heal', ability_name: 'Sacrifice', arena_id: 'guild_house',
    });
    expect(channelDamage.amount).toBeGreaterThan(0);
    expect(channelDamage.text).toBe(`${state.hero.name} · Sacrifice · ${channelDamage.amount} damage · Guild House`);
    expect(state.combat.boss_effects).toEqual([]);
    expect(state.hud.top.effects.text, 'Direct Cardinal damage must not invent a lingering boss condition').toBe('');
    await page.keyboard.down('Space');
    await page.keyboard.up('1');
    const overlapClock = state.combat.physics_seconds;
    state = await log.wait(value => value?.combat?.physics_seconds > overlapClock + 0.25,
      'Physics advances after releasing only slot 1');
    expect(state.combat.is_channeling).toBe(true);
    await page.keyboard.up('Space');
    state = await log.wait(value => value?.combat && !value.combat.is_channeling,
      'The final held binding release stops the channel');
    state = await log.wait(value => value?.combat?.cooldown === 0, 'Starter cooldown ends');
    await page.keyboard.down('Space');
    await log.wait(value => value?.combat?.is_channeling, 'Space still starts the same starter independently');
    await page.keyboard.up('Space');
    state = await log.wait(value => value?.combat && !value.combat.is_channeling, 'Space release stops the channel');

    // Apply clickLogical's canvas-to-logical mapping to a held pointer gesture.
    const box = await page.locator('#canvas').boundingBox();
    expect(box).toBeTruthy();
    const [width, height] = state.logical;
    const scale = Math.min(box.width / width, box.height / height);
    const movePointer = point => page.mouse.move(
      box.x + (box.width - width * scale) / 2 + point[0] * scale,
      box.y + (box.height - height * scale) / 2 + point[1] * scale);
    for (const target of ['bottom-right hotkey', 'centered title']) {
      state = await log.wait(value => value?.combat?.cooldown === 0 && !value.controls.ability.disabled,
        `The ability is ready for a pointer hold on its ${target}`);
      const slot = state.hud.slots[0];
      const [x, y, w, h] = slot.rect;
      const point = target === 'bottom-right hotkey' ? [x + w - 10, y + h - 11] : slot.center;
      await movePointer(point);
      await page.mouse.down();
      state = await log.wait(value => value?.combat?.is_channeling,
        `Holding the ${target} starts the real channel`);
      await movePointer([x - 12, y + h / 2]);
      await page.mouse.up();
      state = await log.wait(value => value?.combat && !value.combat.is_channeling,
        `Releasing outside the button stops the ${target} channel`);
    }
    expect(state.hud.roster.count).toBe(1);
    expect(state.hud.roster.hidden_count).toBe(0);
    expect(state.hud.slots).toHaveLength(4);
    expect(log.errors).toEqual([]);
  } finally {
    await page.mouse.up();
    await page.keyboard.up('1');
    await page.keyboard.up('Space');
    await attachResults(testInfo, log);
  }
});
