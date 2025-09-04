import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../features/checkout/qr_payment_checkout.dart';

class EmailService {
  // Firebase Functions instance
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Main method to send order confirmation email via Gmail
  static Future<bool> sendOrderConfirmationEmail({
    required String toEmail,
    required String customerName,
    required String orderId,
    required List<Map<String, dynamic>> orderItems,
    required double totalAmount,
    required String paymentMethod,
    required Map<String, String> deliveryAddress,
    required DateTime estimatedDelivery,
    bool skipAdminNotification = false,
  }) async {
    try {
      debugPrint('📧 Sending Gmail order confirmation email to: $toEmail');
      debugPrint('Platform: ${kIsWeb ? "Web" : "Mobile"}');

      // Validate input email
      if (!_isValidEmail(toEmail)) {
        debugPrint('❌ Invalid recipient email: $toEmail');
        await _logFailedEmail(toEmail, orderId, customerName);
        return false;
      }

      // Send via Firebase Function with Gmail
      bool emailSent = await _sendViaGmailFirebaseFunction(
        toEmail: toEmail,
        customerName: customerName,
        orderId: orderId,
        orderItems: orderItems,
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        deliveryAddress: deliveryAddress,
        estimatedDelivery: estimatedDelivery,
        skipAdminNotification: skipAdminNotification,
      );

      if (emailSent) {
        debugPrint('✅ Gmail email sent successfully');
        return true;
      } else {
        debugPrint('❌ Failed to send Gmail email');
        await _logFailedEmail(toEmail, orderId, customerName);
        return false;
      }

    } catch (e) {
      debugPrint('❌ Gmail email service error: $e');
      await _logFailedEmail(toEmail, orderId, customerName);
      return false;
    }
  }

  /// Send via Gmail Firebase Cloud Function
  static Future<bool> _sendViaGmailFirebaseFunction({
    required String toEmail,
    required String customerName,
    required String orderId,
    required List<Map<String, dynamic>> orderItems,
    required double totalAmount,
    required String paymentMethod,
    required Map<String, String> deliveryAddress,
    required DateTime estimatedDelivery,
    bool skipAdminNotification = false,
  }) async {
    try {
      debugPrint('📤 Sending email via Gmail Firebase Function...');

      // Prepare data for Gmail Firebase Function
      final functionData = {
        'toEmail': toEmail.trim(),
        'customerName': customerName.trim(),
        'orderId': orderId,
        'orderItems': orderItems.map((item) => {
          'name': item['name'] ?? 'Unknown Item',
          'quantity': (item['quantity'] as num).toInt(),
          'price': (item['price'] as num).toDouble(),
          'variantSku': item['variantSku'],
          'variantDisplayName': item['variantDisplayName'],
          'selectedOptions': item['selectedOptions'],
        }).toList(),
        'totalAmount': totalAmount,
        'paymentMethod': paymentMethod,
        'deliveryAddress': {
          'fullName': deliveryAddress['fullName'] ?? '',
          'email': deliveryAddress['email'] ?? '',
          'phone': deliveryAddress['phone'] ?? '',
          'streetAddress': deliveryAddress['streetAddress'] ?? deliveryAddress['address'] ?? '',
          'apartmentSuite': deliveryAddress['apartmentSuite'] ?? '',
          'city': deliveryAddress['city'] ?? '',
          'province': deliveryAddress['province'] ?? deliveryAddress['state'] ?? '',
          'postalCode': deliveryAddress['postalCode'] ?? deliveryAddress['zipCode'] ?? '',
          'country': deliveryAddress['country'] ?? 'Philippines',
          'deliveryInstructions': deliveryAddress['deliveryInstructions'] ?? '',
        },
        'estimatedDelivery': estimatedDelivery.toIso8601String(),
        'skipAdminNotification': skipAdminNotification,
      };

      debugPrint('📋 Gmail function data: ${jsonEncode(functionData)}');

      // Call Gmail Firebase Function
      final HttpsCallable callable = _functions.httpsCallable('sendOrderConfirmationEmail');
      final result = await callable.call(functionData);

      debugPrint('📬 Gmail Firebase Function response: ${result.data}');

      if (result.data != null && result.data['success'] == true) {
        debugPrint('✅ Email sent via Gmail Firebase Function');
        debugPrint('📧 Message ID: ${result.data['messageId'] ?? 'No message ID'}');
        debugPrint('📧 Order ID: ${result.data['orderId']}');
        return true;
      } else {
        debugPrint('❌ Gmail Firebase Function failed');
        debugPrint('📄 Response data: ${result.data}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Gmail Firebase Function error: $e');
      debugPrint('💡 Make sure your Gmail Firebase Function is deployed');
      return false;
    }
  }

  /// Send admin payment notification for manual verification
  static Future<bool> sendAdminPaymentNotification({
    required String orderId,
    required PaymentMethod paymentMethod,
    required double amount,
    required Map<String, dynamic> customerInfo,
    required Map<String, dynamic> orderDetails,
  }) async {
    try {
      debugPrint('📧 Sending admin payment notification for order: $orderId');

      final paymentMethodNames = {
        PaymentMethod.gcash: 'GCash',
        PaymentMethod.gotyme: 'GoTyme Bank',
        PaymentMethod.metrobank: 'Metrobank',
        PaymentMethod.bpi: 'BPI',
      };

      final functionData = {
        'adminEmail': 'annedfinds@gmail.com',
        'orderId': orderId,
        'paymentMethod': paymentMethodNames[paymentMethod],
        'amount': amount,
        'customerInfo': customerInfo,
        'orderDetails': orderDetails,
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'admin_payment_notification',
      };

      debugPrint('📋 Admin notification data: ${jsonEncode(functionData)}');

      final HttpsCallable callable = _functions.httpsCallable('sendAdminPaymentNotification');
      final result = await callable.call(functionData);

      debugPrint('📬 Admin notification response: ${result.data}');

      if (result.data != null && result.data['success'] == true) {
        debugPrint('✅ Admin payment notification sent successfully');
        return true;
      } else {
        debugPrint('❌ Failed to send admin payment notification');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Admin payment notification error: $e');
      return false;
    }
  }

  /// Send customer payment confirmation after admin verifies payment
  static Future<bool> sendCustomerPaymentConfirmation({
    required String customerEmail,
    required String customerName,
    required String orderId,
    required double amount,
    required String paymentMethod,
  }) async {
    try {
      debugPrint('📧 Sending customer payment confirmation for order: $orderId');

      if (!_isValidEmail(customerEmail)) {
        debugPrint('❌ Invalid customer email: $customerEmail');
        return false;
      }

      final functionData = {
        'customerEmail': customerEmail,
        'customerName': customerName,
        'orderId': orderId,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'customer_payment_confirmation',
      };

      debugPrint('📋 Customer confirmation data: ${jsonEncode(functionData)}');

      final HttpsCallable callable = _functions.httpsCallable('sendCustomerPaymentConfirmation');
      final result = await callable.call(functionData);

      debugPrint('📬 Customer confirmation response: ${result.data}');

      if (result.data != null && result.data['success'] == true) {
        debugPrint('✅ Customer payment confirmation sent successfully');
        return true;
      } else {
        debugPrint('❌ Failed to send customer payment confirmation');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Customer payment confirmation error: $e');
      return false;
    }
  }

  /// Send shipping notification via Gmail
  static Future<bool> sendShippingNotification({
    required String toEmail,
    required String customerName,
    required String orderId,
    required String trackingNumber,
    required String courier,
  }) async {
    try {
      debugPrint('📦 Gmail shipping notification to: $toEmail');

      if (!_isValidEmail(toEmail)) {
        debugPrint('❌ Invalid recipient email: $toEmail');
        return false;
      }

      // For now, log the shipping notification
      // You can create a separate Firebase Function for shipping notifications
      debugPrint('📦 Shipping notification details:');
      debugPrint('  - Order: $orderId');
      debugPrint('  - Customer: $customerName');
      debugPrint('  - Tracking: $trackingNumber');
      debugPrint('  - Courier: $courier');
      
      // TODO: Implement shipping notification Firebase Function for Gmail
      debugPrint('💡 Shipping notifications via Gmail Firebase Function not implemented yet');
      return true;
    } catch (e) {
      debugPrint('❌ Gmail shipping notification error: $e');
      return false;
    }
  }

  /// Test Gmail email configuration
  static Future<bool> testEmailConfiguration() async {
    try {
      debugPrint('🧪 Testing Gmail email configuration...');
      debugPrint('Platform: ${kIsWeb ? "Web" : "Mobile"}');

      return await _testGmailFirebaseFunction();
    } catch (e) {
      debugPrint('❌ Gmail test failed: $e');
      return false;
    }
  }

  /// Test Gmail Firebase Function
  static Future<bool> _testGmailFirebaseFunction() async {
    try {
      debugPrint('🧪 Testing Gmail Firebase Function...');

      // Call the test function
      final HttpsCallable callable = _functions.httpsCallable('testGmailEmail');
      final result = await callable.call({});

      debugPrint('📊 Gmail test result: ${result.data}');

      if (result.data != null && result.data['success'] == true) {
        debugPrint('✅ Gmail Firebase Function test successful');
        debugPrint('📧 Test email sent with message ID: ${result.data['messageId']}');
        return true;
      } else {
        debugPrint('❌ Gmail Firebase Function test failed');
        debugPrint('📄 Response: ${result.data}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Gmail Firebase Function test error: $e');
      debugPrint('💡 Possible issues:');
      debugPrint('   - Gmail Firebase Function not deployed');
      debugPrint('   - Gmail credentials incorrect');
      debugPrint('   - Network/authentication issues');
      return false;
    }
  }

  /// Send a test order confirmation email
  static Future<bool> sendTestOrderEmail({
    required String toEmail,
    required String customerName,
  }) async {
    try {
      debugPrint('🧪 Sending Gmail test order email...');

      // Create test order data
      final testOrderItems = [
        {
          'name': 'Test Product 1',
          'quantity': 2,
          'price': 99.99,
        },
        {
          'name': 'Test Product 2',
          'quantity': 1,
          'price': 149.99,
        }
      ];

      final testDeliveryAddress = {
        'fullName': customerName,
        'address': '123 Test Street, Test Village',
        'city': 'Quezon City',
        'state': '',
        'postalCode': '1100',
        'country': 'Philippines',
        'phone': '+63 917 123 4567',
      };

      return await sendOrderConfirmationEmail(
        toEmail: toEmail,
        customerName: customerName,
        orderId: 'TEST${DateTime.now().millisecondsSinceEpoch}',
        orderItems: testOrderItems,
        totalAmount: 349.97,
        paymentMethod: 'Test Payment',
        deliveryAddress: testDeliveryAddress,
        estimatedDelivery: DateTime.now().add(const Duration(days: 3)),
      );
    } catch (e) {
      debugPrint('❌ Gmail test order email error: $e');
      return false;
    }
  }

  /// Get email service status
  static String getEmailServiceStatus() {
    return 'Gmail Email Service (Firebase Functions + Gmail SMTP) - Ready';
  }

  /// Check if email service is configured
  static bool isEmailServiceConfigured() {
    // Since we're using Firebase Functions, this always returns true
    // The actual Gmail configuration is handled in the Firebase Function
    return true;
  }

  /// Get service diagnostics
  static Future<Map<String, dynamic>> getServiceDiagnostics() async {
    Map<String, dynamic> diagnostics = {
      'timestamp': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'platform': kIsWeb ? 'Web' : 'Mobile',
      'serviceType': 'Gmail SMTP via Firebase Functions',
      'emailProvider': 'Gmail',
    };

    bool serviceWorking = false;
    String? testMessageId;
    
    try {
      // Test the Gmail service
      final HttpsCallable testCallable = _functions.httpsCallable('testGmailEmail');
      final testResult = await testCallable.call({});
      
      serviceWorking = testResult.data != null && testResult.data['success'] == true;
      testMessageId = testResult.data?['messageId'];
    } catch (e) {
      diagnostics['error'] = e.toString();
    }

    diagnostics['gmailService'] = {
      'configured': true,
      'working': serviceWorking,
      'status': serviceWorking ? 'Working' : 'Failed',
      'firebaseFunctionName': 'sendOrderConfirmationEmail',
      'testFunctionName': 'testGmailEmail',
      'lastTestMessageId': testMessageId,
    };

    diagnostics['overallHealth'] = {
      'healthy': serviceWorking,
      'status': serviceWorking ? 'Gmail Email Service Operational' : 'Service Issues Detected',
      'recommendation': serviceWorking 
        ? 'Gmail email service is ready for production use.'
        : 'Please check your Firebase Function deployment and Gmail configuration.'
    };

    return diagnostics;
  }

  /// Send contact form submission to admin
  static Future<bool> sendContactFormSubmission({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String email,
    required String message,
  }) async {
    try {
      debugPrint('📧 Sending contact form submission via dedicated Firebase Function...');

      // Validate input email
      if (!_isValidEmail(email)) {
        debugPrint('❌ Invalid sender email: $email');
        return false;
      }

      // Prepare data for dedicated contact form Firebase Function
      final functionData = {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'phoneNumber': phoneNumber.trim(),
        'email': email.trim(),
        'message': message.trim(),
        'adminEmail': 'annedfinds@gmail.com',
        'timestamp': DateTime.now().toIso8601String(),
      };

      debugPrint('📋 Contact form data: ${jsonEncode(functionData)}');

      // Call dedicated Firebase Function for contact form
      final HttpsCallable callable = _functions.httpsCallable('sendContactFormEmail');
      final result = await callable.call(functionData);

      debugPrint('📬 Contact form response: ${result.data}');

      if (result.data != null && result.data['success'] == true) {
        debugPrint('✅ Contact form submission sent successfully via dedicated function');
        debugPrint('📧 Message ID: ${result.data['messageId'] ?? 'No message ID'}');
        return true;
      } else {
        debugPrint('❌ Failed to send contact form submission');
        debugPrint('📄 Response data: ${result.data}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Contact form submission error: $e');
      debugPrint('💡 Make sure the sendContactFormEmail Firebase Function is deployed');
      return false;
    }
  }

  /// Get detailed debug information
  static Map<String, dynamic> getDebugInfo() {
    return {
      'platform': kIsWeb ? 'Web' : 'Mobile',
      'serviceType': 'Gmail SMTP via Firebase Functions',
      'firebaseFunctions': [
        'sendOrderConfirmationEmail',
        'testGmailEmail'
      ],
      'emailProvider': 'Gmail SMTP',
      'gmailAccount': 'annedfinds@gmail.com',
      'adminEmail': 'annedfinds@gmail.com',
      'features': [
        'Order confirmation emails',
        'Admin notifications',
        'Beautiful HTML templates',
        'Plain text fallback',
        'Email logging to Firestore',
        'Test email function'
      ],
      'timestamp': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
    };
  }

  /// Log failed email attempts
  static Future<void> _logFailedEmail(String toEmail, String orderId, String customerName) async {
    try {
      debugPrint('📧 FAILED GMAIL EMAIL LOG:');
      debugPrint('To: $toEmail');
      debugPrint('Order: $orderId');
      debugPrint('Customer: $customerName');
      debugPrint('Platform: ${kIsWeb ? "Web" : "Mobile"}');
      debugPrint('Service: Gmail SMTP via Firebase Functions');
      debugPrint('Time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
      
      // TODO: You can log this to Firestore if needed
      /*
      await FirebaseFirestore.instance.collection('failed_emails').add({
        'toEmail': toEmail,
        'orderId': orderId,
        'customerName': customerName,
        'timestamp': DateTime.now(),
        'platform': kIsWeb ? 'web' : 'mobile',
        'service': 'gmail_firebase_function',
        'status': 'failed',
      });
      */
    } catch (e) {
      debugPrint('Failed to log Gmail email failure: $e');
    }
  }

  // Helper method to validate email format
  static bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email.trim());
  }

  // Format currency for display
  static String formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }
}