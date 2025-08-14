import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../common/theme.dart';
import '../../models/order.dart';
import '../../services/notification_service.dart';

class OrdersManagementScreen extends StatefulWidget {
  const OrdersManagementScreen({super.key});

  @override
  State<OrdersManagementScreen> createState() => _OrdersManagementScreenState();
}

class _OrdersManagementScreenState extends State<OrdersManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  final List<String> _statusTabs = [
    'All',
    'Pending',
    'Confirmed',
    'Processing',
    'Shipped',
    'Delivered',
    'Cancelled'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Orders Management',
            style: AppTheme.titleStyle.copyWith(fontSize: 28),
          ),
          const SizedBox(height: AppTheme.spacing24),
          
          // Search
          TextField(
            decoration: InputDecoration(
              hintText: 'Search orders by ID, customer, or product...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: AppTheme.spacing24),
          
          // Status Tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppTheme.primaryOrange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryOrange,
            tabs: _statusTabs.map((status) => Tab(text: status)).toList(),
          ),
          const SizedBox(height: AppTheme.spacing16),
          
          // Orders List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _statusTabs.map((status) => _buildOrdersList(status)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(String statusFilter) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getOrdersStream(statusFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(statusFilter);
        }

        final orders = snapshot.data!.docs
            .map((doc) => UserOrder.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
            .where((order) => _filterOrder(order))
            .toList();

        if (orders.isEmpty) {
          return _buildEmptyState(statusFilter);
        }

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _buildOrderCard(order);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getOrdersStream(String statusFilter) {
    Query query = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('createdAt', descending: true);
    
    if (statusFilter != 'All') {
      query = query.where('status', isEqualTo: statusFilter.toLowerCase());
    }
    
    return query.snapshots();
  }

  bool _filterOrder(UserOrder order) {
    if (_searchQuery.isEmpty) return true;
    
    final query = _searchQuery.toLowerCase();
    return order.id.toLowerCase().contains(query) ||
           order.items.any((item) => 
               item.productName.toLowerCase().contains(query)) ||
           (order.shippingAddress['fullName'] ?? '').toLowerCase().contains(query);
  }

  Widget _buildOrderCard(UserOrder order) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Customer: ${order.shippingAddress['fullName'] ?? 'N/A'}',
                    style: AppTheme.captionStyle,
                  ),
                ],
              ),
            ),
            _buildStatusChip(order.status),
            const SizedBox(width: AppTheme.spacing8),
            Text(
              order.formattedTotal,
              style: AppTheme.priceStyle.copyWith(fontSize: 16),
            ),
          ],
        ),
        subtitle: Text(
          _formatDate(order.createdAt),
          style: AppTheme.captionStyle,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Items
                Text(
                  'Items (${order.items.length}):',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppTheme.spacing8),
                ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacing4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${item.productName} x${item.quantity}'),
                      ),
                      Text(item.formattedTotal),
                    ],
                  ),
                )),
                const SizedBox(height: AppTheme.spacing16),
                
                // Customer Info
                Text(
                  'Customer Information:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppTheme.spacing8),
                Text('Name: ${order.shippingAddress['fullName'] ?? 'N/A'}'),
                Text('Phone: ${order.shippingAddress['phoneNumber'] ?? 'N/A'}'),
                Text('Address: ${order.formattedShippingAddress}'),
                const SizedBox(height: AppTheme.spacing16),
                
                // Payment Info
                Text(
                  'Payment Information:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppTheme.spacing8),
                Text('Method: ${order.paymentMethodDisplayName}'),
                Text('Status: ${order.isPaid ? 'Paid' : 'Pending'}'),
                const SizedBox(height: AppTheme.spacing16),
                
                // Order Summary
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceGray,
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:'),
                          Text(order.formattedSubtotal),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Shipping:'),
                          Text(order.formattedShippingFee),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            order.formattedTotal,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryOrange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacing16),
                
                // Action Buttons
                Row(
                  children: [
                    if (order.status == OrderStatus.pending) ...[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(order, OrderStatus.confirmed),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Confirm'),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(order, OrderStatus.cancelled),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ] else if (order.status == OrderStatus.confirmed) ...[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(order, OrderStatus.processing),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Start Processing'),
                        ),
                      ),
                    ] else if (order.status == OrderStatus.processing) ...[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(order, OrderStatus.shipped),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Mark as Shipped'),
                        ),
                      ),
                    ] else if (order.status == OrderStatus.shipped) ...[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateOrderStatus(order, OrderStatus.delivered),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successGreen,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Mark as Delivered'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    Color color;
    switch (status) {
      case OrderStatus.pending:
        color = Colors.orange;
        break;
      case OrderStatus.confirmed:
        color = Colors.blue;
        break;
      case OrderStatus.processing:
        color = Colors.purple;
        break;
      case OrderStatus.shipped:
        color = Colors.teal;
        break;
      case OrderStatus.delivered:
        color = AppTheme.successGreen;
        break;
      case OrderStatus.cancelled:
        color = AppTheme.errorRed;
        break;
      case OrderStatus.refunded:
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String statusFilter) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            statusFilter == 'All' ? 'No orders yet' : 'No $statusFilter orders',
            style: AppTheme.titleStyle.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            statusFilter == 'All'
                ? 'Orders will appear here when customers make purchases'
                : 'Orders with $statusFilter status will appear here',
            style: AppTheme.bodyStyle.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _updateOrderStatus(UserOrder order, OrderStatus newStatus) async {
    try {
      // Update order status in Firestore
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .update({
        'status': newStatus.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // 🔔 SEND NOTIFICATION TO CUSTOMER
      await NotificationService.sendOrderNotification(
        userId: order.userId,
        orderId: order.id,
        status: newStatus.name,
        orderTotal: order.formattedTotal,
      );

      // 🔔 SEND ADMIN NOTIFICATION FOR NEW ORDERS (if this was order confirmation)
      if (newStatus == OrderStatus.confirmed) {
        await NotificationService.sendAdminNotification(
          type: 'new_order',
          data: {
            'orderId': order.id,
            'total': order.formattedTotal,
            'customerName': order.shippingAddress['fullName'] ?? 'N/A',
            'itemCount': order.items.length,
          },
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to ${newStatus.name} and customer notified'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating order: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}