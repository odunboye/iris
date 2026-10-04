const { test, expect } = require('@playwright/test');

for (const host of ['index.html', 'canvas-preview.html']) {
  test(`fresh documented starter runs through ${host}`, async ({ browser }) => {
    const context = await browser.newContext({ deviceScaleFactor: 3.5 });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(`/tests/build/docs/greeter/${host}`);
    if (host === 'index.html') {
      await expect(page.getByText('Count: 0', { exact: true })).toBeVisible();
      await page.getByRole('button', { name: 'Increment', exact: true }).click();
      await expect(page.getByText('Count: 1', { exact: true })).toBeVisible();
    } else {
      const canvas = page.locator('#iris-canvas');
      const increment = page.getByRole('button', { name: 'Increment', exact: true });
      await expect(increment).toBeAttached();
      const dimensions = () => canvas.evaluate(el => [el.width, el.height, el.clientWidth, el.clientHeight]);
      const initial = await dimensions();
      const pixels = await canvas.evaluate(el => el.toDataURL());
      await increment.click();
      await expect.poll(() => canvas.evaluate(el => el.toDataURL())).not.toBe(pixels);
      await page.waitForTimeout(300);
      expect(await dimensions()).toEqual(initial);
      expect(initial[0]).toBe(Math.round(initial[2] * 3.5));
      expect(initial[1]).toBe(Math.round(initial[3] * 3.5));
    }
    expect(errors).toEqual([]);
    await context.close();
  });
}
