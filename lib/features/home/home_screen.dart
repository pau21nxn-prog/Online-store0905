import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../common/theme.dart';
import '../../common/mobile_layout_utils.dart';
import '../../models/product.dart';
import '../../models/banner.dart' as banner_model;
import '../../services/cart_service.dart';
import '../../services/theme_service.dart';
import '../../services/auth_service.dart';
import '../../services/banner_service.dart';
import '../common/widgets/product_card.dart';
import '../product/product_detail_screen.dart';
import '../search/search_screen.dart';
import '../cart/cart_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Banner carousel state
  final PageController _bannerPageController = PageController();
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;
  List<banner_model.Banner> _banners = [];
  bool _bannersLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadBanners();
  }
  
  Future<void> _loadBanners() async {
    try {
      debugPrint('HomeScreen: Starting banner loading...');
      final banners = await BannerService.getBanners();
      debugPrint('HomeScreen: Loaded ${banners.length} banners');
      
      setState(() {
        _banners = banners;
        _bannersLoading = false;
      });
      
      // Start auto-cycling if banners are available
      if (_banners.isNotEmpty) {
        debugPrint('HomeScreen: Starting banner autoplay with ${_banners.length} banners');
        _startBannerAutoplay();
      } else {
        debugPrint('HomeScreen: No banners available, showing empty state');
      }
    } catch (e) {
      debugPrint('HomeScreen: Error loading banners: $e');
      debugPrint('HomeScreen: Error type: ${e.runtimeType}');
      setState(() {
        _bannersLoading = false;
      });
    }
  }
  
  void _startBannerAutoplay() {
    _bannerTimer?.cancel();
    if (_banners.length > 1) {
      _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (mounted) {
          final nextIndex = (_currentBannerIndex + 1) % _banners.length;
          _bannerPageController.animateToPage(
            nextIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }
  
  void _stopBannerAutoplay() {
    _bannerTimer?.cancel();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _bannerTimer?.cancel();
    _bannerPageController.dispose();
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
      key: _scaffoldKey,
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: _buildEnhancedAppBar(context),
      body: CustomScrollView(
        slivers: [
          // Banner carousel - now scrollable with content
          SliverToBoxAdapter(
            child: _buildBannerCarousel(context),
          ),
          
          // "Check mo to Mhie" Featured Section Header
          _buildCheckMoToMhieSection(),
          
          // Featured Products Grid (2-column mobile layout)
          _buildFeaturedProductsGrid(),
          
          // Footer Section
          _buildFooterSection(),
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
          // Logo: ADF logo image with theme-aware rounded container
          // Positioned 2px from left border, no click functionality
          Container(
            margin: const EdgeInsets.only(left: 2), // 2px from left border
            child: Container(
              width: 58, // Container slightly larger than image
              height: 48,
              padding: const EdgeInsets.all(5), // Padding around image
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.black 
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Image.asset(
                  'images/Logo/48x48.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
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
                padding: EdgeInsets.only(left: 6, top: 6, right: 0, bottom: 6), // 0px from right side
              );
            },
          ),
          
          const SizedBox(width: 2), // Minimal spacing
          
          // 4. Login button (icon only, no text) - moved to rightmost position with minimal spacing
          IconButton(
            icon: Icon(Icons.person, color: Colors.white, size: 22), // Slightly reduced
            onPressed: () {
              Navigator.pushNamed(context, '/login');
            },
            tooltip: 'Sign In',
            padding: EdgeInsets.only(left: 2, top: 8, right: 0, bottom: 8), // 0px from right border
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

  // Banner carousel widget
  Widget _buildBannerCarousel(BuildContext context) {
    if (_bannersLoading) {
      // Loading shimmer effect
      return Container(
        height: 180, // 2/3 of typical product card height
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_banners.isEmpty) {
      // Empty state with colored background
      return Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          border: Border.all(
            color: AppTheme.primaryOrange.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_outlined,
                size: 48,
                color: AppTheme.primaryOrange.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'No banners available',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor(context),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 180,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Banner PageView
          PageView.builder(
            controller: _bannerPageController,
            itemCount: _banners.length,
            onPageChanged: (index) {
              setState(() {
                _currentBannerIndex = index;
              });
              // Restart auto-play when user manually changes page
              _startBannerAutoplay();
            },
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 20), // Space for dots
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  child: Image.network(
                    banner.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: AppTheme.surfaceColor(context),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppTheme.surfaceColor(context),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Failed to load image',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          
          // Dots indicator (only show if more than 1 banner)
          if (_banners.length > 1)
            Positioned(
              bottom: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  _banners.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _currentBannerIndex == index ? 24 : 8,
                    decoration: BoxDecoration(
                      color: _currentBannerIndex == index
                          ? AppTheme.primaryOrange
                          : AppTheme.primaryOrange.withValues(
                              alpha: MobileLayoutUtils.shouldUseViewportWrapper(context) ? 0.5 : 0.3
                            ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
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

  // "Check mo to Mhie" Featured Section - Mobile Grid Layout
  Widget _buildCheckMoToMhieSection() {
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('workflow.stage', isEqualTo: 'published')
          .orderBy('createdAt', descending: true)
          .limit(10) // Increased limit for grid display
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: MobileLayoutUtils.getMobilePadding(),
              child: _buildPromotedPlaceholder(),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildListDelegate([
            Padding(
              padding: MobileLayoutUtils.getMobileHorizontalPadding(),
              child: Text(
                'Check this out',
                style: AppTheme.sectionHeaderStyle.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ]),
        );
      },
    );
  }
  
  // Featured Products Grid Section
  Widget _buildFeaturedProductsGrid() {
    final currentUser = AuthService.currentUser;
    final isAdmin = currentUser?.canAccessAdmin ?? false;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('workflow.stage', isEqualTo: 'published')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        final products = snapshot.data!.docs
            .map((doc) => Product.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
            .toList();

        return SliverPadding(
          padding: MobileLayoutUtils.getMobileHorizontalPadding(),
          sliver: SliverGrid(
            gridDelegate: MobileLayoutUtils.getProductGridDelegate(
              isAdmin: isAdmin,
              context: context,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final product = products[index];
                return ProductCard(
                  product: product,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailScreen(product: product),
                      ),
                    );
                  },
                );
              },
              childCount: products.length,
            ),
          ),
        );
      },
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
              AppTheme.primaryOrange.withValues(alpha: 0.1),
              AppTheme.secondaryPink.withValues(alpha: 0.1),
            ],
          ),
          border: Border(
            top: BorderSide(
              color: AppTheme.primaryOrange.withValues(alpha: 0.3),
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
          color: AppTheme.primaryOrange.withValues(alpha: 0.3),
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


  // Removed old methods - replaced with comprehensive new design
}