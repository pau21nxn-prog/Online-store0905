import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as nodemailer from "nodemailer";

admin.initializeApp();

// Gmail configuration using your app password
const GMAIL_CONFIG = {
  service: "gmail",
  auth: {
    user: "annedfinds@gmail.com",
    pass: "wymr vwej jbjy bkhi" // Your app password
  }
};

// Create Gmail transporter - FIXED: createTransport instead of createTransporter
const gmailTransporter = nodemailer.createTransport(GMAIL_CONFIG);

// Email sending function for order confirmations
export const sendOrderConfirmationEmail = onCall(async (request) => {
  const data = request.data;
  try {
    console.log("📧 Received Gmail email request:", data);

    const {
      toEmail,
      customerName,
      orderId,
      orderItems,
      totalAmount,
      paymentMethod,
      deliveryAddress,
      estimatedDelivery
    } = data;

    // Validate required fields
    if (!toEmail || !customerName || !orderId) {
      throw new HttpsError(
        "invalid-argument",
        "Missing required fields: toEmail, customerName, or orderId"
      );
    }

    // Format estimated delivery date
    const deliveryDate = estimatedDelivery 
      ? new Date(estimatedDelivery).toLocaleDateString("en-US", {
          weekday: "long",
          year: "numeric",
          month: "long", 
          day: "numeric"
        })
      : "3-5 business days";

    // Create order items HTML
    const itemsHtml = orderItems.map((item: any) => `
      <tr style="border-bottom: 1px solid #eee;">
        <td style="padding: 12px; text-align: left;">${item.name}</td>
        <td style="padding: 12px; text-align: center;">${item.quantity}</td>
        <td style="padding: 12px; text-align: right;">₱${(item.price * item.quantity).toFixed(2)}</td>
      </tr>
    `).join("");

    // Create order items for plain text
    const itemsText = orderItems.map((item: any) => 
      `• ${item.name} x${item.quantity} = ₱${(item.price * item.quantity).toFixed(2)}`
    ).join("\n");

    // Create beautiful HTML email template
    const htmlContent = `
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Order Confirmation - AnneDFinds</title>
    </head>
    <body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; background-color: #f4f4f4;">
        <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 10px; overflow: hidden; box-shadow: 0 0 20px rgba(0,0,0,0.1);">
            <!-- Header -->
            <div style="background: linear-gradient(135deg, #FF6B35 0%, #FF8A5B 100%); padding: 40px 20px; text-align: center;">
                <h1 style="color: white; margin: 0; font-size: 28px; font-weight: bold;">🛍️ AnneDFinds</h1>
                <p style="color: #FFF3E0; margin: 10px 0 0 0; font-size: 16px;">Your trusted online store</p>
            </div>

            <!-- Success Badge -->
            <div style="text-align: center; margin: -20px 0 0 0;">
                <div style="display: inline-block; background-color: #4CAF50; color: white; padding: 12px 24px; border-radius: 25px; font-weight: bold;">
                    ✅ Order Confirmed
                </div>
            </div>

            <!-- Main Content -->
            <div style="padding: 40px 20px;">
                <h2 style="color: #FF6B35; margin: 0 0 20px 0;">Thank you for your order, ${customerName}! 🎉</h2>
                
                <p style="font-size: 16px; margin: 0 0 30px 0;">
                    We're excited to let you know that we've received your order and are preparing it for shipment.
                </p>

                <!-- Order Details -->
                <div style="background-color: #FFF3E0; border-left: 4px solid #FF6B35; padding: 20px; margin: 30px 0; border-radius: 5px;">
                    <h3 style="margin: 0 0 15px 0; color: #FF6B35;">📋 Order Details</h3>
                    <table style="width: 100%; border-collapse: collapse;">
                        <tr>
                            <td style="padding: 8px 0; font-weight: bold;">Order ID:</td>
                            <td style="padding: 8px 0; color: #FF6B35; font-weight: bold;">${orderId}</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px 0; font-weight: bold;">Order Date:</td>
                            <td style="padding: 8px 0;">${new Date().toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" })}</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px 0; font-weight: bold;">Payment Method:</td>
                            <td style="padding: 8px 0;">${paymentMethod}</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px 0; font-weight: bold;">Estimated Delivery:</td>
                            <td style="padding: 8px 0; color: #4CAF50; font-weight: bold;">${deliveryDate}</td>
                        </tr>
                    </table>
                </div>

                <!-- Order Items -->
                <div style="margin: 30px 0;">
                    <h3 style="color: #FF6B35; margin: 0 0 20px 0;">🛒 Items Ordered</h3>
                    <table style="width: 100%; border-collapse: collapse; background-color: #fafafa; border-radius: 8px; overflow: hidden;">
                        <thead>
                            <tr style="background-color: #FF6B35; color: white;">
                                <th style="padding: 15px; text-align: left;">Item</th>
                                <th style="padding: 15px; text-align: center;">Qty</th>
                                <th style="padding: 15px; text-align: right;">Amount</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${itemsHtml}
                            <tr style="background-color: #FF6B35; color: white; font-weight: bold;">
                                <td colspan="2" style="padding: 15px; text-align: right;">Total:</td>
                                <td style="padding: 15px; text-align: right; font-size: 18px;">₱${totalAmount.toFixed(2)}</td>
                            </tr>
                        </tbody>
                    </table>
                </div>

                <!-- Delivery Address -->
                <div style="background-color: #E3F2FD; border-left: 4px solid #2196F3; padding: 20px; border-radius: 5px; margin: 30px 0;">
                    <h3 style="color: #1976D2; margin: 0 0 15px 0;">🚚 Delivery Address</h3>
                    <table style="width: 100%; border-collapse: collapse;">
                        <tr>
                            <td style="padding: 5px 0; font-weight: bold; width: 140px;">Full Name:</td>
                            <td style="padding: 5px 0;">${deliveryAddress.fullName}</td>
                        </tr>
                        <tr>
                            <td style="padding: 5px 0; font-weight: bold;">Email:</td>
                            <td style="padding: 5px 0;">${deliveryAddress.email || "Not provided"}</td>
                        </tr>
                        <tr>
                            <td style="padding: 5px 0; font-weight: bold;">Phone:</td>
                            <td style="padding: 5px 0;">📞 ${deliveryAddress.phone}</td>
                        </tr>
                        <tr>
                            <td style="padding: 5px 0; font-weight: bold;">Street Address:</td>
                            <td style="padding: 5px 0;">${deliveryAddress.streetAddress || deliveryAddress.street}</td>
                        </tr>
                        ${deliveryAddress.apartmentSuite ? `
                        <tr>
                            <td style="padding: 5px 0; font-weight: bold;">Apt/Suite:</td>
                            <td style="padding: 5px 0;">${deliveryAddress.apartmentSuite}</td>
                        </tr>
                        ` : ""}
                        <tr>
                            <td style="padding: 5px 0; font-weight: bold;">City:</td>
                            <td style="padding: 5px 0;">${deliveryAddress.city}</td>
                        </tr>
                        <tr>
                            <td style="padding: 5px 0; font-weight: bold;">Province:</td>
                            <td style="padding: 5px 0;">${deliveryAddress.province || deliveryAddress.state || ""}</td>
                        </tr>
                        <tr>
                            <td style="padding: 5px 0; font-weight: bold;">Postal Code:</td>
                            <td style="padding: 5px 0;">${deliveryAddress.postalCode || deliveryAddress.zipCode}</td>
                        </tr>
                        <tr>
                            <td style="padding: 5px 0; font-weight: bold;">Country:</td>
                            <td style="padding: 5px 0;">${deliveryAddress.country || "Philippines"}</td>
                        </tr>
                        ${deliveryAddress.deliveryInstructions ? `
                        <tr>
                            <td style="padding: 5px 0; font-weight: bold; vertical-align: top;">Instructions:</td>
                            <td style="padding: 5px 0; font-style: italic; color: #666;">${deliveryAddress.deliveryInstructions}</td>
                        </tr>
                        ` : ""}
                    </table>
                </div>

                <!-- What's Next -->
                <div style="background-color: #F0F9FF; border-left: 4px solid #0EA5E9; padding: 20px; border-radius: 5px; margin: 30px 0;">
                    <h3 style="color: #0369A1; margin: 0 0 15px 0;">🎯 What's Next?</h3>
                    <ul style="margin: 0; padding-left: 20px; line-height: 1.8;">
                        <li>✅ We'll process your order within 1-2 business days</li>
                        <li>📦 You'll receive tracking information once shipped</li>
                        <li>🚚 Estimated delivery: ${deliveryDate}</li>
                        <li>💬 Questions? Contact our support team below</li>
                    </ul>
                </div>

                <!-- Contact Info -->
                <div style="text-align: center; margin: 40px 0 20px 0; padding: 20px; background-color: #F8F9FA; border-radius: 8px;">
                    <h3 style="color: #FF6B35; margin: 0 0 15px 0;">Need Help? 🤝</h3>
                    <p style="margin: 0 0 10px 0;">📧 <a href="mailto:annedfinds@gmail.com" style="color: #FF6B35; text-decoration: none;">annedfinds@gmail.com</a></p>
                    <p style="margin: 0 0 10px 0;">📞 Viber: (+63) 977-325-7043</p>
                    <p style="margin: 0;">🌐 <a href="https://www.annedfinds.web.app" style="color: #FF6B35; text-decoration: none;">www.annedfinds.web.app</a></p>
                </div>

                <div style="text-align: center; margin: 30px 0;">
                    <p style="color: #666; font-size: 14px; margin: 0;">
                        Thank you for choosing AnneDFinds! 🧡<br>
                        We appreciate your trust in us.
                    </p>
                </div>
            </div>

            <!-- Footer -->
            <div style="background-color: #333; color: #fff; text-align: center; padding: 20px;">
                <p style="margin: 0; font-size: 14px;">© 2025 AnneDFinds. All rights reserved.</p>
                <p style="margin: 5px 0 0 0; font-size: 12px; opacity: 0.8;">Sent with ❤️ from the AnneDFinds team</p>
            </div>
        </div>
    </body>
    </html>`;

    // Create plain text version
    const textContent = `
🛍️ AnneDFinds - Order Confirmation

Thank you for your order, ${customerName}! 🎉

ORDER DETAILS
═══════════════════════════════════════════════════════════════════════════
Order ID: ${orderId}
Order Date: ${new Date().toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric" })}
Payment Method: ${paymentMethod}
Estimated Delivery: ${deliveryDate}

ITEMS ORDERED
═══════════════════════════════════════════════════════════════════════════
${itemsText}

Total: ₱${totalAmount.toFixed(2)}

DELIVERY ADDRESS
═══════════════════════════════════════════════════════════════════════════
Full Name: ${deliveryAddress.fullName}
Email: ${deliveryAddress.email || "Not provided"}
Phone: ${deliveryAddress.phone}
Street Address: ${deliveryAddress.streetAddress || deliveryAddress.street}${deliveryAddress.apartmentSuite ? `
Apt/Suite: ${deliveryAddress.apartmentSuite}` : ""}
City: ${deliveryAddress.city}
Province: ${deliveryAddress.province || deliveryAddress.state || ""}
Postal Code: ${deliveryAddress.postalCode || deliveryAddress.zipCode}
Country: ${deliveryAddress.country || "Philippines"}${deliveryAddress.deliveryInstructions ? `
Delivery Instructions: ${deliveryAddress.deliveryInstructions}` : ""}

WHAT'S NEXT?
═══════════════════════════════════════════════════════════════════════════
✅ We'll process your order within 1-2 business days
📦 You'll receive tracking information once shipped
🚚 Estimated delivery: ${deliveryDate}
💬 Questions? Contact our support team

NEED HELP?
═══════════════════════════════════════════════════════════════════════════
📧 annedfinds@gmail.com
📞 Viber: (+63) 977-325-7043
🌐 www.annedfinds.web.app

Thank you for choosing AnneDFinds! 🧡
We appreciate your trust in us.

© 2025 AnneDFinds. All rights reserved.
`;

    // Prepare email options
    const mailOptions = {
      from: {
        name: "AnneDFinds",
        address: "annedfinds@gmail.com"
      },
      to: {
        name: customerName,
        address: toEmail
      },
      subject: `Order Confirmation - ${orderId} | AnneDFinds 🛍️`,
      text: textContent,
      html: htmlContent
    };

    console.log(`📤 Sending email via Gmail SMTP to: ${toEmail}`);

    // Send email via Gmail
    const emailResult = await gmailTransporter.sendMail(mailOptions);
    
    if (emailResult.messageId) {
      console.log("✅ Email sent successfully via Gmail:", emailResult.messageId);
      
      // Log successful email to Firestore
      await admin.firestore().collection("email_logs").add({
        toEmail,
        orderId,
        customerName,
        status: "sent",
        messageId: emailResult.messageId,
        service: "gmail_smtp",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        emailType: "order_confirmation"
      });

      // Send admin notification
      try {
        await sendAdminNotification(orderId, customerName, toEmail, totalAmount, orderItems, deliveryAddress);
      } catch (adminError) {
        console.warn("⚠️ Admin notification failed:", adminError);
      }

      return {
        success: true,
        message: "Order confirmation email sent successfully via Gmail",
        messageId: emailResult.messageId,
        orderId
      };
    } else {
      throw new Error("Failed to get message ID from Gmail");
    }

  } catch (error: any) { // FIXED: Added type annotation for error
    console.error("❌ Gmail email function error:", error);
    
    // Log failed email to Firestore
    await admin.firestore().collection("email_logs").add({
      toEmail: data.toEmail,
      orderId: data.orderId,
      customerName: data.customerName,
      status: "failed",
      error: error.message || String(error), // FIXED: Handle unknown error type
      service: "gmail_smtp",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      emailType: "order_confirmation"
    });

    throw new HttpsError(
      "internal",
      `Failed to send email via Gmail: ${error.message || String(error)}` // FIXED: Handle unknown error type
    );
  }
});

// Helper function to send admin notification via Gmail
async function sendAdminNotification(
  orderId: string, 
  customerName: string, 
  customerEmail: string,
  totalAmount: number, 
  orderItems: any[],
  deliveryAddress?: any
) {
  const adminEmail = "annedfinds@gmail.com";
  
  const itemsList = orderItems.map((item: any) => 
    `• ${item.name} x${item.quantity} = ₱${(item.price * item.quantity).toFixed(2)}`
  ).join("\n");

  const adminTextContent = `
🚨 NEW ORDER ALERT - AnneDFinds

Order ID: ${orderId}
Customer: ${customerName}
Email: ${customerEmail}
Total Amount: ₱${totalAmount.toFixed(2)}
Date: ${new Date().toLocaleString()}

Items Ordered:
${itemsList}

CUSTOMER SHIPPING ADDRESS:
═══════════════════════════════════════════════════════════════════════════
${deliveryAddress ? `Full Name: ${deliveryAddress.fullName}
Email: ${deliveryAddress.email || "Not provided"}
Phone: ${deliveryAddress.phone}
Street Address: ${deliveryAddress.streetAddress || deliveryAddress.street}${deliveryAddress.apartmentSuite ? `
Apt/Suite: ${deliveryAddress.apartmentSuite}` : ""}
City: ${deliveryAddress.city}
Province: ${deliveryAddress.province || deliveryAddress.state || ""}
Postal Code: ${deliveryAddress.postalCode || deliveryAddress.zipCode}
Country: ${deliveryAddress.country || "Philippines"}${deliveryAddress.deliveryInstructions ? `
Delivery Instructions: ${deliveryAddress.deliveryInstructions}` : ""}` : "Address information not available"}

⚡ ACTION REQUIRED: Process this order in your admin dashboard

---
AnneDFinds Admin System
  `;

  const adminHtmlContent = `
  <!DOCTYPE html>
  <html>
  <head>
      <meta charset="utf-8">
      <title>New Order Alert - ${orderId}</title>
  </head>
  <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 20px; background-color: #f4f4f4;">
      <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 10px; overflow: hidden; box-shadow: 0 0 20px rgba(0,0,0,0.1);">
          <div style="background-color: #FF6B35; color: white; padding: 30px; text-align: center;">
              <h1 style="margin: 0; font-size: 24px;">🚨 NEW ORDER ALERT</h1>
              <p style="margin: 10px 0 0 0; opacity: 0.9;">AnneDFinds Admin Notification</p>
          </div>
          
          <div style="padding: 30px;">
              <div style="background-color: #FFF3E0; border-left: 4px solid #FF6B35; padding: 20px; margin: 20px 0; border-radius: 5px;">
                  <h2 style="color: #FF6B35; margin: 0 0 15px 0;">Order Details</h2>
                  <p style="margin: 5px 0;"><strong>Order ID:</strong> ${orderId}</p>
                  <p style="margin: 5px 0;"><strong>Customer:</strong> ${customerName}</p>
                  <p style="margin: 5px 0;"><strong>Email:</strong> ${customerEmail}</p>
                  <p style="margin: 5px 0;"><strong>Total Amount:</strong> <span style="color: #FF6B35; font-size: 18px; font-weight: bold;">₱${totalAmount.toFixed(2)}</span></p>
                  <p style="margin: 5px 0;"><strong>Date:</strong> ${new Date().toLocaleString()}</p>
              </div>

              <div style="background-color: #F0F9FF; border-left: 4px solid #0EA5E9; padding: 20px; margin: 20px 0; border-radius: 5px;">
                  <h3 style="color: #0369A1; margin: 0 0 15px 0;">Items Ordered:</h3>
                  <ul style="margin: 0; padding-left: 20px;">
                      ${orderItems.map((item: any) => 
                        `<li style="margin: 5px 0;">${item.name} x${item.quantity} = ₱${(item.price * item.quantity).toFixed(2)}</li>`
                      ).join("")}
                  </ul>
              </div>

              ${deliveryAddress ? `
              <div style="background-color: #E3F2FD; border-left: 4px solid #2196F3; padding: 20px; margin: 20px 0; border-radius: 5px;">
                  <h3 style="color: #1976D2; margin: 0 0 15px 0;">📍 Customer Shipping Address</h3>
                  <table style="width: 100%; border-collapse: collapse;">
                      <tr>
                          <td style="padding: 3px 0; font-weight: bold; width: 140px;">Full Name:</td>
                          <td style="padding: 3px 0;">${deliveryAddress.fullName}</td>
                      </tr>
                      <tr>
                          <td style="padding: 3px 0; font-weight: bold;">Email:</td>
                          <td style="padding: 3px 0;">${deliveryAddress.email || "Not provided"}</td>
                      </tr>
                      <tr>
                          <td style="padding: 3px 0; font-weight: bold;">Phone:</td>
                          <td style="padding: 3px 0;">📞 ${deliveryAddress.phone}</td>
                      </tr>
                      <tr>
                          <td style="padding: 3px 0; font-weight: bold;">Street Address:</td>
                          <td style="padding: 3px 0;">${deliveryAddress.streetAddress || deliveryAddress.street}</td>
                      </tr>
                      ${deliveryAddress.apartmentSuite ? `
                      <tr>
                          <td style="padding: 3px 0; font-weight: bold;">Apt/Suite:</td>
                          <td style="padding: 3px 0;">${deliveryAddress.apartmentSuite}</td>
                      </tr>
                      ` : ""}
                      <tr>
                          <td style="padding: 3px 0; font-weight: bold;">City:</td>
                          <td style="padding: 3px 0;">${deliveryAddress.city}</td>
                      </tr>
                      <tr>
                          <td style="padding: 3px 0; font-weight: bold;">Province:</td>
                          <td style="padding: 3px 0;">${deliveryAddress.province || deliveryAddress.state || ""}</td>
                      </tr>
                      <tr>
                          <td style="padding: 3px 0; font-weight: bold;">Postal Code:</td>
                          <td style="padding: 3px 0;">${deliveryAddress.postalCode || deliveryAddress.zipCode}</td>
                      </tr>
                      <tr>
                          <td style="padding: 3px 0; font-weight: bold;">Country:</td>
                          <td style="padding: 3px 0;">${deliveryAddress.country || "Philippines"}</td>
                      </tr>
                      ${deliveryAddress.deliveryInstructions ? `
                      <tr>
                          <td style="padding: 3px 0; font-weight: bold; vertical-align: top;">Instructions:</td>
                          <td style="padding: 3px 0; font-style: italic; color: #666;">${deliveryAddress.deliveryInstructions}</td>
                      </tr>
                      ` : ""}
                  </table>
              </div>
              ` : ""}

              <div style="text-align: center; margin-top: 30px; padding: 20px; background-color: #FEF3C7; border-left: 4px solid #F59E0B; border-radius: 5px;">
                  <p style="margin: 0; color: #92400E; font-weight: bold; font-size: 16px;">
                      ⚡ ACTION REQUIRED
                  </p>
                  <p style="margin: 10px 0 0 0; color: #92400E;">
                      Process this order in your admin dashboard
                  </p>
              </div>
          </div>

          <div style="background-color: #333; color: #fff; text-align: center; padding: 20px;">
              <p style="margin: 0; font-size: 14px;">AnneDFinds Admin System</p>
          </div>
      </div>
  </body>
  </html>`;

  const adminMailOptions = {
    from: {
      name: "AnneDFinds System",
      address: "annedfinds@gmail.com"
    },
    to: {
      name: "AnneDFinds Admin",
      address: adminEmail
    },
    subject: `🚨 New Order: ${orderId} - ₱${totalAmount.toFixed(2)} | AnneDFinds`,
    text: adminTextContent,
    html: adminHtmlContent
  };

  try {
    const adminResult = await gmailTransporter.sendMail(adminMailOptions);
    console.log("✅ Admin notification sent successfully via Gmail:", adminResult.messageId);
  } catch (adminError: any) { // FIXED: Added type annotation for error
    console.error("❌ Admin notification failed:", adminError);
    throw adminError;
  }
}

// Test email function
export const testGmailEmail = onCall(async (request) => {
  try {
    console.log("🧪 Testing Gmail email service...");

    const testMailOptions = {
      from: {
        name: "AnneDFinds Test",
        address: "annedfinds@gmail.com"
      },
      to: {
        name: "Test Recipient",
        address: "annedfinds@gmail.com" // Send to yourself
      },
      subject: `🧪 Gmail Test Email - ${new Date().toLocaleString()}`,
      text: `
This is a test email from AnneDFinds Gmail SMTP service.

Test Details:
- Service: Gmail SMTP via Firebase Function
- Time: ${new Date().toLocaleString()}
- Status: Gmail SMTP is working correctly!

If you received this email, your Gmail configuration is successful.

AnneDFinds Email Service
      `,
      html: `
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background: linear-gradient(135deg, #FF6B35, #FF8A5B); color: white; padding: 20px; border-radius: 8px; text-align: center; margin-bottom: 20px;">
    <h2 style="margin: 0;">🧪 Gmail SMTP Test</h2>
    <p style="margin: 5px 0 0 0;">AnneDFinds Email Service</p>
  </div>
  
  <div style="background-color: #d4edda; border: 1px solid #c3e6cb; padding: 15px; border-radius: 5px; margin: 20px 0;">
    <h3 style="color: #155724; margin-top: 0;">✅ Test Successful!</h3>
    <p style="color: #155724; margin: 0;">Your Gmail SMTP configuration is working correctly.</p>
  </div>
  
  <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px;">
    <h4>Test Details:</h4>
    <ul>
      <li><strong>Service:</strong> Gmail SMTP via Firebase Function</li>
      <li><strong>Time:</strong> ${new Date().toLocaleString()}</li>
      <li><strong>Email:</strong> annedfinds@gmail.com</li>
      <li><strong>App Password:</strong> Configured ✅</li>
    </ul>
  </div>
  
  <p style="margin-top: 20px; color: #666;">
    <em>This test email confirms that your AnneDFinds Gmail email service is ready for production use.</em>
  </p>
</div>
      `
    };

    const testResult = await gmailTransporter.sendMail(testMailOptions);
    
    console.log("✅ Gmail test email sent successfully:", testResult.messageId);
    
    return {
      success: true,
      message: "Gmail test email sent successfully",
      messageId: testResult.messageId
    };

  } catch (error: any) { // FIXED: Added type annotation for error
    console.error("❌ Gmail test email failed:", error);
    throw new HttpsError(
      "internal",
      `Gmail test failed: ${error.message || String(error)}` // FIXED: Handle unknown error type
    );
  }
});

// Custom claims management function for admin roles
export const setUserAdminClaim = onCall(async (request) => {
  try {
    console.log("🔑 Setting user admin claim...", request.data);
    
    const { uid, isAdmin } = request.data;
    
    // Validate input
    if (!uid || typeof uid !== 'string') {
      throw new HttpsError('invalid-argument', 'Valid uid is required');
    }
    
    if (typeof isAdmin !== 'boolean') {
      throw new HttpsError('invalid-argument', 'isAdmin must be a boolean');
    }
    
    // Verify caller is authenticated
    const caller = request.auth;
    if (!caller) {
      throw new HttpsError('unauthenticated', 'Must be authenticated');
    }
    
    // Verify caller has admin privileges (check existing custom claims)
    const callerRecord = await admin.auth().getUser(caller.uid);
    const callerClaims = callerRecord.customClaims || {};
    
    if (!callerClaims.admin && caller.uid !== uid) {
      throw new HttpsError(
        'permission-denied', 
        'Only admins can modify admin status of other users'
      );
    }
    
    // Set custom claims on Firebase Auth token
    const customClaims: { [key: string]: any } = {
      admin: isAdmin
    };
    
    await admin.auth().setCustomUserClaims(uid, customClaims);
    console.log(`✅ Custom claims set for user ${uid}: admin=${isAdmin}`);
    
    // Update Firestore user document
    const userUpdate: { [key: string]: any } = {
      isAdmin: isAdmin,
      userType: isAdmin ? 'admin' : 'buyer',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    await admin.firestore().collection('users').doc(uid).update(userUpdate);
    console.log(`✅ Firestore user document updated for ${uid}`);
    
    // Manage adminUsers collection
    if (isAdmin) {
      await admin.firestore().collection('adminUsers').doc(uid).set({
        role: 'admin',
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        grantedBy: caller.uid,
        grantedByEmail: caller.token?.email || 'unknown',
      });
      console.log(`✅ Added to adminUsers collection: ${uid}`);
    } else {
      await admin.firestore().collection('adminUsers').doc(uid).delete();
      console.log(`✅ Removed from adminUsers collection: ${uid}`);
    }
    
    // Log audit trail
    await admin.firestore().collection('auditLogs').add({
      action: isAdmin ? 'GRANT_ADMIN_ACCESS' : 'REVOKE_ADMIN_ACCESS',
      targetUserId: uid,
      performedBy: caller.uid,
      performedByEmail: caller.token?.email || 'unknown',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      details: {
        isAdmin: isAdmin,
        method: 'setUserAdminClaim',
      },
    });
    
    return {
      success: true,
      message: `User ${uid} admin status ${isAdmin ? 'granted' : 'revoked'} successfully`,
      customClaims: customClaims,
    };
    
  } catch (error: any) {
    console.error("❌ Error setting user admin claim:", error);
    
    // Log error for audit
    try {
      if (request.auth) {
        await admin.firestore().collection('auditLogs').add({
          action: 'ADMIN_CLAIM_ERROR',
          targetUserId: request.data?.uid || 'unknown',
          performedBy: request.auth.uid,
          performedByEmail: request.auth.token?.email || 'unknown',
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          error: error.message || String(error),
        });
      }
    } catch (auditError) {
      console.error("❌ Failed to log audit error:", auditError);
    }
    
    // Re-throw HttpsErrors as-is, wrap others
    if (error instanceof HttpsError) {
      throw error;
    }
    
    throw new HttpsError(
      'internal',
      `Failed to set admin claim: ${error.message || String(error)}`
    );
  }
});

// Verify admin claim function (optional - for debugging)
export const verifyAdminClaim = onCall(async (request) => {
  try {
    const caller = request.auth;
    if (!caller) {
      throw new HttpsError('unauthenticated', 'Must be authenticated');
    }
    
    const userRecord = await admin.auth().getUser(caller.uid);
    const customClaims = userRecord.customClaims || {};
    
    return {
      uid: caller.uid,
      email: caller.token?.email,
      customClaims: customClaims,
      isAdmin: customClaims.admin === true,
    };
    
  } catch (error: any) {
    console.error("❌ Error verifying admin claim:", error);
    throw new HttpsError(
      'internal',
      `Failed to verify admin claim: ${error.message || String(error)}`
    );
  }
});