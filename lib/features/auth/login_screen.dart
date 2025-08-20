import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Firebase imports removed - not directly used in this file
import '../../common/theme.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showEmailForm = false;
  bool _showPhoneAuth = false;
  bool _isPhoneVerificationSent = false;
  String? _verificationId;
  final UserType _selectedUserType = UserType.buyer; // Always default to buyer

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    // Prevent double-clicks
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      UserModel? user;
      
      if (_isLogin) {
        user = await AuthService.signInWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        user = await AuthService.createAccountWithEmailPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          userType: _selectedUserType,
        );
      }

      if (user != null && mounted) {
        _showSuccessAndNavigate(_isLogin ? 'Successfully signed in!' : 'Account created successfully!');
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
      
      phoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      
      if (phoneNumber.length == 11 && phoneNumber.startsWith('09')) {
        phoneNumber = '+63${phoneNumber.substring(1)}';
      } else if (phoneNumber.length == 10 && phoneNumber.startsWith('9')) {
        phoneNumber = '+63$phoneNumber';
      } else if (phoneNumber.length == 12 && phoneNumber.startsWith('639')) {
        phoneNumber = '+$phoneNumber';
      } else if (phoneNumber.length == 13 && phoneNumber.startsWith('639')) {
        phoneNumber = '+$phoneNumber';
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid Philippine mobile number (e.g., 09123456789)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await AuthService.signInWithPhone(
        phoneNumber,
        (String verificationId) {
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
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Phone verification failed: $error'),
              backgroundColor: Colors.red,
            ),
          );
        },
        (UserModel? user) {
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
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.primaryOrange,
        duration: const Duration(milliseconds: 800),
      ),
    );

    // Immediately navigate to home screen after successful authentication
    // Use WidgetsBinding to ensure the widget tree is built before navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    });
  }

  void _handleAuthError(dynamic e) {
    if (mounted) {
      String message = 'An error occurred';
      
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

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: AppTheme.textPrimaryColor(context),
          ),
          onPressed: _goHome,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacing24),
            child: Card(
              elevation: 8,
              color: AppTheme.surfaceColor(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(AppTheme.spacing24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo and title
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.shopping_bag,
                        size: 64,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                    Text(
                      'AnneDFinds',
                      style: AppTheme.titleStyle.copyWith(
                        fontSize: 28,
                        color: AppTheme.primaryOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      _showPhoneAuth 
                          ? 'Sign in with your phone'
                          : _showEmailForm 
                              ? (_isLogin ? 'Welcome back!' : 'Create your account')
                              : 'Choose how to sign in',
                      style: AppTheme.bodyStyle.copyWith(
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing24),

                    // Phone auth form
                    if (_showPhoneAuth) ...[
                      _buildPhoneAuthForm(),
                    ] 
                    // Email auth form
                    else if (_showEmailForm) ...[
                      _buildEmailAuthForm(),
                    ] 
                    // Main authentication options
                    else ...[
                      _buildMainAuthOptions(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainAuthOptions() {
    return Column(
      children: [
        // Google Sign-In (primary option)
        _buildAuthOption(
          icon: Icons.login,
          title: 'Continue with Google',
          subtitle: 'Quick sign-in with your Google account',
          onTap: _isLoading ? () {} : _handleGoogleSignIn,
          isPrimary: true,
        ),

        const SizedBox(height: 16),

        // Phone Sign-In
        _buildAuthOption(
          icon: Icons.phone,
          title: 'Continue with Phone',
          subtitle: 'Sign in with SMS verification',
          onTap: _isLoading ? () {} : () {
            setState(() {
              _showPhoneAuth = true;
              _isPhoneVerificationSent = false;
              _phoneController.clear();
              _codeController.clear();
              _verificationId = null;
            });
          },
          isPrimary: false,
        ),

        const SizedBox(height: 16),

        // Email Sign-In
        _buildAuthOption(
          icon: Icons.email,
          title: 'Continue with Email',
          subtitle: 'Sign in with email and password',
          onTap: _isLoading ? () {} : () {
            setState(() {
              _showEmailForm = true;
              _isLogin = true;
            });
          },
          isPrimary: false,
        ),

        const SizedBox(height: 24),

        // Divider
        Row(
          children: [
            Expanded(
              child: Divider(
                color: AppTheme.textSecondaryColor(context).withOpacity(0.3),
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
                color: AppTheme.textSecondaryColor(context).withOpacity(0.3),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Create Account button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _showEmailForm = true;
                _isLogin = false;
              });
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.primaryOrange),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Create New Account',
              style: TextStyle(
                color: AppTheme.primaryOrange,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthOption({
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
                : AppTheme.textSecondaryColor(context).withOpacity(0.2),
            width: isPrimary ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isPrimary 
              ? AppTheme.primaryOrange.withOpacity(0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPrimary 
                    ? AppTheme.primaryOrange.withOpacity(0.1)
                    : AppTheme.textSecondaryColor(context).withOpacity(0.1),
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

  Widget _buildPhoneAuthForm() {
    return Form(
      child: Column(
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
                'Phone Authentication',
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
                LengthLimitingTextInputFormatter(10),
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
                    color: AppTheme.textSecondaryColor(context).withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryOrange),
                ),
              ),
            ),

            const SizedBox(height: 24),

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
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ] else ...[
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
                    color: AppTheme.textSecondaryColor(context).withOpacity(0.3),
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
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),

            const SizedBox(height: 16),

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
      ),
    );
  }

  Widget _buildEmailAuthForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _showEmailForm = false),
                icon: const Icon(Icons.arrow_back),
                color: AppTheme.textSecondaryColor(context),
              ),
              Text(
                _isLogin ? 'Sign In' : 'Create Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),

          // Name field (signup only)
          if (!_isLogin) ...[
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.textSecondaryColor(context).withOpacity(0.3),
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
            const SizedBox(height: AppTheme.spacing16),
          ],

          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.textSecondaryColor(context).withOpacity(0.3),
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
          const SizedBox(height: AppTheme.spacing16),

          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.textSecondaryColor(context).withOpacity(0.3),
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
              if (!_isLogin && value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),

          // Account type removed - all users default to buyer account

          const SizedBox(height: AppTheme.spacing24),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleEmailAuth,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLogin ? AppTheme.primaryOrange : AppTheme.accentBlue,
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
                      _isLogin ? 'Sign In' : 'Create Account',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: AppTheme.spacing16),

          // Toggle login/signup
          Center(
            child: TextButton(
              onPressed: _isLoading ? null : () {
                setState(() {
                  _isLogin = !_isLogin;
                  _nameController.clear();
                  _emailController.clear();
                  _passwordController.clear();
                  // _selectedUserType always remains UserType.buyer
                });
                _formKey.currentState?.reset();
              },
              child: Text(
                _isLogin
                    ? "Don't have an account? Create one"
                    : "Already have an account? Sign in",
                style: TextStyle(
                  color: _isLogin ? AppTheme.accentBlue : AppTheme.primaryOrange,
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