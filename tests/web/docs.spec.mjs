import { test, expect } from '@playwright/test';

const roster = ['hunter', 'warrior', 'thief', 'alchemist', 'cardinal', 'bard', 'forager', 'merchant'];
function errorsFor(page) {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('response', response => { if (response.status() >= 400) errors.push(`${response.status()} ${response.url()}`); });
  return errors;
}
async function painted(page) {
  await expect(page.locator('#load-error')).toBeEmpty();
  await expect.poll(() => page.locator('#arena').evaluate(canvas => {
    const data = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
    let opaque = 0, changes = 0;
    for (let i = 0; i < data.length; i += 80) { if (data[i + 3]) opaque++; if (i && data[i] !== data[0]) changes++; }
    return opaque > 100 && changes > 100;
  })).toBe(true);
}

test('landing, complete catalog, and mobile navigation use repository-relative links', async ({ page }, testInfo) => {
  const errors = errorsFor(page);
  await page.goto('./');
  await expect(page.getByRole('heading', { name: 'Arenic', exact: true })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Play in browser' })).toHaveAttribute('href', 'play/');
  await page.evaluate(() => document.fonts.ready);
  await expect.poll(() => page.locator('img').evaluateAll(images => images.every(img => img.complete && img.naturalWidth > 0))).toBe(true);
  await page.screenshot({ path: testInfo.outputPath('landing-desktop.png'), fullPage: true });
  await page.setViewportSize({ width: 390, height: 844 });
  await expect(page.getByRole('link', { name: 'Play in browser' })).toBeInViewport();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({ path: testInfo.outputPath('landing-mobile.png'), fullPage: true });
  await page.goto('docs/');
  await expect(page.locator('main > a')).toHaveCount(8);
  await page.goto('docs/bosses/');
  await expect(page.locator('main > a')).toHaveCount(8);
  await page.getByRole('navigation', { name: 'Character type' }).getByRole('link', { name: 'NPCs' }).click();
  await expect(page.locator('main > a')).toHaveCount(1);
  await page.goto('docs/attacks.html');
  await expect(page.locator('main section')).toHaveCount(8);
  await expect(page.locator('main a')).toHaveCount(32);
  const hrefs = await page.locator('main a').evaluateAll(links => links.map(a => a.href));
  expect(new Set(hrefs).size).toBe(32);
  for (const href of hrefs) { const result = await page.request.get(href); expect(result.ok(), href).toBe(true); }
  expect(errors).toEqual([]);
});

test('Keeper NPC booklet renders portrait and native motion, with spoilers closed by default', async ({ page }, testInfo) => {
  const errors = errorsFor(page);
  await page.goto('docs/npcs/');
  await page.locator('main').getByRole('link', { name: /The Keeper/ }).click();
  await expect(page.getByRole('heading', { name: 'The Keeper', exact: true })).toBeVisible();
  await expect.poll(() => page.locator('#portrait').evaluate(image => image.complete && image.naturalWidth > 0)).toBe(true);
  await expect(page.locator('.dialogue li')).toHaveCount(4);
  await expect(page.locator('.dialogue')).toContainText('Choose Commit');
  await expect(page.locator('#design-spoilers')).not.toHaveAttribute('open');
  for (const state of ['idle', 'beckon']) {
    await page.locator('#state').selectOption(state);
    for (const direction of ['n', 'e', 's', 'w']) {
      await page.locator('#direction').selectOption(direction);
      await expect.poll(() => page.locator('#sprite').evaluate(canvas => {
        const pixels = canvas.getContext('2d').getImageData(0, 0, 19, 19).data;
        return Array.from(pixels).some((value, index) => index % 4 === 3 && value > 0);
      })).toBe(true);
    }
  }
  await expect(page.locator('#load-error')).toBeEmpty();
  await page.screenshot({ path: testInfo.outputPath('keeper-booklet-desktop.png'), fullPage: true });
  await page.getByText('Design spoilers · future identity', { exact: true }).click();
  await expect(page.locator('#design-spoilers')).toHaveAttribute('open', '');
  await expect(page.locator('#design-spoilers')).toContainText('hidden Architect');
  await page.setViewportSize({ width: 390, height: 844 });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.screenshot({ path: testInfo.outputPath('keeper-booklet-mobile.png'), fullPage: true });
  expect(errors).toEqual([]);
});

for (const hero of roster) test(`${hero}: all four ability previews and linked selection render`, async ({ page }) => {
  const errors = errorsFor(page);
  await page.goto(`docs/${hero}/attacks.html`);
  await expect(page.locator('#cards article')).toHaveCount(4);
  await expect(page.locator('#ability option')).toHaveCount(4);
  await painted(page);
  const abilities = await page.locator('#ability option').evaluateAll(options => options.map(option => option.value));
  for (const ability of abilities) {
    await page.locator('#ability').selectOption(ability);
    await page.locator('#direction').selectOption('s');
    await page.locator('#time').evaluate(input => { input.value = '700'; input.dispatchEvent(new Event('input', { bubbles: true })); });
    await painted(page);
    await expect(page.locator(`#ability-${ability}`)).toBeAttached();
  }
  await page.goto(`docs/${hero}/attacks.html#ability-${abilities[3]}`);
  await expect(page.locator('#ability')).toHaveValue(abilities[3]);
  await painted(page);
  await expect(page.locator('#boss-choice option')).toHaveCount(9);
  const selectedBoss = hero === 'hunter' ? 'alchemist' : 'hunter';
  await page.locator('#boss-choice').selectOption(selectedBoss);
  await page.waitForFunction(id => typeof arenaBoss !== 'undefined' && arenaBoss?.id === id, selectedBoss);
  await painted(page);
  await expect.poll(() => page.evaluate(() => [...document.images].every(image => image.complete && image.naturalWidth > 0))).toBe(true);
  expect(errors).toEqual([]);
});

for (const boss of roster) test(`${boss}: boss forms and four directional studies render`, async ({ page }) => {
  const errors = errorsFor(page);
  await page.goto(`docs/bosses/${boss}/attacks.html`);
  await expect(page.locator('#cards article')).toHaveCount(4);
  await painted(page);
  const states = await page.locator('#state option').evaluateAll(options => options.map(option => option.value));
  expect(states.length).toBeGreaterThan(0);
  for (const state of states) {
    await page.locator('#state').selectOption(state);
    await page.locator('#direction').selectOption('w');
    await page.locator('#time').evaluate(input => { input.value = '700'; input.dispatchEvent(new Event('input', { bubbles: true })); });
    await painted(page);
  }
  await expect(page.locator('#portrait')).toHaveJSProperty('complete', true);
  expect(errors).toEqual([]);
});
