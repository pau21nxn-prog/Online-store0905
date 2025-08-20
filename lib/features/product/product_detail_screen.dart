import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../common/theme.dart';
import '../../models/product.dart';
import '../../models/cart_item.dart';
import '../../services/cart_service.dart';
// Wishlist import removed
import '../auth/checkout_auth_modal.dart';
import '../checkout/checkout_screen.dart';
import '../cart/cart_screen.dart';

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
  int _currentImageIndex = 0;
  late PageController _pageController;
  late TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _quantityController = TextEditingController(text: _quantity.toString());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: Theme.of(context).iconTheme.color,
            actions: [
              // Wishlist Button in App Bar
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SizedBox.shrink(), // Wishlist button removed
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'product-${widget.product.id}',
                child: Container(
                  color: Theme.of(context).cardColor,
                  child: widget.product.imageUrls.isNotEmpty
                      ? Stack(
                          children: [
                            // Image PageView
                            PageView.builder(
                              controller: _pageController,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentImageIndex = index;
                                });
                              },
                              itemCount: widget.product.imageUrls.length,
                              itemBuilder: (context, index) {
                                return Image.network(
                                  widget.product.imageUrls[index],
                                  fit: BoxFit.contain, // Show true size without distortion
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.image_not_supported, size: 80, color: Theme.of(context).iconTheme.color?.withOpacity(0.5)),
                                          const SizedBox(height: 16),
                                          Text('Image not available', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5))),
                                        ],
                                      ),
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(child: CircularProgressIndicator());
                                  },
                                );
                              },
                            ),
                            
                            // Navigation arrows
                            if (widget.product.imageUrls.length > 1) ...[
                              // Left arrow
                              Positioned(
                                left: 16,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                                      onPressed: _currentImageIndex > 0
                                          ? () {
                                              _pageController.previousPage(
                                                duration: const Duration(milliseconds: 300),
                                                curve: Curves.easeInOut,
                                              );
                                            }
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                              
                              // Right arrow
                              Positioned(
                                right: 16,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.chevron_right, color: Colors.white),
                                      onPressed: _currentImageIndex < widget.product.imageUrls.length - 1
                                          ? () {
                                              _pageController.nextPage(
                                                duration: const Duration(milliseconds: 300),
                                                curve: Curves.easeInOut,
                                              );
                                            }
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            
                            // Image indicators
                            if (widget.product.imageUrls.length > 1)
                              Positioned(
                                bottom: 16,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    widget.product.imageUrls.length,
                                    (index) => Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _currentImageIndex == index
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.5),
                                        border: Border.all(
                                          color: Colors.black.withOpacity(0.3),
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            
                            // Image counter
                            if (widget.product.imageUrls.length > 1)
                              Positioned(
                                top: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    '${_currentImageIndex + 1} / ${widget.product.imageUrls.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Center(
                          child: Icon(Icons.shopping_bag, size: 100, color: Theme.of(context).iconTheme.color?.withOpacity(0.5)),
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
                      
                      // Wishlist section removed
                      
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
                                setState(() {
                                  _quantity--;
                                  _quantityController.text = _quantity.toString();
                                });
                              }
                            },
                          ),
                          _buildQuantityTextField(),
                          _buildQuantityButton(
                            Icons.add,
                            () {
                              if (_quantity < widget.product.stockQty) {
                                setState(() {
                                  _quantity++;
                                  _quantityController.text = _quantity.toString();
                                });
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
                
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      
                      // Bottom spacing for the floating button
                      const SizedBox(height: 50),
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
          color: Theme.of(context).bottomNavigationBarTheme.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.2),
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

  // Wishlist section removed


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

  Widget _buildQuantityTextField() {
    return Container(
      width: 80,
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: TextFormField(
        controller: _quantityController,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: AppTheme.bodyStyle.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppTheme.spacing12,
            vertical: AppTheme.spacing12,
          ),
        ),
        onChanged: (value) {
          // Update quantity as user types
          final newQuantity = int.tryParse(value);
          if (newQuantity != null && newQuantity > 0 && newQuantity <= widget.product.stockQty) {
            setState(() => _quantity = newQuantity);
          }
        },
        onFieldSubmitted: (value) {
          _validateAndUpdateQuantity(value);
        },
        onEditingComplete: () {
          _validateAndUpdateQuantity(_quantityController.text);
        },
      ),
    );
  }

  void _validateAndUpdateQuantity(String value) {
    final newQuantity = int.tryParse(value) ?? _quantity;
    if (newQuantity > 0 && newQuantity <= widget.product.stockQty) {
      setState(() {
        _quantity = newQuantity;
        _quantityController.text = _quantity.toString();
      });
    } else {
      // Reset to valid value
      setState(() {
        _quantityController.text = _quantity.toString();
      });
      if (newQuantity > widget.product.stockQty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maximum quantity available: ${widget.product.stockQty}'),
            backgroundColor: Colors.orange,
          ),
        );
      } else if (newQuantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quantity must be at least 1'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
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
                // Navigate back to main screen and go to cart tab (index 2)
                Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
                
                // Small delay to ensure navigation completes, then trigger cart tab
                Future.delayed(const Duration(milliseconds: 100), () {
                  // Use named route to navigate to cart
                  Navigator.of(context).pushNamed('/cart');
                });
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

  void _buyNow() async {
    // Add to cart and show confirmation, then redirect to cart page
    setState(() => _isAddingToCart = true);
    
    try {
      await CartService.addToCart(widget.product, quantity: _quantity);
      
      if (mounted) {
        setState(() => _isAddingToCart = false);
        
        // Show confirmation message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.product.name} (x$_quantity) added to cart!'),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(milliseconds: 1000),
          ),
        );
        
        // Wait 1 second then navigate to cart page
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const CartScreen(),
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAddingToCart = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Map<String, double> _calculateCartTotals(List<CartItem> cartItems) {
    final subtotal = cartItems.fold<double>(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );
    final shipping = subtotal >= 500.0 ? 0.0 : 99.0; // Free shipping over ₱500
    final total = subtotal + shipping;
    
    return {
      'subtotal': subtotal,
      'shipping': shipping,
      'total': total,
    };
  }

  void _navigateToCheckout(List<CartItem> cartItems, Map<String, double> calculations) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          cartItems: cartItems,
          subtotal: calculations['subtotal']!,
          shipping: calculations['shipping']!,
          total: calculations['total']!,
        ),
      ),
    );
  }
}