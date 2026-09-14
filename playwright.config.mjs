import { defineConfig } from '@playwright/test';

const port = Number(process.env.ARENIC_WEB_PORT ?? 4174);
const basePath = `/${(process.env.ARENIC_WEB_BASE_PATH ?? 'arenic-sept-godot').replace(/^\/+|\/+$/g, '')}/`;
const baseURL = process.env.ARENIC_WEB_BASE_URL ?? `http://127.0.0.1:${port}${basePath}`;
const projects = [{
  name: 'chromium',
  use: { browserName: 'chromium', launchOptions: { ignoreDefaultArgs: ['--mute-audio'], args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] } },
}];
if (process.env.ARENIC_WEB_FIREFOX === '1') projects.push({
  name: 'firefox',
  use: { browserName: 'firefox', launchOptions: { firefoxUserPrefs: { 'webgl.force-enabled': true } } },
});

export default defineConfig({
  testDir: './tests/web',
  testMatch: '**/*.spec.mjs',
  timeout: 120_000,
  expect: { timeout: 20_000 },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  // Collect independent failures in one bounded run. Any failure still makes
  // the gate red; every test must pass before deployment is permitted.
  maxFailures: 0,
  forbidOnly: Boolean(process.env.CI),
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL, viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1,
    trace: 'retain-on-failure', screenshot: 'only-on-failure', video: 'retain-on-failure',
  },
  projects,
  webServer: process.env.ARENIC_WEB_BASE_URL ? undefined : {
    command: 'node tests/web/serve.mjs', url: baseURL, timeout: 15_000,
    reuseExistingServer: false,
  },
});
