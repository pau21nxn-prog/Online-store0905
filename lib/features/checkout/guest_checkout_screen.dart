import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/cart_service.dart';
import '../../services/auth_service.dart';
import '../../services/email_service.dart';
import '../../common/theme.dart';

class GuestCheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double totalAmount;

  const GuestCheckoutScreen({
    super.key,
    required this.cartItems,
    required this.totalAmount,
  });

  @override
  State<GuestCheckoutScreen> createState() => _GuestCheckoutScreenState();
}

class _GuestCheckoutScreenState extends State<GuestCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  
  // Payment specific controllers
  final _gcashNumberController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  
  bool _isProcessing = false;
  String _selectedPaymentMethod = 'gcash';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _gcashNumberController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guest Checkout'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryOrange),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Processing your payment...',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Sending email confirmation...',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Summary
                    _buildOrderSummary(),
                    
                    const SizedBox(height: 24),
                    
                    // Email Notice
                    _buildEmailNotice(),
                    
                    const SizedBox(height: 24),
                    
                    // Contact Information
                    _buildSectionTitle('Contact Information'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name *',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your full name';
                        }
                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email Address *',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email address is required for order confirmation';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number *',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (value.length < 10) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Delivery Address
                    _buildSectionTitle('Delivery Address'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _addressController,
                      label: 'Street Address *',
                      icon: Icons.location_on,
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your address';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            controller: _cityController,
                            label: 'City *',
                            icon: Icons.location_city,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your city';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _postalCodeController,
                            label: 'Postal Code *',
                            icon: Icons.markunread_mailbox,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter postal code';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Payment Method
                    _buildSectionTitle('Payment Method'),
                    const SizedBox(height: 12),
                    _buildPaymentMethods(),
                    
                    // Payment Details Form
                    if (_selectedPaymentMethod != 'gcash') ...[
                      const SizedBox(height: 16),
                      _buildPaymentDetailsForm(),
                    ],
                    
                    const SizedBox(height: 32),
                    
                    // Place Order Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _placeOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Pay Now - ₱${widget.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Terms and Privacy
                    Text(
                      'By placing this order, you agree to our Terms of Service and Privacy Policy. '
                      'Your payment will be processed securely and an email confirmation will be sent to your provided email address.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmailNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.email_outlined,
              color: AppTheme.primaryOrange,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email Confirmation Required',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'We will send your order details and tracking information via email. Please ensure your email address is correct.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...widget.cartItems.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${item['name']} x${item['quantity']}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                Text(
                  '₱${((item['price'] ?? 0.0) * (item['quantity'] ?? 1)).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )).toList(),
          const Divider(),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '₱${widget.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryOrange),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryOrange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      children: [
        RadioListTile<String>(
          value: 'gcash',
          groupValue: _selectedPaymentMethod,
          onChanged: (value) {
            setState(() {
              _selectedPaymentMethod = value!;
            });
          },
          title: const Row(
            children: [
              Icon(Icons.phone_android, color: AppTheme.primaryOrange),
              SizedBox(width: 12),
              Text('GCash'),
            ],
          ),
          subtitle: const Text('Pay via GCash mobile wallet'),
          activeColor: AppTheme.primaryOrange,
        ),
        RadioListTile<String>(
          value: 'bank',
          groupValue: _selectedPaymentMethod,
          onChanged: (value) {
            setState(() {
              _selectedPaymentMethod = value!;
            });
          },
          title: const Row(
            children: [
              Icon(Icons.account_balance, color: AppTheme.primaryOrange),
              SizedBox(width: 12),
              Text('Bank Transfer'),
            ],
          ),
          subtitle: const Text('Direct bank account transfer'),
          activeColor: AppTheme.primaryOrange,
        ),
        RadioListTile<String>(
          value: 'card',
          groupValue: _selectedPaymentMethod,
          onChanged: (value) {
            setState(() {
              _selectedPaymentMethod = value!;
            });
          },
          title: const Row(
            children: [
              Icon(Icons.credit_card, color: AppTheme.primaryOrange),
              SizedBox(width: 12),
              Text('Credit/Debit Card'),
            ],
          ),
          subtitle: const Text('Visa, Mastercard, and other major cards'),
          activeColor: AppTheme.primaryOrange,
        ),
      ],
    );
  }

  Widget _buildPaymentDetailsForm() {
    switch (_selectedPaymentMethod) {
      case 'gcash':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GCash Payment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('You will be redirected to GCash to complete your payment.'),
            ],
          ),
        );

      case 'bank':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bank Transfer Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _accountNameController,
                label: 'Account Holder Name *',
                icon: Icons.person,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter account holder name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _accountNumberController,
                label: 'Bank Account Number *',
                icon: Icons.account_balance,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your bank account number';
                  }
                  if (value.length < 10) {
                    return 'Please enter a valid account number';
                  }
                  return null;
                },
              ),
            ],
          ),
        );

      case 'card':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Card Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _cardNumberController,
                label: 'Card Number *',
                icon: Icons.credit_card,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your card number';
                  }
                  if (value.replaceAll(' ', '').length < 16) {
                    return 'Please enter a valid card number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _expiryController,
                      label: 'MM/YY *',
                      icon: Icons.date_range,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        if (!RegExp(r'^(0[1-9]|1[0-2])\/[0-9]{2}$').hasMatch(value)) {
                          return 'Invalid format';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _cvvController,
                      label: 'CVV *',
                      icon: Icons.lock,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        if (value.length < 3) {
                          return 'Invalid CVV';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Step 1: Process payment first
      await _processPayment();
      
      // Step 2: Create anonymous user AFTER successful payment
      final anonymousUser = await AuthService.createAnonymousUserAfterPayment(
        guestEmail: _emailController.text.trim(),
        guestName: _nameController.text.trim(),
        guestPhone: _phoneController.text.trim(),
      );

      if (anonymousUser == null) {
        throw Exception('Failed to create guest account');
      }

      // Step 3: Save cart to Firebase for the new anonymous user
      await CartService.saveCartToFirebaseAfterPayment(anonymousUser.id);
      
      // Step 4: Create order with the new anonymous user
      final orderId = await _createOrder(anonymousUser.id);
      
      // Step 5: Send email confirmation
      await _sendEmailConfirmation(orderId);
      
      // Step 6: Clear cart
      await CartService.clearCart();
      
      // Step 7: Show success and navigate
      if (mounted) {
        _showSuccessDialog(orderId);
      }
      
    } catch (e) {
      print('Error placing order: $e');
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processPayment() async {
    // Simulate payment processing based on selected method
    await Future.delayed(const Duration(seconds: 3));
    
    switch (_selectedPaymentMethod) {
      case 'gcash':
        // In real implementation, integrate with GCash API
        break;
      case 'bank':
        // In real implementation, verify bank transfer details
        break;
      case 'card':
        // In real implementation, process card payment via payment gateway
        break;
    }
    
    // For demo purposes, we'll assume payment is always successful
    // In real implementation, this is where you'd handle payment failures
  }

  Future<String> _createOrder(String userId) async {
    final orderId = 'ORD${DateTime.now().millisecondsSinceEpoch}';
    
    final orderData = {
      'orderId': orderId,
      'buyerUid': userId,
      'items': widget.cartItems,
      'total': widget.totalAmount,
      'subtotal': widget.totalAmount,
      'shipping': 0.0,
      'tax': 0.0,
      'status': 'confirmed', // Payment processed, so confirmed
      'paymentMethod': _selectedPaymentMethod,
      'paymentStatus': 'paid', // All guest payments are processed immediately
      'createdAt': DateTime.now(),
      'estimatedDelivery': DateTime.now().add(const Duration(days: 3)),
      
      // Guest information
      'isGuestOrder': true,
      'guestInfo': {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
      },
      
      // Delivery address
      'deliveryAddress': {
        'fullName': _nameController.text.trim(),
        'addressLine1': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'postalCode': _postalCodeController.text.trim(),
        'country': 'Philippines',
        'phoneNumber': _phoneController.text.trim(),
      },
      
      // Payment details (without sensitive info)
      'paymentDetails': {
        'method': _selectedPaymentMethod,
        'processedAt': DateTime.now(),
        'amount': widget.totalAmount,
      },
    };

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .set(orderData);

    return orderId;
  }

  Future<void> _sendEmailConfirmation(String orderId) async {
    try {
      // Create email content
      final emailContent = _buildEmailContent(orderId);
      
      // Send email using EmailService
      await EmailService.sendOrderConfirmationEmail(
        toEmail: _emailController.text.trim(),
        customerName: _nameController.text.trim(),
        orderId: orderId,
        orderItems: widget.cartItems,
        totalAmount: widget.totalAmount,
        paymentMethod: _getPaymentMethodDisplayName(_selectedPaymentMethod),
        deliveryAddress: {
          'fullName': _nameController.text.trim(),
          'address': _addressController.text.trim(),
          'city': _cityController.text.trim(),
          'postalCode': _postalCodeController.text.trim(),
        },
        estimatedDelivery: DateTime.now().add(const Duration(days: 3)),
      );
      
      print('Email confirmation sent to: ${_emailController.text}');
    } catch (e) {
      print('Failed to send email confirmation: $e');
      // Don't throw error - email failure shouldn't stop the order
    }
  }

  String _buildEmailContent(String orderId) {
    return '''
    Dear ${_nameController.text},
    
    Thank you for your order! Your payment has been successfully processed.
    
    Order Details:
    Order ID: $orderId
    Total Amount: ₱${widget.totalAmount.toStringAsFixed(2)}
    Payment Method: ${_getPaymentMethodDisplayName(_selectedPaymentMethod)}
    
    Items Ordered:
    ${widget.cartItems.map((item) => '- ${item['name']} x${item['quantity']} = ₱${((item['price'] ?? 0.0) * (item['quantity'] ?? 1)).toStringAsFixed(2)}').join('\n')}
    
    Delivery Address:
    ${_nameController.text}
    ${_addressController.text}
    ${_cityController.text}, ${_postalCodeController.text}
    
    Estimated Delivery: ${DateTime.now().add(const Duration(days: 3)).toString().split(' ')[0]}
    
    We'll send you tracking information once your order is shipped.
    
    Thank you for shopping with AnneDFinds!
    ''';
  }

  String _getPaymentMethodDisplayName(String method) {
    switch (method) {
      case 'gcash':
        return 'GCash';
      case 'bank':
        return 'Bank Transfer';
      case 'card':
        return 'Credit/Debit Card';
      default:
        return method;
    }
  }

  void _showSuccessDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 48,
        ),
        title: const Text('Payment Successful!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Your order #$orderId has been confirmed and paid.'),
            const SizedBox(height: 8),
            Text(
              'A confirmation email has been sent to ${_emailController.text}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'You will receive tracking information via email once your order is shipped.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              'Redirecting to home in 3 seconds...',
              style: TextStyle(
                fontSize: 12, 
                color: Colors.grey[600],
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

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.error,
          color: Colors.red,
          size: 48,
        ),
        title: const Text('Payment Failed'),
        content: Text(
          'Sorry, we couldn\'t process your payment. Please check your payment details and try again.\n\nError: $error',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}