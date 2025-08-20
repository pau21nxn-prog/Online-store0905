const puppeteer = require('puppeteer');

async function testPaymentSystem() {
  console.log('🚀 Starting Simple Payment System Test...');
  
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
    await page.waitForTimeout(3000);
    
    // Take screenshot of homepage
    await page.screenshot({ path: 'payment_screenshots/homepage.png', fullPage: true });
    console.log('✅ Homepage loaded successfully');
    
    // Test 2: Try to find and click payment demo button
    console.log('🔍 Looking for Payment Demo button...');
    
    // Look for floating action button
    const fabButtons = await page.$$('button, [role="button"]');
    let paymentDemoFound = false;
    
    for (const button of fabButtons) {
      try {
        const text = await page.evaluate(el => el.textContent || el.innerText, button);
        if (text && text.toLowerCase().includes('payment')) {
          console.log(`📱 Found payment button with text: "${text}"`);
          await button.click();
          paymentDemoFound = true;
          break;
        }
      } catch (e) {
        // Continue to next button
      }
    }
    
    if (!paymentDemoFound) {
      // Try direct navigation
      console.log('🔄 Trying direct navigation to payment demo...');
      await page.goto('http://localhost:8080/#/payment-demo', { waitUntil: 'networkidle2' });
    }
    
    await page.waitForTimeout(3000);
    await page.screenshot({ path: 'payment_screenshots/payment_demo.png', fullPage: true });
    
    // Test 3: Check for payment methods
    console.log('💳 Checking for payment methods...');
    const pageContent = await page.content();
    
    const hasGCash = pageContent.includes('GCash');
    const hasCard = pageContent.includes('Card') || pageContent.includes('Credit');
    const hasBanking = pageContent.includes('Banking') || pageContent.includes('Bank');
    const hasCOD = pageContent.includes('COD') || pageContent.includes('Cash on Delivery');
    const hasOrderSummary = pageContent.includes('Order Summary') || pageContent.includes('Total');
    
    console.log(`GCash: ${hasGCash ? '✅' : '❌'}`);
    console.log(`Credit/Debit Card: ${hasCard ? '✅' : '❌'}`);
    console.log(`Online Banking: ${hasBanking ? '✅' : '❌'}`);
    console.log(`Cash on Delivery: ${hasCOD ? '✅' : '❌'}`);
    console.log(`Order Summary: ${hasOrderSummary ? '✅' : '❌'}`);
    
    // Test 4: Try to interact with payment methods
    console.log('🖱️ Testing payment method selection...');
    
    // Look for clickable payment method elements
    const clickableElements = await page.$$('div, button, [role="button"]');
    
    for (const element of clickableElements) {
      try {
        const text = await page.evaluate(el => el.textContent || el.innerText, element);
        if (text && text.toLowerCase().includes('gcash')) {
          console.log('🔍 Found GCash element, trying to click...');
          await element.click();
          await page.waitForTimeout(1000);
          await page.screenshot({ path: 'payment_screenshots/gcash_selected.png' });
          console.log('✅ GCash selection test completed');
          break;
        }
      } catch (e) {
        // Continue to next element
      }
    }
    
    // Test 5: Look for pay button
    console.log('💰 Looking for pay button...');
    let payButtonFound = false;
    
    for (const element of clickableElements) {
      try {
        const text = await page.evaluate(el => el.textContent || el.innerText, element);
        if (text && text.toLowerCase().includes('pay') && text.includes('₱')) {
          console.log(`💰 Found pay button with text: "${text}"`);
          await element.click();
          await page.waitForTimeout(3000);
          await page.screenshot({ path: 'payment_screenshots/payment_processing.png' });
          payButtonFound = true;
          console.log('✅ Payment processing test completed');
          break;
        }
      } catch (e) {
        // Continue to next element
      }
    }
    
    if (!payButtonFound) {
      console.log('❌ Pay button not found');
    }
    
    // Test 6: Mobile responsiveness
    console.log('📱 Testing mobile responsiveness...');
    await page.setViewport({ width: 390, height: 844 });
    await page.waitForTimeout(2000);
    await page.screenshot({ path: 'payment_screenshots/mobile_view.png' });
    console.log('✅ Mobile responsiveness test completed');
    
    // Final summary
    console.log('\n📊 PAYMENT SYSTEM TEST SUMMARY');
    console.log('='.repeat(50));
    console.log(`✅ Homepage Loading: Success`);
    console.log(`${hasGCash ? '✅' : '❌'} GCash Payment Method: ${hasGCash ? 'Found' : 'Not Found'}`);
    console.log(`${hasCard ? '✅' : '❌'} Card Payment Method: ${hasCard ? 'Found' : 'Not Found'}`);
    console.log(`${hasBanking ? '✅' : '❌'} Banking Payment Method: ${hasBanking ? 'Found' : 'Not Found'}`);
    console.log(`${hasCOD ? '✅' : '❌'} COD Payment Method: ${hasCOD ? 'Found' : 'Not Found'}`);
    console.log(`${hasOrderSummary ? '✅' : '❌'} Order Summary: ${hasOrderSummary ? 'Found' : 'Not Found'}`);
    console.log(`${payButtonFound ? '✅' : '❌'} Payment Processing: ${payButtonFound ? 'Tested' : 'Not Tested'}`);
    console.log('✅ Mobile Responsiveness: Tested');
    console.log('='.repeat(50));
    
    const successCount = [hasGCash, hasCard, hasBanking, hasCOD, hasOrderSummary, payButtonFound].filter(Boolean).length;
    console.log(`🎯 Overall Success Rate: ${Math.round((successCount / 6) * 100)}%`);
    
  } catch (error) {
    console.error('❌ Test failed:', error);
  } finally {
    await browser.close();
    console.log('✅ Payment system test completed!');
  }
}

// Run the test
testPaymentSystem();