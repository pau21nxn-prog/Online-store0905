import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../common/theme.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart'; // Our new service
import '../../services/email_service.dart';
// Wishlist service import removed
import '../../services/theme_service.dart';
import '../../common/mobile_layout_utils.dart';
import '../auth/login_screen.dart';
import '../auth/checkout_auth_modal.dart';
import 'edit_profile_screen.dart';
import 'orders_screen.dart';
import 'addresses_screen.dart';
import 'settings_screen.dart';
import '../admin/admin_access_screen.dart';
// Wishlist screen import removed

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Listen to auth state changes
    AuthService.userStream.listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });
    
    // Set initial user
    _currentUser = AuthService.currentUser;
  }

  void _showCreateAccountModal() {
    showDialog(
      context: context,
      builder: (context) => CheckoutAuthModal(
        cartItems: const [], // Empty cart for profile sign-up
        totalAmount: 0.0,
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await AuthService.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed out successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    final isAuthenticated = AuthService.isAuthenticated;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: _buildAppBar(),
      body: isAuthenticated ? _buildAuthenticatedProfile() : _buildGuestProfile(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Profile',
        style: TextStyle(
          color: AppTheme.textPrimaryColor(context),
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: AppTheme.backgroundColor(context),
      foregroundColor: AppTheme.textPrimaryColor(context),
      elevation: 0,
      actions: [
        // Theme toggle - available for all users
        Consumer<ThemeService>(
          builder: (context, themeService, child) {
            return IconButton(
              icon: Icon(
                themeService.isDarkMode 
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
                color: AppTheme.textPrimaryColor(context),
              ),
              onPressed: () => themeService.toggleTheme(),
              tooltip: 'Toggle theme',
            );
          },
        ),
        // Show additional actions only for authenticated users
        if (AuthService.isAuthenticated) ...[
          // Notifications icon removed
          IconButton(
            icon: Icon(Icons.edit, color: AppTheme.textPrimaryColor(context)),
            onPressed: _navigateToEditProfile,
          ),
        ],
      ],
    );
  }

  Widget _buildGuestProfile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          
          // Quick sign-up section
          _buildGuestAccountCreationSection(),
          const SizedBox(height: 16), // Reduced from 24 to 16
          ..._buildSupportMenuItems(),
        ],
      ),
    );
  }

  Widget _buildAuthenticatedProfile() {
    return RefreshIndicator(
      onRefresh: () async {
        await AuthService.reloadUserData();
      },
      color: AppTheme.primaryOrange,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 16), // Reduced from 24 to 16
          if (_currentUser?.canAccessAdmin ?? false) ...[
            _buildAdminSection(),
            const SizedBox(height: 16), // Reduced from 24 to 16
          ],
          ..._buildAccountMenuItems(),
          const SizedBox(height: 16), // Reduced from 24 to 16
          ..._buildPreferencesMenuItems(),
          const SizedBox(height: 16), // Reduced from 24 to 16
          ..._buildSupportMenuItems(),
          const SizedBox(height: 20), // Reduced from 32 to 20
          _buildSignOutButton(),
          const SizedBox(height: 16), // Reduced from 24 to 16
        ],
      ),
    );
  }


  Widget _buildGuestAccountCreationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryOrange.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_circle_outlined,
                color: AppTheme.primaryOrange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Create Your Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• Keep your cart across sessions\n• Track your orders\n• Save delivery addresses\n• Get exclusive offers',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _showCreateAccountModal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Create Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _navigateToLogin,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppTheme.primaryOrange),
                  ),
                  child: Text(
                    'Sign In',
                    style: TextStyle(
                      color: AppTheme.primaryOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryOrange.withValues(alpha: 0.1),
            AppTheme.secondaryOrange.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryOrange.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.2),
            backgroundImage: _currentUser?.profileImageUrl != null
                ? NetworkImage(_currentUser!.profileImageUrl!)
                : null,
            child: _currentUser?.profileImageUrl == null
                ? Icon(Icons.person, size: 40, color: AppTheme.primaryOrange)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentUser?.displayName ?? 'User',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentUser?.email ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                if (_currentUser?.phoneNumber != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _currentUser!.phoneNumber!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
                // Role badge
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _currentUser?.isAdmin == true 
                        ? AppTheme.primaryOrange.withValues(alpha: 0.2)
                        : AppTheme.accentBlue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _currentUser?.roleDisplayText ?? 'Buyer',
                    style: TextStyle(
                      fontSize: 12,
                      color: _currentUser?.isAdmin == true 
                          ? AppTheme.primaryOrange
                          : AppTheme.accentBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: AppTheme.primaryOrange),
            onPressed: _navigateToEditProfile,
          ),
        ],
      ),
    );
  }


  Widget _buildAdminSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Admin'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryOrange.withValues(alpha: 0.1),
                AppTheme.primaryOrange.withValues(alpha: 0.05)
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.3)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
            ),
            title: const Text(
              'Admin Panel',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryOrange),
            ),
            subtitle: Text(
              'Manage products, orders & analytics',
              style: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 12),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, color: AppTheme.primaryOrange, size: 16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminAccessScreen()),
            ),
          ),
        ),
      ],
    );
  }

  // Keep all your existing methods for building sections
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimaryColor(context),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6), // Reduced from 8 to 6
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(8), // Reduced from 12 to 8
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade700
              : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Compressed padding
        leading: Container(
          padding: const EdgeInsets.all(6), // Reduced from 8 to 6
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6), // Reduced from 8 to 6
          ),
          child: Icon(icon, color: AppTheme.primaryOrange, size: 18), // Reduced icon size
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15, // Reduced from 16 to 15
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11, // Reduced from 12 to 11
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14, // Reduced from 16 to 14
          color: AppTheme.textSecondaryColor(context),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  List<Widget> _buildAccountMenuItems() {
    return [
      _buildMenuItem(
        icon: Icons.shopping_bag,
        title: 'My Orders',
        subtitle: 'Track your orders',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const OrdersScreen()),
        ),
      ),
      _buildMenuItem(
        icon: Icons.location_on,
        title: 'Addresses',
        subtitle: 'Manage delivery addresses',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddressesScreen()),
        ),
      ),
      // Wishlist menu item removed
      // Notifications menu item removed
    ];
  }

  List<Widget> _buildPreferencesMenuItems() {
    return [
      // Settings menu item removed
      // Notification settings menu item removed
    ];
  }

  List<Widget> _buildSupportMenuItems() {
    return [
      _buildMenuItem(
        icon: Icons.contact_support,
        title: 'Contact Us',
        subtitle: 'Get in touch with our team',
        onTap: _showContactUs,
      ),
    ];
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _showSignOutDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.errorRed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          'Sign Out',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // Navigation and utility methods
  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
    if (result == true) {
      await AuthService.reloadUserData();
    }
  }

  void _showContactUs() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.surfaceColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with back button
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back, color: AppTheme.textPrimaryColor(context)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Contact Us',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Promotional message - takes up most space
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tired of paying so much fees to major online selling platforms?\nLet\'s build your own E-commerce website now.',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor(context),
                          fontSize: 14,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.left,
                      ),
                      const SizedBox(height: 20),
                      
                      // Benefits
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBenefitItem('✅', 'Market your own product freely.', Colors.green),
                          const SizedBox(height: 10),
                          _buildBenefitItem('✅', 'Choose your own payment system.', Colors.green),
                          const SizedBox(height: 10),
                          _buildBenefitItem('✅', 'Reach everyone online and expand your business.', Colors.green),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Problems to avoid
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBenefitItem('❌', 'STOP losing your profits.', Colors.red),
                          const SizedBox(height: 10),
                          _buildBenefitItem('❌', 'Say NO to hidden charges and commissions.', Colors.red),
                          const SizedBox(height: 10),
                          _buildBenefitItem('❌', 'Say NO to complex fee structures.', Colors.red),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Call to action
                      Text(
                        'Keep more of your EARNINGS. Maximize your PROFITS.\nLet\'s BUILD your own online shop NOW!',
                        style: TextStyle(
                          color: AppTheme.primaryOrange,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 18),
              
              // Click Here button
              Center(
                child: SizedBox(
                  width: 200,
                  child: ElevatedButton(
                    onPressed: () => _showContactForm(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'CLICK HERE',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 14),
              
              // Contact info at bottom
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    'annedfinds@gmail.com | 09773257043',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(String icon, String text, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          icon,
          style: TextStyle(fontSize: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  void _showContactForm() {
    showDialog(
      context: context,
      builder: (context) => ContactFormDialog(),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        title: Text(
          'Sign Out',
          style: TextStyle(color: AppTheme.textPrimaryColor(context)),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: AppTheme.textSecondaryColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondaryColor(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

}

class ContactFormDialog extends StatefulWidget {
  @override
  _ContactFormDialogState createState() => _ContactFormDialogState();
}

class _ContactFormDialogState extends State<ContactFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  bool _isValidPhilippineNumber(String phone) {
    // Remove all non-digit characters
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check different Philippine number formats
    if (cleanPhone.startsWith('09') && cleanPhone.length == 11) {
      return true; // 09XXXXXXXXX
    }
    if (cleanPhone.startsWith('639') && cleanPhone.length == 12) {
      return true; // 639XXXXXXXXX
    }
    if (cleanPhone.startsWith('63') && cleanPhone.length == 12) {
      return true; // 63XXXXXXXXXX (alternative)
    }
    
    return false;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email.trim());
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Send email using new contact form specific service
      final success = await EmailService.sendContactFormSubmission(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        message: _messageController.text.trim(),
      );

      setState(() => _isLoading = false);

      if (success) {
        // Show success message and close form
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message sent successfully! We\'ll get back to you soon.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Close contact form
      } else {
        // Show error message but keep form open
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: AppTheme.textPrimaryColor(context)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Get in Touch',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Form fields
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // First Name
                      TextFormField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'First Name *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.primaryOrange),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'First name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Last Name
                      TextFormField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Last Name *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.primaryOrange),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Last name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Phone Number
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number *',
                          hintText: '09XXXXXXXXX or +639XXXXXXXXX',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.primaryOrange),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Phone number is required';
                          }
                          if (!_isValidPhilippineNumber(value)) {
                            return 'Please enter a valid Philippine phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.primaryOrange),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!_isValidEmail(value)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Message
                      TextFormField(
                        controller: _messageController,
                        maxLength: 50,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Message *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.primaryOrange),
                          ),
                          counterText: '', // Hide character counter as requested
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Message is required';
                          }
                          if (value.length > 50) {
                            return 'Message must be 50 characters or less';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Send Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'SEND',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}