import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/cart_item.dart';
import '../../models/payment.dart';
import '../../models/order.dart';
import '../../services/payment_service.dart';
import '../../services/cart_service.dart';
import '../../services/notification_service.dart';
import '../../common/theme.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> cartItems;
  final double subtotal;
  final double shipping;
  final double total;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.subtotal,
    required this.shipping,
    required this.total,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  PaymentMethodType? selectedPaymentMethod;
  final _addressFormKey = GlobalKey<FormState>();
  final _gcashFormKey = GlobalKey<FormState>();
  
  // Address controllers
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalCodeController = TextEditingController();
  
  // GCash controllers
  final _gcashNumberController = TextEditingController();
  
  bool _isProcessing = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    _gcashNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Checkout',
          style: TextStyle(color: AppTheme.textPrimaryColor(context)),
        ),
        backgroundColor: AppTheme.backgroundColor(context),
        foregroundColor: AppTheme.textPrimaryColor(context),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderSummary(),
            const SizedBox(height: 24),
            _buildShippingAddress(),
            const SizedBox(height: 24),
            _buildPaymentMethods(),
            if (selectedPaymentMethod == PaymentMethodType.gcash) ...[
              const SizedBox(height: 16),
              _buildGCashForm(),
            ],
            const SizedBox(height: 32),
            _buildPlaceOrderButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.textSecondaryColor(context).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 12),
          ...widget.cartItems.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.productName} x${item.quantity}',
                    style: TextStyle(color: AppTheme.textPrimaryColor(context)),
                  ),
                ),
                Text(
                  PaymentService.formatCurrency(item.price * item.quantity),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ],
            ),
          )),
          Divider(color: AppTheme.textSecondaryColor(context).withOpacity(0.3)),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Subtotal:',
                  style: TextStyle(color: AppTheme.textPrimaryColor(context)),
                ),
              ),
              Text(
                PaymentService.formatCurrency(widget.subtotal),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Shipping:',
                  style: TextStyle(color: AppTheme.textPrimaryColor(context)),
                ),
              ),
              Text(
                PaymentService.formatCurrency(widget.shipping),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ],
          ),
          Divider(color: AppTheme.textSecondaryColor(context).withOpacity(0.3)),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
              Text(
                PaymentService.formatCurrency(widget.total),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShippingAddress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.textSecondaryColor(context).withOpacity(0.2),
        ),
      ),
      child: Form(
        key: _addressFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shipping Address',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _fullNameController,
              label: 'Full Name',
              validator: (value) => value?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              keyboardType: TextInputType.phone,
              validator: (value) => value?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _addressLine1Controller,
              label: 'Street Address',
              validator: (value) => value?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _addressLine2Controller,
              label: 'Apartment, Suite, etc. (Optional)',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _cityController,
                    label: 'City',
                    validator: (value) => value?.isEmpty == true ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _provinceController,
                    label: 'Province',
                    validator: (value) => value?.isEmpty == true ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _postalCodeController,
              label: 'Postal Code',
              keyboardType: TextInputType.number,
              validator: (value) => value?.isEmpty == true ? 'Required' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppTheme.textSecondaryColor(context).withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primaryOrange),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildPaymentMethods() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.textSecondaryColor(context).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 16),
          ...PaymentService.getAvailablePaymentMethods().map((method) {
            return _buildPaymentMethodTile(method);
          }),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodTile(PaymentMethodType method) {
    final isSelected = selectedPaymentMethod == method;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => selectedPaymentMethod = method),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppTheme.primaryOrange : AppTheme.textSecondaryColor(context).withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? AppTheme.primaryOrange.withOpacity(0.1) : null,
          ),
          child: Row(
            children: [
              Icon(
                _getPaymentMethodIcon(method),
                color: isSelected ? AppTheme.primaryOrange : AppTheme.textSecondaryColor(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getPaymentMethodTitle(method),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isSelected ? AppTheme.primaryOrange : AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    Text(
                      _getPaymentMethodDescription(method),
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.primaryOrange,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGCashForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.textSecondaryColor(context).withOpacity(0.2),
        ),
      ),
      child: Form(
        key: _gcashFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GCash Payment Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _gcashNumberController,
              label: 'GCash Mobile Number',
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value?.isEmpty == true) return 'Required';
                if (value!.length < 10) return 'Invalid mobile number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Instructions:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('1. Make sure you have sufficient GCash balance', style: TextStyle(color: AppTheme.textPrimaryColor(context))),
                  Text('2. Keep your phone nearby for SMS verification', style: TextStyle(color: AppTheme.textPrimaryColor(context))),
                  Text('3. Payment will be processed immediately', style: TextStyle(color: AppTheme.textPrimaryColor(context))),
                  const SizedBox(height: 8),
                  Text(
                    'Amount to pay: ${PaymentService.formatCurrency(widget.total)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceOrderButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: selectedPaymentMethod != null && !_isProcessing
            ? _placeOrder
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryOrange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isProcessing
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('Processing Payment...'),
                ],
              )
            : Text(
                'Place Order - ${PaymentService.formatCurrency(widget.total)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _placeOrder() async {
    if (!_addressFormKey.currentState!.validate()) return;
    if (selectedPaymentMethod == PaymentMethodType.gcash && 
        !_gcashFormKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      
      // Create shipping address
      final shippingAddress = ShippingAddress(
        fullName: _fullNameController.text,
        phoneNumber: _phoneController.text,
        addressLine1: _addressLine1Controller.text,
        addressLine2: _addressLine2Controller.text,
        city: _cityController.text,
        province: _provinceController.text,
        postalCode: _postalCodeController.text,
      );

      // Create order
      final orderId = 'ORD_${DateTime.now().millisecondsSinceEpoch}';
      final order = UserOrder(
        id: orderId,
        userId: user.uid,
        items: widget.cartItems.map((item) => OrderItem(
          productId: item.productId,
          productName: item.productName,
          productImage: item.imageUrl,
          price: item.price,
          quantity: item.quantity,
        )).toList(),
        subtotal: widget.subtotal,
        shippingFee: widget.shipping,
        total: widget.total,
        status: OrderStatus.pending,
        paymentMethod: selectedPaymentMethod!.toString().split('.').last,
        shippingAddress: shippingAddress.toMap(),
        createdAt: DateTime.now(),
      );

      // Save order
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .set(order.toFirestore());

      // Send order notification if NotificationService exists
      try {
        await NotificationService.sendOrderNotification(
          userId: user.uid,
          orderId: orderId,
          status: 'pending',
          orderTotal: PaymentService.formatCurrency(widget.total),
        );
      } catch (e) {
        // Notification service might not be implemented yet
        print('Notification error: $e');
      }

      // Create payment
      final paymentId = await PaymentService.createPayment(
        orderId: orderId,
        amount: widget.total,
        method: selectedPaymentMethod!,
      );

      // Process payment based on method
      bool paymentSuccess = false;
      
      if (selectedPaymentMethod == PaymentMethodType.gcash) {
        paymentSuccess = await PaymentService.processGCashPayment(
          paymentId: paymentId,
          gcashNumber: _gcashNumberController.text,
          amount: widget.total,
        );
      } else if (selectedPaymentMethod == PaymentMethodType.cod) {
        paymentSuccess = await PaymentService.processCODPayment(
          paymentId: paymentId,
          address: shippingAddress,
        );
      }

      if (paymentSuccess || selectedPaymentMethod == PaymentMethodType.cod) {
        // Clear cart
        await CartService.clearCart();
        
        // Update order status if payment completed
        if (selectedPaymentMethod == PaymentMethodType.gcash && paymentSuccess) {
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .update({'status': OrderStatus.confirmed.toString().split('.').last});
          
          try {
            await NotificationService.sendOrderNotification(
              userId: user.uid,
              orderId: orderId,
              status: 'confirmed',
              orderTotal: PaymentService.formatCurrency(widget.total),
            );
          } catch (e) {
            print('Notification error: $e');
          }
        }

        // Send admin notification if available
        try {
          await NotificationService.sendAdminNotification(
            type: 'new_order',
            data: {
              'orderId': orderId,
              'total': PaymentService.formatCurrency(widget.total),
              'customerName': _fullNameController.text,
              'itemCount': widget.cartItems.length,
              'paymentMethod': _getPaymentMethodTitle(selectedPaymentMethod!),
            },
          );
        } catch (e) {
          print('Admin notification error: $e');
        }

        // Show success and navigate
        if (mounted) {
          Navigator.of(context).pop(); // Close checkout
          Navigator.of(context).pop(); // Go back to cart
          _showSuccessDialog(orderId);
        }
      } else {
        _showErrorDialog('Payment failed. Please try again.');
      }
    } catch (e) {
      _showErrorDialog('Order failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSuccessDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        icon: const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 64,
        ),
        title: Text(
          'Order Placed Successfully!',
          style: TextStyle(color: AppTheme.textPrimaryColor(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your order #${orderId.substring(0, 8).toUpperCase()} has been placed.',
              style: TextStyle(color: AppTheme.textPrimaryColor(context)),
            ),
            const SizedBox(height: 8),
            if (selectedPaymentMethod == PaymentMethodType.gcash)
              Text(
                'Payment has been processed via GCash.',
                style: TextStyle(color: AppTheme.textPrimaryColor(context)),
              )
            else if (selectedPaymentMethod == PaymentMethodType.cod)
              Text(
                'You will pay cash upon delivery.',
                style: TextStyle(color: AppTheme.textPrimaryColor(context)),
              ),
            const SizedBox(height: 8),
            Text(
              '📱 You\'ll receive notifications about your order status.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context)),
            ),
            const SizedBox(height: 12),
            Text(
              'Redirecting to home in 3 seconds...',
              style: TextStyle(
                fontSize: 12, 
                color: AppTheme.textSecondaryColor(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              // Navigate to home screen automatically
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue Shopping'),
          ),
        ],
      ),
    );

    // Auto-close dialog and redirect after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // Close dialog
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        icon: const Icon(
          Icons.error,
          color: Colors.red,
          size: 64,
        ),
        title: Text(
          'Order Failed',
          style: TextStyle(color: AppTheme.textPrimaryColor(context)),
        ),
        content: Text(
          message,
          style: TextStyle(color: AppTheme.textPrimaryColor(context)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  IconData _getPaymentMethodIcon(PaymentMethodType method) {
    switch (method) {
      case PaymentMethodType.gcash:
        return Icons.phone_android;
      case PaymentMethodType.cod:
        return Icons.money;
      case PaymentMethodType.bankTransfer:
        return Icons.account_balance;
      case PaymentMethodType.paypal:
        return Icons.paypal;
      case PaymentMethodType.creditCard:
        return Icons.credit_card;
    }
  }

  String _getPaymentMethodTitle(PaymentMethodType method) {
    switch (method) {
      case PaymentMethodType.gcash:
        return 'GCash';
      case PaymentMethodType.cod:
        return 'Cash on Delivery';
      case PaymentMethodType.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethodType.paypal:
        return 'PayPal';
      case PaymentMethodType.creditCard:
        return 'Credit Card';
    }
  }

  String _getPaymentMethodDescription(PaymentMethodType method) {
    switch (method) {
      case PaymentMethodType.gcash:
        return 'Pay instantly using your GCash wallet';
      case PaymentMethodType.cod:
        return 'Pay with cash when your order is delivered';
      case PaymentMethodType.bankTransfer:
        return 'Transfer payment directly to our bank account';
      case PaymentMethodType.paypal:
        return 'Pay securely with your PayPal account';
      case PaymentMethodType.creditCard:
        return 'Pay with your credit or debit card';
    }
  }
}