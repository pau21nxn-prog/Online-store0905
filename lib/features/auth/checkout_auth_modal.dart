import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../common/theme.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../models/user.dart';
import '../../models/cart_item.dart';
import '../checkout/guest_checkout_screen.dart';
import '../checkout/checkout_screen.dart';

class CheckoutAuthModal extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double totalAmount;
  final VoidCallback? onGuestCheckout;
  final VoidCallback? onAuthenticationSuccess;
  
  const CheckoutAuthModal({
    super.key,
    required this.cartItems,
    required this.totalAmount,
    this.onGuestCheckout,
    this.onAuthenticationSuccess,
  });

  @override
  State<CheckoutAuthModal> createState() => _CheckoutAuthModalState();
}

class _CheckoutAuthModalState extends State<CheckoutAuthModal> {
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isSignUp = false;
  bool _showAuthForm = false;
  bool _showPhoneAuth = false;
  bool _obscurePassword = true;
  UserType _selectedUserType = UserType.buyer;
  String? _verificationId;
  bool _isPhoneVerificationSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleGuestCheckout() async {
    Navigator.pop(context);
    
    if (widget.onGuestCheckout != null) {
      widget.onGuestCheckout!();
      return;
    }

    // Get current cart items from memory (no async needed)
    final cartItems = CartService.getCurrentCartItemsForCheckout();
    final totalAmount = CartService.getCurrentCartTotal();
    
    if (cartItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your cart is empty'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Navigate to guest checkout
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GuestCheckoutScreen(
          cartItems: cartItems,
          totalAmount: totalAmount,
        ),
      ),
    );
  }

  Future<void> _handleAuthentication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      UserModel? user;
      
      if (_isSignUp) {
        // Check if current user is anonymous and can link account
        if (AuthService.isAnonymous) {
          user = await AuthService.linkAnonymousAccount(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            name: _nameController.text.trim(),
            userType: _selectedUserType,
          );
        } else {
          user = await AuthService.createAccountWithEmailPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            name: _nameController.text.trim(),
            userType: _selectedUserType,
          );
        }
      } else {
        user = await AuthService.signInWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }

      if (user != null && mounted) {
        _showSuccessAndNavigate(_isSignUp ? 'Account created successfully!' : 'Signed in successfully!');
      }
    } catch (e) {
      _handleAuthError(e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final user = await AuthService.signInWithGoogle();
      
      if (user != null && mounted) {
        _showSuccessAndNavigate('Signed in with Google successfully!');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handlePhoneSignIn() async {
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String phoneNumber = _phoneController.text.trim();
      
      // Clean and format phone number for Philippines
      // Remove any non-digit characters first
      phoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      
      // Format based on length and prefix
      if (phoneNumber.length == 11 && phoneNumber.startsWith('09')) {
        // 09123456789 -> +639123456789
        phoneNumber = '+63${phoneNumber.substring(1)}';
      } else if (phoneNumber.length == 10 && phoneNumber.startsWith('9')) {
        // 9123456789 -> +639123456789
        phoneNumber = '+63$phoneNumber';
      } else if (phoneNumber.length == 12 && phoneNumber.startsWith('639')) {
        // 639123456789 -> +639123456789
        phoneNumber = '+$phoneNumber';
      } else if (phoneNumber.length == 13 && phoneNumber.startsWith('639')) {
        // Already has + prefix
        phoneNumber = '+$phoneNumber';
      } else {
        // Invalid format
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid Philippine mobile number (e.g., 09123456789)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      debugPrint('Formatted phone number: $phoneNumber'); // Debug log

      await AuthService.signInWithPhone(
        phoneNumber,
        (String verificationId) {
          // onCodeSent callback
          setState(() {
            _verificationId = verificationId;
            _isPhoneVerificationSent = true;
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification code sent to your phone'),
              backgroundColor: AppTheme.primaryOrange,
            ),
          );
        },
        (String error) {
          // onError callback
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Phone verification failed: $error'),
              backgroundColor: Colors.red,
            ),
          );
        },
        (UserModel? user) {
          // onSignInComplete callback
          setState(() => _isLoading = false);
          if (user != null && mounted) {
            _showSuccessAndNavigate('Phone verification successful!');
          }
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Phone sign-in failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _verifyPhoneCode() async {
    if (_codeController.text.trim().isEmpty || _verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the verification code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.verifyPhoneCode(_verificationId!, _codeController.text.trim());
      
      if (user != null && mounted) {
        _showSuccessAndNavigate('Phone verification successful!');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code verification failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessAndNavigate(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.primaryOrange,
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.pop(context);
    
    if (widget.onAuthenticationSuccess != null) {
      widget.onAuthenticationSuccess!();
    } else {
      // Navigate to authenticated checkout
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutScreen(
            cartItems: widget.cartItems.map<CartItem>((item) => CartItem(
              productId: item['productId'] ?? '',
              productName: item['name'] ?? item['productName'] ?? '',
              price: (item['price'] ?? 0.0).toDouble(),
              quantity: item['quantity'] ?? 1,
              imageUrl: item['imageUrl'] ?? '',
              addedAt: DateTime.now(),
              // Add missing variant fields:
              selectedVariantId: item['selectedVariantId'],
              selectedOptions: item['selectedOptions'] != null 
                  ? Map<String, String>.from(item['selectedOptions'])
                  : null,
              variantSku: item['variantSku'],
              variantDisplayName: item['variantDisplayName'],
            )).toList(),
            subtotal: widget.totalAmount,
            shipping: 0.0,
            total: widget.totalAmount,
          ),
        ),
      );
    }
  }

  void _handleAuthError(dynamic e) {
    if (mounted) {
      String message = 'An error occurred';
      
      // Parse error messages
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('email-already-in-use')) {
        message = 'An account already exists with this email.';
      } else if (errorString.contains('weak-password')) {
        message = 'Password is too weak. Use at least 8 characters.';
      } else if (errorString.contains('invalid-email')) {
        message = 'Please enter a valid email address.';
      } else if (errorString.contains('user-not-found')) {
        message = 'No account found with this email.';
      } else if (errorString.contains('wrong-password')) {
        message = 'Incorrect password.';
      } else if (errorString.contains('invalid-credential')) {
        message = 'Invalid email or password.';
      } else if (errorString.contains('too-many-requests')) {
        message = 'Too many failed attempts. Please try again later.';
      } else if (errorString.contains('network-request-failed')) {
        message = 'Network error. Please check your connection.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showSignUp() {
    setState(() {
      _isSignUp = true;
      _showAuthForm = true;
      _showPhoneAuth = false;
    });
  }

  void _showSignIn() {
    setState(() {
      _isSignUp = false;
      _showAuthForm = true;
      _showPhoneAuth = false;
    });
  }

  void _showPhoneSignIn() {
    setState(() {
      _showPhoneAuth = true;
      _showAuthForm = false;
      _isPhoneVerificationSent = false;
      _phoneController.clear();
      _codeController.clear();
      _verificationId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shopping_cart_checkout,
                        color: AppTheme.primaryOrange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Before you checkout',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                          Text(
                            'Choose how you\'d like to proceed',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondaryColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Order Summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Order Summary',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimaryColor(context),
                                ),
                              ),
                              Text(
                                '${widget.cartItems.length} item${widget.cartItems.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondaryColor(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor(context),
                                ),
                              ),
                              Text(
                                '₱${widget.totalAmount.toStringAsFixed(2)}',
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
                    ),

                    const SizedBox(height: 24),

                    // Authentication options, form, or phone auth
                    if (_showPhoneAuth) ...[
                      _buildPhoneAuthForm(),
                    ] else if (!_showAuthForm) ...[
                      // Create Account option (highlighted, at the top)
                      _buildOption(
                        icon: Icons.person_add_outlined,
                        title: 'Create Account',
                        subtitle: 'Save cart, track orders & enjoy member benefits',
                        onTap: _showSignUp,
                        isPrimary: true,
                      ),

                      const SizedBox(height: 16),

                      // Divider
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR SIGN IN',
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Google Sign-In Option
                      _buildOption(
                        icon: Icons.login,
                        title: 'Sign in with Google',
                        subtitle: 'Quick sign-in with your Google account',
                        onTap: _isLoading ? () {} : _handleGoogleSignIn,
                        isPrimary: false,
                      ),

                      const SizedBox(height: 12),

                      // Phone Sign-In Option
                      _buildOption(
                        icon: Icons.phone,
                        title: 'Sign in with Phone',
                        subtitle: 'Quick sign-in with SMS verification',
                        onTap: _isLoading ? () {} : _showPhoneSignIn,
                        isPrimary: false,
                      ),

                      const SizedBox(height: 12),

                      // Email Sign-In Option
                      _buildOption(
                        icon: Icons.email,
                        title: 'Email Sign In',
                        subtitle: 'Use email & password to sign in',
                        onTap: _showSignIn,
                        isPrimary: false,
                      ),

                      const SizedBox(height: 20),

                      // Second divider
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Guest checkout option (moved to bottom)
                      _buildOption(
                        icon: Icons.person_outline,
                        title: 'Checkout as Guest',
                        subtitle: 'Quick checkout without creating an account',
                        onTap: _handleGuestCheckout,
                        isPrimary: false,
                      ),

                      // Guest benefits
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: AppTheme.textSecondaryColor(context),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Guest Checkout Benefits',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondaryColor(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• Quick and easy checkout\n• No account required\n• Your cart is saved during this session',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Authentication form
                      _buildAuthForm(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneAuthForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _showPhoneAuth = false),
              icon: const Icon(Icons.arrow_back),
              color: AppTheme.textSecondaryColor(context),
            ),
            Text(
              'Sign in with Phone',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),

        if (!_isPhoneVerificationSent) ...[
          // Phone number input
          Text(
            'Enter your phone number',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10), // Max 10 digits after +63
            ],
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: '9123456789',
              prefixIcon: const Icon(Icons.phone),
              prefixText: '+63 ',
              helperText: 'Enter 10 digits (e.g., 9123456789)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryOrange),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'We\'ll send you a verification code via SMS',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),

          const SizedBox(height: 24),

          // Send Code Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handlePhoneSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Send Verification Code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ] else ...[
          // Verification code input
          Text(
            'Enter verification code',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: 'Verification Code',
              hintText: '123456',
              prefixIcon: const Icon(Icons.sms),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryOrange),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Code sent to +63${_phoneController.text}',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),

          const SizedBox(height: 24),

          // Verify Code Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyPhoneCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Verify & Sign In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Resend code
          Center(
            child: TextButton(
              onPressed: _isLoading ? null : () {
                setState(() {
                  _isPhoneVerificationSent = false;
                  _codeController.clear();
                });
              },
              child: const Text(
                'Resend code',
                style: TextStyle(
                  color: AppTheme.primaryOrange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isPrimary 
                ? AppTheme.primaryOrange 
                : AppTheme.textSecondaryColor(context).withValues(alpha: 0.2),
            width: isPrimary ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isPrimary 
              ? AppTheme.primaryOrange.withValues(alpha: 0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPrimary 
                    ? AppTheme.primaryOrange.withValues(alpha: 0.1)
                    : AppTheme.textSecondaryColor(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isPrimary 
                    ? AppTheme.primaryOrange 
                    : AppTheme.textSecondaryColor(context),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isPrimary 
                          ? AppTheme.primaryOrange 
                          : AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: isPrimary 
                  ? AppTheme.primaryOrange 
                  : AppTheme.textSecondaryColor(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: AppTheme.textSecondaryColor(context),
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondaryColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isSignUp ? 'Create Your Account' : 'Sign In to Your Account',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          
          const SizedBox(height: 16),

          // Name field (sign up only)
          if (_isSignUp) ...[
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter your full name',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryOrange),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                if (value.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],

          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryOrange),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryOrange),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (_isSignUp && value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),

          // User type selection (sign up only)
          if (_isSignUp) ...[
            const SizedBox(height: 16),
            Text(
              'Account Type',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  RadioListTile<UserType>(
                    title: const Text('Buyer Account'),
                    subtitle: const Text('For purchasing products'),
                    value: UserType.buyer,
                    groupValue: _selectedUserType,
                    onChanged: (value) => setState(() => _selectedUserType = value!),
                    activeColor: AppTheme.primaryOrange,
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<UserType>(
                    title: const Text('Seller Account'),
                    subtitle: const Text('For selling products (coming soon)'),
                    value: UserType.seller,
                    groupValue: _selectedUserType,
                    onChanged: null, // Disabled for now
                    activeColor: AppTheme.primaryOrange,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleAuthentication,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSignUp ? AppTheme.accentBlue : AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _isSignUp ? 'Create Account & Checkout' : 'Sign In & Checkout',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Toggle between sign in and sign up
          Center(
            child: TextButton(
              onPressed: _isLoading ? null : () {
                setState(() {
                  _isSignUp = !_isSignUp;
                  _nameController.clear();
                  _emailController.clear();
                  _passwordController.clear();
                  _selectedUserType = UserType.buyer;
                });
                _formKey.currentState?.reset();
              },
              child: Text(
                _isSignUp 
                    ? 'Already have an account? Sign in' 
                    : 'Don\'t have an account? Create one',
                style: TextStyle(
                  color: _isSignUp ? AppTheme.accentBlue : AppTheme.primaryOrange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Back to options
          Center(
            child: TextButton(
              onPressed: _isLoading ? null : () {
                setState(() => _showAuthForm = false);
              },
              child: Text(
                'Back to options',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}