import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../common/theme.dart';
import '../../models/product.dart';
import '../../models/cart_item.dart';
import '../../models/variant_option.dart';
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
  
  // Variant selection state
  Map<String, String> _selectedVariantOptions = {};
  VariantConfiguration? _selectedVariantConfiguration;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _quantityController = TextEditingController(text: _quantity.toString());
    _initializeVariantSelection();
  }
  
  void _initializeVariantSelection() {
    if (widget.product.hasCustomizableVariants && widget.product.activeVariantConfigurations.isNotEmpty) {
      // Select the first available variant configuration by default
      _selectedVariantConfiguration = widget.product.activeVariantConfigurations.first;
      _selectedVariantOptions = Map.from(_selectedVariantConfiguration!.attributeValues);
    }
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
                      
                      // Price Display with strikethrough for base price and sale price
                      Row(
                        children: [
                          // Show original price (striked) if there's a sale price
                          if (widget.product.hasDiscount && widget.product.originalPrice > widget.product.price) ...[
                            Text(
                              '₱${widget.product.originalPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 20,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          // Current selling price (sale price or base price)
                          Text(
                            _selectedVariantConfiguration?.formattedPrice ?? widget.product.formattedPrice,
                            style: AppTheme.priceStyle.copyWith(fontSize: 28),
                          ),
                          if (_selectedVariantConfiguration?.hasDiscount == true) ...[
                            const SizedBox(width: 8),
                            Text(
                              _selectedVariantConfiguration!.formattedCompareAtPrice,
                              style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: AppTheme.textSecondary,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ],
                      ),
                      
                      const SizedBox(height: AppTheme.spacing16),
                      
                      // Short Description  
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
                      
                      // Variant Selection
                      if (widget.product.hasCustomizableVariants) ...[
                        ..._buildVariantSelectors(),
                        const SizedBox(height: AppTheme.spacing24),
                      ],
                      
                      // Stock Information
                      Text(
                        'Stock',
                        style: AppTheme.subtitleStyle.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: AppTheme.spacing8),
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacing12),
                        decoration: BoxDecoration(
                          color: _getAvailableStock() > 0 
                              ? AppTheme.successGreen.withOpacity(0.1)
                              : AppTheme.errorRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radius8),
                          border: Border.all(
                            color: _getAvailableStock() > 0 
                                ? AppTheme.successGreen.withOpacity(0.3)
                                : AppTheme.errorRed.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getAvailableStock() > 0 ? Icons.check_circle : Icons.error,
                              color: _getAvailableStock() > 0 
                                  ? AppTheme.successGreen
                                  : AppTheme.errorRed,
                              size: 20,
                            ),
                            const SizedBox(width: AppTheme.spacing8),
                            Text(
                              _getAvailableStock() > 0 
                                  ? '${_getAvailableStock()} units available'
                                  : 'Out of Stock',
                              style: TextStyle(
                                color: _getAvailableStock() > 0 
                                    ? AppTheme.successGreen
                                    : AppTheme.errorRed,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
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
                              if (_quantity < _getAvailableStock()) {
                                setState(() {
                                  _quantity++;
                                  _quantityController.text = _quantity.toString();
                                });
                              }
                            },
                          ),
                          const Spacer(),
                          Text(
                            'Total: ₱${(_getCurrentPrice() * _quantity).toStringAsFixed(2)}',
                            style: AppTheme.priceStyle.copyWith(fontSize: 20),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: AppTheme.spacing24),
                      
                      // Brand Information
                      if (widget.product.brandId != null && widget.product.brandId!.isNotEmpty) ...[
                        Text(
                          'Brand',
                          style: AppTheme.subtitleStyle.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: AppTheme.spacing8),
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spacing12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radius8),
                            border: Border.all(
                              color: AppTheme.primaryOrange.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.business,
                                color: AppTheme.primaryOrange,
                                size: 20,
                              ),
                              const SizedBox(width: AppTheme.spacing8),
                              Text(
                                widget.product.brandId!,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing24),
                      ],
                      
                      // Detailed Description
                      if (widget.product.detailedDescription.isNotEmpty) ...[
                        Text(
                          'Detailed Information',
                          style: AppTheme.subtitleStyle.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: AppTheme.spacing8),
                        Text(
                          widget.product.detailedDescription,
                          style: AppTheme.bodyStyle.copyWith(
                            height: 1.6,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing24),
                      ],
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
                  onPressed: _getAvailableStock() > 0 && !_isAddingToCart
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
                        : _getAvailableStock() > 0
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
                  onPressed: _getAvailableStock() > 0 ? _buyNow : null,
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
          if (newQuantity != null && newQuantity > 0 && newQuantity <= _getAvailableStock()) {
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
    final availableStock = _getAvailableStock();
    if (newQuantity > 0 && newQuantity <= availableStock) {
      setState(() {
        _quantity = newQuantity;
        _quantityController.text = _quantity.toString();
      });
    } else {
      // Reset to valid value
      setState(() {
        _quantityController.text = _quantity.toString();
      });
      if (newQuantity > availableStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maximum quantity available: $availableStock'),
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

  List<Widget> _buildVariantSelectors() {
    if (!widget.product.hasCustomizableVariants || widget.product.activeVariantAttributes.isEmpty) {
      return [];
    }

    List<Widget> selectors = [];

    for (final attribute in widget.product.activeVariantAttributes) {
      selectors.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  attribute.type.icon,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  attribute.name,
                  style: AppTheme.subtitleStyle.copyWith(fontSize: 16),
                ),
                if (attribute.isRequired)
                  const Text(
                    ' *',
                    style: TextStyle(color: AppTheme.errorRed),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildVariantAttributeSelector(attribute),
            const SizedBox(height: 20),
          ],
        ),
      );
    }

    // Show selected variant info if available
    if (_selectedVariantConfiguration != null) {
      selectors.add(
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            border: Border.all(
              color: AppTheme.primaryOrange.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppTheme.primaryOrange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Selected Variant',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _selectedVariantConfiguration!.displayName,
                style: AppTheme.bodyStyle.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    _selectedVariantConfiguration!.formattedPrice,
                    style: AppTheme.priceStyle.copyWith(fontSize: 18),
                  ),
                  if (_selectedVariantConfiguration!.hasDiscount) ...[
                    const SizedBox(width: 8),
                    Text(
                      _selectedVariantConfiguration!.formattedCompareAtPrice,
                      style: TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedVariantConfiguration!.isInStock
                          ? AppTheme.successGreen.withOpacity(0.1)
                          : AppTheme.errorRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _selectedVariantConfiguration!.isInStock
                          ? '${_selectedVariantConfiguration!.quantity} in stock'
                          : 'Out of stock',
                      style: TextStyle(
                        color: _selectedVariantConfiguration!.isInStock
                            ? AppTheme.successGreen
                            : AppTheme.errorRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return selectors;
  }

  Widget _buildVariantAttributeSelector(VariantAttribute attribute) {
    final selectedValue = _selectedVariantOptions[attribute.id];

    if (attribute.type == VariantAttributeType.color) {
      return _buildColorSelector(attribute, selectedValue);
    } else {
      return _buildTextSelector(attribute, selectedValue);
    }
  }

  Widget _buildColorSelector(VariantAttribute attribute, String? selectedValue) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: attribute.activeValues.map((value) {
        final isSelected = selectedValue == value.value;
        final color = value.color;

        return GestureDetector(
          onTap: () => _onVariantOptionSelected(attribute.id, value.value),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color ?? Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppTheme.primaryOrange : Colors.grey.shade400,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryOrange.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: color == null
                ? Center(
                    child: Text(
                      value.value.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextSelector(VariantAttribute attribute, String? selectedValue) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: attribute.activeValues.map((value) {
        final isSelected = selectedValue == value.value;

        return GestureDetector(
          onTap: () => _onVariantOptionSelected(attribute.id, value.value),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryOrange : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppTheme.primaryOrange : Colors.grey.shade400,
              ),
            ),
            child: Text(
              value.effectiveDisplayName,
              style: TextStyle(
                color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _onVariantOptionSelected(String attributeId, String value) {
    setState(() {
      _selectedVariantOptions[attributeId] = value;
      _updateSelectedVariantConfiguration();
    });
  }

  void _updateSelectedVariantConfiguration() {
    // Find the variant configuration that matches all selected options
    final matchingConfiguration = widget.product.activeVariantConfigurations.firstWhere(
      (config) {
        // Check if this configuration matches all selected options
        for (final entry in _selectedVariantOptions.entries) {
          if (config.attributeValues[entry.key] != entry.value) {
            return false;
          }
        }
        return true;
      },
      orElse: () => widget.product.activeVariantConfigurations.isNotEmpty
          ? widget.product.activeVariantConfigurations.first
          : widget.product.defaultVariantConfiguration!,
    );

    _selectedVariantConfiguration = matchingConfiguration;
    
    // Reset quantity if it exceeds the new stock limit
    if (_quantity > _getAvailableStock()) {
      _quantity = 1;
      _quantityController.text = _quantity.toString();
    }
  }

  int _getAvailableStock() {
    if (_selectedVariantConfiguration != null) {
      return _selectedVariantConfiguration!.quantity;
    }
    // Use totalStock from product data, fallback to stockQty for compatibility
    return widget.product.totalStock > 0 ? widget.product.totalStock : widget.product.stockQty;
  }

  double _getCurrentPrice() {
    if (_selectedVariantConfiguration != null) {
      return _selectedVariantConfiguration!.price;
    }
    return widget.product.price;
  }
}