import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:typed_data';
// Conditional import for platform-specific download functionality
import '../../web_utils.dart' if (dart.library.io) '../../mobile_utils.dart';
import '../../common/theme.dart';
import '../../common/mobile_layout_utils.dart';
import '../../services/email_service.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../services/payment_service.dart';
import '../../models/order.dart';
import '../../models/payment.dart';

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
  PaymentMethod? expandedQRMethod;
  bool isProcessing = false;

  @override
  Widget build(BuildContext context) {
    // ULTRA DEBUG: Multiple logging approaches to ensure visibility
    debugPrint('🎯 DEBUG - QR Payment Screen Initialized:');
    debugPrint('💰 Total Amount: ${widget.totalAmount}');
    debugPrint('🆔 Order ID: ${widget.orderId}');
    debugPrint('📦 OrderDetails Keys: ${widget.orderDetails.keys.toList()}');
    debugPrint('📋 Items in OrderDetails: ${widget.orderDetails['items']?.length ?? 0}');
    
    // Log each item in detail
    final items = widget.orderDetails['items'] as List<dynamic>? ?? [];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      debugPrint('🔍 QR PAYMENT ITEM $i:');
      debugPrint('  - Name: ${item['name']}');
      debugPrint('  - Variant SKU: ${item['variantSku']}');
      debugPrint('  - Variant Display Name: ${item['variantDisplayName']}');
      debugPrint('  - Selected Options: ${item['selectedOptions']}');
      debugPrint('  - Quantity: ${item['quantity']}');
      debugPrint('  - Price: ${item['price']}');
    }
    
    debugPrint('🚨 QR PAYMENT SCREEN BUILD METHOD EXECUTED - CODE IS RUNNING!');
    
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
            _buildPaymentInstructions(),
            const SizedBox(height: 24),
            _buildPaymentMethodSelection(),
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
    final shipping = widget.orderDetails['shipping'] as double? ?? 49.0; // Fallback shipping updated to match your settings
    
    // DEBUG: Log order details to console
    debugPrint('🔍 DEBUG - QR Payment Order Details:');
    debugPrint('📦 Total items: ${items.length}');
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      debugPrint('📋 Item $i:');
      debugPrint('  - Name: ${item['name']}');
      debugPrint('  - Quantity: ${item['quantity']}');
      debugPrint('  - Price: ${item['price']}');
      debugPrint('  - Variant SKU: ${item['variantSku']}');
      debugPrint('  - Variant Display Name: ${item['variantDisplayName']}');
      debugPrint('  - Selected Options: ${item['selectedOptions']}');
    }
    
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
                _buildPaymentOrderItem(item),
                const SizedBox(height: 12),
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
    final isExpanded = expandedQRMethod == method;
    final isSelected = selectedPaymentMethod == method;
    
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              // Toggle QR display for this method
              if (expandedQRMethod == method) {
                expandedQRMethod = null;
                selectedPaymentMethod = null;
              } else {
                expandedQRMethod = method;
                selectedPaymentMethod = method;
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: isExpanded ? color : Colors.grey[300]!,
                width: isExpanded ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              color: isExpanded ? color.withValues(alpha: 0.1) : null,
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
                          color: isExpanded ? color : null,
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
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: isExpanded ? color : Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
        
        // Inline QR Display
        if (isExpanded) _buildInlineQRDisplay(method, color),
      ],
    );
  }

  Widget _buildInlineQRDisplay(PaymentMethod method, Color color) {
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

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Text(
            'Scan QR Code for ${paymentNames[method]}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.3),
                  spreadRadius: 1,
                  blurRadius: 3,
                ),
              ],
            ),
            child: Image.asset(
              qrImages[method]!,
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey[200],
                  child: const Icon(
                    Icons.qr_code,
                    size: 60,
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
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  'Account Information',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${accountInfo[method]!['label']}:',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    Text(
                      accountInfo[method]!['value']!,
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
                      accountInfo[method]!['name']!,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Download QR Code Button (Web only)
          if (kIsWeb)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              child: OutlinedButton.icon(
                onPressed: () => _downloadQRCode(method),
                icon: Icon(
                  Icons.download,
                  size: 18,
                  color: color,
                ),
                label: Text(
                  'Save QR Code',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          
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

    bool orderCreated = false;
    bool emailSent = false;
    bool cartCleared = false;

    try {
      debugPrint('🚀 Starting payment confirmation process for order: ${widget.orderId}');
      
      // Step 1: Create order from stored checkout data
      debugPrint('📝 Step 1: Creating order...');
      await _createOrderFromCheckoutData();
      orderCreated = true;
      debugPrint('✅ Order created successfully');
      
      // Step 2: Send email notification to admin
      debugPrint('📧 Step 2: Sending email notifications...');
      await _sendAdminNotification();
      emailSent = true;
      debugPrint('✅ Email notifications sent successfully');
      
      // Step 3: Clear only selected items from cart
      debugPrint('🗑️ Step 3: Clearing selected items from cart...');
      try {
        await _clearSelectedItemsFromCart();
        cartCleared = true;
        debugPrint('✅ Cart clearing completed successfully');
        
        // Step 4: Clear saved cart selections only if cart clearing succeeded
        debugPrint('🧹 Step 4: Clearing saved cart selections...');
        await _clearSavedCartSelections();
        debugPrint('✅ Cart selections cleared successfully');
        
      } catch (cartError) {
        debugPrint('❌ Cart clearing failed: $cartError');
        
        // Preserve unselected items for user recovery
        await _preserveUnselectedItemsInCart();
        
        // Show specific error message about cart clearing
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('⚠️ Order created successfully but cart clearing failed'),
                  Text('You may need to manually remove items from your cart'),
                  Text('Order ID: ${widget.orderId}'),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 8),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      }
      
      debugPrint('🎉 Payment confirmation process completed');
      debugPrint('📊 Status - Order: $orderCreated, Email: $emailSent, Cart: $cartCleared');
      
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
      debugPrint('❌ CRITICAL ERROR in payment confirmation: $e');
      
      String errorMessage;
      Color backgroundColor;
      
      if (!orderCreated) {
        errorMessage = 'Order creation failed: $e';
        backgroundColor = Colors.red;
      } else if (!emailSent) {
        errorMessage = 'Order created but email notification failed: $e';
        backgroundColor = Colors.orange;
      } else {
        errorMessage = 'Error in payment processing: $e';
        backgroundColor = Colors.red;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: backgroundColor,
            duration: Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
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

  Future<void> _createOrderFromCheckoutData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final checkoutDataJson = prefs.getString('checkout_data_${widget.orderId}');
      
      if (checkoutDataJson == null) {
        throw Exception('Checkout data not found for order ${widget.orderId}');
      }
      
      final checkoutData = jsonDecode(checkoutDataJson) as Map<String, dynamic>;
      
      // Convert stored cart items back to OrderItem objects
      final orderItems = (checkoutData['cartItems'] as List<dynamic>).map((item) => OrderItem(
        productId: item['productId'] ?? '',
        productName: item['productName'] ?? '',
        productImage: item['productImage'] ?? '',
        price: (item['price'] ?? 0).toDouble(),
        quantity: item['quantity'] ?? 0,
        selectedVariantId: item['selectedVariantId'],
        selectedOptions: item['selectedOptions'] != null 
            ? Map<String, String>.from(item['selectedOptions']) 
            : null,
        variantSku: item['variantSku'],
        variantDisplayName: item['variantDisplayName'],
      )).toList();
      
      // Create UserOrder from stored data
      final order = UserOrder(
        id: checkoutData['orderId'],
        userId: checkoutData['userId'],
        items: orderItems,
        subtotal: (checkoutData['subtotal'] ?? 0).toDouble(),
        shippingFee: (checkoutData['shippingFee'] ?? 0).toDouble(),
        total: (checkoutData['total'] ?? 0).toDouble(),
        status: OrderStatus.pending,
        paymentMethod: _getPaymentMethodString(selectedPaymentMethod!),
        shippingAddress: Map<String, dynamic>.from(checkoutData['shippingAddress']),
        createdAt: DateTime.parse(checkoutData['createdAt']),
      );
      
      // Save order to Firestore
      debugPrint('🔍 Creating order ${order.id} in Firestore...');
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .set(order.toFirestore());
      
      // Create payment record
      await PaymentService.createPayment(
        orderId: order.id,
        amount: order.total,
        method: _getPaymentMethodType(selectedPaymentMethod!),
      );
      
      // Clean up stored checkout data
      await prefs.remove('checkout_data_${widget.orderId}');
      
      debugPrint('✅ Order ${order.id} created successfully');
    } catch (e) {
      debugPrint('❌ Error creating order from checkout data: $e');
      rethrow;
    }
  }

  Future<void> _clearSelectedItemsFromCart() async {
    debugPrint('🚀 Starting cart clearing process for order: ${widget.orderId}');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Try primary checkout data first
      String? checkoutDataJson = prefs.getString('checkout_data_${widget.orderId}');
      String dataSource = 'primary';
      
      // Try backup data if primary is missing
      if (checkoutDataJson == null) {
        debugPrint('⚠️ Primary checkout data not found, trying backup...');
        checkoutDataJson = prefs.getString('checkout_backup_${widget.orderId}');
        dataSource = 'backup';
      }
      
      // If still no data, try to create fallback from order details
      if (checkoutDataJson == null) {
        debugPrint('⚠️ Backup checkout data not found, attempting fallback cart clearing...');
        await _fallbackCartClearingFromOrderDetails();
        return;
      }

      debugPrint('✅ Found checkout data from $dataSource source');
      
      final checkoutData = jsonDecode(checkoutDataJson) as Map<String, dynamic>;
      final cartItems = checkoutData['cartItems'] as List<dynamic>;
      
      debugPrint('🛒 Found ${cartItems.length} items to remove from cart');
      debugPrint('📊 Checkout data timestamp: ${checkoutData['storageTimestamp'] ?? 'unknown'}');
      
      // Collect all cart keys to remove
      List<String> cartKeysToRemove = [];
      for (int i = 0; i < cartItems.length; i++) {
        final item = cartItems[i];
        
        // Use stored cart key if available, otherwise generate it
        String cartKey;
        if (item['cartKey'] != null && item['cartKey'].isNotEmpty) {
          cartKey = item['cartKey'];
          debugPrint('🔍 [$i] Using stored cart key: $cartKey');
        } else {
          // Fallback to generating cart key (for backwards compatibility)
          final productId = item['productId'];
          final variantId = item['selectedVariantId'];
          cartKey = variantId != null && variantId.isNotEmpty 
              ? '${productId}_$variantId' 
              : productId;
          debugPrint('🔍 [$i] Generated cart key (fallback): $cartKey');
        }
        
        cartKeysToRemove.add(cartKey);
        debugPrint('📝 [$i] Added to removal list: ${item['productName']} (key: $cartKey)');
      }
      
      // Use the optimized cart clearing method that handles both auth states
      debugPrint('🗑️ Removing ${cartKeysToRemove.length} items using optimized cart clearing...');
      await CartService.clearSelectedItemsAfterCheckout(cartKeysToRemove);
      
      // Clean up stored checkout data after successful clearing
      await _cleanupCheckoutData();
      
      debugPrint('🎉 All selected items successfully cleared from cart');
      
    } catch (e) {
      debugPrint('❌ CRITICAL ERROR in cart clearing process: $e');
      // Try alternative clearing methods before giving up
      await _emergencyCartClearingFallback();
    }
  }

  Future<void> _fallbackCartClearingFromOrderDetails() async {
    debugPrint('🆘 Attempting fallback cart clearing using order details...');
    
    // This is a fallback method that tries to clear cart based on what we know
    // about the order that was just created. This should only be used when 
    // checkout data is completely missing.
    
    // For now, we'll create a user notification that manual cart clearing may be needed
    debugPrint('⚠️ Fallback cart clearing not yet implemented - user may need to manually clear cart');
    
    // TODO: Implement fallback logic based on order details stored elsewhere
    // This could involve querying the created order from Firestore and using that data
  }

  Future<void> _emergencyCartClearingFallback() async {
    debugPrint('🚨 Emergency cart clearing fallback triggered');
    
    // This is a last resort - we'll show an error to the user and provide
    // guidance on manual cart management
    debugPrint('🚨 Cart clearing failed completely - user notification required');
    
    // Set a flag that can be used to show user notification
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cart_clearing_failed_${widget.orderId}', true);
    
    throw Exception('Cart clearing failed - order created successfully but cart items may need to be manually removed');
  }

  Future<void> _cleanupCheckoutData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('checkout_data_${widget.orderId}');
      await prefs.remove('checkout_backup_${widget.orderId}');
      debugPrint('🧹 Cleanup: Removed checkout data for order ${widget.orderId}');
    } catch (e) {
      debugPrint('⚠️ Error cleaning up checkout data: $e');
      // Not critical - data will eventually be cleaned up
    }
  }

  Future<void> _clearSavedCartSelections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // IMPORTANT: Only clear selections if cart clearing was successful
      // Check if there's a cart clearing failure flag first
      final cartClearingFailed = prefs.getBool('cart_clearing_failed_${widget.orderId}') ?? false;
      
      if (cartClearingFailed) {
        debugPrint('⚠️ Cart clearing failed - preserving selection state for user recovery');
        return;
      }
      
      await prefs.remove('cart_selections');
      debugPrint('✅ Saved cart selections cleared after successful cart clearing');
    } catch (e) {
      debugPrint('❌ Error clearing saved cart selections: $e');
      // Don't rethrow - this failure shouldn't stop the order process
    }
  }

  Future<void> _preserveUnselectedItemsInCart() async {
    debugPrint('🔄 Preserving unselected items in cart after partial checkout');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get the original cart selections
      final savedSelectionsJson = prefs.getString('cart_selections');
      if (savedSelectionsJson == null) {
        debugPrint('⚠️ No saved selections found - cannot preserve unselected items');
        return;
      }
      
      final originalSelections = jsonDecode(savedSelectionsJson) as List<dynamic>;
      final selectedItems = originalSelections.cast<String>().toSet();
      
      debugPrint('📋 Original selections: ${selectedItems.toList()}');
      
      // Get current cart items to determine what should remain unselected
      // This would require accessing the cart service to get current items
      // and then updating the selection state to preserve unselected items
      
      // For now, we'll store the information that selections should be restored
      await prefs.setString('preserve_cart_selections_${widget.orderId}', savedSelectionsJson);
      debugPrint('💾 Stored cart selections for preservation after failed clearing');
      
    } catch (e) {
      debugPrint('❌ Error preserving unselected items: $e');
    }
  }

  String _getPaymentMethodString(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.gcash:
        return 'gcash';
      case PaymentMethod.gotyme:
        return 'gotyme';
      case PaymentMethod.metrobank:
        return 'metrobank';
      case PaymentMethod.bpi:
        return 'bpi';
    }
  }

  PaymentMethodType _getPaymentMethodType(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.gcash:
        return PaymentMethodType.gcash;
      case PaymentMethod.gotyme:
        return PaymentMethodType.gotyme;
      case PaymentMethod.metrobank:
        return PaymentMethodType.metrobank;
      case PaymentMethod.bpi:
        return PaymentMethodType.bpi;
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
      debugPrint('Error sending notifications: $e');
      rethrow;
    }
  }

  Future<void> _sendAdminEmailUsingWorkingTemplate(Map<String, dynamic> customerInfo) async {
    try {
      // Prepare order items in the correct format with enhanced details
      final orderItems = (widget.orderDetails['items'] as List<dynamic>?)
          ?.map((item) => {
            'name': () {
              // Build enhanced product name with variant info for email
              String productName = item['name'] ?? 'Unknown Item';
              
              // Add variant display name if available
              if (item['variantDisplayName'] != null && item['variantDisplayName'].toString().isNotEmpty) {
                productName = '$productName - ${item['variantDisplayName']}';
              }
              
              // Add SKU if available
              if (item['variantSku'] != null && item['variantSku'].toString().isNotEmpty) {
                productName = '$productName (SKU: ${item['variantSku']})';
              }
              
              // Add price information
              return '$productName (₱${((item['price'] ?? 0.0).toDouble()).toStringAsFixed(2)} each)';
            }(),
            'quantity': item['quantity'] ?? 1,
            'price': (item['price'] ?? 0.0).toDouble(),
            'variantSku': item['variantSku'],
            'variantDisplayName': item['variantDisplayName'],
            'selectedOptions': item['selectedOptions'],
          }).toList() ?? [];

      // ULTRA DEBUG: Admin email data with maximum visibility
      debugPrint('🚨🚨🚨 ADMIN EMAIL METHOD EXECUTING 🚨🚨🚨');
      debugPrint('📧 DEBUG - Admin Email Data:');
      debugPrint('📦 Admin Order Items Count: ${orderItems.length}');
      for (int i = 0; i < orderItems.length; i++) {
        final item = orderItems[i];
        debugPrint('🔥 ADMIN EMAIL ITEM $i:');
        debugPrint('  - FINAL NAME: ${item['name']}');
        debugPrint('  - RAW VARIANT SKU: ${item['variantSku']}');
        debugPrint('  - RAW VARIANT DISPLAY NAME: ${item['variantDisplayName']}');
        debugPrint('  - RAW SELECTED OPTIONS: ${item['selectedOptions']}');
        debugPrint('  - QUANTITY: ${item['quantity']}');
        debugPrint('  - PRICE: ${item['price']}');
      }
      debugPrint('🚨 ADMIN EMAIL DATA PREPARED - SENDING TO EMAIL SERVICE 🚨');

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
        skipAdminNotification: true, // Prevent duplicate admin notification
      );

      if (adminSuccess) {
        debugPrint('✅ Admin payment notification sent successfully with complete information');
      } else {
        throw Exception('Failed to send admin notification');
      }

    } catch (e) {
      debugPrint('❌ Error sending admin notification: $e');
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
        debugPrint('Skipping customer email - invalid email address: $customerEmail');
        return;
      }

      // Prepare order items in the correct format with enhanced details
      final orderItems = (widget.orderDetails['items'] as List<dynamic>?)
          ?.map((item) => {
            'name': () {
              // Build enhanced product name with variant info for email
              String productName = item['name'] ?? 'Unknown Item';
              
              // Add variant display name if available
              if (item['variantDisplayName'] != null && item['variantDisplayName'].toString().isNotEmpty) {
                productName = '$productName - ${item['variantDisplayName']}';
              }
              
              // Add SKU if available
              if (item['variantSku'] != null && item['variantSku'].toString().isNotEmpty) {
                productName = '$productName (SKU: ${item['variantSku']})';
              }
              
              // Add price information
              return '$productName - ₱${((item['price'] ?? 0.0).toDouble()).toStringAsFixed(2)} each';
            }(),
            'quantity': item['quantity'] ?? 1,
            'price': (item['price'] ?? 0.0).toDouble(),
            'variantSku': item['variantSku'],
            'variantDisplayName': item['variantDisplayName'],
            'selectedOptions': item['selectedOptions'],
          }).toList() ?? [];

      // ULTRA DEBUG: Customer email data with maximum visibility  
      debugPrint('🚨🚨🚨 CUSTOMER EMAIL METHOD EXECUTING 🚨🚨🚨');
      debugPrint('📧 DEBUG - Customer Email Data:');
      debugPrint('📦 Customer Order Items Count: ${orderItems.length}');
      for (int i = 0; i < orderItems.length; i++) {
        final item = orderItems[i];
        debugPrint('🔥 CUSTOMER EMAIL ITEM $i:');
        debugPrint('  - FINAL NAME: ${item['name']}');
        debugPrint('  - RAW VARIANT SKU: ${item['variantSku']}');
        debugPrint('  - RAW VARIANT DISPLAY NAME: ${item['variantDisplayName']}');
        debugPrint('  - RAW SELECTED OPTIONS: ${item['selectedOptions']}');
        debugPrint('  - QUANTITY: ${item['quantity']}');
        debugPrint('  - PRICE: ${item['price']}');
      }
      debugPrint('🚨 CUSTOMER EMAIL DATA PREPARED - SENDING TO EMAIL SERVICE 🚨');

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
        debugPrint('✅ Customer confirmation email sent successfully with complete information');
      } else {
        debugPrint('❌ Failed to send customer confirmation email');
      }

    } catch (e) {
      debugPrint('❌ Error sending customer confirmation: $e');
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

  Widget _buildPaymentOrderItem(dynamic item) {
    // Enhanced variant display logic
    final hasVariantDisplayName = item['variantDisplayName'] != null && item['variantDisplayName'].toString().isNotEmpty;
    final hasVariantSku = item['variantSku'] != null && item['variantSku'].toString().isNotEmpty;
    final hasSelectedOptions = item['selectedOptions'] != null && (item['selectedOptions'] as Map).isNotEmpty;
    
    // Build product name - use base name only to avoid duplication
    String displayName = item['name'] ?? 'Unknown Item';
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: (hasVariantDisplayName || hasVariantSku || hasSelectedOptions) ? AppTheme.primaryOrange : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(left: (hasVariantDisplayName || hasVariantSku || hasSelectedOptions) ? 12 : 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name (base name only)
                  Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: (hasVariantDisplayName || hasVariantSku || hasSelectedOptions) ? AppTheme.primaryOrange : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Show either variant display name OR selected options (not both to avoid duplication)
                  if (hasVariantDisplayName)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primaryOrange.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        item['variantDisplayName'],
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else if (hasSelectedOptions)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: _buildPaymentVariantDisplay(
                        Map<String, String>.from(item['selectedOptions']),
                      ),
                    ),
                  
                  // Enhanced SKU Display
                  if (hasVariantSku)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'SKU: ${item['variantSku']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  
                  // Fallback message when no variant data
                  if (!hasVariantDisplayName && !hasVariantSku && !hasSelectedOptions)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Standard product (no variants)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Quantity
            Text(
              'Qty: ${item['quantity'] ?? 1}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 16),
            
            // Price
            Text(
              '₱${((item['price'] ?? 0.0) * (item['quantity'] ?? 1)).toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentVariantDisplay(Map<String, String> options) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: options.entries.map((entry) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              entry.value,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Download QR Code functionality for web platform
  Future<void> _downloadQRCode(PaymentMethod method) async {
    if (!kIsWeb) {
      // Only available on web platform
      return;
    }

    try {
      // Map payment methods to their asset paths and file extensions
      final qrAssets = {
        PaymentMethod.gcash: {'path': 'QR/Gcash.jpg', 'ext': 'jpg'},
        PaymentMethod.gotyme: {'path': 'QR/GoTyme.jpg', 'ext': 'jpg'},
        PaymentMethod.metrobank: {'path': 'QR/Metrobank.jpg', 'ext': 'jpg'},
        PaymentMethod.bpi: {'path': 'QR/BPI.png', 'ext': 'png'},
      };

      final paymentNames = {
        PaymentMethod.gcash: 'GCash',
        PaymentMethod.gotyme: 'GoTyme_Bank',
        PaymentMethod.metrobank: 'Metrobank',
        PaymentMethod.bpi: 'BPI',
      };

      final assetInfo = qrAssets[method]!;
      final paymentName = paymentNames[method]!;
      
      // Load the asset as bytes
      final ByteData data = await rootBundle.load(assetInfo['path']!);
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Create filename with branding
      final filename = '${paymentName}_QR_AnnedFinds.${assetInfo['ext']}';
      
      // Create download using platform-specific implementation
      if (kIsWeb) {
        downloadFile(bytes, filename);
      } else {
        // For mobile platforms, show a message that file download is not supported
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR code download is only available on web'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      
      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR code saved as $filename'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download QR code: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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