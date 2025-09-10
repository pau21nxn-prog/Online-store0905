import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/cart_item.dart';
import '../../services/cart_service.dart';
import '../../services/payment_service.dart';
import '../../services/shipping_service.dart';
import '../../services/address_service.dart';
import '../../services/tab_navigation_service.dart';
import '../../common/theme.dart';
import '../../common/mobile_layout_utils.dart';
import '../auth/checkout_auth_modal.dart';
import '../checkout/checkout_screen.dart';
import '../../main.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // Track selected items by their cart keys
  Set<String> selectedItems = <String>{};
  bool selectAllState = true;
  bool _isInitialized = false;
  List<CartItem> _currentCartItems = [];

  @override
  void initState() {
    super.initState();
    _loadSavedSelections();
    _checkForCartClearingFailures();
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
        
        // Only initialize selection state once or when cart items change
        if (!_isInitialized || _cartItemsChanged(cartItems)) {
          _initializeSelection(cartItems);
          _currentCartItems = List.from(cartItems);
          _isInitialized = true;
        }
        
        return cartItems.isEmpty 
            ? _buildEmptyCart(context) 
            : _buildCartWithItems(context, cartItems);
      },
    );
  }

  bool _cartItemsChanged(List<CartItem> newItems) {
    if (_currentCartItems.length != newItems.length) return true;
    
    final oldKeys = _currentCartItems.map((item) => item.getCartKey()).toSet();
    final newKeys = newItems.map((item) => item.getCartKey()).toSet();
    
    return !oldKeys.containsAll(newKeys) || !newKeys.containsAll(oldKeys);
  }

  void _initializeSelection(List<CartItem> cartItems) {
    final currentKeys = cartItems.map((item) => item.getCartKey()).toSet();
    
    // Remove keys that are no longer in cart
    selectedItems.removeWhere((key) => !currentKeys.contains(key));
    
    // Add new items as selected (pre-select new items) only if they're truly new
    for (final item in cartItems) {
      final cartKey = item.getCartKey();
      if (!selectedItems.contains(cartKey) && !_currentCartItems.any((oldItem) => oldItem.getCartKey() == cartKey)) {
        selectedItems.add(cartKey);
      }
    }
    
    // Update selectAllState based on current selection
    selectAllState = cartItems.isNotEmpty && selectedItems.length == cartItems.length;
    
    // Save selections to prevent loss on rebuild
    _saveSelections();
  }

  Future<void> _loadSavedSelections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSelectionsJson = prefs.getString('cart_selections');
      
      if (savedSelectionsJson != null) {
        final savedSelections = jsonDecode(savedSelectionsJson) as List<dynamic>;
        selectedItems = savedSelections.cast<String>().toSet();
      }
    } catch (e) {
      debugPrint('Error loading saved selections: $e');
    }
  }

  Future<void> _saveSelections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cart_selections', jsonEncode(selectedItems.toList()));
    } catch (e) {
      debugPrint('Error saving selections: $e');
    }
  }

  Future<void> _clearSavedSelections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cart_selections');
    } catch (e) {
      debugPrint('Error clearing saved selections: $e');
    }
  }

  Future<void> _checkForCartClearingFailures() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      // Check for any cart clearing failure flags
      final failedOrderKeys = keys.where((key) => key.startsWith('cart_clearing_failed_')).toList();
      
      if (failedOrderKeys.isNotEmpty) {
        debugPrint('⚠️ Found ${failedOrderKeys.length} cart clearing failures');
        
        // Show user notification about failed cart clearing
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showCartClearingFailureDialog(failedOrderKeys);
        });
      }
    } catch (e) {
      debugPrint('Error checking for cart clearing failures: $e');
    }
  }

  void _showCartClearingFailureDialog(List<String> failedOrderKeys) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '⚠️ Cart Update Notice',
          style: TextStyle(color: AppTheme.textPrimaryColor(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Some items in your cart may have already been ordered but are still showing here.',
              style: TextStyle(color: AppTheme.textPrimaryColor(context)),
            ),
            SizedBox(height: 8),
            Text(
              'Please review your cart and remove any items you\'ve already purchased.',
              style: TextStyle(color: AppTheme.textSecondaryColor(context)),
            ),
            SizedBox(height: 8),
            Text(
              'Failed orders: ${failedOrderKeys.length}',
              style: TextStyle(
                color: AppTheme.textSecondaryColor(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceColor(context),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'I\'ll Review Manually',
              style: TextStyle(color: AppTheme.textSecondaryColor(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearCartClearingFailureFlags(failedOrderKeys);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
            ),
            child: Text('Clear Notifications'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCartClearingFailureFlags(List<String> failedOrderKeys) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      for (final key in failedOrderKeys) {
        await prefs.remove(key);
      }
      
      debugPrint('✅ Cleared ${failedOrderKeys.length} cart clearing failure flags');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cart notifications cleared'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error clearing cart failure flags: $e');
    }
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
                // Dismiss keyboard before navigation to prevent it from appearing on mobile
                FocusScope.of(context).unfocus();
                // Switch directly to Home tab without reloading the app
                TabNavigationService.instance.switchToHome();
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
              icon: Image.asset(
                'images/Logo/48x48.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
                color: Colors.white,
                colorBlendMode: BlendMode.srcIn,
              ),
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
    final selectedCartItems = cartItems.where((item) => selectedItems.contains(item.getCartKey())).toList();

    return Column(
      children: [
        // Select All/None Controls
        _buildSelectionControls(context, cartItems),
        
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
        
        // Cart Summary with async calculation
        FutureBuilder<Map<String, double>>(
          future: _calculateTotals(selectedCartItems),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildCartSummaryLoading(context, selectedCartItems);
            } else if (snapshot.hasError) {
              return _buildCartSummaryError(context, selectedCartItems);
            } else {
              final calculations = snapshot.data ?? {'subtotal': 0.0, 'shipping': 49.0, 'total': 49.0};
              return _buildCartSummary(context, selectedCartItems, calculations);
            }
          },
        ),
      ],
    );
  }

  Widget _buildSelectionControls(BuildContext context, List<CartItem> cartItems) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade700
                : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Select Items (${selectedItems.length}/${cartItems.length})',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                if (selectAllState) {
                  // Deselect all
                  selectedItems.clear();
                  selectAllState = false;
                } else {
                  // Select all
                  selectedItems = cartItems.map((item) => item.getCartKey()).toSet();
                  selectAllState = true;
                }
                _saveSelections(); // Save state immediately
              });
            },
            child: Text(
              selectAllState ? 'Deselect All' : 'Select All',
              style: TextStyle(
                color: AppTheme.primaryOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, CartItem item) {
    final isSelected = selectedItems.contains(item.getCartKey());
    
    return Container(
      decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? AppTheme.primaryOrange
                : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade700
                    : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Selection Checkbox
              GestureDetector(
                onTap: () {
                  setState(() {
                    final cartKey = item.getCartKey();
                    if (isSelected) {
                      selectedItems.remove(cartKey);
                    } else {
                      selectedItems.add(cartKey);
                    }
                    // Update selectAllState based on current selection
                    final cartItems = _currentCartItems;
                    selectAllState = cartItems.isNotEmpty && selectedItems.length == cartItems.length;
                    _saveSelections(); // Save state immediately
                  });
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryOrange : Colors.grey,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    color: isSelected ? AppTheme.primaryOrange : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
            // Product Image - Clickable
            GestureDetector(
              onTap: () {
                // Navigate to product detail page
                Navigator.pushNamed(
                  context, 
                  '/product', 
                  arguments: {'productId': item.productId}
                );
              },
              child: ClipRRect(
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
                : Colors.grey.withValues(alpha: 0.2),
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
                onPressed: cartItems.isNotEmpty 
                    ? () => _handleCheckout(context, cartItems, calculations)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cartItems.isNotEmpty 
                      ? AppTheme.primaryOrange 
                      : Colors.grey,
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

  Widget _buildCartSummaryLoading(BuildContext context, List<CartItem> cartItems) {
    final subtotal = cartItems.fold<double>(0, (sum, item) => sum + (item.price * item.quantity));
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black26
                : Colors.grey.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow(context, 'Subtotal (${cartItems.length} items):', subtotal),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Shipping Fee:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const Spacer(),
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryOrange),
                  ),
                ),
              ],
            ),
            Divider(
              height: 24,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade600
                  : Colors.grey.shade300,
            ),
            Row(
              children: [
                Text(
                  'Total:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const Spacer(),
                Text(
                  'Calculating...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: null, // Disabled while calculating
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Calculating Total...',
                  style: TextStyle(
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

  Widget _buildCartSummaryError(BuildContext context, List<CartItem> cartItems) {
    final subtotal = cartItems.fold<double>(0, (sum, item) => sum + (item.price * item.quantity));
    const fallbackShipping = 49.0; // Updated to match your global settings
    final total = subtotal + fallbackShipping;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black26
                : Colors.grey.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow(context, 'Subtotal (${cartItems.length} items):', subtotal),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Shipping Fee:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const Spacer(),
                Text(
                  '${PaymentService.formatCurrency(fallbackShipping)} (default)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Unable to calculate custom shipping rates',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange,
              ),
              textAlign: TextAlign.center,
            ),
            Divider(
              height: 20,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade600
                  : Colors.grey.shade300,
            ),
            _buildSummaryRow(context, 'Total:', total, isTotal: true),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: cartItems.isNotEmpty 
                    ? () => _handleCheckout(context, cartItems, {
                        'subtotal': subtotal, 
                        'shipping': fallbackShipping, 
                        'total': total
                      })
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cartItems.isNotEmpty 
                      ? AppTheme.primaryOrange 
                      : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Proceed to Checkout - ${PaymentService.formatCurrency(total)}',
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

  // Helper method to calculate totals
  Future<Map<String, double>> _calculateTotals(List<CartItem> cartItems) async {
    final subtotal = cartItems.fold<double>(
      0, 
      (sum, item) => sum + (item.price * item.quantity),
    );
    
    final totalWeight = cartItems.fold<double>(
      0, 
      (sum, item) => sum + (item.quantity * 0.5), // Assume 0.5kg per item
    );
    
    double shipping = 49.0; // Use configured fallback rate to match your global settings
    
    try {
      // Get shipping configuration first to use proper fallback
      final shippingService = ShippingService();
      final config = await shippingService.ensureConfigurationExists();
      shipping = config.fallbackRate; // Use configured fallback rate
      
      debugPrint('Cart: Using fallback rate ₱${config.fallbackRate} (threshold: ₱${config.freeShippingThreshold})');
      
      // Determine destination based on user login status and saved address
      String destinationProvince = 'Metro Manila'; // Default fallback location
      String destinationCity = 'Manila';
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          // Get user's default address for shipping calculation
          final addresses = await AddressService.getAddresses();
          if (addresses.isNotEmpty) {
            final defaultAddress = addresses.first; // First address is default (ordered by isDefault)
            destinationProvince = defaultAddress.province;
            destinationCity = defaultAddress.city;
            debugPrint('Cart: Using user address: ${defaultAddress.city}, ${defaultAddress.province}');
          } else {
            debugPrint('Cart: User logged in but no saved address, using default location');
          }
        } catch (e) {
          debugPrint('Cart: Error getting user address: $e, using default location');
        }
      } else {
        debugPrint('Cart: Guest user, using default location for estimate');
      }
      
      // Use new ShippingService that respects global configuration
      final shippingCalculation = await shippingService.calculateShippingFee(
        subtotal: subtotal,
        totalWeight: totalWeight,
        destinationProvince: destinationProvince,
        destinationCity: destinationCity,
      );
      
      shipping = shippingCalculation.shippingFee;
      debugPrint('Cart: Calculated shipping ₱${shipping} (${shippingCalculation.calculationMethod}) for ${destinationCity}, ${destinationProvince}');
      
    } catch (e, stackTrace) {
      debugPrint('❌ Cart: Error calculating shipping: $e');
      debugPrint('❌ Cart: Stack trace: $stackTrace');
      // shipping already set to configured fallback rate above
      debugPrint('Cart: Using fallback rate ₱${shipping} due to error');
    }
    
    final total = subtotal + shipping;

    return {
      'subtotal': subtotal,
      'shipping': shipping,
      'total': total,
    };
  }

  // Handle checkout with authentication
  Future<void> _handleCheckout(
    BuildContext context,
    List<CartItem> cartItems,
    Map<String, double> calculations,
  ) async {
    // Only checkout selected items
    final selectedCartItems = cartItems.where((item) => selectedItems.contains(item.getCartKey())).toList();
    
    if (selectedCartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one item to checkout'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser != null) {
      // User is logged in, go directly to checkout
      await _navigateToCheckout(context, selectedCartItems, calculations);
    } else {
      // User is not logged in, show authentication modal
      // Convert CartItem list to Map format for compatibility
      final cartItemsMap = selectedCartItems.map((item) => {
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

  Future<void> _navigateToCheckout(
    BuildContext context,
    List<CartItem> cartItems,
    Map<String, double> calculations,
  ) async {
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