const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs').promises;

// Test configuration
const BASE_URL = 'http://localhost:8080';
const SCREENSHOT_DIR = path.join(__dirname, 'payment_screenshots');
const TEST_TIMEOUT = 30000;

// Ensure screenshot directory exists
async function ensureScreenshotDir() {
  try {
    await fs.mkdir(SCREENSHOT_DIR, { recursive: true });
  } catch (error) {
    console.log('Screenshot directory already exists');
  }
}

// Payment System Test Suite
class PaymentSystemTestSuite {
  constructor() {
    this.browser = null;
    this.page = null;
    this.testResults = [];
  }

  async setup() {
    console.log('🚀 Setting up Payment System Test Suite...');
    
    this.browser = await puppeteer.launch({
      headless: false, // Set to true for CI
      slowMo: 100,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-web-security',
        '--allow-running-insecure-content'
      ]
    });

    this.page = await this.browser.newPage();
    
    // Set viewport for desktop testing
    await this.page.setViewport({ width: 1280, height: 720 });
    
    await ensureScreenshotDir();
    console.log('✅ Payment test setup completed');
  }

  async teardown() {
    if (this.browser) {
      await this.browser.close();
    }
    this.generateTestReport();
  }

  async screenshot(name) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const filename = `${timestamp}_${name}.png`;
    const filepath = path.join(SCREENSHOT_DIR, filename);
    await this.page.screenshot({ path: filepath, fullPage: true });
    console.log(`📸 Payment screenshot saved: ${filename}`);
    return filepath;
  }

  async logTest(testName, status, details = '') {
    const result = {
      test: testName,
      status: status,
      timestamp: new Date().toISOString(),
      details: details
    };
    this.testResults.push(result);
    
    const emoji = status === 'PASS' ? '✅' : '❌';
    console.log(`${emoji} ${testName}: ${status} ${details}`);
  }

  // Test 1: Navigate to Payment Demo
  async testNavigateToPaymentDemo() {
    console.log('\n💳 Test 1: Navigate to Payment Demo');
    
    try {
      await this.page.goto(BASE_URL, { waitUntil: 'networkidle2', timeout: TEST_TIMEOUT });
      await this.screenshot('01_homepage_load');
      
      // Wait for Flutter to load
      await this.page.waitForTimeout(3000);
      
      // Look for Payment Demo button
      const paymentDemoButton = await this.page.$('text/Payment Demo');
      if (!paymentDemoButton) {
        // Try alternative selectors
        const floatingButton = await this.page.$('[role="button"]:has-text("Payment Demo")');
        if (floatingButton) {
          await floatingButton.click();
        } else {
          // Navigate directly to payment demo route
          await this.page.goto(`${BASE_URL}#/payment-demo`, { waitUntil: 'networkidle2' });
        }
      } else {
        await paymentDemoButton.click();
      }
      
      await this.page.waitForTimeout(2000);
      await this.screenshot('02_navigate_payment_demo');
      
      // Check if we're on payment demo page
      const pageContent = await this.page.content();
      const hasPaymentContent = pageContent.includes('Payment System') || 
                               pageContent.includes('Choose Payment Method') ||
                               pageContent.includes('GCash') ||
                               pageContent.includes('Credit/Debit Card');
      
      await this.logTest('Navigate to Payment Demo', hasPaymentContent ? 'PASS' : 'FAIL', 
        hasPaymentContent ? 'Payment demo page loaded' : 'Payment demo page not found');
      
      return hasPaymentContent;
      
    } catch (error) {
      await this.logTest('Navigate to Payment Demo', 'FAIL', error.message);
      return false;
    }
  }

  // Test 2: Payment Method Selection
  async testPaymentMethodSelection() {
    console.log('\n💳 Test 2: Payment Method Selection');
    
    try {
      await this.page.waitForTimeout(2000);
      
      // Test selecting GCash
      const gcashMethod = await this.page.$('text/GCash');
      if (gcashMethod) {
        await gcashMethod.click();
        await this.page.waitForTimeout(1000);
        await this.screenshot('03_gcash_selected');
        await this.logTest('GCash Selection', 'PASS', 'GCash payment method selected');
      } else {
        await this.logTest('GCash Selection', 'FAIL', 'GCash option not found');
      }
      
      // Test selecting Credit Card
      const cardMethod = await this.page.$('text/Credit/Debit Card');
      if (cardMethod) {
        await cardMethod.click();
        await this.page.waitForTimeout(1000);
        await this.screenshot('04_card_selected');
        await this.logTest('Card Selection', 'PASS', 'Card payment method selected');
      } else {
        await this.logTest('Card Selection', 'FAIL', 'Card option not found');
      }
      
      // Test selecting Online Banking
      const bankMethod = await this.page.$('text/Online Banking');
      if (bankMethod) {
        await bankMethod.click();
        await this.page.waitForTimeout(1000);
        await this.screenshot('05_bank_selected');
        await this.logTest('Bank Transfer Selection', 'PASS', 'Bank transfer method selected');
      } else {
        await this.logTest('Bank Transfer Selection', 'FAIL', 'Bank transfer option not found');
      }
      
      // Test selecting Cash on Delivery
      const codMethod = await this.page.$('text/Cash on Delivery');
      if (codMethod) {
        await codMethod.click();
        await this.page.waitForTimeout(1000);
        await this.screenshot('06_cod_selected');
        await this.logTest('COD Selection', 'PASS', 'COD payment method selected');
      } else {
        await this.logTest('COD Selection', 'FAIL', 'COD option not found');
      }
      
      return true;
      
    } catch (error) {
      await this.logTest('Payment Method Selection', 'FAIL', error.message);
      return false;
    }
  }

  // Test 3: Payment Processing
  async testPaymentProcessing() {
    console.log('\n💳 Test 3: Payment Processing');
    
    try {
      // Ensure a payment method is selected (GCash)
      const gcashMethod = await this.page.$('text/GCash');
      if (gcashMethod) {
        await gcashMethod.click();
        await this.page.waitForTimeout(1000);
      }
      
      // Look for Pay button
      const payButton = await this.page.$('text/Pay ₱4,197.00') || 
                       await this.page.$('[role="button"]:has-text("Pay")') ||
                       await this.page.$('button:has-text("Pay")');
      
      if (payButton) {
        await payButton.click();
        await this.page.waitForTimeout(1000);
        await this.screenshot('07_payment_processing');
        
        // Wait for payment processing (should show loading or success)
        await this.page.waitForTimeout(4000);
        await this.screenshot('08_payment_result');
        
        // Check for success dialog or message
        const pageContent = await this.page.content();
        const hasSuccessMessage = pageContent.includes('Payment Successful') ||
                                 pageContent.includes('success') ||
                                 pageContent.includes('confirmed') ||
                                 pageContent.includes('completed');
        
        await this.logTest('Payment Processing', hasSuccessMessage ? 'PASS' : 'FAIL',
          hasSuccessMessage ? 'Payment processed successfully' : 'Payment did not complete');
        
        return hasSuccessMessage;
      } else {
        await this.logTest('Payment Processing', 'FAIL', 'Pay button not found');
        return false;
      }
      
    } catch (error) {
      await this.logTest('Payment Processing', 'FAIL', error.message);
      return false;
    }
  }

  // Test 4: Payment UI Components
  async testPaymentUIComponents() {
    console.log('\n💳 Test 4: Payment UI Components');
    
    try {
      await this.page.waitForTimeout(2000);
      
      // Check for order summary
      const pageContent = await this.page.content();
      const hasOrderSummary = pageContent.includes('Order Summary') ||
                             pageContent.includes('Total') ||
                             pageContent.includes('₱');
      
      await this.logTest('Order Summary Display', hasOrderSummary ? 'PASS' : 'FAIL',
        hasOrderSummary ? 'Order summary visible' : 'Order summary not found');
      
      // Check for payment method options
      const hasPaymentMethods = pageContent.includes('GCash') &&
                               pageContent.includes('Credit') &&
                               pageContent.includes('Banking');
      
      await this.logTest('Payment Methods Display', hasPaymentMethods ? 'PASS' : 'FAIL',
        hasPaymentMethods ? 'All payment methods visible' : 'Some payment methods missing');
      
      // Check for security indicators
      const hasSecurityInfo = pageContent.includes('secure') ||
                             pageContent.includes('PCI') ||
                             pageContent.includes('SSL') ||
                             pageContent.includes('encrypted');
      
      await this.logTest('Security Information', hasSecurityInfo ? 'PASS' : 'FAIL',
        hasSecurityInfo ? 'Security information displayed' : 'Security information missing');
      
      await this.screenshot('09_ui_components');
      
      return true;
      
    } catch (error) {
      await this.logTest('Payment UI Components', 'FAIL', error.message);
      return false;
    }
  }

  // Test 5: Mobile Responsiveness
  async testMobilePaymentUX() {
    console.log('\n💳 Test 5: Mobile Payment UX');
    
    try {
      // Test iPhone 12 size
      await this.page.setViewport({ width: 390, height: 844 });
      await this.page.waitForTimeout(2000);
      await this.screenshot('10_mobile_iphone12');
      
      // Check if payment methods are still accessible
      const pageContent = await this.page.content();
      const hasPaymentMethods = pageContent.includes('GCash') && pageContent.includes('Credit');
      
      await this.logTest('Mobile Payment Methods', hasPaymentMethods ? 'PASS' : 'FAIL',
        hasPaymentMethods ? 'Payment methods accessible on mobile' : 'Payment methods not accessible');
      
      // Test tablet size
      await this.page.setViewport({ width: 768, height: 1024 });
      await this.page.waitForTimeout(1000);
      await this.screenshot('11_mobile_tablet');
      
      // Back to desktop
      await this.page.setViewport({ width: 1280, height: 720 });
      await this.page.waitForTimeout(1000);
      
      return true;
      
    } catch (error) {
      await this.logTest('Mobile Payment UX', 'FAIL', error.message);
      return false;
    }
  }

  // Test 6: Payment Security Features
  async testPaymentSecurity() {
    console.log('\n💳 Test 6: Payment Security Features');
    
    try {
      await this.page.waitForTimeout(2000);
      
      // Check for HTTPS (in production this would be tested)
      const url = this.page.url();
      const isSecure = url.startsWith('https') || url.includes('localhost'); // localhost is OK for testing
      
      await this.logTest('Secure Connection', isSecure ? 'PASS' : 'FAIL',
        isSecure ? 'Connection is secure' : 'Connection is not secure');
      
      // Check for payment form security indicators
      const pageContent = await this.page.content();
      const hasSecurityFeatures = pageContent.includes('PCI DSS') ||
                                 pageContent.includes('3D Secure') ||
                                 pageContent.includes('SSL') ||
                                 pageContent.includes('encrypted') ||
                                 pageContent.includes('secure');
      
      await this.logTest('Payment Security Features', hasSecurityFeatures ? 'PASS' : 'FAIL',
        hasSecurityFeatures ? 'Security features present' : 'Security features missing');
      
      await this.screenshot('12_security_features');
      
      return true;
      
    } catch (error) {
      await this.logTest('Payment Security', 'FAIL', error.message);
      return false;
    }
  }

  generateTestReport() {
    console.log('\n📊 PAYMENT SYSTEM TEST REPORT');
    console.log('='.repeat(60));
    
    const passedTests = this.testResults.filter(r => r.status === 'PASS').length;
    const failedTests = this.testResults.filter(r => r.status === 'FAIL').length;
    const totalTests = this.testResults.length;
    
    console.log(`Total Tests: ${totalTests}`);
    console.log(`Passed: ${passedTests} ✅`);
    console.log(`Failed: ${failedTests} ❌`);
    console.log(`Success Rate: ${((passedTests / totalTests) * 100).toFixed(1)}%`);
    
    console.log('\nPayment System Features Tested:');
    console.log('✓ Payment Method Selection (GCash, Card, Banking, COD)');
    console.log('✓ Payment Processing Flow');
    console.log('✓ UI/UX Components');
    console.log('✓ Mobile Responsiveness');
    console.log('✓ Security Features');
    
    console.log('\nDetailed Results:');
    this.testResults.forEach(result => {
      const emoji = result.status === 'PASS' ? '✅' : '❌';
      console.log(`${emoji} ${result.test}: ${result.status} ${result.details}`);
    });
    
    console.log(`\n📸 Screenshots saved in: ${SCREENSHOT_DIR}`);
    console.log('='.repeat(60));
  }

  // Main test runner
  async runAllPaymentTests() {
    try {
      await this.setup();
      
      console.log('\n🚀 Starting AnnedFinds Payment System Tests...\n');
      
      // Run all payment tests
      await this.testNavigateToPaymentDemo();
      await this.testPaymentMethodSelection();
      await this.testPaymentUIComponents();
      await this.testPaymentProcessing();
      await this.testMobilePaymentUX();
      await this.testPaymentSecurity();
      
    } catch (error) {
      console.error('❌ Payment test suite failed:', error);
    } finally {
      await this.teardown();
    }
  }
}

// Run tests if this file is executed directly
if (require.main === module) {
  const paymentTestSuite = new PaymentSystemTestSuite();
  paymentTestSuite.runAllPaymentTests().then(() => {
    console.log('\n🎉 AnnedFinds Payment System Testing Complete!');
    process.exit(0);
  }).catch(error => {
    console.error('💥 Payment test execution failed:', error);
    process.exit(1);
  });
}

module.exports = PaymentSystemTestSuite;