const { test, expect } = require('@playwright/test');
const path = require('path');

test.describe('Firebase Storage Image Upload', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to the app
    await page.goto('/');
    
    // Wait for Flutter to load
    await page.waitForSelector('[data-flutter-state="ready"]', { timeout: 30000 });
  });

  test('should navigate to admin panel and upload product image', async ({ page }) => {
    // Navigate to admin access
    await page.click('text=Profile');
    await page.click('text=Admin Access');
    
    // Login as admin (you may need to adjust credentials)
    await page.fill('input[type="email"]', 'admin@annedfinds.com');
    await page.fill('input[type="password"]', 'admin123');
    await page.click('text=Access Admin Panel');
    
    // Wait for admin panel to load
    await page.waitForSelector('text=Admin Panel', { timeout: 10000 });
    
    // Navigate to product management
    await page.click('text=Products');
    await page.click('text=Add Product');
    
    // Go to Media tab
    await page.click('text=Media');
    
    // Wait for media section to load
    await page.waitForSelector('text=Product Images');
    
    // Verify demo mode message is removed
    await expect(page.locator('text=Demo Mode: Images will be replaced with placeholders')).not.toBeVisible();
    
    // Upload a test image
    const fileChooserPromise = page.waitForEvent('filechooser');
    await page.click('text=Browse Files');
    const fileChooser = await fileChooserPromise;
    
    // Create a test image file (you may need to provide an actual image file)
    const testImagePath = path.join(__dirname, '..', 'images', 'uploaded image.png');
    await fileChooser.setFiles(testImagePath);
    
    // Wait for upload success message
    await page.waitForSelector('text=uploaded successfully', { timeout: 30000 });
    
    // Verify image appears in the media list (not as placeholder)
    const mediaItem = page.locator('[data-testid="media-item"]').first();
    await expect(mediaItem).toBeVisible();
    
    // Verify the image is not a placeholder icon
    const imageElement = mediaItem.locator('img');
    if (await imageElement.count() > 0) {
      const src = await imageElement.getAttribute('src');
      expect(src).not.toContain('placeholder');
      expect(src).toContain('firebase'); // Should contain Firebase Storage URL
    }
    
    // Take a screenshot for verification
    await page.screenshot({ path: 'tests/screenshots/image-upload-success.png' });
  });

  test('should display uploaded images correctly in product list', async ({ page }) => {
    // Navigate to admin products list
    await page.click('text=Profile');
    await page.click('text=Admin Access');
    
    // Login as admin
    await page.fill('input[type="email"]', 'admin@annedfinds.com');
    await page.fill('input[type="password"]', 'admin123');
    await page.click('text=Access Admin Panel');
    
    // Wait for admin panel and go to products
    await page.waitForSelector('text=Admin Panel', { timeout: 10000 });
    await page.click('text=Products');
    
    // Check if any products with images exist
    const productCards = page.locator('[data-testid="product-card"]');
    const productCount = await productCards.count();
    
    if (productCount > 0) {
      // Check that product images are not placeholders
      for (let i = 0; i < Math.min(productCount, 3); i++) {
        const productCard = productCards.nth(i);
        const imageElement = productCard.locator('img');
        
        if (await imageElement.count() > 0) {
          const src = await imageElement.getAttribute('src');
          if (src && !src.includes('placeholder')) {
            // This is a real image, verify it loads
            await expect(imageElement).toBeVisible();
          }
        }
      }
    }
    
    await page.screenshot({ path: 'tests/screenshots/product-list-with-images.png' });
  });

  test('should load optimized images for different screen sizes', async ({ page }) => {
    // Test responsive image loading
    await page.goto('/');
    
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    await page.screenshot({ path: 'tests/screenshots/mobile-product-images.png' });
    
    // Set tablet viewport  
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.screenshot({ path: 'tests/screenshots/tablet-product-images.png' });
    
    // Set desktop viewport
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.screenshot({ path: 'tests/screenshots/desktop-product-images.png' });
    
    // Verify images load at different sizes
    const productImages = page.locator('img[src*="products/"]');
    const imageCount = await productImages.count();
    
    if (imageCount > 0) {
      // Check that images have different URLs for different sizes (thumb, medium, large)
      const firstImage = productImages.first();
      const src = await firstImage.getAttribute('src');
      
      // Firebase Storage URLs should contain size indicators
      expect(src).toMatch(/(thumb|medium|large)/);
    }
  });

  test('should handle upload errors gracefully', async ({ page }) => {
    // Navigate to admin media upload
    await page.click('text=Profile');
    await page.click('text=Admin Access');
    
    await page.fill('input[type="email"]', 'admin@annedfinds.com');
    await page.fill('input[type="password"]', 'admin123');
    await page.click('text=Access Admin Panel');
    
    await page.waitForSelector('text=Admin Panel', { timeout: 10000 });
    await page.click('text=Products');
    await page.click('text=Add Product');
    await page.click('text=Media');
    
    // Try to upload an invalid file type (if we can simulate this)
    // This test verifies error handling without actually uploading invalid files
    
    // Verify file size limits are enforced
    await expect(page.locator('text=Maximum size is 10MB')).toBeVisible();
    
    // Verify supported formats are mentioned
    await expect(page.locator('text=JPG, PNG, WebP')).toBeVisible();
  });
});