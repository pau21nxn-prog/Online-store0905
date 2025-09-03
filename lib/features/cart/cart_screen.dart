import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/cart_item.dart';
import '../../services/cart_service.dart';
import '../../services/payment_service.dart';
import '../../common/theme.dart';
import '../../common/mobile_layout_utils.dart';
import '../auth/checkout_auth_modal.dart';
import '../checkout/checkout_screen.dart';
import '../checkout/guest_checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

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
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: _buildAppBar(context),
      body: _buildBodyContent(context),
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    return StreamBuilder<List<CartItem>>(
      stream: CartService.getCartItems(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(context);
        }

        final cartItems = snapshot.data ?? [];
        return cartItems.isEmpty 
            ? _buildEmptyCart(context) 
            : _buildCartWithItems(context, cartItems);
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        'My Cart',
        style: TextStyle(
          color: AppTheme.textPrimaryColor(context),
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: AppTheme.backgroundColor(context),
      foregroundColor: AppTheme.textPrimaryColor(context),
      elevation: 0,
      actions: [
        StreamBuilder<List<CartItem>>(
          stream: CartService.getCartItems(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox();
            }
            return SizedBox.shrink(); // Clear All button removed
          },
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppTheme.primaryOrange),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading cart',
            style: TextStyle(
              fontSize: 18,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              (context as Element).reassemble();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
            ),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 120,
              color: AppTheme.textSecondaryColor(context),
            ),
            const SizedBox(height: 24),
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add some items to get started!',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondaryColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to home screen using MainNavigationScreen
                // Find the MainNavigationScreen and call its navigation method
                Navigator.of(context).popUntil((route) => route.isFirst);
                
                // Alternative: Use a more direct approach to ensure we get to home
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
                
                // If we're in a nested navigator, this will ensure we get back to the main app
                Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.shopping_bag),
              label: const Text(
                'Start Shopping',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartWithItems(BuildContext context, List<CartItem> cartItems) {
    final calculations = _calculateTotals(cartItems);

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cartItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildCartItem(context, cartItems[index]);
            },
          ),
        ),
        _buildCartSummary(context, cartItems, calculations),
      ],
    );
  }

  Widget _buildCartItem(BuildContext context, CartItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade700
              : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 80,
                    height: 80,
                    color: AppTheme.surfaceColor(context),
                    child: Icon(
                      Icons.image_not_supported,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            
            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Variant information
                  if (item.variantDisplayName != null) ...[
                    Text(
                      item.variantDisplayName!,
                      style: TextStyle(
                        color: AppTheme.primaryOrange,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  // SKU information
                  if (item.variantSku != null) ...[
                    Text(
                      'SKU: ${item.variantSku!}',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    PaymentService.formatCurrency(item.price),
                    style: const TextStyle(
                      color: AppTheme.primaryOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Quantity Controls
                  Row(
                    children: [
                      _buildQuantityButton(
                        context,
                        Icons.remove,
                        item.quantity > 1 
                            ? () => CartService.updateQuantity(item.getCartKey(), item.quantity - 1)
                            : null,
                      ),
                      
                      _buildQuantityTextField(context, item),
                      
                      _buildQuantityButton(
                        context,
                        Icons.add,
                        () => CartService.updateQuantity(item.getCartKey(), item.quantity + 1),
                      ),
                      
                      const Spacer(),
                      
                      // Delete button
                      IconButton(
                        onPressed: () => _showRemoveItemDialog(context, item),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Remove item',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityTextField(BuildContext context, CartItem item) {
    final controller = TextEditingController(text: '${item.quantity}');
    
    return Container(
      width: 50,
      height: 32,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade600
              : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppTheme.textPrimaryColor(context),
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
        onFieldSubmitted: (value) {
          final newQuantity = int.tryParse(value) ?? item.quantity;
          if (newQuantity > 0 && newQuantity != item.quantity) {
            CartService.updateQuantity(item.getCartKey(), newQuantity);
          } else if (newQuantity <= 0) {
            // Reset to original quantity if invalid
            controller.text = '${item.quantity}';
          }
        },
        onEditingComplete: () {
          final newQuantity = int.tryParse(controller.text) ?? item.quantity;
          if (newQuantity > 0 && newQuantity != item.quantity) {
            CartService.updateQuantity(item.getCartKey(), newQuantity);
          } else if (newQuantity <= 0) {
            // Reset to original quantity if invalid
            controller.text = '${item.quantity}';
          }
        },
      ),
    );
  }

  Widget _buildQuantityButton(
    BuildContext context,
    IconData icon,
    VoidCallback? onPressed,
  ) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade600
              : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(4),
        color: AppTheme.surfaceColor(context),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 16,
          color: onPressed != null 
              ? AppTheme.textPrimaryColor(context)
              : AppTheme.textSecondaryColor(context),
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildCartSummary(
    BuildContext context,
    List<CartItem> cartItems,
    Map<String, double> calculations,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black26
                : Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow(
              context,
              'Subtotal (${cartItems.length} items):',
              calculations['subtotal']!,
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              context,
              'Shipping Fee:',
              calculations['shipping']!,
            ),
            Divider(
              height: 24,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade600
                  : Colors.grey.shade300,
            ),
            _buildSummaryRow(
              context,
              'Total:',
              calculations['total']!,
              isTotal: true,
            ),
            const SizedBox(height: 16),
            
            // Checkout button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _handleCheckout(context, cartItems, calculations),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Proceed to Checkout - ${PaymentService.formatCurrency(calculations['total']!)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String label,
    double amount, {
    bool isTotal = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const Spacer(),
        Text(
          PaymentService.formatCurrency(amount),
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? AppTheme.primaryOrange : AppTheme.textPrimaryColor(context),
          ),
        ),
      ],
    );
  }

  // Helper method to calculate totals
  Map<String, double> _calculateTotals(List<CartItem> cartItems) {
    final subtotal = cartItems.fold<double>(
      0, 
      (sum, item) => sum + (item.price * item.quantity),
    );
    
    final totalWeight = cartItems.fold<double>(
      0, 
      (sum, item) => sum + (item.quantity * 0.5), // Assume 0.5kg per item
    );
    
    final shipping = PaymentService.calculateShippingFee(
      city: 'Quezon City',
      province: 'Metro Manila',
      totalWeight: totalWeight,
    );
    
    final total = subtotal + shipping;

    return {
      'subtotal': subtotal,
      'shipping': shipping,
      'total': total,
    };
  }

  // Handle checkout with authentication
  void _handleCheckout(
    BuildContext context,
    List<CartItem> cartItems,
    Map<String, double> calculations,
  ) {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser != null) {
      // User is logged in, go directly to checkout
      _navigateToCheckout(context, cartItems, calculations);
    } else {
      // User is not logged in, show authentication modal
      // Convert CartItem list to Map format for compatibility
      final cartItemsMap = cartItems.map((item) => {
        'productId': item.productId,
        'name': item.productName, // Use 'name' key to match guest checkout expectations
        'price': item.price,
        'quantity': item.quantity,
        'imageUrl': item.imageUrl,
        'variantSku': item.variantSku,
        'variantDisplayName': item.variantDisplayName,
        'selectedOptions': item.selectedOptions,
      }).toList();

      showDialog(
        context: context,
        builder: (context) => CheckoutAuthModal(
          cartItems: cartItemsMap,
          totalAmount: calculations['total']!,
        ),
      );
    }
  }

  void _navigateToCheckout(
    BuildContext context,
    List<CartItem> cartItems,
    Map<String, double> calculations,
  ) {
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

  void _showRemoveItemDialog(BuildContext context, CartItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        title: Text(
          'Remove Item',
          style: TextStyle(color: AppTheme.textPrimaryColor(context)),
        ),
        content: Text(
          'Remove ${item.productName} from your cart?',
          style: TextStyle(color: AppTheme.textSecondaryColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondaryColor(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              CartService.removeFromCart(item.getCartKey());
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${item.productName} removed from cart'),
                  backgroundColor: AppTheme.primaryOrange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // Clear cart dialog removed as Clear All button was removed
}