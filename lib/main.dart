import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// Theme and Services
import 'common/theme.dart';
import 'services/cart_service.dart';
import 'services/theme_service.dart';
import 'services/auth_service.dart';

// Models
import 'models/user.dart';

// Features
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/search/search_screen.dart';
import 'features/cart/cart_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/orders_screen.dart'; // Updated import path
import 'features/admin/admin_main_screen.dart';
import 'features/notification/notifications_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with CORRECT configuration
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyB8B1YD9QGVDTVNld9-dXI2HfemNQLUUXs",
      authDomain: "annedfinds.firebaseapp.com",
      projectId: "annedfinds",
      storageBucket: "annedfinds.firebasestorage.app",
      messagingSenderId: "48916413018",
      appId: "1:48916413018:web:2c7d9f261b186622f93663",
      measurementId: "G-HWSG0DXHLQ"
    ),
  );
  
  // Initialize services
  await AuthService.initialize(); // Enhanced auth with anonymous support
  CartService.initialize(); // Cart service for guest/authenticated users (void return)
  
  // Initialize theme service
  final themeService = ThemeService();
  await themeService.loadTheme();
  
  runApp(
    ChangeNotifierProvider.value(
      value: themeService,
      child: const AnneDFindsApp(),
    ),
  );
}

class AnneDFindsApp extends StatelessWidget {
  const AnneDFindsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'AnneDFinds',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.themeMode,
          home: const MainNavigationScreen(),
          debugShowCheckedModeBanner: false,
          routes: {
            '/': (context) => const MainNavigationScreen(),
            '/login': (context) => const LoginScreen(),
            '/orders': (context) => const OrdersScreen(), // Updated route
            '/notifications': (context) => const NotificationsScreen(),
          },
        );
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  UserModel? _currentUser;

  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const CartScreen(),
    const ProfileScreen(),
  ];

  final List<Widget> _adminScreens = [
    const AdminMainScreen(),
    const SearchScreen(), 
    const CartScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Listen to user state changes
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show admin screens only if user is authenticated AND is admin
    final showAdminView = _currentUser?.canAccessAdmin ?? false;
    final screens = showAdminView ? _adminScreens : _screens;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.black26 
                : Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppTheme.primaryOrange,
          unselectedItemColor: AppTheme.textSecondaryColor(context),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          items: [
            BottomNavigationBarItem(
              icon: Icon(
                showAdminView ? Icons.dashboard_outlined : Icons.home_outlined
              ),
              activeIcon: Icon(
                showAdminView ? Icons.dashboard : Icons.home
              ),
              label: showAdminView ? 'Admin' : 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: StreamBuilder<int>(
                stream: CartService.getCartItemCountStream(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Stack(
                    children: [
                      const Icon(Icons.shopping_cart_outlined),
                      if (count > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryOrange,
                              borderRadius: BorderRadius.all(Radius.circular(10)),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              activeIcon: StreamBuilder<int>(
                stream: CartService.getCartItemCountStream(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Stack(
                    children: [
                      const Icon(Icons.shopping_cart),
                      if (count > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryOrange,
                              borderRadius: BorderRadius.all(Radius.circular(10)),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              label: 'Cart',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.person_outline),
                  // Show indicator for guest users
                  if (_currentUser?.isGuest ?? true)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.accentBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              activeIcon: Stack(
                children: [
                  const Icon(Icons.person),
                  // Show indicator for guest users
                  if (_currentUser?.isGuest ?? true)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.accentBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}