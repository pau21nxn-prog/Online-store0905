import 'package:flutter/material.dart';
import 'dart:async';
import '../../common/theme.dart';
import '../../models/product.dart';
import '../../models/category.dart';
import '../../widgets/mobile_product_card.dart';
import '../../widgets/enhanced_search_bar.dart';
import 'search_screen.dart';
import 'mobile_product_details_screen.dart';

class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen>
    with TickerProviderStateMixin {
  late PageController _bannerController;
  late TabController _categoryTabController;
  late ScrollController _scrollController;
  
  // State
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;
  bool _showSearchBar = true;
  
  // Data
  List<String> _bannerImages = [];
  List<Category> _categories = [];
  List<Product> _featuredProducts = [];
  List<Product> _popularProducts = [];
  List<Product> _newProducts = [];
  List<Product> _dealsProducts = [];
  
  // UI State
  bool _isLoading = true;
  String _selectedCategoryId = 'all';

  @override
  void initState() {
    super.initState();
    _bannerController = PageController();
    _categoryTabController = TabController(length: 5, vsync: this);
    _scrollController = ScrollController();
    
    _scrollController.addListener(_onScroll);
    _loadHomeData();
    _startBannerAutoPlay();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      setState(() {
        _showSearchBar = _scrollController.offset < 100;
      });
    }
  }

  void _startBannerAutoPlay() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_bannerImages.isNotEmpty && _bannerController.hasClients) {
        final nextIndex = (_currentBannerIndex + 1) % _bannerImages.length;
        _bannerController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadHomeData() async {
    // Simulate loading data
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      _bannerImages = [
        'banner1', 'banner2', 'banner3', 'banner4'
      ];
      
      _categories = [
        Category(id: 'electronics', name: 'Electronics', imageUrl: ''),
        Category(id: 'fashion', name: 'Fashion', imageUrl: ''),
        Category(id: 'home', name: 'Home & Garden', imageUrl: ''),
        Category(id: 'sports', name: 'Sports', imageUrl: ''),
        Category(id: 'books', name: 'Books', imageUrl: ''),
      ];
      
      // Mock products
      _featuredProducts = _generateMockProducts('Featured', 8);
      _popularProducts = _generateMockProducts('Popular', 6);
      _newProducts = _generateMockProducts('New', 6);
      _dealsProducts = _generateMockProducts('Deal', 8);
      
      _isLoading = false;
    });
  }

  List<Product> _generateMockProducts(String prefix, int count) {
    return List.generate(count, (index) {
      final isOnSale = index % 3 == 0;
      final basePrice = 100.0 + (index * 50);
      final salePrice = isOnSale ? basePrice * 0.8 : basePrice;
      
      return Product(
        id: '${prefix.toLowerCase()}_$index',
        title: '$prefix Product ${index + 1}',
        description: 'This is a great $prefix product with excellent features and quality.',
        imageUrls: [],
        priceRange: PriceRange(min: salePrice, max: salePrice),
        originalPrice: basePrice,
        categoryPath: ['electronics'],
        primaryCategoryId: 'electronics',
        brandId: 'brand_${index % 3}',
        tags: ['popular', 'trending'],
        attributes: {},
        searchTokens: [],
        totalStock: 50 + (index * 10),
        variantCount: 3,
        soldCount: index * 12,
        ratingAvg: 4.0 + (index % 6) * 0.2,
        ratingCount: 20 + (index * 5),
        isLowStock: index % 7 == 0,
        hasIssues: false,
        isPublished: true,
        isNew: prefix == 'New',
        hasDiscount: isOnSale,
        workflow: WorkflowState(
          stage: ProductStatus.published,
          assignedTo: null,
          notes: [],
        ),
        performance: ProductPerformance(
          views: index * 100,
          clicks: index * 20,
          conversions: index * 2,
          revenue: salePrice * (index * 2),
        ),
        computed: ComputedFields(
          isLowStock: index % 7 == 0,
          reorderPoint: 10,
          daysOfInventory: 30,
          searchRelevance: 0.8,
        ),
        media: MediaCounts(images: 3, videos: 0),
        createdAt: DateTime.now().subtract(Duration(days: index)),
        updatedAt: DateTime.now().subtract(Duration(hours: index)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildBannerSection(),
                _buildQuickAccessGrid(),
                _buildCategoriesSection(),
                _buildFeaturedSection(),
                _buildPopularSection(),
                _buildDealsSection(),
                _buildNewArrivalsSection(),
                const SizedBox(height: 80), // Bottom padding for navigation
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: AppTheme.primaryOrange,
      title: AnimatedOpacity(
        opacity: _showSearchBar ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: const Text(
          'AnnedFinds',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            // Navigate to notifications
          },
          icon: Stack(
            children: [
              const Icon(Icons.notifications_outlined, color: Colors.white),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            // Navigate to cart
          },
          icon: Stack(
            children: [
              const Icon(Icons.shopping_cart_outlined, color: Colors.white),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: EnhancedSearchBar(
            onSearchSubmitted: _navigateToSearch,
            margin: EdgeInsets.zero,
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildBannerSection() {
    return Container(
      height: 200,
      margin: const EdgeInsets.all(AppTheme.spacing16),
      child: Stack(
        children: [
          PageView.builder(
            controller: _bannerController,
            onPageChanged: (index) {
              setState(() {
                _currentBannerIndex = index;
              });
            },
            itemCount: _bannerImages.length,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryOrange.withOpacity(0.8),
                      AppTheme.primaryOrange,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Banner ${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Banner indicators
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _bannerImages.asMap().entries.map((entry) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentBannerIndex == entry.key
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessGrid() {
    final quickActions = [
      {'icon': Icons.flash_on, 'label': 'Flash Sale', 'color': Colors.red},
      {'icon': Icons.local_shipping, 'label': 'Free Shipping', 'color': Colors.green},
      {'icon': Icons.star, 'label': 'Top Rated', 'color': Colors.amber},
      {'icon': Icons.new_releases, 'label': 'New Arrivals', 'color': Colors.purple},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: quickActions.length,
        itemBuilder: (context, index) {
          final action = quickActions[index];
          return InkWell(
            onTap: () => _handleQuickAction(action['label'] as String),
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            child: Container(
              decoration: BoxDecoration(
                color: (action['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                border: Border.all(
                  color: (action['color'] as Color).withOpacity(0.3),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    action['icon'] as IconData,
                    color: action['color'] as Color,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    action['label'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: action['color'] as Color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(AppTheme.spacing16),
          child: Text(
            'Shop by Category',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              return Container(
                width: 80,
                margin: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () => _navigateToCategoryProducts(category),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getCategoryIcon(category.id),
                          size: 24,
                          color: AppTheme.primaryOrange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedSection() {
    return _buildProductSection(
      title: 'Featured Products',
      products: _featuredProducts,
      showViewAll: true,
    );
  }

  Widget _buildPopularSection() {
    return _buildProductSection(
      title: 'Most Popular',
      products: _popularProducts,
      showViewAll: true,
    );
  }

  Widget _buildDealsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.red.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.flash_on, color: Colors.red),
              const SizedBox(width: 8),
              const Text(
                'Flash Deals',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Ends in 2h 34m',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing16),
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _dealsProducts.length,
              itemBuilder: (context, index) {
                final product = _dealsProducts[index];
                return SizedBox(
                  width: 160,
                  child: MobileProductCard(
                    product: product,
                    onTap: () => _navigateToProductDetails(product),
                    margin: const EdgeInsets.only(right: 12),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewArrivalsSection() {
    return _buildProductSection(
      title: 'New Arrivals',
      products: _newProducts,
      showViewAll: true,
    );
  }

  Widget _buildProductSection({
    required String title,
    required List<Product> products,
    bool showViewAll = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (showViewAll)
                TextButton(
                  onPressed: () => _viewAllProducts(title),
                  child: const Text('View All'),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return SizedBox(
                width: 160,
                child: MobileProductCard(
                  product: product,
                  onTap: () => _navigateToProductDetails(product),
                  margin: const EdgeInsets.only(right: 12),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Event handlers
  void _navigateToSearch([String? query]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(initialQuery: query),
      ),
    );
  }

  void _navigateToProductDetails(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MobileProductDetailsScreen(product: product),
      ),
    );
  }

  void _navigateToCategoryProducts(Category category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          initialFilters: {'category': category.id},
        ),
      ),
    );
  }

  void _handleQuickAction(String action) {
    switch (action) {
      case 'Flash Sale':
        _navigateToSearch('flash sale');
        break;
      case 'Free Shipping':
        // Navigate to free shipping products
        break;
      case 'Top Rated':
        _navigateToSearch('top rated');
        break;
      case 'New Arrivals':
        _navigateToSearch('new arrivals');
        break;
    }
  }

  void _viewAllProducts(String section) {
    _navigateToSearch(section.toLowerCase());
  }

  IconData _getCategoryIcon(String categoryId) {
    switch (categoryId) {
      case 'electronics':
        return Icons.devices;
      case 'fashion':
        return Icons.checkroom;
      case 'home':
        return Icons.home;
      case 'sports':
        return Icons.sports;
      case 'books':
        return Icons.book;
      default:
        return Icons.category;
    }
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _categoryTabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}