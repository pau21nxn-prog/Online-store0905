import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/cart_item.dart';
import '../../models/payment.dart';
import '../../models/address.dart' as addr;
import '../../services/payment_service.dart';
// Notification service import removed
import '../../services/address_service.dart';
import '../../common/theme.dart';
import '../../common/mobile_layout_utils.dart';
import 'qr_payment_checkout.dart';

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
  // Removed selectedPaymentMethod - no longer needed
  final _addressFormKey = GlobalKey<FormState>();
  
  // Address controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _deliveryInstructionsController = TextEditingController();
  
  
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeUserData();
  }

  Future<void> _initializeUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      _emailController.text = user.email!;
      
      // Load default address if available
      await _loadDefaultAddress();
    }
  }

  Future<void> _loadDefaultAddress() async {
    try {
      final defaultAddress = await AddressService.getDefaultAddress();
      if (defaultAddress != null && mounted) {
        setState(() {
          _fullNameController.text = defaultAddress.fullName;
          _emailController.text = defaultAddress.email;
          _phoneController.text = defaultAddress.phoneNumber;
          _addressLine1Controller.text = defaultAddress.streetAddress;
          _addressLine2Controller.text = defaultAddress.apartmentSuite;
          _cityController.text = defaultAddress.city;
          _provinceController.text = defaultAddress.province;
          _postalCodeController.text = defaultAddress.postalCode;
          _deliveryInstructionsController.text = defaultAddress.deliveryInstructions;
        });
      }
    } catch (e) {
      debugPrint('Error loading default address: $e');
      // Don't show error to user, just log it
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    _deliveryInstructionsController.dispose();
    super.dispose();
  }

  void _showAddressBook() async {
    try {
      final addresses = await AddressService.getAddresses();
      
      if (addresses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No saved addresses found. Add one from your Profile > My Addresses'),
            backgroundColor: AppTheme.primaryOrange,
          ),
        );
        return;
      }

      final selectedAddress = await showDialog<addr.Address>(
        context: context,
        builder: (context) => _buildAddressSelectionDialog(addresses),
      );

      if (selectedAddress != null && mounted) {
        setState(() {
          _fullNameController.text = selectedAddress.fullName;
          _emailController.text = selectedAddress.email;
          _phoneController.text = selectedAddress.phoneNumber;
          _addressLine1Controller.text = selectedAddress.streetAddress;
          _addressLine2Controller.text = selectedAddress.apartmentSuite;
          _cityController.text = selectedAddress.city;
          _provinceController.text = selectedAddress.province;
          _postalCodeController.text = selectedAddress.postalCode;
          _deliveryInstructionsController.text = selectedAddress.deliveryInstructions;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Address loaded: ${selectedAddress.fullName}'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading addresses: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Widget _buildAddressSelectionDialog(List<addr.Address> addresses) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceColor(context),
      title: Text(
        'Select Address',
        style: TextStyle(color: AppTheme.textPrimaryColor(context)),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: addresses.length,
          itemBuilder: (context, index) {
            final address = addresses[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  address.isDefault ? Icons.star : Icons.location_on,
                  color: address.isDefault ? AppTheme.primaryOrange : Colors.grey,
                ),
                title: Text(
                  address.fullName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address.shortAddress,
                      style: TextStyle(color: AppTheme.textSecondaryColor(context)),
                    ),
                    Text(
                      address.phoneNumber,
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: address.isDefault 
                    ? const Text(
                        'DEFAULT',
                        style: TextStyle(
                          color: AppTheme.primaryOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(address),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppTheme.textSecondaryColor(context)),
          ),
        ),
      ],
    );
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
          'Checkout',
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrderSummary(),
          const SizedBox(height: 24),
          _buildEmailNotice(),
          const SizedBox(height: 24),
          _buildShippingAddress(),
          const SizedBox(height: 32),
          _buildPlaceOrderButton(),
        ],
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
          color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.2),
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
          ...widget.cartItems.map((item) => _buildOrderItem(item)),
          Divider(color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.3)),
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
          Divider(color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.3)),
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

  Widget _buildEmailNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withValues(alpha: 0.2),
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

  Widget _buildShippingAddress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.2),
        ),
      ),
      child: Form(
        key: _addressFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Shipping Address',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _showAddressBook,
                  icon: const Icon(Icons.book, size: 16),
                  label: const Text('Address Book'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryOrange,
                    side: const BorderSide(color: AppTheme.primaryOrange),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _fullNameController,
              label: 'Full Name',
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
            const SizedBox(height: 12),
            _buildTextField(
              controller: _emailController,
              label: 'Email Address *',
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
            const SizedBox(height: 12),
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number (Philippines)',
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
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _provinceController,
                    label: 'Province',
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
            const SizedBox(height: 12),
            _buildTextField(
              controller: _postalCodeController,
              label: 'Postal Code',
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
            const SizedBox(height: 12),
            _buildTextField(
              controller: _deliveryInstructionsController,
              label: 'Delivery Instructions (Optional)',
              maxLines: 3,
              validator: (value) => null, // Optional field, no validation
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
    int maxLines = 1,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.white70 : Colors.grey[700],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey[600]! : AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primaryOrange),
        ),
        filled: true,
        fillColor: isDarkMode ? Colors.grey[850] : Colors.white,
      ),
      validator: validator,
    );
  }

  // Payment method selection removed - using QR payment only

  // Payment method tile removed - using QR payment only


  Widget _buildPlaceOrderButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: !_isProcessing
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
                'Proceed to Payment',
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

    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated. Please sign in or refresh the page.');
      }
      
      // DEBUG: Log email from form controller
      debugPrint('🔍 DEBUG - EMAIL TRACKING: Email from form controller: "${_emailController.text.trim()}"');
      
      // Create shipping address
      final shippingAddress = ShippingAddress(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        addressLine1: _addressLine1Controller.text.trim(),
        addressLine2: _addressLine2Controller.text.trim(),
        city: _cityController.text.trim(),
        province: _provinceController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        deliveryInstructions: _deliveryInstructionsController.text.trim(),
      );
      
      // DEBUG: Log ShippingAddress object
      debugPrint('🔍 DEBUG - EMAIL TRACKING: ShippingAddress created with email: "${shippingAddress.email}"');
      
      // DEBUG: Log shippingAddress.toMap() output
      final shippingAddressMap = shippingAddress.toMap();
      debugPrint('🔍 DEBUG - EMAIL TRACKING: shippingAddress.toMap() contains:');
      debugPrint('  - Keys: ${shippingAddressMap.keys.toList()}');
      debugPrint('  - Email value: "${shippingAddressMap['email']}"');
      debugPrint('  - Full map: $shippingAddressMap');

      // Generate temporary order ID for reference
      final tempOrderId = 'ORD_${DateTime.now().millisecondsSinceEpoch}';
      
      // Store checkout data for order creation after payment
      await _storeCheckoutData(tempOrderId, shippingAddress, user.uid);

      // All payment methods redirect to QR checkout for manual processing
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => QRPaymentCheckout(
              totalAmount: widget.total,
              orderId: tempOrderId, // Use the temporary order ID
              orderDetails: {
                'items': () {
                  // DEBUG: Log cart items data before mapping
                  debugPrint('🔍 DEBUG - Regular Checkout Cart Items:');
                  debugPrint('📦 Total cart items: ${widget.cartItems.length}');
                  for (int i = 0; i < widget.cartItems.length; i++) {
                    final item = widget.cartItems[i];
                    debugPrint('📋 Cart Item $i:');
                    debugPrint('  - Product Name: ${item.productName}');
                    debugPrint('  - Quantity: ${item.quantity}');
                    debugPrint('  - Price: ${item.price}');
                    debugPrint('  - Variant SKU: ${item.variantSku}');
                    debugPrint('  - Variant Display Name: ${item.variantDisplayName}');
                    debugPrint('  - Selected Options: ${item.selectedOptions}');
                  }
                  
                  final mappedItems = widget.cartItems.map((item) => {
                    'name': item.productName,
                    'quantity': item.quantity,
                    'price': item.price,
                    'variantSku': item.variantSku,
                    'variantDisplayName': item.variantDisplayName,
                    'selectedOptions': item.selectedOptions,
                  }).toList();
                  
                  // DEBUG: Log mapped order items for QR Payment
                  debugPrint('🔄 DEBUG - Regular Checkout Mapped Items for QR Payment:');
                  for (int i = 0; i < mappedItems.length; i++) {
                    final item = mappedItems[i];
                    debugPrint('📋 Mapped Item $i:');
                    debugPrint('  - Name: ${item['name']}');
                    debugPrint('  - Variant SKU: ${item['variantSku']}');
                    debugPrint('  - Variant Display Name: ${item['variantDisplayName']}');
                    debugPrint('  - Selected Options: ${item['selectedOptions']}');
                  }
                  
                  return mappedItems;
                }(),
                'subtotal': widget.subtotal,
                'shipping': widget.shipping,
                'total': widget.total,
                'customerInfo': {
                  'name': _fullNameController.text.trim(),
                  'email': _emailController.text.trim(),
                  'phone': _phoneController.text.trim(),
                  'isGuest': false,
                },
                'shippingAddress': shippingAddress.toMap(),
              },
            ),
          ),
        );
      }
      return; // Exit early - all payments are manual QR now
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
            Text(
              'Payment notification sent for admin verification.',
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

  // Payment method helper functions removed - using QR payment only

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

  Future<void> _storeCheckoutData(String orderId, ShippingAddress shippingAddress, String userId) async {
    debugPrint('🚀 Starting checkout data storage for order: $orderId');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Store checkout data for order creation after payment
      final checkoutData = {
        'orderId': orderId,
        'userId': userId,
        'cartItems': widget.cartItems.map((item) => {
          'productId': item.productId,
          'productName': item.productName,
          'productImage': item.imageUrl,
          'price': item.price,
          'quantity': item.quantity,
          'selectedVariantId': item.selectedVariantId,
          'selectedOptions': item.selectedOptions,
          'variantSku': item.variantSku,
          'variantDisplayName': item.variantDisplayName,
          // Add cart key for precise removal matching
          'cartKey': item.getCartKey(),
        }).toList(),
        'subtotal': widget.subtotal,
        'shippingFee': widget.shipping,
        'total': widget.total,
        'shippingAddress': shippingAddress.toMap(),
        'createdAt': DateTime.now().toIso8601String(),
        'storageTimestamp': DateTime.now().millisecondsSinceEpoch, // Add timestamp for debugging
      };
      
      final dataKey = 'checkout_data_$orderId';
      final jsonString = jsonEncode(checkoutData);
      
      debugPrint('🔍 Storing data with key: $dataKey');
      debugPrint('📦 Data size: ${jsonString.length} characters');
      
      await prefs.setString(dataKey, jsonString);
      
      // Immediately verify data was stored correctly
      final verifyData = prefs.getString(dataKey);
      if (verifyData == null) {
        throw Exception('Checkout data storage verification failed - data not found after storage');
      }
      
      if (verifyData != jsonString) {
        throw Exception('Checkout data storage verification failed - data corruption detected');
      }
      
      // Enhanced debugging
      debugPrint('✅ Checkout data stored and verified for order: $orderId');
      debugPrint('🔍 DEBUG - Stored ${widget.cartItems.length} selected items for removal:');
      for (int i = 0; i < widget.cartItems.length; i++) {
        final item = widget.cartItems[i];
        debugPrint('  Item $i: ${item.productName} (Key: ${item.getCartKey()})');
      }
      
      // Store additional backup with timestamp for troubleshooting
      await prefs.setString('checkout_backup_$orderId', jsonString);
      debugPrint('💾 Backup checkout data also stored');
      
    } catch (e) {
      debugPrint('❌ CRITICAL ERROR storing checkout data: $e');
      debugPrint('📊 SharedPreferences status: ${await _checkSharedPreferencesStatus()}');
      rethrow;
    }
  }

  Future<String> _checkSharedPreferencesStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      return 'Available keys: ${keys.length}, Keys: ${keys.toList()}';
    } catch (e) {
      return 'SharedPreferences error: $e';
    }
  }

  Widget _buildOrderItem(CartItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Show variant information if available
                if (item.selectedOptions != null && item.selectedOptions!.isNotEmpty)
                  _buildVariantDisplay(item.selectedOptions!),
                // Show SKU if available
                if (item.variantSku != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'SKU: ${item.variantSku}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Qty: ${item.quantity}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            PaymentService.formatCurrency(item.price * item.quantity),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantDisplay(Map<String, String> options) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: options.entries.map((entry) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryOrange.withValues(alpha: 0.3),
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