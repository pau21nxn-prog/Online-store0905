import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../common/theme.dart';
import '../../models/product.dart';
import '../../models/review.dart';
import '../../services/cart_service.dart';
import '../../services/reviews_service.dart';
import '../../widgets/wishlist_button.dart';
import '../reviews/product_reviews_screen.dart';
import '../reviews/add_review_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  bool _isAddingToCart = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            actions: [
              // Wishlist Button in App Bar
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: WishlistButton(
                    product: widget.product,
                    size: 24,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'product-${widget.product.id}',
                child: Container(
                  color: Colors.grey.shade100,
                  child: widget.product.imageUrls.isNotEmpty
                      ? Image.network(
                          widget.product.imageUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text('Image not available', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                        )
                      : const Center(
                          child: Icon(Icons.shopping_bag, size: 100, color: Colors.grey),
                        ),
                ),
              ),
            ),
          ),

          // Product Details
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name & Price
                      Text(
                        widget.product.name,
                        style: AppTheme.titleStyle.copyWith(fontSize: 24),
                      ),
                      const SizedBox(height: AppTheme.spacing8),
                      
                      Row(
                        children: [
                          Text(
                            widget.product.formattedPrice,
                            style: AppTheme.priceStyle.copyWith(fontSize: 28),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacing12,
                              vertical: AppTheme.spacing4,
                            ),
                            decoration: BoxDecoration(
                              color: widget.product.stockQty > 0 
                                  ? AppTheme.successGreen.withOpacity(0.1)
                                  : AppTheme.errorRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radius8),
                            ),
                            child: Text(
                              widget.product.stockQty > 0 
                                  ? 'In Stock (${widget.product.stockQty})'
                                  : 'Out of Stock',
                              style: TextStyle(
                                color: widget.product.stockQty > 0 
                                    ? AppTheme.successGreen
                                    : AppTheme.errorRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: AppTheme.spacing24),
                      
                      // Wishlist Section
                      _buildWishlistSection(),
                      
                      const SizedBox(height: AppTheme.spacing24),
                      
                      // Description
                      Text(
                        'Description',
                        style: AppTheme.subtitleStyle.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: AppTheme.spacing8),
                      Text(
                        widget.product.description,
                        style: AppTheme.bodyStyle.copyWith(
                          height: 1.6,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      
                      const SizedBox(height: AppTheme.spacing24),
                      
                      // Features (Mock data for now)
                      Text(
                        'Features',
                        style: AppTheme.subtitleStyle.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: AppTheme.spacing12),
                      
                      ..._buildFeaturesList(),
                      
                      const SizedBox(height: AppTheme.spacing24),
                      
                      // Quantity Selector
                      Text(
                        'Quantity',
                        style: AppTheme.subtitleStyle.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: AppTheme.spacing12),
                      
                      Row(
                        children: [
                          _buildQuantityButton(
                            Icons.remove,
                            () {
                              if (_quantity > 1) {
                                setState(() => _quantity--);
                              }
                            },
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacing24,
                              vertical: AppTheme.spacing12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(AppTheme.radius8),
                            ),
                            child: Text(
                              _quantity.toString(),
                              style: AppTheme.bodyStyle.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _buildQuantityButton(
                            Icons.add,
                            () {
                              if (_quantity < widget.product.stockQty) {
                                setState(() => _quantity++);
                              }
                            },
                          ),
                          const Spacer(),
                          Text(
                            'Total: ₱${(widget.product.price * _quantity).toStringAsFixed(2)}',
                            style: AppTheme.priceStyle.copyWith(fontSize: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Reviews Section
                _buildReviewsSection(),
                
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Related Products Section (Coming Soon)
                      Text(
                        'You may also like',
                        style: AppTheme.subtitleStyle.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: AppTheme.spacing12),
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(AppTheme.radius8),
                        ),
                        child: const Center(
                          child: Text(
                            'Related products coming soon!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      
                      // Bottom spacing for the floating button
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      
      // Bottom Action Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Add to Cart Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.product.stockQty > 0 && !_isAddingToCart
                      ? _addToCart
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                  ),
                  icon: _isAddingToCart
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.shopping_cart, color: Colors.white),
                  label: Text(
                    _isAddingToCart
                        ? 'Adding...'
                        : widget.product.stockQty > 0
                            ? 'Add to Cart ($_quantity)'
                            : 'Out of Stock',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: AppTheme.spacing12),
              
              // Buy Now Button
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.product.stockQty > 0 ? _buyNow : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                  ),
                  child: const Text(
                    'Buy Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Wishlist Section Widget
  Widget _buildWishlistSection() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.favorite_border,
            color: AppTheme.primaryOrange,
            size: 24,
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Love this product?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Save it to your wishlist for later',
                  style: AppTheme.captionStyle,
                ),
              ],
            ),
          ),
          WishlistButton(
            product: widget.product,
            size: 24,
            showLabel: true,
          ),
        ],
      ),
    );
  }

  // Reviews Section Widget
  Widget _buildReviewsSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: ReviewsService.getProductRatingSummary(widget.product.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data!;
        final averageRating = data['averageRating'] as double;
        final totalReviews = data['totalReviews'] as int;

        return Container(
          margin: const EdgeInsets.all(AppTheme.spacing16),
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reviews & Ratings',
                    style: AppTheme.titleStyle.copyWith(fontSize: 18),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductReviewsScreen(product: widget.product),
                        ),
                      );
                    },
                    child: const Text('See All'),
                  ),
                ],
              ),
              
              if (totalReviews > 0) ...[
                const SizedBox(height: AppTheme.spacing12),
                Row(
                  children: [
                    Text(
                      averageRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStarRating(averageRating),
                    const SizedBox(width: 8),
                    Text(
                      '($totalReviews review${totalReviews != 1 ? 's' : ''})',
                      style: AppTheme.captionStyle,
                    ),
                  ],
                ),
                
                const SizedBox(height: AppTheme.spacing16),
                
                // Recent Reviews Preview
                StreamBuilder<List<Review>>(
                  stream: ReviewsService.getProductReviews(widget.product.id),
                  builder: (context, reviewSnapshot) {
                    if (!reviewSnapshot.hasData || reviewSnapshot.data!.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final recentReviews = reviewSnapshot.data!.take(2).toList();
                    
                    return Column(
                      children: [
                        ...recentReviews.map((review) => _buildReviewPreview(review)),
                        if (reviewSnapshot.data!.length > 2) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProductReviewsScreen(product: widget.product),
                                  ),
                                );
                              },
                              child: Text('View all ${reviewSnapshot.data!.length} reviews'),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ] else ...[
                const SizedBox(height: AppTheme.spacing12),
                const Text('No reviews yet. Be the first to review!'),
                const SizedBox(height: AppTheme.spacing12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please sign in to write a review')),
                        );
                        return;
                      }

                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddReviewScreen(product: widget.product),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryOrange,
                      side: BorderSide(color: AppTheme.primaryOrange),
                    ),
                    child: const Text('Write the First Review'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStarRating(double rating) {
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

  Widget _buildReviewPreview(Review review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                review.userName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              _buildReviewStarRating(review.rating.toDouble(), 14),
              const Spacer(),
              if (review.isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: const Text(
                    'Verified',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            review.comment,
            style: AppTheme.captionStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStarRating(double rating, [double size = 16]) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(Icons.star, color: Colors.amber, size: size);
        } else if (index < rating) {
          return Icon(Icons.star_half, color: Colors.amber, size: size);
        } else {
          return Icon(Icons.star_border, color: Colors.amber, size: size);
        }
      }),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppTheme.radius8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(AppTheme.radius8),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }

  List<Widget> _buildFeaturesList() {
    // Mock features based on product category/type
    List<String> features = [];
    
    if (widget.product.name.toLowerCase().contains('phone')) {
      features = ['Latest processor', 'High-quality camera', '5G connectivity', 'Long battery life'];
    } else if (widget.product.name.toLowerCase().contains('buds') || 
               widget.product.name.toLowerCase().contains('earbuds')) {
      features = ['Noise cancellation', 'Wireless charging', 'Water resistant', 'Long playtime'];
    } else if (widget.product.name.toLowerCase().contains('shoes') || 
               widget.product.name.toLowerCase().contains('nike')) {
      features = ['Comfortable fit', 'Durable materials', 'Stylish design', 'All-day comfort'];
    } else {
      features = ['High quality', 'Durable construction', 'Great value', 'Customer favorite'];
    }
    
    return features.map((feature) => Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: AppTheme.successGreen,
            size: 20,
          ),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            feature,
            style: AppTheme.bodyStyle.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    )).toList();
  }

  Future<void> _addToCart() async {
    setState(() => _isAddingToCart = true);
    
    try {
      await CartService.addToCart(widget.product, quantity: _quantity);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.product.name} (x$_quantity) added to cart!'),
            backgroundColor: AppTheme.successGreen,
            action: SnackBarAction(
              label: 'View Cart',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pop(context);
                // Navigate to cart tab
                // Note: This assumes you have a way to control the main navigation
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding to cart: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingToCart = false);
      }
    }
  }

  void _buyNow() {
    // For now, add to cart and show checkout dialog
    _addToCart().then((_) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Quick Checkout'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${widget.product.name} (x$_quantity)'),
                const SizedBox(height: 8),
                Text(
                  'Total: ₱${(widget.product.price * _quantity + 99).toStringAsFixed(2)}',
                  style: AppTheme.priceStyle,
                ),
                const SizedBox(height: 8),
                const Text('(Including ₱99.00 shipping)'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Order placed! Checkout functionality coming soon.'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                },
                child: const Text('Place Order'),
              ),
            ],
          ),
        );
      }
    });
  }
}