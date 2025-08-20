const { test, expect } = require('@playwright/test');

test.describe('AnneDFinds Basic UI Tests', () => {
  test('homepage loads successfully', async ({ page }) => {
    await page.goto('/');
    
    // Wait for the page to load
    await page.waitForLoadState('networkidle');
    
    // Check if main elements are present
    await expect(page.locator('text=AnneDFinds')).toBeVisible();
    
    // Check if product cards are loading
    await page.waitForSelector('text=Search products', { timeout: 10000 });
    
    // Take screenshot
    await page.screenshot({ path: 'tests/screenshots/homepage.png', fullPage: true });
  });

  test('theme toggle works', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    // Find and click theme toggle button
    const themeToggle = page.locator('[role="button"] >> icon').first();
    await themeToggle.click();
    
    // Wait a moment for theme to change
    await page.waitForTimeout(1000);
    
    // Take screenshot of dark mode
    await page.screenshot({ path: 'tests/screenshots/dark-mode.png', fullPage: true });
    
    // Click again to go back to light mode
    await themeToggle.click();
    await page.waitForTimeout(1000);
    
    // Take screenshot of light mode
    await page.screenshot({ path: 'tests/screenshots/light-mode.png', fullPage: true });
  });

  test('admin panel access', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    // Navigate to profile/admin access
    // This test just verifies the UI navigation works
    
    // Try to find navigation elements
    const profileTab = page.locator('text=Profile');
    if (await profileTab.isVisible()) {
      await profileTab.click();
      await page.waitForTimeout(2000);
      
      // Take screenshot of profile page
      await page.screenshot({ path: 'tests/screenshots/profile-page.png', fullPage: true });
    }
  });

  test('responsive design', async ({ page }) => {
    // Test mobile view
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await page.screenshot({ path: 'tests/screenshots/mobile-view.png', fullPage: true });
    
    // Test tablet view
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.reload();
    await page.waitForLoadState('networkidle');
    await page.screenshot({ path: 'tests/screenshots/tablet-view.png', fullPage: true });
    
    // Test desktop view
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.reload();
    await page.waitForLoadState('networkidle');
    await page.screenshot({ path: 'tests/screenshots/desktop-view.png', fullPage: true });
  });
});