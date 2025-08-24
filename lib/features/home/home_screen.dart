import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../common/theme.dart';
import '../../models/product.dart';
import '../../models/category.dart';
import '../../services/cart_service.dart';
import '../../services/theme_service.dart';
import '../../services/category_service.dart';
// Wishlist import removed
import '../common/widgets/product_card.dart';
import '../product/product_detail_screen.dart';
import '../categories/category_list_screen.dart';
import '../search/search_screen.dart';
import '../cart/cart_screen.dart';
// dart:async removed - no longer needed for promotional banners

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Category> _categories = [];
  bool _categoriesLoading = true;
  
  // Promotional banner system removed
  
  @override
  void initState() {
    super.initState();
    _loadCategories();
    // Promotional system initialization removed
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await CategoryService.getTopLevelCategories();
      setState(() {
        _categories = categories;
        _categoriesLoading = false;
      });
    } catch (e) {
      setState(() {
        _categoriesLoading = false;
      });
    }
  }
  
  // Promotional banner methods removed
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildEnhancedAppBar(context),
      drawer: _buildCategoryDrawer(context),
      body: Column(
        children: [
          // Search bar below header
          _buildSearchBarBelowHeader(context),
          
          // Main content
          Expanded(
            child: CustomScrollView(
              slivers: [
                // "Check mo to Mhie" Featured Section
                _buildCheckMoToMhieSection(),
                
                // Footer Section
                _buildFooterSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Redesigned Header based on Header.png reference
  PreferredSizeWidget _buildEnhancedAppBar(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: AppTheme.primaryOrange, // Changed back to orange
      foregroundColor: Colors.white,
      toolbarHeight: 60, // Reduced height for cleaner look
      automaticallyImplyLeading: false,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Hamburger Menu Button
          IconButton(
            icon: Icon(Icons.menu, color: Colors.white, size: 22), // Reduced size
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            tooltip: 'Categories',
            padding: EdgeInsets.all(6), // Compressed padding
          ),
          
          const SizedBox(width: 6), // Reduced spacing
          
          // 2. Logo: "AnneDFinds" text in orange with white rounded rectangle, slightly tilted, 0.8x size
          Transform.rotate(
            angle: -0.1, // Slight tilt (about 5.7 degrees)
            child: Container(
              height: 40, // Reduced from 50 to 40 (0.8x)
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Compressed padding
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10), // Slightly smaller
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'AnneDFinds',
                  style: TextStyle(
                    color: AppTheme.primaryOrange,
                    fontSize: 23, // Reduced from 29 to 23 (0.8x)
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ),
          
          const Spacer(), // Push remaining items to the right
          
          // 3. Theme Toggle button - compressed
          Consumer<ThemeService>(
            builder: (context, themeService, child) {
              return IconButton(
                icon: Icon(
                  themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                  color: Colors.white,
                  size: 20, // Reduced from 22 to 20
                ),
                onPressed: themeService.toggleTheme,
                tooltip: themeService.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                padding: EdgeInsets.all(6), // Compressed padding
              );
            },
          ),
          
          const SizedBox(width: 4), // Minimal spacing
          
          // 4. Login button (icon only, no text) - moved to rightmost position with minimal spacing
          IconButton(
            icon: Icon(Icons.person, color: Colors.white, size: 22), // Slightly reduced
            onPressed: () {
              Navigator.pushNamed(context, '/login');
            },
            tooltip: 'Sign In',
            padding: EdgeInsets.all(6), // Compressed padding
          ),
        ],
      ),
    );
  }

  // Search bar below header
  Widget _buildSearchBarBelowHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.backgroundColor(context),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search products...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey),
            onPressed: () => _searchController.clear(),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppTheme.surfaceColor(context),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
        ),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SearchScreen(initialQuery: value),
              ),
            );
          }
        },
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SearchScreen(),
            ),
          );
        },
        readOnly: true,
      ),
    );
  }

  // Login button now navigates directly to login screen

  Widget _buildCartIconWithBadge(BuildContext context) {
    return StreamBuilder<List<dynamic>>(
      stream: CartService.getCartItems(),
      builder: (context, snapshot) {
        final itemCount = snapshot.data?.length ?? 0;
        return Stack(
          children: [
            IconButton(
              icon: Icon(
                Icons.shopping_cart,
                color: Colors.white,
              ),
              onPressed: () {
                // Navigate directly to cart screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CartScreen(),
                  ),
                );
              },
            ),
            if (itemCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$itemCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // Search bar now integrated in header layout

  // Wishlist product card removed

  // Promotional banner removed

  // Hero Banner Section removed as requested

  // Removed Quick Access Grid as requested

  // "Check mo to Mhie" Featured Section
  Widget _buildCheckMoToMhieSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Check this out',
              style: AppTheme.sectionHeaderStyle.copyWith(
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .where('workflow.stage', isEqualTo: 'published')
                    .orderBy('createdAt', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildPromotedPlaceholder();
                  }

                  final products = snapshot.data!.docs
                      .map((doc) => Product.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
                      .toList();

                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 150,
                        margin: const EdgeInsets.only(right: 12),
                        child: ProductCard(
                          product: products[index],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductDetailScreen(product: products[index]),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotedPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.star,
            size: 40,
            color: AppTheme.secondaryPink,
          ),
          const SizedBox(height: 8),
          Text(
            'No promoted products yet',
            style: TextStyle(
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  // Removed Product Section methods as requested

  // Reviews and Ratings section removed as requested

  // Footer Section - 1.5x header height (90px)
  Widget _buildFooterSection() {
    return SliverToBoxAdapter(
      child: Container(
        height: 120, // 2x header height (60px * 2 = 120px)
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryOrange.withOpacity(0.1),
              AppTheme.secondaryPink.withOpacity(0.1),
            ],
          ),
          border: Border(
            top: BorderSide(
              color: AppTheme.primaryOrange.withOpacity(0.3),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Section: Contact info vertically stacked with reasonable margins
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(left: 16), // Reasonable left margin
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start, // Left-aligned
                  children: [
                    Text(
                      '📧 annedfinds@gmail.com',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6), // Reasonable vertical spacing
                    Text(
                      '📱 09682285496 / 09773257043',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '⏰ Open 24/7!',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '🚚 NCR and parts of Luzon',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Right Section: App download buttons vertically stacked, right-aligned
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end, // Right-aligned
                children: [
                  _buildCompactAppButton('Android', Icons.android), // Android on top
                  const SizedBox(height: 8), // Spacing between buttons
                  _buildCompactAppButton('iOS', Icons.phone_iphone),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactAppButton(String name, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppTheme.primaryOrange.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: AppTheme.textPrimaryColor(context),
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            name,
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Category Drawer
  Widget _buildCategoryDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.backgroundColor(context),
      child: Column(
        children: [
          Container(
            height: 80, // Reduced height
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryOrange, AppTheme.secondaryPink],
              ),
            ),
            padding: const EdgeInsets.all(16),
            alignment: Alignment.centerLeft,
            child: Text(
              'Categories',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _buildCategoryList(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCategoryList() {
    if (_categoriesLoading) {
      return [
        const ListTile(
          leading: CircularProgressIndicator(),
          title: Text('Loading categories...'),
        ),
      ];
    }

    if (_categories.isEmpty) {
      return [
        ListTile(
          leading: Icon(Icons.warning, color: Colors.orange),
          title: const Text('No categories available'),
          subtitle: const Text('Categories are being set up'),
        ),
      ];
    }

    return _categories.map((category) => _buildCategoryTile(
      category.name,
      category.icon,
      category.id,
    )).toList();
  }

  Widget _buildCategoryTile(String name, IconData icon, String categoryId) {
    return ListTile(
      leading: Icon(
        icon,
        color: AppTheme.primaryOrange,
        size: 20,
      ),
      title: Text(
        name,
        style: TextStyle(
          color: AppTheme.textPrimaryColor(context),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryListScreen(
              categoryId: categoryId,
              categoryName: name,
            ),
          ),
        );
      },
      dense: true,
    );
  }

  // Removed old methods - replaced with comprehensive new design
}