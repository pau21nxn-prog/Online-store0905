import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../common/theme.dart';
import '../../models/wishlist_item.dart';
import '../../models/product.dart';
import '../../services/wishlist_service.dart';
import '../../services/cart_service.dart';
import '../product/product_detail_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  bool _isMovingToCart = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _buildSignInPrompt();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wishlist'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'move_all',
                child: Row(
                  children: [
                    Icon(Icons.shopping_cart, size: 16),
                    SizedBox(width: 8),
                    Text('Move All to Cart'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear Wishlist', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<WishlistItem>>(
        stream: WishlistService.getUserWishlist(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading wishlist: ${snapshot.error}'),
            );
          }

          final wishlistItems = snapshot.data ?? [];

          if (wishlistItems.isEmpty) {
            return _buildEmptyWishlist();
          }

          return Column(
            children: [
              // Wishlist Summary
              _buildWishlistSummary(wishlistItems),
              
              // Wishlist Items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  itemCount: wishlistItems.length,
                  itemBuilder: (context, index) {
                    return _buildWishlistCard(wishlistItems[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSignInPrompt() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wishlist'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                'Sign in to view your wishlist',
                style: AppTheme.titleStyle.copyWith(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacing8),
              Text(
                'Save your favorite products and shop them later',
                style: AppTheme.bodyStyle.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacing32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please sign in to view your wishlist'),
                        backgroundColor: AppTheme.primaryOrange,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Sign In',
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

  Widget _buildEmptyWishlist() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              'Your wishlist is empty',
              style: AppTheme.titleStyle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              'Save products you love to buy them later',
              style: AppTheme.bodyStyle.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing32),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing24,
                  vertical: AppTheme.spacing12,
                ),
              ),
              child: const Text('Start Shopping'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWishlistSummary(List<WishlistItem> items) {
    final availableItems = items.where((item) => item.isAvailable).length;
    final totalValue = items.fold<double>(0, (sum, item) => sum + item.price);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      margin: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryOrange.withOpacity(0.1),
            AppTheme.secondaryOrange.withOpacity(0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${items.length} item${items.length != 1 ? 's' : ''} saved',
                  style: AppTheme.titleStyle.copyWith(
                    color: AppTheme.primaryOrange,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total value: ₱${totalValue.toStringAsFixed(2)}',
                  style: AppTheme.bodyStyle.copyWith(color: Colors.grey[700]),
                ),
                if (availableItems < items.length) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${items.length - availableItems} item${items.length - availableItems != 1 ? 's' : ''} unavailable',
                    style: AppTheme.captionStyle.copyWith(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
          if (availableItems > 0)
            ElevatedButton.icon(
              onPressed: _isMovingToCart ? null : _moveAllToCart,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
              ),
              icon: _isMovingToCart
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.shopping_cart, size: 16),
              label: Text(_isMovingToCart ? 'Adding...' : 'Add All'),
            ),
        ],
      ),
    );
  }

  Widget _buildWishlistCard(WishlistItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: InkWell(
        onTap: () => _navigateToProduct(item.productId),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          child: Row(
            children: [
              // Product Image
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                child: Image.network(
                  item.imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported),
                    );
                  },
                ),
              ),
              
              const SizedBox(width: AppTheme.spacing12),
              
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: AppTheme.bodyStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.formattedPrice,
                      style: AppTheme.priceStyle.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: item.isAvailable
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.isAvailable ? 'Available' : 'Unavailable',
                            style: TextStyle(
                              color: item.isAvailable ? Colors.green : Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          item.formattedDate,
                          style: AppTheme.captionStyle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Action Buttons
              Column(
                children: [
                  if (item.isAvailable)
                    IconButton(
                      onPressed: () => _addToCart(item),
                      icon: const Icon(Icons.shopping_cart),
                      color: AppTheme.primaryOrange,
                      tooltip: 'Add to Cart',
                    ),
                  IconButton(
                    onPressed: () => _removeFromWishlist(item),
                    icon: const Icon(Icons.delete),
                    color: Colors.red,
                    tooltip: 'Remove from Wishlist',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addToCart(WishlistItem item) async {
    try {
      // Create a mock product object for the cart service
      // In a real app, you might want to fetch the full product details
      final productData = {
        'id': item.productId,
        'name': item.productName,
        'price': item.price,
        'imageUrls': [item.imageUrl],
        'stockQty': 1, // Assume available
        'isActive': true,
        'description': '',
        'categoryId': '',
        'createdAt': DateTime.now(),
      };

      // Note: You might want to create a method in CartService that accepts individual parameters
      // For now, we'll add it directly to Firestore
      final user = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance
          .collection('carts')
          .doc(user.uid)
          .collection('items')
          .add({
        'productId': item.productId,
        'productName': item.productName,
        'price': item.price,
        'imageUrl': item.imageUrl,
        'quantity': 1,
        'addedAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.productName} added to cart!'),
          backgroundColor: AppTheme.successGreen,
          action: SnackBarAction(
            label: 'Remove from Wishlist',
            textColor: Colors.white,
            onPressed: () => _removeFromWishlist(item),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding to cart: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _removeFromWishlist(WishlistItem item) async {
    try {
      await WishlistService.removeFromWishlist(item.productId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.productName} removed from wishlist'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing from wishlist: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _moveAllToCart() async {
    setState(() {
      _isMovingToCart = true;
    });

    try {
      final itemsAdded = await WishlistService.moveAllToCart();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$itemsAdded item${itemsAdded != 1 ? 's' : ''} added to cart!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error moving items to cart: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      setState(() {
        _isMovingToCart = false;
      });
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'move_all':
        _moveAllToCart();
        break;
      case 'clear_all':
        _clearWishlist();
        break;
    }
  }

  Future<void> _clearWishlist() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Wishlist'),
        content: const Text('Are you sure you want to remove all items from your wishlist? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await WishlistService.clearWishlist();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wishlist cleared successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing wishlist: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _navigateToProduct(String productId) async {
    try {
      // Fetch the product by ID from Firestore
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();

      if (productDoc.exists && mounted) {
        final product = Product.fromFirestore(productDoc.id, productDoc.data()!);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: product),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product not found or no longer available'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading product: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }
}