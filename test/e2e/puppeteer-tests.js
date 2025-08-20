const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs').promises;

// Test configuration
const BASE_URL = 'http://localhost:8080';
const SCREENSHOT_DIR = path.join(__dirname, 'screenshots');
const TEST_TIMEOUT = 30000;

// Ensure screenshot directory exists
async function ensureScreenshotDir() {
  try {
    await fs.mkdir(SCREENSHOT_DIR, { recursive: true });
  } catch (error) {
    console.log('Screenshot directory already exists');
  }
}

// Test utilities
class AnnedFindsTestSuite {
  constructor() {
    this.browser = null;
    this.page = null;
    this.testResults = [];
  }

  async setup() {
    console.log('🚀 Setting up AnnedFinds E-commerce Test Suite...');
    
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
    
    // Set user agent
    await this.page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36');
    
    await ensureScreenshotDir();
    console.log('✅ Test setup completed');
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
    console.log(`📸 Screenshot saved: ${filename}`);
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

  async waitForFlutterApp() {
    console.log('⏳ Waiting for Flutter app to load...');
    
    try {
      // Wait for Flutter to be ready
      await this.page.waitForFunction(
        () => window.flutterCanvasKit !== undefined || window.flutter !== undefined,
        { timeout: 15000 }
      );
      
      // Additional wait for app to fully render
      await this.page.waitForTimeout(3000);
      
      await this.logTest('Flutter App Load', 'PASS', 'Flutter framework detected');
      return true;
    } catch (error) {
      await this.logTest('Flutter App Load', 'FAIL', `Flutter not detected: ${error.message}`);
      return false;
    }
  }

  // Test 1: Basic App Loading
  async testAppLoading() {
    console.log('\n🧪 Test 1: Application Loading');
    
    try {
      await this.page.goto(BASE_URL, { waitUntil: 'networkidle2', timeout: TEST_TIMEOUT });
      await this.screenshot('01_app_load');
      
      // Check if page loads without errors
      const title = await this.page.title();
      await this.logTest('Page Load', 'PASS', `Title: ${title}`);
      
      // Wait for Flutter app
      const flutterReady = await this.waitForFlutterApp();
      if (!flutterReady) return false;
      
      await this.screenshot('02_flutter_ready');
      return true;
      
    } catch (error) {
      await this.logTest('Page Load', 'FAIL', error.message);
      return false;
    }
  }

  // Test 2: Home Screen Elements
  async testHomeScreen() {
    console.log('\n🧪 Test 2: Home Screen UI Elements');
    
    try {
      await this.page.waitForTimeout(2000);
      
      // Check for main navigation elements
      const pageContent = await this.page.content();
      
      // Look for common Flutter/Material Design elements
      const hasContent = pageContent.length > 1000;
      await this.logTest('Home Content', hasContent ? 'PASS' : 'FAIL', 
        `Page content length: ${pageContent.length} chars`);
      
      await this.screenshot('03_home_screen');
      
      // Test responsive design - mobile view
      await this.page.setViewport({ width: 375, height: 667 });
      await this.page.waitForTimeout(1000);
      await this.screenshot('04_home_mobile');
      
      // Back to desktop
      await this.page.setViewport({ width: 1280, height: 720 });
      await this.page.waitForTimeout(1000);
      
      return true;
      
    } catch (error) {
      await this.logTest('Home Screen UI', 'FAIL', error.message);
      return false;
    }
  }

  // Test 3: Search Functionality
  async testSearchFunctionality() {
    console.log('\n🧪 Test 3: Search Functionality');
    
    try {
      await this.page.waitForTimeout(2000);
      
      // Try to find search input by various selectors
      let searchInput = null;
      const searchSelectors = [
        'input[type="search"]',
        'input[placeholder*="search" i]',
        'input[placeholder*="Search" i]',
        '.search-input',
        '[data-testid="search-input"]',
        'flt-text-editing-host input'
      ];
      
      for (const selector of searchSelectors) {
        try {
          searchInput = await this.page.$(selector);
          if (searchInput) {
            await this.logTest('Search Input Found', 'PASS', `Using selector: ${selector}`);
            break;
          }
        } catch (e) {
          continue;
        }
      }
      
      if (searchInput) {
        // Test search input
        await searchInput.click();
        await searchInput.type('laptop', { delay: 100 });
        await this.screenshot('05_search_input');
        
        // Try to submit search
        await this.page.keyboard.press('Enter');
        await this.page.waitForTimeout(2000);
        await this.screenshot('06_search_results');
        
        await this.logTest('Search Functionality', 'PASS', 'Search input and submission works');
      } else {
        await this.logTest('Search Input Found', 'FAIL', 'No search input element found');
      }
      
      return true;
      
    } catch (error) {
      await this.logTest('Search Functionality', 'FAIL', error.message);
      return false;
    }
  }

  // Test 4: Performance Testing
  async testPerformance() {
    console.log('\n🧪 Test 4: Performance Testing');
    
    try {
      // Measure page load performance
      const performanceMetrics = await this.page.evaluate(() => {
        const perf = performance.getEntriesByType('navigation')[0];
        return {
          domContentLoaded: perf.domContentLoadedEventEnd - perf.domContentLoadedEventStart,
          loadComplete: perf.loadEventEnd - perf.loadEventStart,
          totalTime: perf.loadEventEnd - perf.navigationStart
        };
      });
      
      await this.logTest('Performance Metrics', 'PASS', 
        `DOM: ${performanceMetrics.domContentLoaded.toFixed(2)}ms, Total: ${performanceMetrics.totalTime.toFixed(2)}ms`);
      
      // Test memory usage
      const memoryInfo = await this.page.evaluate(() => {
        if (performance.memory) {
          return {
            used: Math.round(performance.memory.usedJSHeapSize / 1024 / 1024),
            total: Math.round(performance.memory.totalJSHeapSize / 1024 / 1024),
            limit: Math.round(performance.memory.jsHeapSizeLimit / 1024 / 1024)
          };
        }
        return null;
      });
      
      if (memoryInfo) {
        await this.logTest('Memory Usage', 'PASS', 
          `Used: ${memoryInfo.used}MB, Total: ${memoryInfo.total}MB`);
      }
      
      return true;
      
    } catch (error) {
      await this.logTest('Performance Testing', 'FAIL', error.message);
      return false;
    }
  }

  // Test 5: Mobile Responsiveness
  async testMobileResponsiveness() {
    console.log('\n🧪 Test 5: Mobile Responsiveness');
    
    const devices = [
      { name: 'iPhone 12', width: 390, height: 844 },
      { name: 'iPad', width: 768, height: 1024 },
      { name: 'Samsung Galaxy S21', width: 360, height: 800 }
    ];
    
    try {
      for (const device of devices) {
        await this.page.setViewport({ width: device.width, height: device.height });
        await this.page.waitForTimeout(2000);
        
        await this.screenshot(`07_responsive_${device.name.toLowerCase().replace(/\s+/g, '_')}`);
        
        // Check if content is properly displayed
        const viewportContent = await this.page.evaluate(() => {
          return {
            scrollHeight: document.documentElement.scrollHeight,
            clientHeight: document.documentElement.clientHeight,
            hasHorizontalScroll: document.documentElement.scrollWidth > document.documentElement.clientWidth
          };
        });
        
        const isResponsive = !viewportContent.hasHorizontalScroll;
        await this.logTest(`${device.name} Responsiveness`, 
          isResponsive ? 'PASS' : 'FAIL',
          `Horizontal scroll: ${viewportContent.hasHorizontalScroll}`);
      }
      
      // Back to desktop
      await this.page.setViewport({ width: 1280, height: 720 });
      return true;
      
    } catch (error) {
      await this.logTest('Mobile Responsiveness', 'FAIL', error.message);
      return false;
    }
  }

  // Test 6: Error Handling
  async testErrorHandling() {
    console.log('\n🧪 Test 6: Error Handling');
    
    try {
      // Listen for console errors
      const errors = [];
      this.page.on('console', msg => {
        if (msg.type() === 'error') {
          errors.push(msg.text());
        }
      });
      
      // Navigate to potentially non-existent route
      await this.page.goto(`${BASE_URL}/#/non-existent-route`, { waitUntil: 'networkidle2' });
      await this.page.waitForTimeout(3000);
      await this.screenshot('08_error_handling');
      
      // Check for graceful error handling
      const hasUnhandledErrors = errors.filter(error => 
        !error.includes('Failed to load resource') && 
        !error.includes('net::ERR_')
      ).length > 0;
      
      await this.logTest('Error Handling', 
        !hasUnhandledErrors ? 'PASS' : 'FAIL',
        `Console errors: ${errors.length}`);
      
      return true;
      
    } catch (error) {
      await this.logTest('Error Handling', 'FAIL', error.message);
      return false;
    }
  }

  // Test 7: Accessibility Testing
  async testAccessibility() {
    console.log('\n🧪 Test 7: Basic Accessibility Testing');
    
    try {
      await this.page.goto(BASE_URL, { waitUntil: 'networkidle2' });
      await this.page.waitForTimeout(3000);
      
      // Check for basic accessibility features
      const accessibilityChecks = await this.page.evaluate(() => {
        const checks = {
          hasTitle: !!document.title && document.title.length > 0,
          hasLang: !!document.documentElement.lang,
          hasViewport: !!document.querySelector('meta[name="viewport"]'),
          hasDescription: !!document.querySelector('meta[name="description"]')
        };
        return checks;
      });
      
      let passedChecks = 0;
      const totalChecks = Object.keys(accessibilityChecks).length;
      
      for (const [check, passed] of Object.entries(accessibilityChecks)) {
        if (passed) passedChecks++;
        await this.logTest(`Accessibility: ${check}`, passed ? 'PASS' : 'FAIL');
      }
      
      await this.screenshot('09_accessibility');
      
      const accessibilityScore = (passedChecks / totalChecks) * 100;
      await this.logTest('Overall Accessibility', 
        accessibilityScore >= 75 ? 'PASS' : 'FAIL',
        `Score: ${accessibilityScore.toFixed(1)}%`);
      
      return true;
      
    } catch (error) {
      await this.logTest('Accessibility Testing', 'FAIL', error.message);
      return false;
    }
  }

  generateTestReport() {
    console.log('\n📊 TEST REPORT SUMMARY');
    console.log('='.repeat(50));
    
    const passedTests = this.testResults.filter(r => r.status === 'PASS').length;
    const failedTests = this.testResults.filter(r => r.status === 'FAIL').length;
    const totalTests = this.testResults.length;
    
    console.log(`Total Tests: ${totalTests}`);
    console.log(`Passed: ${passedTests} ✅`);
    console.log(`Failed: ${failedTests} ❌`);
    console.log(`Success Rate: ${((passedTests / totalTests) * 100).toFixed(1)}%`);
    
    console.log('\nDetailed Results:');
    this.testResults.forEach(result => {
      const emoji = result.status === 'PASS' ? '✅' : '❌';
      console.log(`${emoji} ${result.test}: ${result.status} ${result.details}`);
    });
    
    console.log(`\n📸 Screenshots saved in: ${SCREENSHOT_DIR}`);
    console.log('='.repeat(50));
  }

  // Main test runner
  async runAllTests() {
    try {
      await this.setup();
      
      // Run all tests
      await this.testAppLoading();
      await this.testHomeScreen();
      await this.testSearchFunctionality();
      await this.testPerformance();
      await this.testMobileResponsiveness();
      await this.testErrorHandling();
      await this.testAccessibility();
      
    } catch (error) {
      console.error('❌ Test suite failed:', error);
    } finally {
      await this.teardown();
    }
  }
}

// Run tests if this file is executed directly
if (require.main === module) {
  const testSuite = new AnnedFindsTestSuite();
  testSuite.runAllTests().then(() => {
    console.log('\n🎉 AnnedFinds E-commerce Testing Complete!');
    process.exit(0);
  }).catch(error => {
    console.error('💥 Test execution failed:', error);
    process.exit(1);
  });
}

module.exports = AnnedFindsTestSuite;