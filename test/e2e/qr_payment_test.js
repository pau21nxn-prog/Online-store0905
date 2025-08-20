const puppeteer = require('puppeteer');

async function testQRPaymentSystem() {
  console.log('🚀 Starting QR Payment System Test...');
  
  const browser = await puppeteer.launch({
    headless: false,
    slowMo: 100
  });
  
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 720 });
  
  try {
    // Test 1: Load homepage
    console.log('📱 Loading homepage...');
    await page.goto('http://localhost:8080', { waitUntil: 'networkidle2' });
    await page.waitForTimeout(5000); // Wait longer for Flutter to load
    
    // Take screenshot of homepage
    await page.screenshot({ path: 'payment_screenshots/qr_homepage.png', fullPage: true });
    console.log('✅ Homepage loaded successfully');
    
    // Test 2: Navigate to Payment Demo
    console.log('🔍 Looking for Payment Demo button...');
    
    // Try to find and click the Payment Demo button
    let paymentDemoFound = false;
    
    // Wait for Flutter to load and look for the payment demo button
    await page.waitForTimeout(5000);
    
    // Try multiple selectors for Flutter elements
    const selectors = [
      'flt-semantics[role="button"]',
      '[role="button"]',
      'button',
      '.fab',
      'flt-semantics',
      '[data-semantics-role="button"]'
    ];
    
    for (const selector of selectors) {
      try {
        const elements = await page.$$(selector);
        console.log(`Found ${elements.length} elements with selector: ${selector}`);
        
        for (const element of elements) {
          try {
            const boundingBox = await element.boundingBox();
            if (boundingBox) {
              const text = await page.evaluate(el => {
                return el.textContent || el.innerText || el.getAttribute('aria-label') || el.getAttribute('data-tooltip-text') || '';
              }, element);
              
              if (text) {
                console.log(`Found element with text: "${text}"`);
              }
              
              if (text && (text.toLowerCase().includes('payment demo') || 
                          text.toLowerCase().includes('payment') && text.toLowerCase().includes('demo'))) {
                console.log(`📱 Found payment demo button: "${text}"`);
                await element.click();
                paymentDemoFound = true;
                await page.waitForTimeout(5000);
                break;
              }
            }
          } catch (e) {
            // Continue to next element
          }
        }
        
        if (paymentDemoFound) break;
      } catch (e) {
        // Continue to next selector
      }
    }
    
    if (!paymentDemoFound) {
      // Try direct navigation
      console.log('🔄 Payment Demo button not found, trying direct navigation...');
      await page.goto('http://localhost:8080/#/payment-demo', { waitUntil: 'networkidle2' });
      await page.waitForTimeout(5000);
      paymentDemoFound = true;
    }
    
    await page.screenshot({ path: 'payment_screenshots/qr_payment_demo.png', fullPage: true });
    
    // Test 3: Test "Proceed to Payment" button
    console.log('💰 Looking for "Proceed to Payment" button...');
    
    const proceedButtons = await page.$$('button, [role="button"], flt-semantics[role="button"]');
    let proceedButtonFound = false;
    
    for (const button of proceedButtons) {
      try {
        const text = await page.evaluate(el => {
          return el.textContent || el.innerText || el.getAttribute('aria-label') || '';
        }, button);
        
        if (text && (text.includes('Proceed to Payment') || text.includes('₱4,197.00'))) {
          console.log(`💰 Found proceed button: "${text}"`);
          await button.click();
          proceedButtonFound = true;
          await page.waitForTimeout(5000); // Wait for navigation
          break;
        }
      } catch (e) {
        // Continue to next button
      }
    }
    
    if (proceedButtonFound) {
      await page.screenshot({ path: 'payment_screenshots/qr_checkout_page.png', fullPage: true });
      console.log('✅ Successfully navigated to QR checkout page');
      
      // Test 4: Check for QR payment methods
      console.log('💳 Testing QR payment method selection...');
      const pageContent = await page.content();
      
      const hasGCash = pageContent.includes('GCash') || pageContent.includes('gcash');
      const hasGoTyme = pageContent.includes('GoTyme') || pageContent.includes('gotyme');
      const hasMetrobank = pageContent.includes('Metrobank') || pageContent.includes('metrobank');
      const hasOrderSummary = pageContent.includes('Order Summary') || pageContent.includes('Total Amount');
      const hasAdminContact = pageContent.includes('annedfinds@gmail.com') || pageContent.includes('977-325-7043');
      
      console.log(`GCash Payment: ${hasGCash ? '✅' : '❌'}`);
      console.log(`GoTyme Bank: ${hasGoTyme ? '✅' : '❌'}`);
      console.log(`Metrobank: ${hasMetrobank ? '✅' : '❌'}`);
      console.log(`Order Summary: ${hasOrderSummary ? '✅' : '❌'}`);
      console.log(`Admin Contact Info: ${hasAdminContact ? '✅' : '❌'}`);
      
      // Test 5: Try to select a payment method
      console.log('🖱️ Testing payment method selection...');
      
      // Look for clickable payment method elements
      const clickableElements = await page.$$('div, button, [role="button"], flt-semantics');
      let paymentMethodSelected = false;
      
      for (const element of clickableElements) {
        try {
          const text = await page.evaluate(el => {
            return el.textContent || el.innerText || '';
          }, element);
          
          if (text && text.toLowerCase().includes('gcash')) {
            console.log('🔍 Found GCash element, trying to click...');
            await element.click();
            await page.waitForTimeout(2000);
            paymentMethodSelected = true;
            await page.screenshot({ path: 'payment_screenshots/qr_gcash_selected.png' });
            console.log('✅ GCash selection test completed');
            break;
          }
        } catch (e) {
          // Continue to next element
        }
      }
      
      // Test 6: Check for QR code display
      console.log('📱 Checking for QR code display...');
      
      // Look for QR code images
      const images = await page.$$('img');
      let qrCodeFound = false;
      
      for (const img of images) {
        try {
          const src = await page.evaluate(el => el.src, img);
          if (src && (src.includes('QR/') || src.includes('Gcash') || src.includes('GoTyme') || src.includes('Metrobank'))) {
            console.log(`📱 Found QR code image: ${src}`);
            qrCodeFound = true;
            break;
          }
        } catch (e) {
          // Continue
        }
      }
      
      console.log(`QR Code Display: ${qrCodeFound ? '✅' : '❌'}`);
      
      // Test 7: Look for "I have sent the payment" button
      console.log('💰 Looking for payment confirmation button...');
      let confirmButtonFound = false;
      
      for (const element of clickableElements) {
        try {
          const text = await page.evaluate(el => {
            return el.textContent || el.innerText || '';
          }, element);
          
          if (text && text.toLowerCase().includes('sent the payment')) {
            console.log(`💰 Found confirmation button: "${text}"`);
            confirmButtonFound = true;
            break;
          }
        } catch (e) {
          // Continue
        }
      }
      
      console.log(`Payment Confirmation Button: ${confirmButtonFound ? '✅' : '❌'}`);
      
      // Test 8: Mobile responsiveness
      console.log('📱 Testing mobile responsiveness...');
      await page.setViewport({ width: 390, height: 844 });
      await page.waitForTimeout(2000);
      await page.screenshot({ path: 'payment_screenshots/qr_mobile_view.png' });
      console.log('✅ Mobile responsiveness test completed');
      
      // Final summary
      console.log('\\n📊 QR PAYMENT SYSTEM TEST SUMMARY');
      console.log('='.repeat(50));
      console.log(`✅ Homepage Loading: Success`);
      console.log(`${proceedButtonFound ? '✅' : '❌'} Payment Demo Navigation: ${proceedButtonFound ? 'Success' : 'Failed'}`);
      console.log(`${hasGCash ? '✅' : '❌'} GCash Payment Method: ${hasGCash ? 'Found' : 'Not Found'}`);
      console.log(`${hasGoTyme ? '✅' : '❌'} GoTyme Bank Payment: ${hasGoTyme ? 'Found' : 'Not Found'}`);
      console.log(`${hasMetrobank ? '✅' : '❌'} Metrobank Payment: ${hasMetrobank ? 'Found' : 'Not Found'}`);
      console.log(`${hasOrderSummary ? '✅' : '❌'} Order Summary: ${hasOrderSummary ? 'Found' : 'Not Found'}`);
      console.log(`${hasAdminContact ? '✅' : '❌'} Admin Contact Info: ${hasAdminContact ? 'Found' : 'Not Found'}`);
      console.log(`${qrCodeFound ? '✅' : '❌'} QR Code Display: ${qrCodeFound ? 'Working' : 'Not Working'}`);
      console.log(`${paymentMethodSelected ? '✅' : '❌'} Payment Method Selection: ${paymentMethodSelected ? 'Working' : 'Not Working'}`);
      console.log(`${confirmButtonFound ? '✅' : '❌'} Payment Confirmation Button: ${confirmButtonFound ? 'Found' : 'Not Found'}`);
      console.log('✅ Mobile Responsiveness: Tested');
      console.log('='.repeat(50));
      
      const successCount = [
        true, // Homepage loading
        proceedButtonFound,
        hasGCash,
        hasGoTyme,
        hasMetrobank,
        hasOrderSummary,
        hasAdminContact,
        qrCodeFound,
        paymentMethodSelected,
        confirmButtonFound
      ].filter(Boolean).length;
      
      console.log(`🎯 Overall Success Rate: ${Math.round((successCount / 10) * 100)}%`);
      
    } else {
      console.log('❌ Failed to find proceed to payment button');
    }
    
  } catch (error) {
    console.error('❌ Test failed:', error);
  } finally {
    await browser.close();
    console.log('✅ QR Payment system test completed!');
  }
}

// Run the test
testQRPaymentSystem();