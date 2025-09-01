import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../common/theme.dart';
import '../../common/mobile_layout_utils.dart';
import '../../services/email_service.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../models/user.dart';

enum PaymentMethod { gcash, gotyme, metrobank, bpi }

class QRPaymentCheckout extends StatefulWidget {
  final double totalAmount;
  final String orderId;
  final Map<String, dynamic> orderDetails;

  const QRPaymentCheckout({
    super.key,
    required this.totalAmount,
    required this.orderId,
    required this.orderDetails,
  });

  @override
  State<QRPaymentCheckout> createState() => _QRPaymentCheckoutState();
}

class _QRPaymentCheckoutState extends State<QRPaymentCheckout> {
  PaymentMethod? selectedPaymentMethod;
  bool isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final shouldUseWrapper = MobileLayoutUtils.shouldUseViewportWrapper(context);
    
    if (shouldUseWrapper) {
      return Center(
        child: Container(
          width: MobileLayoutUtils.getEffectiveViewportWidth(context),
          decoration: MobileLayoutUtils.getMobileViewportDecoration(),
          child: _buildScaffoldContent(context),
        ),
      );
    }
    
    return _buildScaffoldContent(context);
  }

  Widget _buildScaffoldContent(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Payment',
          style: TextStyle(color: AppTheme.textPrimaryColor(context)),
        ),
        backgroundColor: AppTheme.backgroundColor(context),
        foregroundColor: AppTheme.textPrimaryColor(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderSummary(),
            const SizedBox(height: 24),
            _buildPaymentMethodSelection(),
            const SizedBox(height: 24),
            if (selectedPaymentMethod != null) _buildQRCodeDisplay(),
            const SizedBox(height: 24),
            _buildPaymentInstructions(),
            const SizedBox(height: 32),
            _buildConfirmPaymentButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    // Extract order items from orderDetails
    final items = widget.orderDetails['items'] as List<dynamic>? ?? [];
    final subtotal = widget.orderDetails['subtotal'] as double? ?? 0.0;
    final shipping = widget.orderDetails['shipping'] as double? ?? 99.0; // Default shipping
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // Order ID
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order ID: ${widget.orderId}'),
                const Icon(Icons.copy, size: 16),
              ],
            ),
            const SizedBox(height: 16),
            
            // Order Items
            if (items.isNotEmpty) ...[
              for (var item in items) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item['name'] ?? 'Unknown Item'} x${item['quantity'] ?? 1}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      '₱${((item['price'] ?? 0.0) * (item['quantity'] ?? 1)).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              
              const Divider(),
              const SizedBox(height: 8),
              
              // Subtotal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal:', style: TextStyle(fontSize: 14)),
                  Text(
                    '₱${subtotal > 0 ? subtotal.toStringAsFixed(2) : (widget.totalAmount - shipping).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Shipping
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Shipping:', style: TextStyle(fontSize: 14)),
                  Text(
                    '₱${shipping.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              const Divider(),
              const SizedBox(height: 8),
            ],
            
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '₱${widget.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Payment Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildPaymentOption(
              PaymentMethod.gcash,
              'GCash',
              'Scan QR code with your GCash app',
              Icons.qr_code,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildPaymentOption(
              PaymentMethod.gotyme,
              'GoTyme Bank',
              'Scan QR code with your GoTyme app',
              Icons.account_balance,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildPaymentOption(
              PaymentMethod.metrobank,
              'Metrobank',
              'Use Metrobank online banking or app',
              Icons.account_balance,
              Colors.red,
            ),
            const SizedBox(height: 12),
            _buildPaymentOption(
              PaymentMethod.bpi,
              'BPI',
              'Scan QR code with your BPI app',
              Icons.account_balance,
              Colors.red.shade800,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(
    PaymentMethod method,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final isSelected = selectedPaymentMethod == method;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPaymentMethod = method;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? color.withOpacity(0.1) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCodeDisplay() {
    final qrImages = {
      PaymentMethod.gcash: 'QR/Gcash.jpg',
      PaymentMethod.gotyme: 'QR/GoTyme.jpg',
      PaymentMethod.metrobank: 'QR/Metrobank.jpg',
      PaymentMethod.bpi: 'QR/BPI.png',
    };

    final paymentNames = {
      PaymentMethod.gcash: 'GCash',
      PaymentMethod.gotyme: 'GoTyme Bank',
      PaymentMethod.metrobank: 'Metrobank',
      PaymentMethod.bpi: 'BPI',
    };

    final accountInfo = {
      PaymentMethod.gcash: {
        'label': 'Phone number',
        'value': '***',
        'name': '***',
      },
      PaymentMethod.gotyme: {
        'label': 'Account number',
        'value': '***',
        'name': '***',
      },
      PaymentMethod.metrobank: {
        'label': 'Account number',
        'value': '***',
        'name': '***',
      },
      PaymentMethod.bpi: {
        'label': 'Account number',
        'value': '***',
        'name': '***',
      },
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Scan QR Code for ${paymentNames[selectedPaymentMethod]}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Image.asset(
                qrImages[selectedPaymentMethod]!,
                width: 250,
                height: 250,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 250,
                    height: 250,
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.qr_code,
                      size: 80,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            
            // Account Information Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Text(
                    'Account Information',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${accountInfo[selectedPaymentMethod]!['label']}:',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      Text(
                        accountInfo[selectedPaymentMethod]!['value']!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Account name:',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      Text(
                        accountInfo[selectedPaymentMethod]!['name']!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            Text(
              'Amount to Pay: ₱${widget.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInstructions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Instructions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              '1. Select Payment Method.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '2. Scan or Upload QR on your banking app.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '3. Pay exact amount.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '4. Click "Payment Sent" button below.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '5. Check email confirmation.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // Admin contact section removed as requested

  Widget _buildConfirmPaymentButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: selectedPaymentMethod != null && !isProcessing
            ? _handlePaymentConfirmation
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: isProcessing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Payment Sent',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  void _handlePaymentConfirmation() async {
    if (selectedPaymentMethod == null) return;

    setState(() {
      isProcessing = true;
    });

    try {
      // Here we would send email notification to admin
      await _sendAdminNotification();
      
      // Clear the cart after successful payment notification
      await CartService.clearCart();
      
      // Navigate to confirmation page
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PaymentConfirmationPage(
              orderId: widget.orderId,
              paymentMethod: selectedPaymentMethod!,
              amount: widget.totalAmount,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  Future<void> _sendAdminNotification() async {
    try {
      // Get customer info from orderDetails or current user
      final customerInfo = widget.orderDetails['customerInfo'] ?? 
                          widget.orderDetails['guestInfo'] ?? 
                          _getDefaultCustomerInfo();

      // Enhance customer info with complete details
      final enhancedCustomerInfo = {
        'name': customerInfo['name'] ?? 'Unknown Customer',
        'email': customerInfo['email'] ?? 'no-email@provided.com',
        'phone': customerInfo['phone'] ?? 'Not provided',
        'address': _formatCompleteAddress(),
        'isGuest': customerInfo['isGuest'] ?? true,
        'userType': customerInfo['isGuest'] == true ? 'Guest Customer' : 'Registered Customer',
      };

      // Send admin notification with comprehensive details
      await _sendAdminEmailUsingWorkingTemplate(enhancedCustomerInfo);

      // Send customer confirmation email
      await _sendCustomerConfirmation(enhancedCustomerInfo);

    } catch (e) {
      print('Error sending notifications: $e');
      rethrow;
    }
  }

  Future<void> _sendAdminEmailUsingWorkingTemplate(Map<String, dynamic> customerInfo) async {
    try {
      // Prepare order items in the correct format with enhanced details
      final orderItems = (widget.orderDetails['items'] as List<dynamic>?)
          ?.map((item) => {
            'name': '${item['name'] ?? 'Unknown Item'} (₱${((item['price'] ?? 0.0).toDouble()).toStringAsFixed(2)} each)',
            'quantity': item['quantity'] ?? 1,
            'price': (item['price'] ?? 0.0).toDouble(),
          }).toList() ?? [];

      // Get shipping address details
      final shippingAddress = widget.orderDetails['shippingAddress'] ?? 
                              widget.orderDetails['deliveryAddress'] ?? {};
      
      final fullAddress = _formatCompleteShippingAddress(shippingAddress);

      // Get payment method name
      final paymentMethodNames = {
        PaymentMethod.gcash: 'GCash',
        PaymentMethod.gotyme: 'GoTyme Bank',
        PaymentMethod.metrobank: 'Metrobank',
        PaymentMethod.bpi: 'BPI',
      };

      final paymentMethodName = paymentMethodNames[selectedPaymentMethod!] ?? 'Unknown';

      // Admin email with complete customer information formatted properly
      final adminSuccess = await EmailService.sendOrderConfirmationEmail(
        toEmail: 'annedfinds@gmail.com',
        customerName: 'AnneDFinds Admin - Payment Verification Required',
        orderId: '${widget.orderId} - PAYMENT NOTIFICATION',
        orderItems: orderItems,
        totalAmount: widget.totalAmount,
        paymentMethod: '''📋 PAYMENT NOTIFICATION - $paymentMethodName

🔔 PAYMENT SUBMITTED BY CUSTOMER - ADMIN ACTION REQUIRED

Customer Details:
• Full Name: ${customerInfo['name']}
• Email: ${customerInfo['email']}
• Phone: ${customerInfo['phone']}
• Type: ${customerInfo['userType']}

Please verify payment has been received and confirm with customer! 🎉''',
        deliveryAddress: {
          'fullName': '${customerInfo['name'] ?? 'Unknown Customer'}',
          'email': '${customerInfo['email'] ?? 'Not provided'}',
          'phone': '${customerInfo['phone'] ?? 'Not provided'}',
          'streetAddress': '${shippingAddress['streetAddress'] ?? shippingAddress['addressLine1'] ?? 'Not provided'}',
          'apartmentSuite': '${shippingAddress['apartmentSuite'] ?? ''}',
          'city': '${shippingAddress['city'] ?? 'Not provided'}',
          'province': '${shippingAddress['province'] ?? shippingAddress['state'] ?? 'Not provided'}',
          'postalCode': '${shippingAddress['postalCode'] ?? shippingAddress['zipCode'] ?? 'Not provided'}',
          'country': 'Philippines',
          'deliveryInstructions': '${shippingAddress['deliveryInstructions'] ?? ''}',
        },
        estimatedDelivery: DateTime.now().add(const Duration(days: 3)),
      );

      if (adminSuccess) {
        print('✅ Admin payment notification sent successfully with complete information');
      } else {
        throw Exception('Failed to send admin notification');
      }

    } catch (e) {
      print('❌ Error sending admin notification: $e');
      rethrow;
    }
  }

  String _formatCompleteShippingAddress(Map<String, dynamic> shippingAddress) {
    final parts = <String>[];
    
    if (shippingAddress['fullName']?.isNotEmpty == true) {
      parts.add('Name: ${shippingAddress['fullName']}');
    }
    if (shippingAddress['addressLine1']?.isNotEmpty == true) {
      parts.add('Address: ${shippingAddress['addressLine1']}');
    }
    if (shippingAddress['addressLine2']?.isNotEmpty == true) {
      parts.add('${shippingAddress['addressLine2']}');
    }
    if (shippingAddress['city']?.isNotEmpty == true) {
      parts.add('City: ${shippingAddress['city']}');
    }
    if (shippingAddress['province']?.isNotEmpty == true) {
      parts.add('Province: ${shippingAddress['province']}');
    }
    if (shippingAddress['postalCode']?.isNotEmpty == true) {
      parts.add('Postal Code: ${shippingAddress['postalCode']}');
    }
    if (shippingAddress['phoneNumber']?.isNotEmpty == true) {
      parts.add('Phone: ${shippingAddress['phoneNumber']}');
    }
    
    return parts.isNotEmpty ? parts.join('\n• ') : 'Address not provided';
  }

  Future<void> _sendCustomerConfirmation(Map<String, dynamic> customerInfo) async {
    try {
      final customerEmail = customerInfo['email'] as String;
      
      // Skip if no valid email
      if (customerEmail == 'no-email@provided.com' || 
          customerEmail.isEmpty || 
          !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(customerEmail)) {
        print('Skipping customer email - invalid email address: $customerEmail');
        return;
      }

      // Prepare order items in the correct format with enhanced details
      final orderItems = (widget.orderDetails['items'] as List<dynamic>?)
          ?.map((item) => {
            'name': '${item['name'] ?? 'Unknown Item'} - ₱${((item['price'] ?? 0.0).toDouble()).toStringAsFixed(2)} each',
            'quantity': item['quantity'] ?? 1,
            'price': (item['price'] ?? 0.0).toDouble(),
          }).toList() ?? [];

      // Get shipping address details
      final shippingAddress = widget.orderDetails['shippingAddress'] ?? 
                              widget.orderDetails['deliveryAddress'] ?? {};
      
      final fullAddress = _formatCompleteShippingAddress(shippingAddress);

      // Get payment method name
      final paymentMethodNames = {
        PaymentMethod.gcash: 'GCash',
        PaymentMethod.gotyme: 'GoTyme Bank',
        PaymentMethod.metrobank: 'Metrobank',
        PaymentMethod.bpi: 'BPI',
      };

      final paymentMethodName = paymentMethodNames[selectedPaymentMethod!] ?? 'Unknown';

      // Send customer confirmation email with standard order confirmation format
      // This will trigger one admin notification which is expected
      final customerSuccess = await EmailService.sendOrderConfirmationEmail(
        toEmail: customerEmail,
        customerName: customerInfo['name'] ?? 'Valued Customer',
        orderId: widget.orderId,
        orderItems: orderItems,
        totalAmount: widget.totalAmount,
        paymentMethod: '$paymentMethodName - Payment Submitted (Awaiting Admin Verification)',
        deliveryAddress: {
          'fullName': (customerInfo['name'] ?? '').toString(),
          'email': (customerInfo['email'] ?? '').toString(),
          'phone': (customerInfo['phone'] ?? '').toString(),
          'streetAddress': (shippingAddress['streetAddress'] ?? shippingAddress['addressLine1'] ?? '').toString(),
          'apartmentSuite': (shippingAddress['apartmentSuite'] ?? '').toString(),
          'city': (shippingAddress['city'] ?? '').toString(),
          'province': (shippingAddress['province'] ?? shippingAddress['state'] ?? '').toString(),
          'postalCode': (shippingAddress['postalCode'] ?? shippingAddress['zipCode'] ?? '').toString(),
          'country': 'Philippines',
          'deliveryInstructions': (shippingAddress['deliveryInstructions'] ?? '').toString(),
        },
        estimatedDelivery: DateTime.now().add(const Duration(days: 3)),
      );

      if (customerSuccess) {
        print('✅ Customer confirmation email sent successfully with complete information');
      } else {
        print('❌ Failed to send customer confirmation email');
      }

    } catch (e) {
      print('❌ Error sending customer confirmation: $e');
      // Don't rethrow - customer email failure shouldn't stop the flow
    }
  }

  Map<String, dynamic> _getDefaultCustomerInfo() {
    final currentUser = AuthService.currentUser;
    return {
      'name': currentUser?.name ?? 'Guest User',
      'email': currentUser?.email ?? 'no-email@provided.com',
      'phone': currentUser?.phoneNumber ?? 'Not provided',
      'isGuest': currentUser?.isGuest ?? true,
    };
  }

  String _formatCompleteAddress() {
    final shippingAddress = widget.orderDetails['shippingAddress'] ?? 
                            widget.orderDetails['deliveryAddress'] ?? {};
    
    final parts = <String>[];
    
    if (shippingAddress['addressLine1']?.isNotEmpty == true) {
      parts.add(shippingAddress['addressLine1']);
    }
    if (shippingAddress['addressLine2']?.isNotEmpty == true) {
      parts.add(shippingAddress['addressLine2']);
    }
    if (shippingAddress['city']?.isNotEmpty == true) {
      parts.add(shippingAddress['city']);
    }
    if (shippingAddress['province']?.isNotEmpty == true) {
      parts.add(shippingAddress['province']);
    }
    if (shippingAddress['postalCode']?.isNotEmpty == true) {
      parts.add(shippingAddress['postalCode']);
    }
    
    return parts.isNotEmpty ? parts.join(', ') : 'Address not provided';
  }

  // Admin contact helper functions removed as no longer needed
}

class PaymentConfirmationPage extends StatelessWidget {
  final String orderId;
  final PaymentMethod paymentMethod;
  final double amount;

  const PaymentConfirmationPage({
    super.key,
    required this.orderId,
    required this.paymentMethod,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final paymentNames = {
      PaymentMethod.gcash: 'GCash',
      PaymentMethod.gotyme: 'GoTyme Bank',
      PaymentMethod.metrobank: 'Metrobank',
      PaymentMethod.bpi: 'BPI',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Submitted'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 80,
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Notification Sent!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Payment notification sent to admin team and order confirmation sent to your email.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Order ID:'),
                        Text(orderId, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Payment Method:'),
                        Text(paymentNames[paymentMethod]!, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount:'),
                        Text('₱${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'What happens next?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              '• Admin will verify your payment\n'
              '• You will receive an email confirmation once verified\n'
              '• Your order will then be processed and shipped',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}