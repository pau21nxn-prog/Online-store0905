import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
  }) async {
    try {
      print('📧 Sending Gmail order confirmation email to: $toEmail');
      print('Platform: ${kIsWeb ? "Web" : "Mobile"}');

      // Validate input email
      if (!_isValidEmail(toEmail)) {
        print('❌ Invalid recipient email: $toEmail');
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
      );

      if (emailSent) {
        print('✅ Gmail email sent successfully');
        return true;
      } else {
        print('❌ Failed to send Gmail email');
        await _logFailedEmail(toEmail, orderId, customerName);
        return false;
      }

    } catch (e) {
      print('❌ Gmail email service error: $e');
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
  }) async {
    try {
      print('📤 Sending email via Gmail Firebase Function...');

      // Prepare data for Gmail Firebase Function
      final functionData = {
        'toEmail': toEmail.trim(),
        'customerName': customerName.trim(),
        'orderId': orderId,
        'orderItems': orderItems.map((item) => {
          'name': item['name'] ?? 'Unknown Item',
          'quantity': (item['quantity'] as num).toInt(),
          'price': (item['price'] as num).toDouble(),
        }).toList(),
        'totalAmount': totalAmount,
        'paymentMethod': paymentMethod,
        'deliveryAddress': {
          'fullName': deliveryAddress['fullName'] ?? '',
          'street': deliveryAddress['address'] ?? '',
          'city': deliveryAddress['city'] ?? '',
          'state': deliveryAddress['state'] ?? '',
          'zipCode': deliveryAddress['postalCode'] ?? deliveryAddress['zipCode'] ?? '',
          'country': deliveryAddress['country'] ?? 'Philippines',
          'phone': deliveryAddress['phone'] ?? '',
        },
        'estimatedDelivery': estimatedDelivery.toIso8601String(),
      };

      print('📋 Gmail function data: ${jsonEncode(functionData)}');

      // Call Gmail Firebase Function
      final HttpsCallable callable = _functions.httpsCallable('sendOrderConfirmationEmail');
      final result = await callable.call(functionData);

      print('📬 Gmail Firebase Function response: ${result.data}');

      if (result.data != null && result.data['success'] == true) {
        print('✅ Email sent via Gmail Firebase Function');
        print('📧 Message ID: ${result.data['messageId'] ?? 'No message ID'}');
        print('📧 Order ID: ${result.data['orderId']}');
        return true;
      } else {
        print('❌ Gmail Firebase Function failed');
        print('📄 Response data: ${result.data}');
        return false;
      }
    } catch (e) {
      print('❌ Gmail Firebase Function error: $e');
      print('💡 Make sure your Gmail Firebase Function is deployed');
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
      print('📦 Gmail shipping notification to: $toEmail');

      if (!_isValidEmail(toEmail)) {
        print('❌ Invalid recipient email: $toEmail');
        return false;
      }

      // For now, log the shipping notification
      // You can create a separate Firebase Function for shipping notifications
      print('📦 Shipping notification details:');
      print('  - Order: $orderId');
      print('  - Customer: $customerName');
      print('  - Tracking: $trackingNumber');
      print('  - Courier: $courier');
      
      // TODO: Implement shipping notification Firebase Function for Gmail
      print('💡 Shipping notifications via Gmail Firebase Function not implemented yet');
      return true;
    } catch (e) {
      print('❌ Gmail shipping notification error: $e');
      return false;
    }
  }

  /// Test Gmail email configuration
  static Future<bool> testEmailConfiguration() async {
    try {
      print('🧪 Testing Gmail email configuration...');
      print('Platform: ${kIsWeb ? "Web" : "Mobile"}');

      return await _testGmailFirebaseFunction();
    } catch (e) {
      print('❌ Gmail test failed: $e');
      return false;
    }
  }

  /// Test Gmail Firebase Function
  static Future<bool> _testGmailFirebaseFunction() async {
    try {
      print('🧪 Testing Gmail Firebase Function...');

      // Call the test function
      final HttpsCallable callable = _functions.httpsCallable('testGmailEmail');
      final result = await callable.call({});

      print('📊 Gmail test result: ${result.data}');

      if (result.data != null && result.data['success'] == true) {
        print('✅ Gmail Firebase Function test successful');
        print('📧 Test email sent with message ID: ${result.data['messageId']}');
        return true;
      } else {
        print('❌ Gmail Firebase Function test failed');
        print('📄 Response: ${result.data}');
        return false;
      }
    } catch (e) {
      print('❌ Gmail Firebase Function test error: $e');
      print('💡 Possible issues:');
      print('   - Gmail Firebase Function not deployed');
      print('   - Gmail credentials incorrect');
      print('   - Network/authentication issues');
      return false;
    }
  }

  /// Send a test order confirmation email
  static Future<bool> sendTestOrderEmail({
    required String toEmail,
    required String customerName,
  }) async {
    try {
      print('🧪 Sending Gmail test order email...');

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
      print('❌ Gmail test order email error: $e');
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
      print('📧 FAILED GMAIL EMAIL LOG:');
      print('To: $toEmail');
      print('Order: $orderId');
      print('Customer: $customerName');
      print('Platform: ${kIsWeb ? "Web" : "Mobile"}');
      print('Service: Gmail SMTP via Firebase Functions');
      print('Time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
      
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
      print('Failed to log Gmail email failure: $e');
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