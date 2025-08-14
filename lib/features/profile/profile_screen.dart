import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../common/theme.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart'; // Our new service
import '../../services/wishlist_service.dart';
import '../../services/theme_service.dart';
import '../auth/login_screen.dart';
import '../auth/checkout_auth_modal.dart';
import 'edit_profile_screen.dart';
import 'orders_screen.dart';
import 'addresses_screen.dart';
import 'settings_screen.dart';
import '../admin/admin_access_screen.dart';
import '../wishlist/wishlist_screen.dart';

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
    final isGuest = _currentUser?.isGuest ?? true;
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
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: AppTheme.textPrimaryColor(context)),
            onPressed: () => _showComingSoon('Notifications'),
          ),
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
          _buildGuestHeader(),
          const SizedBox(height: 24),
          
          // Quick sign-up section
          _buildGuestAccountCreationSection(),
          const SizedBox(height: 24),
          
          _buildSectionHeader('Preferences'),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'App preferences & dark mode',
            onTap: () => _navigateToSettings(),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Support'),
          const SizedBox(height: 12),
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
          const SizedBox(height: 24),
          _buildQuickStats(),
          const SizedBox(height: 24),
          if (_currentUser?.canAccessAdmin ?? false) ...[
            _buildAdminSection(),
            const SizedBox(height: 24),
          ],
          _buildSectionHeader('Account'),
          const SizedBox(height: 12),
          ..._buildAccountMenuItems(),
          const SizedBox(height: 24),
          _buildSectionHeader('Preferences'),
          const SizedBox(height: 12),
          ..._buildPreferencesMenuItems(),
          const SizedBox(height: 24),
          _buildSectionHeader('Support'),
          const SizedBox(height: 12),
          ..._buildSupportMenuItems(),
          const SizedBox(height: 32),
          _buildSignOutButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGuestHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentBlue.withOpacity(0.1),
            AppTheme.accentBlue.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentBlue.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppTheme.accentBlue.withOpacity(0.2),
            child: Icon(Icons.person_outline, size: 40, color: AppTheme.accentBlue),
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome, Guest!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re browsing as a guest. Your cart is saved for this session.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor(context),
            ),
            textAlign: TextAlign.center,
          ),
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
          color: AppTheme.primaryOrange.withOpacity(0.3),
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
            AppTheme.primaryOrange.withOpacity(0.1),
            AppTheme.secondaryOrange.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryOrange.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppTheme.primaryOrange.withOpacity(0.2),
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
                        ? AppTheme.primaryOrange.withOpacity(0.2)
                        : AppTheme.accentBlue.withOpacity(0.2),
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

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<int>(
            stream: WishlistService.getWishlistCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return _buildStatCard(
                icon: Icons.favorite,
                label: 'Wishlist',
                value: count.toString(),
                color: Colors.red,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.shopping_cart,
            label: 'Orders',
            value: '0', // You can add order count stream here
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.star,
            label: 'Reviews',
            value: '0', // You can add review count stream here
            color: Colors.amber,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? color.withOpacity(0.3)
              : color.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor(context),
            ),
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
                AppTheme.primaryOrange.withOpacity(0.1),
                AppTheme.primaryOrange.withOpacity(0.05)
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade700
              : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryOrange, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppTheme.textSecondaryColor(context),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      _buildMenuItem(
        icon: Icons.favorite,
        title: 'Wishlist',
        subtitle: 'Your saved items',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WishlistScreen()),
        ),
      ),
      _buildMenuItem(
        icon: Icons.notifications,
        title: 'Notifications',
        subtitle: 'View your notifications (Coming Soon)',
        onTap: () => _showComingSoon('Notifications'),
      ),
    ];
  }

  List<Widget> _buildPreferencesMenuItems() {
    return [
      _buildMenuItem(
        icon: Icons.settings,
        title: 'Settings',
        subtitle: 'App preferences & dark mode',
        onTap: _navigateToSettings,
      ),
      _buildMenuItem(
        icon: Icons.notifications_active,
        title: 'Notification Settings',
        subtitle: 'Manage notification preferences (Coming Soon)',
        onTap: () => _showComingSoon('Notification settings'),
      ),
    ];
  }

  List<Widget> _buildSupportMenuItems() {
    return [
      _buildMenuItem(
        icon: Icons.help,
        title: 'Help & Support',
        subtitle: 'Get help and contact us',
        onTap: () => _showComingSoon('Help'),
      ),
      _buildMenuItem(
        icon: Icons.info,
        title: 'About',
        subtitle: 'App information',
        onTap: _showAboutDialog,
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

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        backgroundColor: AppTheme.primaryOrange,
      ),
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

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'AnneDFinds',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryOrange,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.shopping_bag, color: Colors.white, size: 24),
      ),
      children: [
        Text(
          'Your trusted online marketplace for quality products at great prices.',
          style: TextStyle(color: AppTheme.textSecondaryColor(context)),
        ),
        const SizedBox(height: 16),
        Text(
          'Built with Flutter and Firebase.',
          style: TextStyle(color: AppTheme.textSecondaryColor(context)),
        ),
      ],
    );
  }
}