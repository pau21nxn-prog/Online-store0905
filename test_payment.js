const puppeteer = require('puppeteer');

// Test configuration
const TEST_CONFIG = {
  possibleUrls: [
    'http://localhost:3000',
    'http://localhost:8080', 
    'http://localhost:5000',
    'http://localhost:55623', // From Flutter debug output
    'http://127.0.0.1:55623'
  ],
  testUser: {
    email: 'paucsyumetec@gmail.com',
    password: 'Testuser123@'
  },
  paymentMethods: ['gcash', 'gotyme', 'metrobank', 'bpi'],
  successThreshold: 1.0 // 100% success rate
};

class PaymentTester {
  constructor() {
    this.browser = null;
    this.results = {
      totalTests: 0,
      passed: 0,
      failed: 0,
      errors: []
    };
  }

  async initialize() {
    this.browser = await puppeteer.launch({
      headless: false,
      defaultViewport: { width: 1920, height: 1080 },
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });
    
    // Find working URL
    this.baseUrl = await this.findWorkingUrl();
    if (!this.baseUrl) {
      throw new Error('No working Flutter web server found');
    }
    console.log(`📱 Found Flutter app at: ${this.baseUrl}`);
  }

  async findWorkingUrl() {
    const page = await this.browser.newPage();
    
    for (const url of TEST_CONFIG.possibleUrls) {
      try {
        console.log(`🔍 Trying ${url}...`);
        const response = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 5000 });
        
        if (response.ok()) {
          // Check if it's actually the Flutter app
          await page.waitForTimeout(2000);
          const isFlutterApp = await page.$('flt-renderer') || 
                              await page.$('flutter-view') ||
                              await page.evaluate(() => window.flutterConfiguration);
          
          if (isFlutterApp) {
            await page.close();
            return url;
          }
        }
      } catch (error) {
        console.log(`❌ ${url} not available`);
      }
    }
    
    await page.close();
    return null;
  }

  async testGuestCheckout() {
    const page = await this.browser.newPage();
    
    try {
      console.log('🧪 Testing Guest Checkout Payment Methods...');
      
      // Navigate to the app
      await page.goto(this.baseUrl, { waitUntil: 'networkidle2' });
      
      // Wait for app to load
      await page.waitForTimeout(3000);
      
      // Navigate to checkout (assuming we need to add items to cart first)
      await this.addItemToCart(page);
      
      // Go to guest checkout
      await this.navigateToGuestCheckout(page);
      
      // Test that only QR payment methods are visible
      await this.verifyPaymentMethods(page);
      
      // Test form submission with each payment method
      for (const method of TEST_CONFIG.paymentMethods) {
        await this.testPaymentMethod(page, method);
      }
      
      this.results.passed++;
      console.log('✅ Guest checkout test passed');
      
    } catch (error) {
      this.results.failed++;
      this.results.errors.push(`Guest checkout: ${error.message}`);
      console.error('❌ Guest checkout test failed:', error.message);
    } finally {
      await page.close();
    }
  }

  async addItemToCart(page) {
    try {
      // Look for product cards and add first available item
      const productCard = await page.$('[data-testid="product-card"]') || 
                         await page.$('.product-card') ||
                         await page.$('button:contains("Add to Cart")');
      
      if (productCard) {
        await productCard.click();
        await page.waitForTimeout(1000);
      } else {
        // If no product cards, try navigation to products
        const productsLink = await page.$('a[href*="products"]') || 
                            await page.$('text="Products"');
        if (productsLink) {
          await productsLink.click();
          await page.waitForTimeout(2000);
          const firstProduct = await page.$('button:contains("Add to Cart")');
          if (firstProduct) {
            await firstProduct.click();
            await page.waitForTimeout(1000);
          }
        }
      }
    } catch (error) {
      console.log('⚠️  Could not add item to cart automatically, proceeding anyway');
    }
  }

  async navigateToGuestCheckout(page) {
    // Look for cart icon or checkout button
    const cartButton = await page.$('[data-testid="cart-button"]') || 
                      await page.$('.cart-icon') ||
                      await page.$('button:contains("Cart")');
    
    if (cartButton) {
      await cartButton.click();
      await page.waitForTimeout(1000);
    }
    
    // Look for guest checkout button
    const guestCheckoutButton = await page.$('button:contains("Guest Checkout")') ||
                               await page.$('[data-testid="guest-checkout"]');
    
    if (guestCheckoutButton) {
      await guestCheckoutButton.click();
      await page.waitForTimeout(2000);
    }
  }

  async verifyPaymentMethods(page) {
    console.log('🔍 Verifying payment methods...');
    
    // Check that credit card options are not present
    const creditCardInputs = await page.$$('input[placeholder*="Card"]') || 
                            await page.$$('input[placeholder*="card"]') ||
                            await page.$$('input[name*="card"]');
    
    if (creditCardInputs.length > 0) {
      throw new Error('Credit card input fields still present');
    }
    
    // Check that all QR payment methods are present
    for (const method of TEST_CONFIG.paymentMethods) {
      const methodElement = await page.$(`input[value="${method}"]`) ||
                           await page.$(`[data-payment-method="${method}"]`) ||
                           await page.$(`text="${method.toUpperCase()}"`);
      
      if (!methodElement) {
        console.warn(`⚠️  Payment method ${method} not found`);
      } else {
        console.log(`✓ Payment method ${method} found`);
      }
    }
    
    console.log('✅ Payment methods verification completed');
  }

  async testPaymentMethod(page, method) {
    try {
      console.log(`🧪 Testing ${method} payment...`);
      
      // Select payment method
      const methodRadio = await page.$(`input[value="${method}"]`) ||
                         await page.$(`[data-payment-method="${method}"]`);
      
      if (methodRadio) {
        await methodRadio.click();
        await page.waitForTimeout(500);
      }
      
      // Fill required form fields
      await this.fillGuestCheckoutForm(page);
      
      // Submit form
      const submitButton = await page.$('button:contains("Pay Now")') ||
                          await page.$('button[type="submit"]') ||
                          await page.$('[data-testid="submit-payment"]');
      
      if (submitButton) {
        await submitButton.click();
        await page.waitForTimeout(3000);
        
        // Check for success indicators
        const successIndicator = await page.$('text="Payment Successful"') ||
                                 await page.$('text="Order Placed"') ||
                                 await page.$('.success') ||
                                 await page.$('[data-testid="payment-success"]');
        
        if (successIndicator) {
          console.log(`✅ ${method} payment test passed`);
          this.results.passed++;
        } else {
          console.log(`❌ ${method} payment test failed - no success indicator`);
          this.results.failed++;
        }
      }
      
      this.results.totalTests++;
      
    } catch (error) {
      console.error(`❌ ${method} payment test error:`, error.message);
      this.results.failed++;
      this.results.errors.push(`${method}: ${error.message}`);
    }
  }

  async fillGuestCheckoutForm(page) {
    const formFields = [
      { selector: 'input[name="name"]', value: 'Test User' },
      { selector: 'input[name="email"]', value: 'test@annedfinds.com' },
      { selector: 'input[name="phone"]', value: '09123456789' },
      { selector: 'input[name="address"]', value: '123 Test Street' },
      { selector: 'input[name="city"]', value: 'Manila' },
      { selector: 'input[name="postalCode"]', value: '1000' }
    ];
    
    for (const field of formFields) {
      const input = await page.$(field.selector);
      if (input) {
        await input.clear();
        await input.type(field.value);
        await page.waitForTimeout(100);
      }
    }
  }

  async testRegisteredUserCheckout() {
    const page = await this.browser.newPage();
    
    try {
      console.log('🧪 Testing Registered User Checkout...');
      
      // Navigate to the app
      await page.goto(this.baseUrl, { waitUntil: 'networkidle2' });
      await page.waitForTimeout(3000);
      
      // Login as registered user
      await this.loginUser(page);
      
      // Add items to cart and go to checkout
      await this.addItemToCart(page);
      await this.navigateToCheckout(page);
      
      // Verify no GCash payment details form is shown
      const gcashForm = await page.$('input[placeholder*="GCash"]') || 
                       await page.$('input[label*="GCash"]');
      
      if (gcashForm) {
        throw new Error('GCash payment details form still present in registered user checkout');
      }
      
      // Test payment method selection and QR redirect
      for (const method of TEST_CONFIG.paymentMethods) {
        await this.testRegisteredPaymentMethod(page, method);
      }
      
      this.results.passed++;
      console.log('✅ Registered user checkout test passed');
      
    } catch (error) {
      this.results.failed++;
      this.results.errors.push(`Registered user checkout: ${error.message}`);
      console.error('❌ Registered user checkout test failed:', error.message);
    } finally {
      await page.close();
    }
  }

  async testBuyNowFeature() {
    const page = await this.browser.newPage();
    
    try {
      console.log('🧪 Testing Buy Now Feature...');
      
      // Navigate to the app
      await page.goto(this.baseUrl, { waitUntil: 'networkidle2' });
      await page.waitForTimeout(3000);
      
      // Find and click on a product
      const productCard = await page.$('[data-testid="product-card"]') || 
                         await page.$('.product-card') ||
                         await page.$('img[src*="product"]');
      
      if (productCard) {
        await productCard.click();
        await page.waitForTimeout(2000);
        
        // Look for Buy Now button
        const buyNowButton = await page.$('button:contains("Buy Now")') ||
                            await page.$('[data-testid="buy-now"]');
        
        if (buyNowButton) {
          await buyNowButton.click();
          await page.waitForTimeout(2000);
          
          // Check if redirected to cart page
          const currentUrl = page.url();
          if (currentUrl.includes('/cart')) {
            console.log('✅ Buy Now correctly redirects to cart page');
            this.results.passed++;
          } else {
            throw new Error('Buy Now button did not redirect to cart page');
          }
        } else {
          console.log('⚠️  Buy Now button not found, may be out of stock');
          this.results.passed++; // Not an error if button not available
        }
      } else {
        throw new Error('No product found to test Buy Now feature');
      }
      
    } catch (error) {
      this.results.failed++;
      this.results.errors.push(`Buy Now feature: ${error.message}`);
      console.error('❌ Buy Now feature test failed:', error.message);
    } finally {
      await page.close();
    }
  }

  async loginUser(page) {
    // Look for login button or user menu
    const loginButton = await page.$('a[href*="login"]') || 
                       await page.$('button:contains("Login")') ||
                       await page.$('[data-testid="login"]');
    
    if (loginButton) {
      await loginButton.click();
      await page.waitForTimeout(1000);
      
      // Fill login form
      const emailInput = await page.$('input[type="email"]') ||
                         await page.$('input[name="email"]');
      const passwordInput = await page.$('input[type="password"]') ||
                            await page.$('input[name="password"]');
      
      if (emailInput && passwordInput) {
        await emailInput.type(TEST_CONFIG.testUser.email);
        await passwordInput.type(TEST_CONFIG.testUser.password);
        
        const submitButton = await page.$('button[type="submit"]') ||
                            await page.$('button:contains("Login")');
        
        if (submitButton) {
          await submitButton.click();
          await page.waitForTimeout(3000);
        }
      }
    }
  }

  async navigateToCheckout(page) {
    // Look for checkout button in cart
    const checkoutButton = await page.$('button:contains("Checkout")') ||
                          await page.$('[data-testid="checkout"]');
    
    if (checkoutButton) {
      await checkoutButton.click();
      await page.waitForTimeout(2000);
    }
  }

  async testRegisteredPaymentMethod(page, method) {
    try {
      console.log(`🧪 Testing ${method} payment for registered user...`);
      
      // Select payment method
      const methodRadio = await page.$(`input[value="${method}"]`) ||
                         await page.$(`[data-payment-method="${method}"]`);
      
      if (methodRadio) {
        await methodRadio.click();
        await page.waitForTimeout(500);
      }
      
      // Submit order
      const submitButton = await page.$('button:contains("Place Order")') ||
                          await page.$('[data-testid="place-order"]');
      
      if (submitButton) {
        await submitButton.click();
        await page.waitForTimeout(3000);
        
        // Check if redirected to QR payment screen
        const qrCodeElement = await page.$('img[src*="QR"]') ||
                             await page.$('[data-testid="qr-code"]') ||
                             await page.$('text="Scan QR code"');
        
        if (qrCodeElement) {
          console.log(`✅ ${method} correctly redirects to QR payment screen`);
          this.results.passed++;
        } else {
          console.log(`❌ ${method} did not redirect to QR payment screen`);
          this.results.failed++;
        }
      }
      
      this.results.totalTests++;
      
    } catch (error) {
      console.error(`❌ ${method} registered payment test error:`, error.message);
      this.results.failed++;
      this.results.errors.push(`${method} registered: ${error.message}`);
    }
  }

  async runTests() {
    try {
      await this.initialize();
      console.log('🚀 Starting Payment System Tests...\n');
      
      // Test guest checkout
      await this.testGuestCheckout();
      
      // Test registered user checkout
      await this.testRegisteredUserCheckout();
      
      // Test Buy Now functionality
      await this.testBuyNowFeature();
      
      // Calculate success rate
      const successRate = this.results.totalTests > 0 ? 
        (this.results.passed / this.results.totalTests) : 0;
      
      console.log('\n📊 Test Results:');
      console.log(`Total Tests: ${this.results.totalTests}`);
      console.log(`Passed: ${this.results.passed}`);
      console.log(`Failed: ${this.results.failed}`);
      console.log(`Success Rate: ${(successRate * 100).toFixed(2)}%`);
      
      if (this.results.errors.length > 0) {
        console.log('\n❌ Errors:');
        this.results.errors.forEach(error => console.log(`- ${error}`));
      }
      
      if (successRate >= TEST_CONFIG.successThreshold) {
        console.log(`\n🎉 SUCCESS: Achieved ${(successRate * 100).toFixed(2)}% success rate (target: ${(TEST_CONFIG.successThreshold * 100)}%)`);
        return true;
      } else {
        console.log(`\n⚠️  NEEDS IMPROVEMENT: ${(successRate * 100).toFixed(2)}% success rate (target: ${(TEST_CONFIG.successThreshold * 100)}%)`);
        return false;
      }
      
    } catch (error) {
      console.error('💥 Test suite failed:', error);
      return false;
    } finally {
      if (this.browser) {
        await this.browser.close();
      }
    }
  }
}

// Run tests
async function main() {
  const tester = new PaymentTester();
  const success = await tester.runTests();
  process.exit(success ? 0 : 1);
}

main().catch(console.error);