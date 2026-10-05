const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const path = require('node:path');

const rpcPort = Number(process.env.IRIS_RPC_TEST_PORT || Number(process.env.IRIS_TEST_PORT || 4173) + 1);

// Each example is compiled by make examples-check before this suite runs.
test('typed routes navigate, guard, and respond to browser history', async ({ page }) => {
  await page.goto('/examples/router/index.html');
  await page.getByRole('button', { name: 'Home', exact: true }).click();
  await expect(page.getByText('Current page: Home', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'About', exact: true }).click();
  await expect(page).toHaveURL(/\/about$/);
  await expect(page.getByText('Current page: About', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'User: alice', exact: true }).click();
  await expect(page).toHaveURL(/\/users\/alice$/);
  await page.getByRole('button', { name: '<- Back', exact: true }).click();
  await expect(page.getByText('Current page: About', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Forward ->', exact: true }).click();
  await expect(page.getByText('Current page: User: alice', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'User: admin (blocked)', exact: true }).click();
  await expect(page.getByText('Current page: Home', { exact: true })).toBeVisible();
  await expect(page.getByText('Notice: Redirected away from a blocked page.', { exact: true })).toBeVisible();
  await page.getByRole('textbox').fill('hello world');
  await expect(page.getByText('  -> /?q=hello%20world', { exact: true })).toBeVisible();
});

test('typed RPC decodes validation errors and authenticated results', async ({ page }) => {
  await page.goto(`http://127.0.0.1:${rpcPort}/`);
  await page.getByRole('button', { name: 'Greet', exact: true }).click();
  await expect(page.getByText('Server error 400 (empty_name): Name must not be empty', { exact: true })).toBeVisible();
  await page.getByRole('textbox').nth(0).fill('Ada');
  await page.getByRole('button', { name: 'Greet', exact: true }).click();
  await expect(page.getByText('Hello, Ada!', { exact: true })).toBeVisible();
  await page.getByRole('textbox').nth(1).fill('wrong');
  await page.getByRole('button', { name: 'Call protected endpoint', exact: true }).click();
  await expect(page.getByText('Server error 401 (unauthorized): Missing or invalid bearer token', { exact: true })).toBeVisible();
  await page.getByRole('textbox').nth(1).fill('demo-token');
  await page.getByRole('button', { name: 'Call protected endpoint', exact: true }).click();
  await expect(page.getByText('Secret: The cake is a lie.', { exact: true })).toBeVisible();
});

test('mobile commands marshal results and retire mocked network listeners on pause', async ({ page }) => {
  await page.goto('/examples/mobile-commands/index.html');
  for (const label of ['Toast', 'Alert', 'Confirm', 'Prompt', 'Action sheet', 'Device info', 'Battery info', 'Device id', 'Network status']) {
    await page.getByRole('button', { name: label, exact: true }).click();
  }
  for (const line of ['Toast: shown', 'Alert: dismissed', 'Confirm:', 'Prompt:', 'ActionSheet:', 'DeviceInfo:', 'BatteryInfo:', 'DeviceId: mock-device-id-0000', 'NetworkStatus:']) {
    await expect(page.locator('#iris-app')).toContainText(line);
  }
  await page.evaluate(() => {
    window.__demoListenerRemoved = 0;
    window.__demoNetworkCallback = null;
    mockPlugins.Network.addListener = (_, callback) => {
      window.__demoNetworkCallback = callback;
      return { remove() { window.__demoListenerRemoved++; } };
    };
  });
  await page.getByRole('button', { name: 'Watch network', exact: true }).click();
  await expect.poll(() => page.evaluate(() => !!window.__demoNetworkCallback)).toBe(true);
  await page.evaluate(() => window.__demoNetworkCallback({ connected: false, connectionType: 'none' }));
  await expect(page.locator('#iris-app')).toContainText('NetworkChanged:');
  await page.evaluate(() => dispatchEvent(new Event('pagehide')));
  await expect.poll(() => page.evaluate(() => window.__demoListenerRemoved)).toBe(1);
});

test('theme tokens change actual control colors', async ({ page }) => {
  await page.goto('/examples/theme/index.html');
  const toggle = page.getByRole('button', { name: 'Toggle light/dark', exact: true });
  await expect(toggle).toBeVisible();
  await expect.poll(() => toggle.evaluate(el => getComputedStyle(el).backgroundColor)).toBe('rgb(63, 81, 181)');
  await toggle.click();
  await expect(page.getByText('Theme: iris-dark (dark)', { exact: true })).toBeVisible();
  // Move off the button: its generic hover rule is independent of theme tokens.
  await page.mouse.move(1000, 700);
  await expect.poll(() => toggle.evaluate(el => getComputedStyle(el).backgroundColor)).toBe('rgb(165, 178, 244)');
  await toggle.click();
  await expect(page.getByText('Theme: iris-light (light)', { exact: true })).toBeVisible();
  await page.mouse.move(1000, 700);
  await expect.poll(() => toggle.evaluate(el => getComputedStyle(el).backgroundColor)).toBe('rgb(63, 81, 181)');
});

test('hot reload preserves state and installs each version update', async ({ page }) => {
  await page.goto('/examples/hot-reload/index.html');
  await page.locator('#load-v1').click();
  await expect(page.getByText('Count: 0', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Increment', exact: true }).click();
  await expect(page.getByText('Count: 1', { exact: true })).toBeVisible();
  await page.locator('#load-v2').click();
  await expect(page.locator('#swap-status')).toHaveText('Running v2.');
  await expect(page.getByText('Count: 1', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Increment', exact: true }).click();
  await expect(page.getByText('Count: 11', { exact: true })).toBeVisible();
  await page.locator('#load-v1').click();
  await expect(page.locator('#swap-status')).toHaveText('Running v1.');
  await expect(page.getByText('Count: 11', { exact: true })).toBeVisible();
  expect(await page.evaluate(() => document.adoptedStyleSheets.length)).toBe(1);
});

test('a slow hot-reload request cannot replace the latest selection', async ({ page }) => {
  const source = fs.readFileSync(path.join(__dirname, '../../examples/hot-reload/build/exec/hot-v1-web'), 'utf8');
  let release;
  const gate = new Promise(resolve => { release = resolve; });
  await page.route('**/hot-v1-web', async route => {
    await gate;
    await route.fulfill({ contentType: 'text/javascript', body: source }).catch(() => {});
  });
  await page.goto('/examples/hot-reload/index.html');
  await page.locator('#load-v1').click();
  await page.locator('#load-v2').click();
  await expect(page.locator('#swap-status')).toHaveText('Running v2.');
  release();
  await page.waitForTimeout(150);
  await expect(page.locator('#swap-status')).toHaveText('Running v2.');
  await page.getByRole('button', { name: 'Increment', exact: true }).click();
  await expect(page.getByText('Count: 10', { exact: true })).toBeVisible();
});

for (const failure of ['http', 'syntax']) {
  test(`hot reload ${failure} failure keeps the current app usable and can retry`, async ({ page }) => {
    await page.goto('/examples/hot-reload/index.html');
    await page.locator('#load-v1').click();
    await expect(page.getByText('Count: 0', { exact: true })).toBeVisible();
    await page.route('**/hot-v2-web', route => route.fulfill(failure === 'http'
      ? { status: 404, body: 'not found' }
      : { contentType: 'text/javascript', body: 'this is invalid javascript' }));
    await page.locator('#load-v2').click();
    await expect(page.locator('#swap-status')).toContainText('Could not load v2:');
    await page.getByRole('button', { name: 'Increment', exact: true }).click();
    await expect(page.getByText('Count: 1', { exact: true })).toBeVisible();
    await page.unroute('**/hot-v2-web');
    await page.locator('#load-v2').click();
    await expect(page.locator('#swap-status')).toHaveText('Running v2.');
    await expect(page.getByText('Count: 1', { exact: true })).toBeVisible();
  });
}
