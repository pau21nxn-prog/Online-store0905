const { onCall } = require("firebase-functions/v2/https");
const nodemailer = require("nodemailer");

// Gmail configuration
const transporter = nodemailer.createTransporter({
  service: "gmail",
  auth: {
    user: "annedfinds@gmail.com",
    pass: process.env.GMAIL_APP_PASSWORD // App password for Gmail
  }
});

// Send admin payment notification
exports.sendAdminPaymentNotification = onCall(async (request) => {
  try {
    const {
      orderId,
      paymentMethod,
      amount,
      customerInfo,
      orderDetails,
      timestamp
    } = request.data;

    console.log(`Sending admin payment notification for order: ${orderId}`);

    // Create confirmation URL for admin
    const confirmUrl = `https://annedfinds.web.app/admin/confirm-payment?orderId=${orderId}&token=${generateConfirmationToken(orderId)}`;

    const emailHtml = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; }
        .header { background-color: #ff6b35; color: white; padding: 15px; text-align: center; border-radius: 8px 8px 0 0; }
        .content { padding: 20px; }
        .order-info { background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 15px 0; }
        .customer-info { background-color: #e3f2fd; padding: 15px; border-radius: 5px; margin: 15px 0; }
        .payment-info { background-color: #fff3e0; padding: 15px; border-radius: 5px; margin: 15px 0; }
        .confirm-btn { background-color: #4caf50; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 10px 5px; }
        .reject-btn { background-color: #f44336; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 10px 5px; }
        .amount { font-size: 24px; font-weight: bold; color: #ff6b35; }
        .method { font-weight: bold; color: #2196f3; }
        .important { background-color: #ffeb3b; padding: 10px; border-radius: 5px; margin: 15px 0; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🏪 New Payment Notification - AnnedFinds</h1>
        </div>
        
        <div class="content">
          <h2>Payment Verification Required</h2>
          <p>A customer has submitted a payment notification. Please verify the payment in your bank account.</p>
          
          <div class="order-info">
            <h3>📋 Order Information</h3>
            <p><strong>Order ID:</strong> ${orderId}</p>
            <p><strong>Date:</strong> ${new Date(timestamp).toLocaleString("en-PH")}</p>
            <p><strong>Items:</strong> ${JSON.stringify(orderDetails.items || "Order details")}</p>
          </div>
          
          <div class="payment-info">
            <h3>💳 Payment Details</h3>
            <p><strong>Amount:</strong> <span class="amount">₱${amount.toFixed(2)}</span></p>
            <p><strong>Payment Method:</strong> <span class="method">${paymentMethod}</span></p>
            <p><strong>Expected in:</strong> ${getExpectedAccount(paymentMethod)}</p>
          </div>
          
          <div class="customer-info">
            <h3>👤 Customer Information</h3>
            <p><strong>Name:</strong> ${customerInfo.name}</p>
            <p><strong>Email:</strong> ${customerInfo.email}</p>
            <p><strong>Phone:</strong> ${customerInfo.phone}</p>
            <p><strong>Address:</strong> ${customerInfo.address}</p>
          </div>
          
          <div class="important">
            <h3>⚠️ Next Steps</h3>
            <ol>
              <li>Check your ${paymentMethod} account for the payment of ₱${amount.toFixed(2)}</li>
              <li>Verify the amount matches exactly</li>
              <li>Click "Confirm Payment" below if payment is received</li>
              <li>Customer will be automatically notified</li>
            </ol>
          </div>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="${confirmUrl}" class="confirm-btn">✅ Confirm Payment Received</a>
            <a href="mailto:${customerInfo.email}?subject=Payment Clarification - Order ${orderId}" class="reject-btn">📧 Contact Customer</a>
          </div>
          
          <div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin-top: 20px;">
            <h4>📞 Admin Support</h4>
            <p><strong>Email:</strong> annedfinds@gmail.com</p>
            <p><strong>Viber:</strong> +63 977-325-7043</p>
          </div>
        </div>
      </div>
    </body>
    </html>
    `;

    const mailOptions = {
      from: "AnnedFinds <annedfinds@gmail.com>",
      to: "annedfinds@gmail.com",
      subject: `🏪 Payment Verification Required - Order ${orderId}`,
      html: emailHtml,
      text: `New payment notification for Order ${orderId}. Amount: ₱${amount.toFixed(2)}. Payment Method: ${paymentMethod}. Customer: ${customerInfo.name} (${customerInfo.email}). Please verify payment in your ${paymentMethod} account.`
    };

    await transporter.sendMail(mailOptions);
    
    console.log(`Admin payment notification sent for order: ${orderId}`);
    
    return {
      success: true,
      message: "Admin payment notification sent successfully",
      orderId: orderId
    };

  } catch (error) {
    console.error("Error sending admin payment notification:", error);
    return {
      success: false,
      error: error.message
    };
  }
});

// Send customer payment confirmation
exports.sendCustomerPaymentConfirmation = onCall(async (request) => {
  try {
    const {
      customerEmail,
      customerName,
      orderId,
      amount,
      paymentMethod,
      timestamp
    } = request.data;

    console.log(`Sending customer payment confirmation for order: ${orderId}`);

    const emailHtml = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; }
        .header { background-color: #4caf50; color: white; padding: 15px; text-align: center; border-radius: 8px 8px 0 0; }
        .content { padding: 20px; }
        .success-icon { font-size: 48px; text-align: center; margin: 20px 0; }
        .order-summary { background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 15px 0; }
        .next-steps { background-color: #e8f5e8; padding: 15px; border-radius: 5px; margin: 15px 0; }
        .amount { font-size: 20px; font-weight: bold; color: #4caf50; }
        .contact-info { background-color: #fff3e0; padding: 15px; border-radius: 5px; margin: 15px 0; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>✅ Payment Confirmed - AnnedFinds</h1>
        </div>
        
        <div class="content">
          <div class="success-icon">🎉</div>
          
          <h2>Hello ${customerName}!</h2>
          <p>Great news! Your payment has been verified and confirmed.</p>
          
          <div class="order-summary">
            <h3>📋 Order Summary</h3>
            <p><strong>Order ID:</strong> ${orderId}</p>
            <p><strong>Amount Paid:</strong> <span class="amount">₱${amount.toFixed(2)}</span></p>
            <p><strong>Payment Method:</strong> ${paymentMethod}</p>
            <p><strong>Confirmation Date:</strong> ${new Date(timestamp).toLocaleString("en-PH")}</p>
          </div>
          
          <div class="next-steps">
            <h3>📦 What happens next?</h3>
            <ul>
              <li>Your order is now being processed</li>
              <li>We will prepare your items for shipping</li>
              <li>You will receive tracking information within 2-3 business days</li>
              <li>Estimated delivery: 3-7 business days</li>
            </ul>
          </div>
          
          <div class="contact-info">
            <h3>📞 Need Help?</h3>
            <p>If you have any questions about your order, feel free to contact us:</p>
            <p><strong>Email:</strong> annedfinds@gmail.com</p>
            <p><strong>Viber:</strong> +63 977-325-7043</p>
          </div>
          
          <div style="text-align: center; margin: 30px 0;">
            <p>Thank you for shopping with AnnedFinds!</p>
            <p><em>We appreciate your business and look forward to serving you again.</em></p>
          </div>
        </div>
      </div>
    </body>
    </html>
    `;

    const mailOptions = {
      from: "AnnedFinds <annedfinds@gmail.com>",
      to: customerEmail,
      subject: `✅ Payment Confirmed - Order ${orderId} | AnnedFinds`,
      html: emailHtml,
      text: `Hello ${customerName}! Your payment for Order ${orderId} (₱${amount.toFixed(2)}) has been confirmed. Your order is now being processed and will ship within 2-3 business days. Thank you for shopping with AnnedFinds!`
    };

    await transporter.sendMail(mailOptions);
    
    console.log(`Customer payment confirmation sent for order: ${orderId}`);
    
    return {
      success: true,
      message: "Customer payment confirmation sent successfully",
      orderId: orderId
    };

  } catch (error) {
    console.error("Error sending customer payment confirmation:", error);
    return {
      success: false,
      error: error.message
    };
  }
});

// Helper functions
function getExpectedAccount(paymentMethod) {
  const accounts = {
    "GCash": "GCash account ending in XXXX",
    "GoTyme Bank": "GoTyme Bank account ending in XXXX",
    "Metrobank": "Metrobank account ending in XXXX"
  };
  return accounts[paymentMethod] || "Your designated account";
}

function generateConfirmationToken(orderId) {
  // Simple token generation - in production, use a more secure method
  return Buffer.from(`${orderId}-${Date.now()}`).toString("base64");
}