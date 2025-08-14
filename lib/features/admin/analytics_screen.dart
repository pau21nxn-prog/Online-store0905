import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../common/theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedPeriod = '7 days';
  Map<String, dynamic> _analytics = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get orders for analytics
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .get();

      // Get products for analytics
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .get();

      // Get users for analytics
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      // Calculate analytics
      final orders = ordersSnapshot.docs;
      final products = productsSnapshot.docs;
      final users = usersSnapshot.docs;

      // Calculate totals
      double totalRevenue = 0;
      int totalOrders = orders.length;
      Map<String, int> statusCounts = {};
      Map<String, double> dailySales = {};

      for (var order in orders) {
        final data = order.data() as Map<String, dynamic>;
        final total = (data['total'] as num?)?.toDouble() ?? 0.0;
        final status = data['status'] as String? ?? 'unknown';
        
        totalRevenue += total;
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;

        // For daily sales chart
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final dateKey = _formatDateForChart(createdAt.toDate());
          dailySales[dateKey] = (dailySales[dateKey] ?? 0) + total;
        }
      }

      // Calculate product popularity
      Map<String, int> productSales = {};
      for (var order in orders) {
        final data = order.data() as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        for (var item in items) {
          final productName = item['productName'] as String? ?? 'Unknown';
          final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
          productSales[productName] = (productSales[productName] ?? 0) + quantity;
        }
      }

      // Sort top products
      final topProducts = productSales.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))
        ..take(5);

      setState(() {
        _analytics = {
          'totalRevenue': totalRevenue,
          'totalOrders': totalOrders,
          'totalProducts': products.length,
          'totalUsers': users.length,
          'statusCounts': statusCounts,
          'dailySales': dailySales,
          'topProducts': topProducts,
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDateForChart(DateTime date) {
    return '${date.month}/${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            initialValue: _selectedPeriod,
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
              });
              _loadAnalytics();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '7 days', child: Text('Last 7 days')),
              const PopupMenuItem(value: '30 days', child: Text('Last 30 days')),
              const PopupMenuItem(value: '90 days', child: Text('Last 90 days')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: ListView(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                children: [
                  // KPI Cards
                  _buildKPICards(),
                  
                  const SizedBox(height: AppTheme.spacing24),
                  
                  // Sales Chart
                  _buildSalesChart(),
                  
                  const SizedBox(height: AppTheme.spacing24),
                  
                  // Order Status Distribution
                  _buildOrderStatusChart(),
                  
                  const SizedBox(height: AppTheme.spacing24),
                  
                  // Top Products
                  _buildTopProducts(),
                  
                  const SizedBox(height: AppTheme.spacing24),
                  
                  // Recent Activity
                  _buildRecentActivity(),
                ],
              ),
            ),
    );
  }

  Widget _buildKPICards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: AppTheme.spacing16,
      mainAxisSpacing: AppTheme.spacing16,
      childAspectRatio: 1.5,
      children: [
        _buildKPICard(
          'Total Revenue',
          '₱${(_analytics['totalRevenue'] ?? 0.0).toStringAsFixed(2)}',
          Icons.attach_money,
          Colors.green,
        ),
        _buildKPICard(
          'Total Orders',
          '${_analytics['totalOrders'] ?? 0}',
          Icons.shopping_cart,
          Colors.blue,
        ),
        _buildKPICard(
          'Products',
          '${_analytics['totalProducts'] ?? 0}',
          Icons.inventory,
          Colors.orange,
        ),
        _buildKPICard(
          'Users',
          '${_analytics['totalUsers'] ?? 0}',
          Icons.people,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart() {
    final dailySales = _analytics['dailySales'] as Map<String, double>? ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Trend ($_selectedPeriod)',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            SizedBox(
              height: 200,
              child: dailySales.isEmpty
                  ? const Center(child: Text('No sales data available'))
                  : _buildSimpleChart(dailySales),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleChart(Map<String, double> data) {
    if (data.isEmpty) return const Center(child: Text('No data'));
    
    final maxValue = data.values.reduce((a, b) => a > b ? a : b);
    final entries = data.entries.toList();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: entries.map((entry) {
        final height = (entry.value / maxValue) * 150;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '₱${entry.value.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 10),
            ),
            const SizedBox(height: 4),
            Container(
              width: 30,
              height: height.toDouble(),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              entry.key,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildOrderStatusChart() {
    final statusCounts = _analytics['statusCounts'] as Map<String, int>? ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Status Distribution',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            if (statusCounts.isEmpty)
              const Center(child: Text('No order data available'))
            else
              ...statusCounts.entries.map((entry) {
                final total = statusCounts.values.reduce((a, b) => a + b);
                final percentage = (entry.value / total * 100).toStringAsFixed(1);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _getStatusColor(entry.key),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(entry.key.toUpperCase()),
                      const Spacer(),
                      Text('${entry.value} ($percentage%)'),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProducts() {
    final topProducts = _analytics['topProducts'] as List<MapEntry<String, int>>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Products',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            if (topProducts.isEmpty)
              const Center(child: Text('No product data available'))
            else
              ...topProducts.take(5).map((product) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                    child: Icon(
                      Icons.shopping_bag,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                  title: Text(product.key),
                  trailing: Text(
                    '${product.value} sold',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .orderBy('createdAt', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final orders = snapshot.data!.docs;
                
                if (orders.isEmpty) {
                  return const Center(child: Text('No recent activity'));
                }

                return Column(
                  children: orders.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final orderId = data['id'] ?? doc.id;
                    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
                    final status = data['status'] ?? 'unknown';
                    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                    
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.shopping_cart,
                        color: _getStatusColor(status),
                      ),
                      title: Text('Order #$orderId'),
                      subtitle: Text(
                        createdAt != null 
                            ? _formatDateTime(createdAt)
                            : 'Unknown date',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₱${total.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              color: _getStatusColor(status),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.purple;
      case 'shipped':
        return Colors.teal;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}