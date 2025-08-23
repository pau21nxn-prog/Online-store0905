import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../common/theme.dart';
import '../../services/audit_service.dart';

class AnalyticsWidgets extends StatefulWidget {
  const AnalyticsWidgets({super.key});

  @override
  State<AnalyticsWidgets> createState() => _AnalyticsWidgetsState();
}

class _AnalyticsWidgetsState extends State<AnalyticsWidgets> {
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _auditStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    
    try {
      // Load basic statistics
      final stats = await _getBasicStats();
      final auditStats = await AuditService.getAuditStatistics(
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
      );
      
      setState(() {
        _stats = stats;
        _auditStats = auditStats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>> _getBasicStats() async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final stats = <String, dynamic>{};

    // Users statistics
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    final activeUsersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('isActive', isEqualTo: true)
        .get();
    final newUsersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('createdAt', isGreaterThan: thirtyDaysAgo)
        .get();
    
    stats['totalUsers'] = usersSnapshot.size;
    stats['activeUsers'] = activeUsersSnapshot.size;
    stats['newUsers'] = newUsersSnapshot.size;
    stats['userRetentionRate'] = ((stats['activeUsers'] / stats['totalUsers']) * 100).round();

    // Orders statistics
    final ordersSnapshot = await FirebaseFirestore.instance.collection('orders').get();
    final recentOrdersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('createdAt', isGreaterThan: sevenDaysAgo)
        .get();
    final pendingOrdersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .get();
    final completedOrdersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'delivered')
        .get();

    stats['totalOrders'] = ordersSnapshot.size;
    stats['recentOrders'] = recentOrdersSnapshot.size;
    stats['pendingOrders'] = pendingOrdersSnapshot.size;
    stats['completedOrders'] = completedOrdersSnapshot.size;

    // Revenue calculation
    double totalRevenue = 0;
    double recentRevenue = 0;
    
    for (final doc in ordersSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final total = (data['total'] as num?)?.toDouble() ?? 0;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      
      totalRevenue += total;
      if (createdAt != null && createdAt.isAfter(sevenDaysAgo)) {
        recentRevenue += total;
      }
    }

    stats['totalRevenue'] = totalRevenue;
    stats['recentRevenue'] = recentRevenue;
    stats['averageOrderValue'] = totalRevenue / (ordersSnapshot.size > 0 ? ordersSnapshot.size : 1);

    // Products statistics
    final productsSnapshot = await FirebaseFirestore.instance.collection('products').get();
    final publishedProductsSnapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('isPublished', isEqualTo: true)
        .get();

    stats['totalProducts'] = productsSnapshot.size;
    stats['publishedProducts'] = publishedProductsSnapshot.size;

    return stats;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.analytics,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                'Analytics Dashboard',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadAnalytics,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Data',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // KPI Cards Row 1
          Row(
            children: [
              Expanded(child: _buildKpiCard(
                'Total Users',
                _stats['totalUsers']?.toString() ?? '0',
                Icons.people,
                Colors.blue,
                subtitle: '${_stats['newUsers'] ?? 0} new this month',
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildKpiCard(
                'Active Users',
                _stats['activeUsers']?.toString() ?? '0',
                Icons.people_alt,
                Colors.green,
                subtitle: '${_stats['userRetentionRate'] ?? 0}% retention rate',
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildKpiCard(
                'Total Orders',
                _stats['totalOrders']?.toString() ?? '0',
                Icons.shopping_cart,
                Colors.orange,
                subtitle: '${_stats['recentOrders'] ?? 0} this week',
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildKpiCard(
                'Pending Orders',
                _stats['pendingOrders']?.toString() ?? '0',
                Icons.schedule,
                Colors.red,
                subtitle: 'Needs attention',
              )),
            ],
          ),
          const SizedBox(height: 16),

          // KPI Cards Row 2
          Row(
            children: [
              Expanded(child: _buildKpiCard(
                'Total Revenue',
                '₱${(_stats['totalRevenue'] ?? 0).toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.green,
                subtitle: '₱${(_stats['recentRevenue'] ?? 0).toStringAsFixed(2)} this week',
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildKpiCard(
                'Avg Order Value',
                '₱${(_stats['averageOrderValue'] ?? 0).toStringAsFixed(2)}',
                Icons.trending_up,
                Colors.purple,
                subtitle: 'Per order average',
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildKpiCard(
                'Products',
                _stats['totalProducts']?.toString() ?? '0',
                Icons.inventory,
                Colors.indigo,
                subtitle: '${_stats['publishedProducts'] ?? 0} published',
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildKpiCard(
                'Admin Actions',
                _auditStats['totalActions']?.toString() ?? '0',
                Icons.admin_panel_settings,
                Colors.teal,
                subtitle: 'Last 30 days',
              )),
            ],
          ),
          const SizedBox(height: 32),

          // Charts Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Status Chart
              Expanded(
                child: _buildOrderStatusChart(),
              ),
              const SizedBox(width: 16),
              // Recent Activity
              Expanded(
                child: _buildRecentActivityWidget(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Admin Activity Section
          if (_auditStats['actionsByAdmin'] != null)
            _buildAdminActivityWidget(),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: color,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.trending_up,
                    size: 16,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary(context),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pie_chart,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Order Status Distribution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildStatusIndicator('Pending', _stats['pendingOrders'] ?? 0, Colors.orange),
            _buildStatusIndicator('Completed', _stats['completedOrders'] ?? 0, Colors.green),
            _buildStatusIndicator('Total', _stats['totalOrders'] ?? 0, Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, int count, Color color) {
    final total = _stats['totalOrders'] ?? 1;
    final percentage = ((count / total) * 100).round();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$count ($percentage%)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityWidget() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: AuditService.getRecentActivity(limit: 5),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final logs = snapshot.data!.docs;
                if (logs.isEmpty) {
                  return Center(
                    child: Text(
                      'No recent activity',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  );
                }

                return Column(
                  children: logs.take(5).map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildActivityItem(
                      data['action'] ?? 'Unknown',
                      data['description'] ?? 'No description',
                      data['adminEmail'] ?? 'System',
                      data['timestamp']?.toDate() ?? DateTime.now(),
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

  Widget _buildActivityItem(String action, String description, String admin, DateTime timestamp) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 8,
            backgroundColor: _getActionColor(action),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            _formatTimeAgo(timestamp),
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActivityWidget() {
    final adminStats = _auditStats['actionsByAdmin'] as Map<String, dynamic>? ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Admin Activity (Last 30 Days)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...adminStats.entries.take(5).map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${entry.value} actions',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'created': return Colors.green;
      case 'updated': return Colors.blue;
      case 'deleted': return Colors.red;
      case 'cancelled': return Colors.red;
      case 'activated': return Colors.green;
      case 'deactivated': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}