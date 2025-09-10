import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../common/theme.dart';
import '../../common/mobile_layout_utils.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../models/order.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  // Track expanded state of order cards
  final Set<String> _expandedOrders = {};

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
    final currentUser = AuthService.currentUser;
    
    if (currentUser == null || currentUser.isAnonymous) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor(context),
        appBar: AppBar(
          title: Text(
            'My Orders',
            style: TextStyle(color: AppTheme.textPrimaryColor(context)),
          ),
          backgroundColor: AppTheme.backgroundColor(context),
          foregroundColor: AppTheme.textPrimaryColor(context),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.login,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign in to view your orders',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create an account to track your purchases\nand order history',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        title: Text(
          'My Orders',
          style: TextStyle(color: AppTheme.textPrimaryColor(context)),
        ),
        backgroundColor: AppTheme.backgroundColor(context),
        foregroundColor: AppTheme.textPrimaryColor(context),
      ),
      body: _buildOrdersList(currentUser.id),
    );
  }

  Widget _buildOrdersList(String userId) {
    Query query = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true); // Order by most recent first

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryOrange),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading orders: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final orders = snapshot.data!.docs
            .map((doc) => UserOrder.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
            .toList();

        // Sort orders by creation date (newest first)
        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _buildOrderCard(order);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(UserOrder order) {
    final isExpanded = _expandedOrders.contains(order.id);
    final statusTimestamp = _getStatusTimestamp(order);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedOrders.remove(order.id);
            } else {
              _expandedOrders.add(order.id);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Order #${order.id.toUpperCase()}', // Display full order number
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Order Status and Timestamp
              Row(
                children: [
                  Text(
                    order.statusDisplayName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    ' • ${_formatStatusTimestamp(statusTimestamp)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Order Items Preview (Collapsed View)
              Row(
                children: [
                  // Item images
                  if (order.items.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: order.items.first.productImage.isNotEmpty
                            ? Image.network(
                                order.items.first.productImage,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.image_not_supported, size: 20),
                                  );
                                },
                              )
                            : Container(
                                color: Colors.grey.shade200,
                                child: Image.asset(
                                  'images/Logo/48x48.png',
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.contain,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  
                  // Item details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.items.length == 1
                              ? order.items.first.productName
                              : '${order.items.first.productName}${order.items.length > 1 ? ' + ${order.items.length - 1} more' : ''}',
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${order.items.length} ${order.items.length == 1 ? 'item' : 'items'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Total amount
                  Text(
                    order.formattedTotal,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                ],
              ),
              
              // Expanded Content
              if (isExpanded) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                _buildExpandedOrderDetails(order),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedOrderDetails(UserOrder order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Order Summary Header
        const Text(
          'Order Summary',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Items List
        ...order.items.map((item) => _buildOrderItemDetail(item)),
        
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        
        // Price Breakdown
        Column(
          children: [
            _buildPriceRow('Subtotal:', order.formattedSubtotal),
            if (order.shippingFee > 0)
              _buildPriceRow('Shipping:', order.formattedShippingFee),
            if (order.tax > 0)
              _buildPriceRow('Tax:', '₱${order.tax.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            _buildPriceRow(
              'Total:',
              order.formattedTotal,
              isTotal: true,
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Buy Again Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _handleBuyAgain(order),
            icon: const Icon(Icons.shopping_cart, size: 20),
            label: const Text('Buy Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItemDetail(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Name
          Text(
            item.productName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          
          // Variant Options (if available)
          if (item.selectedOptions != null && item.selectedOptions!.isNotEmpty) ...[
            Row(
              children: item.selectedOptions!.entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    entry.value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
          ],
          
          // SKU (if available)
          if (item.variantSku != null && item.variantSku!.isNotEmpty) ...[
            Text(
              'SKU: ${item.variantSku}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
          ],
          
          // Quantity and Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Qty: ${item.quantity}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                item.formattedTotal,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black : Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.bold,
              color: isTotal ? AppTheme.primaryOrange : Colors.black,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'images/Logo/96x96.png',
            width: 80,
            height: 80,
            fit: BoxFit.contain,
            color: Colors.grey.shade400,
            colorBlendMode: BlendMode.srcIn,
          ),
          const SizedBox(height: 16),
          Text(
            'No orders yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When you place orders, they will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.shopping_cart),
            label: const Text('Continue Shopping'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Handle Buy Again functionality
  Future<void> _handleBuyAgain(UserOrder order) async {
    try {
      // Add all order items back to cart
      for (final item in order.items) {
        await CartService.addToCartWithParams(
          productId: item.productId,
          productName: item.productName,
          price: item.price,
          imageUrl: item.productImage,
          quantity: item.quantity,
          selectedVariantId: item.selectedVariantId,
          selectedOptions: item.selectedOptions,
          variantSku: item.variantSku,
          variantDisplayName: item.variantDisplayName,
        );
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Added ${order.items.length} ${order.items.length == 1 ? 'item' : 'items'} to your cart',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate to cart screen after a short delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushNamed(context, '/cart');
        }
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Failed to add items to cart. Please try again.'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Get the appropriate timestamp based on order status
  DateTime _getStatusTimestamp(UserOrder order) {
    switch (order.status) {
      case OrderStatus.pending:
        return order.createdAt;
      case OrderStatus.confirmed:
        return order.confirmedAt ?? order.updatedAt ?? order.createdAt;
      case OrderStatus.processing:
        return order.processingAt ?? order.updatedAt ?? order.createdAt;
      case OrderStatus.shipped:
        return order.shippedAt ?? order.updatedAt ?? order.createdAt;
      case OrderStatus.delivered:
        return order.deliveredAt ?? order.updatedAt ?? order.createdAt;
      case OrderStatus.cancelled:
        return order.cancelledAt ?? order.updatedAt ?? order.createdAt;
      case OrderStatus.refunded:
        return order.updatedAt ?? order.createdAt;
    }
  }

  // Format timestamp in yyyy-mm-dd hh:mm am/pm format (matching admin screen)
  String _formatStatusTimestamp(DateTime dateTime) {
    final dateFormatter = DateFormat('yyyy-MM-dd');
    final timeFormatter = DateFormat('h:mm a');
    
    final dateStr = dateFormatter.format(dateTime);
    final timeStr = timeFormatter.format(dateTime).toLowerCase();
    
    return '$dateStr $timeStr';
  }


}