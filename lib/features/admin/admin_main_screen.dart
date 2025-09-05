import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../common/theme.dart';
import '../../services/theme_service.dart';
import 'products_management_screen.dart';
import 'orders_management_screen.dart';
import 'users_management_screen.dart';
import 'banner_management_screen.dart';
import '../../scripts/initialize_categories.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;
  bool _isSidebarCollapsed = false;

  final List<Widget> _pages = [
    const ProductsManagementScreen(),
    const OrdersManagementScreen(),
    const UsersManagementScreen(),
    const BannerManagementScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AnneDFinds Admin'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(_isSidebarCollapsed ? Icons.menu_open : Icons.menu),
          onPressed: () {
            setState(() {
              _isSidebarCollapsed = !_isSidebarCollapsed;
            });
          },
          tooltip: _isSidebarCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: _initializeCategories,
            tooltip: 'Initialize 26 Categories',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          Consumer<ThemeService>(
            builder: (context, themeService, child) {
              return IconButton(
                icon: Icon(
                  themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                  color: Colors.white,
                ),
                onPressed: themeService.toggleTheme,
                tooltip: themeService.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar Navigation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isSidebarCollapsed ? 80 : 250,
            color: AppTheme.surfaceGray,
            child: Column(
              children: [
                // Admin Profile Section
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryOrange.withValues(alpha: 0.1),
                        AppTheme.secondaryOrange.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                  child: _isSidebarCollapsed
                      ? Center(
                          child: CircleAvatar(
                            backgroundColor: AppTheme.primaryOrange,
                            child: const Icon(Icons.admin_panel_settings, color: Colors.white),
                          ),
                        )
                      : Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.primaryOrange,
                              child: const Icon(Icons.admin_panel_settings, color: Colors.white),
                            ),
                            const SizedBox(width: AppTheme.spacing12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Admin',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    FirebaseAuth.instance.currentUser?.email ?? '',
                                    style: AppTheme.captionStyle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
                
                // Navigation Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
                    children: [
                      _buildNavItem(0, Icons.inventory, 'Products'),
                      _buildNavItem(1, Icons.shopping_bag, 'Orders'),
                      _buildNavItem(2, Icons.people, 'Users'),
                      _buildNavItem(3, Icons.image, 'Banners'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Main Content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _selectedIndex = index),
              children: _pages,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing4,
      ),
      child: _isSidebarCollapsed
          ? Tooltip(
              message: title,
              child: InkWell(
                onTap: () {
                  setState(() => _selectedIndex = index);
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryOrange.withValues(alpha: 0.1) : null,
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: isSelected ? AppTheme.primaryOrange : Colors.grey,
                      size: 28,
                    ),
                  ),
                ),
              ),
            )
          : ListTile(
              leading: Icon(
                icon,
                color: isSelected ? AppTheme.primaryOrange : Colors.grey,
              ),
              title: Text(
                title,
                style: TextStyle(
                  color: isSelected ? AppTheme.primaryOrange : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedTileColor: AppTheme.primaryOrange.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              onTap: () {
                setState(() => _selectedIndex = index);
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
    );
  }

  void _initializeCategories() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Initialize Categories'),
        content: const Text('This will replace all existing categories with the 26 comprehensive categories. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange),
            child: const Text('Initialize'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Initializing categories...'),
            backgroundColor: Colors.blue,
          ),
        );

        await initializeCategories();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Categories initialized successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error initializing categories: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout from admin panel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog first
              await _performLogout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Logging out...'),
            ],
          ),
        ),
      );

      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        // Close loading dialog
        Navigator.pop(context);
        // Navigate back to main app (pop all admin screens)
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        // Close loading dialog if still showing
        Navigator.pop(context);
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }
}

