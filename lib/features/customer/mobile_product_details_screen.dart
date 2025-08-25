import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product.dart';
import '../../models/product_variant.dart';
import '../../common/theme.dart';
import '../../services/product_analytics_service.dart';
import '../../services/cart_service.dart';

class MobileProductDetailsScreen extends StatefulWidget {
  final Product product;

  const MobileProductDetailsScreen({
    super.key,
    required this.product,
  });

  @override
  State<MobileProductDetailsScreen> createState() => _MobileProductDetailsScreenState();
}

class _MobileProductDetailsScreenState extends State<MobileProductDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late PageController _imagePageController;
  late ScrollController _scrollController;
  
  // State
  int _currentImageIndex = 0;
  ProductVariant? _selectedVariant;
  int _quantity = 1;
  bool _isFavorite = false;
  bool _showFullDescription = false;
  
  // UI state
  bool _isAddingToCart = false;
  bool _showStickyHeader = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _imagePageController = PageController();
    _scrollController = ScrollController();
    
    _scrollController.addListener(_onScroll);
    
    // Track product view
    ProductAnalyticsService.trackProductView(widget.product.id);
    
    // Load variants and select first one if available
    _loadVariants();
  }

  void _onScroll() {
    const threshold = 200.0;
    if (_scrollController.hasClients) {
      setState(() {
        _showStickyHeader = _scrollController.offset > threshold;
      });
    }
  }

  Future<void> _loadVariants() async {
    // In a real app, you'd load variants from Firestore
    // For now, we'll simulate having variants
    if (widget.product.variantCount > 0) {
      // Mock variant selection
      setState(() {
        _selectedVariant = ProductVariant(
          id: 'variant_1',
          productId: widget.product.id,
          sku: 'SKU001',
          options: {'Color': 'Black', 'Size': 'M'},
          pricing: VariantPricing(
            basePrice: widget.product.priceRange.min,
            salePrice: widget.product.priceRange.min,
          ),
          inventory: InventoryInfo(
            available: widget.product.totalStock,
            reserved: 0,
            policy: StockPolicy.trackQuantity,
          ),
          isActive: true,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildImageGallery(),
                _buildProductInfo(), // Contains: Image, Title, Price, Description
                _buildVariantSelector(), // Variants
                _buildStockStatusSection(), // Stock 
                _buildQuantitySelector(), // Quantity
                _buildBrandInfo(), // Brand
                _buildDetailedDescription(), // Detailed Description
                _buildTabSection(),
                _buildRelatedProducts(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      elevation: _showStickyHeader ? 4 : 0,
      backgroundColor: _showStickyHeader ? Colors.white : Colors.transparent,
      foregroundColor: _showStickyHeader ? Colors.black : Colors.white,
      title: _showStickyHeader
          ? Text(
              widget.product.title,
              style: const TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      actions: [
        IconButton(
          onPressed: _toggleFavorite,
          icon: Icon(
            _isFavorite ? Icons.favorite : Icons.favorite_border,
            color: _isFavorite ? Colors.red : (_showStickyHeader ? Colors.black : Colors.white),
          ),
        ),
        IconButton(
          onPressed: _shareProduct,
          icon: Icon(
            Icons.share,
            color: _showStickyHeader ? Colors.black : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildImageGallery() {
    final images = widget.product.imageUrls.isNotEmpty 
        ? widget.product.imageUrls 
        : ['placeholder'];

    return Container(
      height: 400,
      color: Colors.grey.shade100,
      child: Stack(
        children: [
          // Image PageView
          PageView.builder(
            controller: _imagePageController,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemCount: images.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _showImageViewer(index),
                child: images[index] == 'placeholder'
                    ? _buildImagePlaceholder()
                    : Image.network(
                        images[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                      ),
              );
            },
          ),
          
          // Image indicators
          if (images.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: images.asMap().entries.map((entry) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentImageIndex == entry.key
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                  );
                }).toList(),
              ),
            ),
          
          // Badges
          Positioned(
            top: 16,
            left: 16,
            child: _buildImageBadges(),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          size: 80,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildImageBadges() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.product.hasDiscount)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${widget.product.discountPercent}% OFF',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        
        const SizedBox(height: 8),
        
        if (widget.product.isNew)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'NEW',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProductInfo() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            widget.product.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacing8),
          
          // Rating and reviews
          Row(
            children: [
              _buildRatingStars(widget.product.ratingAvg),
              const SizedBox(width: 8),
              Text(
                '${widget.product.ratingAvg.toStringAsFixed(1)} (${widget.product.ratingCount} reviews)',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '• ${widget.product.soldCount} sold',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacing16),
          
          // Price
          Row(
            children: [
              if (widget.product.hasDiscount && widget.product.originalPrice > widget.product.priceRange.min) ...[
                Text(
                  '₱${widget.product.originalPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 16,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                widget.product.formattedPriceRange,
                style: const TextStyle(
                  color: AppTheme.primaryOrange,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacing16),
          
          // Description (moved up in order)
          _buildDescription(),
        ],
      ),
    );
  }

  Widget _buildStockStatus() {
    final availableStock = widget.product.totalStock > 0 ? widget.product.totalStock : widget.product.stockQty;
    if (availableStock <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600, size: 16),
            const SizedBox(width: 4),
            Text(
              'Out of Stock',
              style: TextStyle(
                color: Colors.red.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (widget.product.isLowStock || availableStock <= 5) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_outlined, color: Colors.orange.shade600, size: 16),
            const SizedBox(width: 4),
            Text(
              'Only $availableStock left in stock',
              style: TextStyle(
                color: Colors.orange.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 16),
            const SizedBox(width: 4),
            Text(
              'In Stock',
              style: TextStyle(
                color: Colors.green.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDescription() {
    const maxLines = 3;
    final hasLongDescription = widget.product.description.length > 150;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.product.description,
          style: TextStyle(
            color: Colors.grey.shade700,
            height: 1.5,
          ),
          maxLines: _showFullDescription ? null : maxLines,
          overflow: _showFullDescription ? null : TextOverflow.ellipsis,
        ),
        if (hasLongDescription)
          TextButton(
            onPressed: () {
              setState(() {
                _showFullDescription = !_showFullDescription;
              });
            },
            child: Text(_showFullDescription ? 'Show Less' : 'Show More'),
          ),
      ],
    );
  }

  Widget _buildVariantSelector() {
    if (_selectedVariant == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Variants',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          
          // Mock variant options (Color, Size, etc.)
          ..._selectedVariant!.options.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.key}: ${entry.value}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _buildVariantOptions(entry.key, entry.value),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildVariantOptions(String optionName, String selectedValue) {
    // Mock options
    List<String> options;
    switch (optionName) {
      case 'Color':
        options = ['Black', 'White', 'Red', 'Blue'];
        break;
      case 'Size':
        options = ['S', 'M', 'L', 'XL'];
        break;
      default:
        options = [selectedValue];
    }

    return Wrap(
      spacing: 8,
      children: options.map((option) {
        final isSelected = option == selectedValue;
        return FilterChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              // Update variant selection
              setState(() {
                _selectedVariant = _selectedVariant!.copyWith(
                  options: {
                    ..._selectedVariant!.options,
                    optionName: option,
                  },
                );
              });
            }
          },
          selectedColor: AppTheme.primaryOrange.withOpacity(0.2),
          checkmarkColor: AppTheme.primaryOrange,
        );
      }).toList(),
    );
  }

  Widget _buildQuantitySelector() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Row(
        children: [
          const Text(
            'Quantity:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppTheme.spacing16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  icon: const Icon(Icons.remove),
                  iconSize: 20,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    _quantity.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _quantity < (widget.product.totalStock > 0 ? widget.product.totalStock : widget.product.stockQty) 
                      ? () => setState(() => _quantity++) 
                      : null,
                  icon: const Icon(Icons.add),
                  iconSize: 20,
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            '${widget.product.totalStock > 0 ? widget.product.totalStock : widget.product.stockQty} available',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSection() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Reviews'),
              Tab(text: 'Shipping'),
              Tab(text: 'Returns'),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey.shade600,
            indicator: BoxDecoration(
              color: AppTheme.primaryOrange,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildReviewsTab(),
              _buildShippingTab(),
              _buildReturnsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsTab() {
    return const Padding(
      padding: EdgeInsets.all(AppTheme.spacing16),
      child: Center(
        child: Text('Reviews will be shown here'),
      ),
    );
  }

  Widget _buildShippingTab() {
    return const Padding(
      padding: EdgeInsets.all(AppTheme.spacing16),
      child: Center(
        child: Text('Shipping information will be shown here'),
      ),
    );
  }

  Widget _buildReturnsTab() {
    return const Padding(
      padding: EdgeInsets.all(AppTheme.spacing16),
      child: Center(
        child: Text('Return policy will be shown here'),
      ),
    );
  }

  Widget _buildBrandInfo() {
    if (widget.product.brandId == null || widget.product.brandId!.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(
          color: AppTheme.primaryOrange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.business,
                color: AppTheme.primaryOrange,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Brand',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            widget.product.brandId!,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryOrange,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailedDescription() {
    if (widget.product.detailedDescription.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detailed Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            widget.product.detailedDescription,
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStockStatusSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stock',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          _buildStockStatus(),
        ],
      ),
    );
  }

  Widget _buildRelatedProducts() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You might also like',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5, // Mock related products
              itemBuilder: (context, index) {
                return Container(
                  width: 150,
                  margin: const EdgeInsets.only(right: 12),
                  child: Card(
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.shopping_bag_outlined),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              Text(
                                'Related Product ${index + 1}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const Text(
                                '₱299',
                                style: TextStyle(
                                  color: AppTheme.primaryOrange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Chat button
            OutlinedButton.icon(
              onPressed: _chatWithSeller,
              icon: const Icon(Icons.chat_outlined, size: 20),
              label: const Text('Chat'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            
            const SizedBox(width: AppTheme.spacing12),
            
            // Add to cart button
            Expanded(
              child: ElevatedButton(
                onPressed: (widget.product.totalStock > 0 ? widget.product.totalStock : widget.product.stockQty) > 0 && !_isAddingToCart
                    ? _addToCart
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isAddingToCart
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Add to Cart',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, color: Colors.amber, size: 16);
        } else if (index < rating) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 16);
        } else {
          return const Icon(Icons.star_border, color: Colors.amber, size: 16);
        }
      }),
    );
  }

  // Event handlers
  void _toggleFavorite() {
    HapticFeedback.lightImpact();
    setState(() {
      _isFavorite = !_isFavorite;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFavorite ? 'Added to favorites' : 'Removed from favorites'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _shareProduct() {
    HapticFeedback.lightImpact();
    // Implement sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality will be implemented')),
    );
  }

  void _showImageViewer(int initialIndex) {
    // Navigate to full-screen image viewer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ImageViewerScreen(
          images: widget.product.imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _addToCart() async {
    final availableStock = widget.product.totalStock > 0 ? widget.product.totalStock : widget.product.stockQty;
    if (availableStock <= 0) return;
    
    setState(() {
      _isAddingToCart = true;
    });
    
    HapticFeedback.lightImpact();
    
    // Track add to cart event
    ProductAnalyticsService.trackAddToCart(
      widget.product.id,
      variantId: _selectedVariant?.id,
      quantity: _quantity,
    );
    
    // Prepare variant data
    String? selectedVariantId;
    Map<String, String>? selectedOptions;
    String? variantSku;
    String? variantDisplayName;
    
    if (_selectedVariant != null) {
      selectedVariantId = _selectedVariant!.id;
      selectedOptions = Map<String, String>.from(_selectedVariant!.optionValues);
      variantSku = _selectedVariant!.sku;
      variantDisplayName = _selectedVariant!.variantDisplayName;
    }
    
    // Actually add to cart
    await CartService.addToCart(
      widget.product, 
      quantity: _quantity,
      selectedVariantId: selectedVariantId,
      selectedOptions: selectedOptions,
      variantSku: variantSku,
      variantDisplayName: variantDisplayName,
    );
    
    setState(() {
      _isAddingToCart = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.product.title} (x$_quantity) added to cart!'),
          backgroundColor: AppTheme.successGreen,
          action: SnackBarAction(
            label: 'View Cart',
            onPressed: () {
              // Navigate to cart
            },
          ),
        ),
      );
    }
  }

  void _chatWithSeller() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat feature will be implemented')),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _imagePageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// Full-screen image viewer
class _ImageViewerScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _ImageViewerScreen({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} of ${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: Image.network(
                widget.images[index],
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.error,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}