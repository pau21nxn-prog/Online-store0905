import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/cart_service.dart';
import '../../services/auth_service.dart';
import '../../services/email_service.dart';
import '../../common/theme.dart';
import '../../common/mobile_layout_utils.dart';
import 'qr_payment_checkout.dart';

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
  final _apartmentController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _deliveryInstructionsController = TextEditingController();
  
  // Payment specific controllers
  final _gcashNumberController = TextEditingController();
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
    _apartmentController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    _deliveryInstructionsController.dispose();
    _gcashNumberController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

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
          'Guest Checkout',
          style: TextStyle(color: AppTheme.textPrimaryColor(context)),
        ),
        backgroundColor: AppTheme.backgroundColor(context),
        foregroundColor: AppTheme.textPrimaryColor(context),
        elevation: 0,
      ),
      body: _buildBodyContent(context),
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    return _isProcessing
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
                          return 'Phone number is required';
                        }
                        // Philippine phone number validation
                        final cleanNumber = value.replaceAll(RegExp(r'[^0-9+]'), '');
                        if (!RegExp(r'^(\+63|63|0)?9\d{9}$').hasMatch(cleanNumber)) {
                          return 'Please enter a valid Philippine phone number';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Shipping Address
                    _buildSectionTitle('Shipping Address'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _addressController,
                      label: 'Street Address',
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
                    _buildTextField(
                      controller: _apartmentController,
                      label: 'Apartment, Suite, etc. (Optional)',
                      icon: Icons.apartment,
                      maxLines: 1,
                      validator: (value) => null, // Optional field, no validation
                    ),
                    
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _cityController,
                            label: 'City',
                            icon: Icons.location_city,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'City is required';
                              }
                              if (!_isValidPhilippineCity(value.trim())) {
                                return 'Please enter a valid Philippine city';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _provinceController,
                            label: 'Province',
                            icon: Icons.map,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Province is required';
                              }
                              if (!_isValidPhilippineProvince(value.trim())) {
                                return 'Please enter a valid Philippine province';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _postalCodeController,
                      label: 'Postal Code',
                      icon: Icons.markunread_mailbox,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Postal code is required';
                        }
                        if (!_isValidPhilippinePostalCode(value.trim())) {
                          return 'Please enter a valid Philippine postal code (4 digits)';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _deliveryInstructionsController,
                      label: 'Delivery Instructions (Optional)',
                      icon: Icons.note_add,
                      maxLines: 3,
                      validator: (value) => null, // Optional field, no validation
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Payment Method
                    _buildSectionTitle('Payment Method'),
                    const SizedBox(height: 12),
                    _buildPaymentMethods(),
                    
                    // Payment Details Form - Removed information boxes as requested
                    
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
                  'Your email address is required as we will send your order confirmation, payment instructions, and tracking information via email. Please ensure your email address is correct.',
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
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
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          ...widget.cartItems.map((item) => _buildGuestOrderItem(item, isDarkMode)).toList(),
          Divider(color: isDarkMode ? Colors.grey[600] : Colors.grey[400]),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
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
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.white70 : Colors.grey[700],
        ),
        prefixIcon: Icon(icon, color: AppTheme.primaryOrange),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
          ),
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
        fillColor: isDarkMode ? Colors.grey[850] : Colors.white,
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
          subtitle: const Text('Scan QR code with your GCash app'),
          activeColor: AppTheme.primaryOrange,
        ),
        RadioListTile<String>(
          value: 'gotyme',
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
              Text('GoTyme Bank'),
            ],
          ),
          subtitle: const Text('Scan QR code with your GoTyme app'),
          activeColor: AppTheme.primaryOrange,
        ),
        RadioListTile<String>(
          value: 'metrobank',
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
              Text('Metrobank'),
            ],
          ),
          subtitle: const Text('Use Metrobank online banking or app'),
          activeColor: AppTheme.primaryOrange,
        ),
        RadioListTile<String>(
          value: 'bpi',
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
              Text('BPI'),
            ],
          ),
          subtitle: const Text('Scan QR code with your BPI app'),
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
                'GCash QR Payment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('You will scan a QR code to complete your GCash payment.'),
            ],
          ),
        );

      case 'gotyme':
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
                'GoTyme Bank QR Payment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('You will scan a QR code to complete your GoTyme Bank payment.'),
            ],
          ),
        );

      case 'metrobank':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Metrobank QR Payment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('You will use Metrobank online banking or scan QR code.'),
            ],
          ),
        );

      case 'bpi':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BPI QR Payment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('You will scan a QR code to complete your BPI payment.'),
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
      // Create anonymous user first and wait for authentication
      final anonymousUser = await AuthService.createAnonymousUserAfterPayment(
        guestEmail: _emailController.text.trim(),
        guestName: _nameController.text.trim(),
        guestPhone: _phoneController.text.trim(),
      );

      if (anonymousUser == null) {
        throw Exception('Failed to create guest account');
      }

      // Verify Firebase Auth user exists before proceeding
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null || firebaseUser.uid != anonymousUser.id) {
        throw Exception('Authentication error. Please try again.');
      }

      // Save cart to Firebase for the new anonymous user
      await CartService.saveCartToFirebaseAfterPayment(anonymousUser.id);
      
      // Create order with the new anonymous user
      final orderId = await _createOrder(anonymousUser.id);
      
      // Redirect to QR payment screen instead of processing payment
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => QRPaymentCheckout(
              totalAmount: widget.totalAmount,
              orderId: orderId,
              orderDetails: {
                'items': () {
                  // DEBUG: Log cart items data before mapping
                  print('🔍 DEBUG - Guest Checkout Cart Items:');
                  print('📦 Total cart items: ${widget.cartItems.length}');
                  for (int i = 0; i < widget.cartItems.length; i++) {
                    final item = widget.cartItems[i];
                    print('📋 Cart Item $i:');
                    print('  - Name: ${item['name']}');
                    print('  - Quantity: ${item['quantity']}');
                    print('  - Price: ${item['price']}');
                    print('  - Variant SKU: ${item['variantSku']}');
                    print('  - Variant Display Name: ${item['variantDisplayName']}');
                    print('  - Selected Options: ${item['selectedOptions']}');
                  }
                  
                  final mappedItems = widget.cartItems.map((item) => {
                    'name': item['name'],
                    'quantity': item['quantity'],
                    'price': item['price'],
                    'variantSku': item['variantSku'],
                    'variantDisplayName': item['variantDisplayName'],
                    'selectedOptions': item['selectedOptions'],
                  }).toList();
                  
                  // DEBUG: Log mapped order items
                  print('🔄 DEBUG - Mapped Order Items for QR Payment:');
                  for (int i = 0; i < mappedItems.length; i++) {
                    final item = mappedItems[i];
                    print('📋 Mapped Item $i:');
                    print('  - Name: ${item['name']}');
                    print('  - Variant SKU: ${item['variantSku']}');
                    print('  - Variant Display Name: ${item['variantDisplayName']}');
                    print('  - Selected Options: ${item['selectedOptions']}');
                  }
                  
                  return mappedItems;
                }(),
                'subtotal': widget.totalAmount,
                'shipping': 0.0,
                'total': widget.totalAmount,
                'guestInfo': {
                  'name': _nameController.text.trim(),
                  'email': _emailController.text.trim(),
                  'phone': _phoneController.text.trim(),
                },
                'deliveryAddress': {
                  'fullName': _nameController.text.trim(),
                  'addressLine1': _addressController.text.trim(),
                  'addressLine2': _apartmentController.text.trim(),
                  'city': _cityController.text.trim(),
                  'province': _provinceController.text.trim(),
                  'postalCode': _postalCodeController.text.trim(),
                  'phoneNumber': _phoneController.text.trim(),
                  'deliveryInstructions': _deliveryInstructionsController.text.trim(),
                },
              },
            ),
          ),
        );
      }
      
    } catch (e) {
      print('Error creating order: $e');
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
      case 'gotyme':
        // In real implementation, integrate with GoTyme Bank API
        break;
      case 'metrobank':
        // In real implementation, integrate with Metrobank API
        break;
      case 'bpi':
        // In real implementation, integrate with BPI API
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
        'addressLine2': _apartmentController.text.trim(),
        'city': _cityController.text.trim(),
        'province': _provinceController.text.trim(),
        'postalCode': _postalCodeController.text.trim(),
        'country': 'Philippines',
        'phoneNumber': _phoneController.text.trim(),
        'deliveryInstructions': _deliveryInstructionsController.text.trim(),
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
          'apartment': _apartmentController.text.trim(),
          'city': _cityController.text.trim(),
          'province': _provinceController.text.trim(),
          'postalCode': _postalCodeController.text.trim(),
          'deliveryInstructions': _deliveryInstructionsController.text.trim(),
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
    ${_apartmentController.text.isNotEmpty ? '${_apartmentController.text}\n' : ''}${_cityController.text}, ${_provinceController.text} ${_postalCodeController.text}
    ${_deliveryInstructionsController.text.isNotEmpty ? '\nDelivery Instructions: ${_deliveryInstructionsController.text}' : ''}
    
    Estimated Delivery: ${DateTime.now().add(const Duration(days: 3)).toString().split(' ')[0]}
    
    We'll send you tracking information once your order is shipped.
    
    Thank you for shopping with AnneDFinds!
    ''';
  }

  String _getPaymentMethodDisplayName(String method) {
    switch (method) {
      case 'gcash':
        return 'GCash';
      case 'gotyme':
        return 'GoTyme Bank';
      case 'metrobank':
        return 'Metrobank';
      case 'bpi':
        return 'BPI';
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

  // Philippine address validation methods
  bool _isValidPhilippineCity(String city) {
    final validCities = [
      // Metro Manila
      'Manila', 'Quezon City', 'Makati', 'Pasig', 'Taguig', 'Paranaque', 'Las Pinas',
      'Muntinlupa', 'Mandaluyong', 'San Juan', 'Pasay', 'Marikina', 'Caloocan',
      'Valenzuela', 'Malabon', 'Navotas', 'Pateros',
      // Major cities
      'Cebu City', 'Davao City', 'Zamboanga City', 'Cagayan de Oro', 'General Santos',
      'Iloilo City', 'Bacolod', 'Tacloban', 'Butuan', 'Iligan', 'Cotabato City',
      'Baguio', 'Dagupan', 'Laoag', 'Vigan', 'San Fernando', 'Angeles', 'Olongapo',
      'Batangas City', 'Lipa', 'Lucena', 'Antipolo', 'Cainta', 'Taytay', 'Binangonan',
      'Rodriguez', 'San Mateo', 'Marikina', 'Cabanatuan', 'Gapan', 'Palayan',
      'Santa Rosa', 'Cabuyao', 'Calamba', 'San Pablo', 'Imus', 'Bacoor', 'Cavite City',
      'Trece Martires', 'General Trias', 'Dasmarinas', 'Tagaytay', 'Naga',
      'Legazpi', 'Sorsogon', 'Masbate', 'Catbalogan', 'Borongan', 'Ormoc',
      'Maasin', 'Dumaguete', 'Tagbilaran', 'Lapu-Lapu', 'Mandaue', 'Toledo',
      'Carcar', 'Danao', 'Talisay', 'Minglanilla', 'Consolacion', 'Liloan',
      'Compostela', 'Carmen', 'Catmon', 'Sogod', 'Bantayan', 'Madridejos',
      'Santa Fe', 'Bogo', 'San Remigio', 'Tabogon', 'Borbon', 'Tabuelan',
      'Tuburan', 'Asturias', 'Balamban', 'Pinamungajan', 'Aloguinsan', 'Barili',
      'Dumanjug', 'Ronda', 'Alcantara', 'Moalboal', 'Badian', 'Alegria',
      'Malabuyoc', 'Ginatilan', 'Samboan', 'Santander', 'Oslob', 'Dalaguete',
      'Argao', 'Sibonga', 'San Fernando', 'Naga', 'Minglanilla', 'Talisay'
    ];
    
    return validCities.any((validCity) => 
      city.toLowerCase().contains(validCity.toLowerCase()) ||
      validCity.toLowerCase().contains(city.toLowerCase())
    );
  }

  bool _isValidPhilippineProvince(String province) {
    final validProvinces = [
      // Luzon
      'Metro Manila', 'National Capital Region', 'NCR',
      'Abra', 'Agusan del Norte', 'Agusan del Sur', 'Aklan', 'Albay', 'Antique',
      'Apayao', 'Aurora', 'Basilan', 'Bataan', 'Batanes', 'Batangas', 'Benguet',
      'Biliran', 'Bohol', 'Bukidnon', 'Bulacan', 'Cagayan', 'Camarines Norte',
      'Camarines Sur', 'Camiguin', 'Capiz', 'Catanduanes', 'Cavite', 'Cebu',
      'Compostela Valley', 'Davao de Oro', 'Davao del Norte', 'Davao del Sur',
      'Davao Occidental', 'Davao Oriental', 'Dinagat Islands', 'Eastern Samar',
      'Guimaras', 'Ifugao', 'Ilocos Norte', 'Ilocos Sur', 'Iloilo', 'Isabela',
      'Kalinga', 'La Union', 'Laguna', 'Lanao del Norte', 'Lanao del Sur',
      'Leyte', 'Maguindanao', 'Marinduque', 'Masbate', 'Misamis Occidental',
      'Misamis Oriental', 'Mountain Province', 'Negros Occidental', 'Negros Oriental',
      'Northern Samar', 'Nueva Ecija', 'Nueva Vizcaya', 'Occidental Mindoro',
      'Oriental Mindoro', 'Palawan', 'Pampanga', 'Pangasinan', 'Quezon', 'Quirino',
      'Rizal', 'Romblon', 'Samar', 'Sarangani', 'Siquijor', 'Sorsogon',
      'South Cotabato', 'Southern Leyte', 'Sultan Kudarat', 'Sulu', 'Surigao del Norte',
      'Surigao del Sur', 'Tarlac', 'Tawi-Tawi', 'Zambales', 'Zamboanga del Norte',
      'Zamboanga del Sur', 'Zamboanga Sibugay'
    ];
    
    return validProvinces.any((validProvince) => 
      province.toLowerCase().contains(validProvince.toLowerCase()) ||
      validProvince.toLowerCase().contains(province.toLowerCase())
    );
  }

  bool _isValidPhilippinePostalCode(String postalCode) {
    // Philippine postal codes are 4 digits
    return RegExp(r'^\d{4}$').hasMatch(postalCode);
  }

  Widget _buildGuestOrderItem(Map<String, dynamic> item, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item['name'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Text(
                'x${item['quantity']}',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₱${((item['price'] ?? 0.0) * (item['quantity'] ?? 1)).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          // Show variant information if available
          if (item['selectedOptions'] != null && 
              (item['selectedOptions'] as Map).isNotEmpty)
            _buildGuestVariantDisplay(
              Map<String, String>.from(item['selectedOptions']),
              isDarkMode,
            ),
          // Show SKU if available
          if (item['variantSku'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'SKU: ${item['variantSku']}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGuestVariantDisplay(Map<String, String> options, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: options.entries.map((entry) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryOrange.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              entry.value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryOrange,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}