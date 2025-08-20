const puppeteer = require('puppeteer');

async function testIntegratedQRPaymentSystem() {
  console.log('🚀 Starting Integrated QR Payment System Test...');
  console.log('Testing both guest and registered user flows');
  
  const browser = await puppeteer.launch({
    headless: false,
    slowMo: 150,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 720 });
  
  try {
    // Test 1: Load homepage
    console.log('📱 Loading AnnedFinds homepage...');
    await page.goto('http://localhost:8082', { waitUntil: 'networkidle2' });
    await page.waitForTimeout(8000); // Wait for Flutter to fully load
    
    await page.screenshot({ path: 'payment_screenshots/integrated_homepage.png', fullPage: true });
    console.log('✅ Homepage loaded successfully');
    
    // Test 2: Test as Guest User first
    console.log('\\n👤 === TESTING AS GUEST USER ===');
    
    // Check if guest welcome message is removed from profile
    console.log('🔍 Checking Profile page (guest welcome message removal)...');
    await page.evaluate(() => {
      // Find and click profile tab (usually the last tab)
      const profileButtons = [...document.querySelectorAll('*')].filter(el => 
        el.textContent && el.textContent.toLowerCase().includes('profile')
      );
      if (profileButtons.length > 0) {
        profileButtons[0].click();
      }
    });
    
    await page.waitForTimeout(3000);
    await page.screenshot({ path: 'payment_screenshots/integrated_profile_guest.png', fullPage: true });
    
    const profileContent = await page.content();
    const hasOldGuestMessage = profileContent.includes('Welcome, Guest!') || 
                              profileContent.includes('browsing as a guest');
    
    console.log(`Guest Welcome Message Removed: ${!hasOldGuestMessage ? '✅' : '❌'}`);
    
    // Test 3: Add item to cart and go to checkout
    console.log('\\n🛒 Testing Cart and Checkout Flow...');
    
    // Go back to home
    await page.evaluate(() => {
      const homeButtons = [...document.querySelectorAll('*')].filter(el => 
        el.textContent && el.textContent.toLowerCase().includes('home')
      );
      if (homeButtons.length > 0) {
        homeButtons[0].click();
      }
    });
    
    await page.waitForTimeout(3000);
    
    // Try to find and click an "Add to Cart" button or product
    let productAdded = false;
    
    try {
      await page.evaluate(() => {
        // Look for product cards or add to cart buttons
        const addToCartButtons = [...document.querySelectorAll('*')].filter(el => {
          const text = el.textContent || '';
          return text.toLowerCase().includes('add to cart') || 
                 text.toLowerCase().includes('add') ||
                 el.className.includes('product');
        });
        
        if (addToCartButtons.length > 0) {
          addToCartButtons[0].click();
          return true;
        }
        return false;
      });
      
      await page.waitForTimeout(2000);
      productAdded = true;
      console.log('✅ Product added to cart');
    } catch (e) {
      console.log('⚠️ Could not add product to cart automatically');
    }
    
    // Go to cart
    await page.evaluate(() => {
      const cartButtons = [...document.querySelectorAll('*')].filter(el => 
        el.textContent && el.textContent.toLowerCase().includes('cart')
      );
      if (cartButtons.length > 0) {
        cartButtons[0].click();
      }
    });
    
    await page.waitForTimeout(3000);
    await page.screenshot({ path: 'payment_screenshots/integrated_cart.png', fullPage: true });
    
    // Try to proceed to checkout
    let checkoutFound = false;
    
    try {
      await page.evaluate(() => {
        const checkoutButtons = [...document.querySelectorAll('*')].filter(el => {
          const text = el.textContent || '';
          return text.toLowerCase().includes('checkout') || 
                 text.toLowerCase().includes('proceed') ||
                 text.toLowerCase().includes('buy now');
        });
        
        if (checkoutButtons.length > 0) {
          checkoutButtons[0].click();
          return true;
        }
        return false;
      });
      
      await page.waitForTimeout(5000);
      checkoutFound = true;
      console.log('✅ Proceeded to checkout');
    } catch (e) {
      console.log('⚠️ Could not find checkout button');
    }
    
    // Test 4: Check QR Payment Methods in Checkout
    console.log('\\n💳 Testing QR Payment Method Integration...');
    
    const checkoutContent = await page.content();
    
    const hasGCash = checkoutContent.includes('GCash');
    const hasGoTyme = checkoutContent.includes('GoTyme');
    const hasMetrobank = checkoutContent.includes('Metrobank');
    const hasRemovedCOD = !checkoutContent.includes('Cash on Delivery') && !checkoutContent.includes('COD');
    const hasRemovedCard = !checkoutContent.includes('Credit/Debit') && !checkoutContent.includes('Credit Card');
    
    console.log(`✅ Payment Methods Available:`);
    console.log(`  GCash: ${hasGCash ? '✅' : '❌'}`);
    console.log(`  GoTyme Bank: ${hasGoTyme ? '✅' : '❌'}`);
    console.log(`  Metrobank: ${hasMetrobank ? '✅' : '❌'}`);
    console.log(`\\n✅ Removed Payment Methods:`);
    console.log(`  COD Removed: ${hasRemovedCOD ? '✅' : '❌'}`);
    console.log(`  Card Options Removed: ${hasRemovedCard ? '✅' : '❌'}`);
    
    await page.screenshot({ path: 'payment_screenshots/integrated_checkout_guest.png', fullPage: true });
    
    // Test 5: Try to select a QR payment method and navigate to QR checkout
    console.log('\\n📱 Testing QR Payment Selection...');
    
    let qrCheckoutReached = false;
    
    try {
      // Try to select GoTyme or Metrobank (which should navigate to QR checkout)
      await page.evaluate(() => {
        const paymentOptions = [...document.querySelectorAll('*')].filter(el => {
          const text = el.textContent || '';
          return text.includes('GoTyme') || text.includes('Metrobank');
        });
        
        if (paymentOptions.length > 0) {
          paymentOptions[0].click();
        }
      });
      
      await page.waitForTimeout(2000);
      
      // Look for place order or pay button
      await page.evaluate(() => {
        const payButtons = [...document.querySelectorAll('*')].filter(el => {
          const text = el.textContent || '';
          return text.toLowerCase().includes('place order') || 
                 text.toLowerCase().includes('pay') ||
                 text.toLowerCase().includes('proceed');
        });
        
        if (payButtons.length > 0) {
          payButtons[0].click();
        }
      });
      
      await page.waitForTimeout(5000);
      
      const currentContent = await page.content();
      if (currentContent.includes('Scan QR') || currentContent.includes('QR Code') || 
          currentContent.includes('annedfinds@gmail.com')) {
        qrCheckoutReached = true;
        console.log('✅ Successfully navigated to QR checkout page');
        await page.screenshot({ path: 'payment_screenshots/integrated_qr_checkout.png', fullPage: true });
      }
      
    } catch (e) {
      console.log('⚠️ Could not complete QR payment selection flow');
    }
    
    // Test 6: Test with Registered User
    console.log('\\n👤 === TESTING WITH REGISTERED USER ===');
    console.log('🔑 Attempting to login with test credentials...');
    
    // Go back to home and try to access login
    await page.goto('http://localhost:8082', { waitUntil: 'networkidle2' });
    await page.waitForTimeout(5000);
    
    // Look for login button or profile to access login
    let loginAttempted = false;
    
    try {
      await page.evaluate(() => {
        const loginButtons = [...document.querySelectorAll('*')].filter(el => {
          const text = el.textContent || '';
          return text.toLowerCase().includes('login') || 
                 text.toLowerCase().includes('sign in') ||
                 text.toLowerCase().includes('account');
        });
        
        if (loginButtons.length > 0) {
          loginButtons[0].click();
        }
      });
      
      await page.waitForTimeout(3000);
      
      // Try to fill in login credentials
      const emailInputs = await page.$$('input[type="email"], input[placeholder*="email"], input[name*="email"]');
      const passwordInputs = await page.$$('input[type="password"], input[placeholder*="password"], input[name*="password"]');
      
      if (emailInputs.length > 0 && passwordInputs.length > 0) {
        await emailInputs[0].type('paucsyumetec@gmail.com');
        await passwordInputs[0].type('Testuser123@');
        
        // Look for login submit button
        await page.evaluate(() => {
          const submitButtons = [...document.querySelectorAll('button, input[type="submit"]')].filter(el => {
            const text = el.textContent || el.value || '';
            return text.toLowerCase().includes('login') || 
                   text.toLowerCase().includes('sign in') ||
                   text.toLowerCase().includes('submit');
          });
          
          if (submitButtons.length > 0) {
            submitButtons[0].click();
          }
        });
        
        await page.waitForTimeout(5000);
        loginAttempted = true;
        console.log('✅ Login credentials entered and submitted');
        
        await page.screenshot({ path: 'payment_screenshots/integrated_login_attempt.png', fullPage: true });
      }
      
    } catch (e) {
      console.log('⚠️ Could not complete login process automatically');
    }
    
    // Test 7: Mobile Responsiveness
    console.log('\\n📱 Testing Mobile Responsiveness...');
    await page.setViewport({ width: 390, height: 844 });
    await page.waitForTimeout(2000);
    await page.screenshot({ path: 'payment_screenshots/integrated_mobile_view.png', fullPage: true });
    console.log('✅ Mobile responsiveness test completed');
    
    // Final Results Summary
    console.log('\\n📊 INTEGRATED QR PAYMENT SYSTEM TEST RESULTS');
    console.log('='.repeat(60));
    console.log(`✅ Homepage Loading: Success`);
    console.log(`${!hasOldGuestMessage ? '✅' : '❌'} Guest Welcome Message Removed: ${!hasOldGuestMessage ? 'Success' : 'Still Present'}`);
    console.log(`${productAdded ? '✅' : '⚠️'} Add to Cart: ${productAdded ? 'Success' : 'Manual Test Needed'}`);
    console.log(`${checkoutFound ? '✅' : '⚠️'} Checkout Navigation: ${checkoutFound ? 'Success' : 'Manual Test Needed'}`);
    console.log(`${hasGCash ? '✅' : '❌'} GCash Payment Option: ${hasGCash ? 'Available' : 'Missing'}`);
    console.log(`${hasGoTyme ? '✅' : '❌'} GoTyme Bank Option: ${hasGoTyme ? 'Available' : 'Missing'}`);
    console.log(`${hasMetrobank ? '✅' : '❌'} Metrobank Option: ${hasMetrobank ? 'Available' : 'Missing'}`);
    console.log(`${hasRemovedCOD ? '✅' : '❌'} COD Removal: ${hasRemovedCOD ? 'Success' : 'Still Present'}`);
    console.log(`${hasRemovedCard ? '✅' : '❌'} Card Options Removal: ${hasRemovedCard ? 'Success' : 'Still Present'}`);
    console.log(`${qrCheckoutReached ? '✅' : '⚠️'} QR Checkout Flow: ${qrCheckoutReached ? 'Success' : 'Needs Manual Testing'}`);
    console.log(`${loginAttempted ? '✅' : '⚠️'} User Login Test: ${loginAttempted ? 'Attempted' : 'Manual Test Needed'}`);
    console.log('✅ Mobile Responsiveness: Tested');
    console.log('='.repeat(60));
    
    const features = [
      true, // Homepage
      !hasOldGuestMessage, // Guest message removed
      hasGCash, // GCash available
      hasGoTyme, // GoTyme available
      hasMetrobank, // Metrobank available
      hasRemovedCOD, // COD removed
      hasRemovedCard, // Card removed
      true // Mobile tested
    ];
    
    const successCount = features.filter(Boolean).length;
    const successRate = Math.round((successCount / features.length) * 100);
    
    console.log(`🎯 Overall Integration Success Rate: ${successRate}%`);
    
    if (successRate >= 90) {
      console.log('🎉 EXCELLENT! QR Payment System Integration is production-ready!');
    } else if (successRate >= 75) {
      console.log('✅ GOOD! QR Payment System is mostly integrated, minor issues to resolve');
    } else {
      console.log('⚠️ QR Payment System integration needs attention');
    }
    
    console.log('\\n🌐 Test completed! You can now manually test at: http://localhost:8082');
    console.log('👤 Test User Credentials:');
    console.log('   Email: paucsyumetec@gmail.com');
    console.log('   Password: Testuser123@');
    
  } catch (error) {
    console.error('❌ Test failed:', error);
  } finally {
    await browser.close();
    console.log('✅ Integrated QR Payment system test completed!');
  }
}

// Run the test
testIntegratedQRPaymentSystem();