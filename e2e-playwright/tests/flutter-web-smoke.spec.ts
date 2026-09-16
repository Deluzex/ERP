import { test, expect } from '@playwright/test';

test.describe('Deluzex ERP - Web UI User Simulation', () => {
  test('should load ERP login page and verify page title and elements', async ({ page }) => {
    // Navigate to running Flutter Web instance
    await page.goto('/');

    // Verify page title
    await expect(page).toHaveTitle(/Deluzex/i);

    // Wait for Flutter Web canvas / semantics root to render
    const flutterRoot = page.locator('flt-glass-pane, flutter-view, canvas');
    await expect(flutterRoot.first()).toBeVisible({ timeout: 15000 });
  });
});
