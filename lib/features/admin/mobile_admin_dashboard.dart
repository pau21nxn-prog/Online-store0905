import 'package:flutter/material.dart';
import 'dart:async';
import '../../common/theme.dart';
import '../../models/product.dart';
import '../../services/inventory_management_service.dart';
import '../../services/product_analytics_service.dart';

class MobileAdminDashboard extends StatefulWidget {
  const MobileAdminDashboard({super.key});

  @override
  State<MobileAdminDashboard> createState() => _MobileAdminDashboardState();
}

class _MobileAdminDashboardState extends State<MobileAdminDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _refreshAnimationController;
  
  // Data
  Map<String, dynamic> _dashboardData = {};
  List<InventoryAlert> _criticalAlerts = [];
  Map<String, dynamic> _realTimeMetrics = {};
  
  // State
  bool _isLoading = true;
  StreamSubscription<Map<String, dynamic>>? _realTimeSubscription;
  StreamSubscription<List<InventoryAlert>>? _alertsSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _refreshAnimationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    _loadDashboardData();
    _subscribeToRealTimeUpdates();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load dashboard data in parallel
      final futures = await Future.wait([
        _loadSalesMetrics(),
        _loadInventoryStats(),
        _loadOrdersData(),
        _loadRecentActivity(),
      ]);

      setState(() {
        _dashboardData = {
          'sales': futures[0],
          'inventory': futures[1],
          'orders': futures[2],
          'activity': futures[3],
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load dashboard data');
    }
  }

  Future<Map<String, dynamic>> _loadSalesMetrics() async {
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 500));
    
    return {
      'todayRevenue': 15420.50,
      'todayOrders': 34,
      'weekRevenue': 89250.75,
      'weekOrders': 187,
      'monthRevenue': 345678.90,
      'monthOrders': 1245,
      'conversionRate': 3.2,
      'averageOrderValue': 453.25,
      'revenueGrowth': 12.5,
      'ordersGrowth': 8.3,
    };
  }

  Future<Map<String, dynamic>> _loadInventoryStats() async {
    final stats = await InventoryManagementService.getInventoryStats();
    return {
      'totalProducts': stats.totalProducts,
      'lowStockProducts': stats.lowStockProducts,
      'outOfStockProducts': stats.outOfStockProducts,
      'totalValue': stats.totalInventoryValue,
      'totalUnits': stats.totalUnits,
    };
  }

  Future<Map<String, dynamic>> _loadOrdersData() async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    return {
      'pendingOrders': 12,
      'processingOrders': 28,
      'shippedOrders': 45,
      'deliveredToday': 67,
      'returnRequests': 3,
      'refundsPending': 2,
    };
  }

  Future<List<Map<String, dynamic>>> _loadRecentActivity() async {
    await Future.delayed(const Duration(milliseconds: 400));
    
    return [
      {
        'type': 'order',
        'message': 'New order #ORD-1234 received',
        'time': DateTime.now().subtract(const Duration(minutes: 5)),
        'value': 299.99,
      },
      {
        'type': 'inventory',
        'message': 'iPhone 14 Pro running low on stock',
        'time': DateTime.now().subtract(const Duration(minutes: 15)),
        'urgency': 'high',
      },
      {
        'type': 'review',
        'message': 'New 5-star review for Wireless Headphones',
        'time': DateTime.now().subtract(const Duration(minutes: 30)),
        'rating': 5,
      },
      {
        'type': 'customer',
        'message': 'Customer inquiry about delivery',
        'time': DateTime.now().subtract(const Duration(hours: 1)),
        'urgency': 'medium',
      },
    ];
  }

  void _subscribeToRealTimeUpdates() {
    // Real-time analytics
    _realTimeSubscription = ProductAnalyticsService.getRealTimeAnalytics()
        .listen((metrics) {
      setState(() {
        _realTimeMetrics = metrics;
      });
    });

    // Critical alerts
    _alertsSubscription = InventoryManagementService.watchActiveAlerts()
        .listen((alerts) {
      setState(() {
        _criticalAlerts = alerts
            .where((alert) => 
                alert.priority == AlertPriority.critical || 
                alert.priority == AlertPriority.high)
            .take(5)
            .toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _refreshDashboard,
            icon: AnimatedBuilder(
              animation: _refreshAnimationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _refreshAnimationController.value * 2 * 3.14159,
                  child: const Icon(Icons.refresh),
                );
              },
            ),
          ),
          IconButton(
            onPressed: _showNotifications,
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined),
                if (_criticalAlerts.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_criticalAlerts.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.shopping_cart), text: 'Orders'),
            Tab(icon: Icon(Icons.inventory), text: 'Inventory'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildOrdersTab(),
                _buildInventoryTab(),
                _buildAnalyticsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Real-time metrics
            if (_realTimeMetrics.isNotEmpty) _buildRealTimeMetrics(),
            
            // Quick stats
            _buildQuickStats(),
            
            const SizedBox(height: AppTheme.spacing16),
            
            // Critical alerts
            if (_criticalAlerts.isNotEmpty) _buildCriticalAlerts(),
            
            // Recent activity
            _buildRecentActivity(),
            
            // Quick actions
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTimeMetrics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.circle, color: Colors.green, size: 12),
                const SizedBox(width: 8),
                const Text(
                  'Live Metrics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'Updated now',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            Row(
              children: [
                Expanded(
                  child: _buildLiveMetricTile(
                    'Active Users',
                    '${_realTimeMetrics['activeUsers'] ?? 0}',
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildLiveMetricTile(
                    'Today Views',
                    '${_realTimeMetrics['todayViews'] ?? 0}',
                    Icons.visibility,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildLiveMetricTile(
                    'Today Sales',
                    '${_realTimeMetrics['todaySales'] ?? 0}',
                    Icons.shopping_cart,
                    AppTheme.primaryOrange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveMetricTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final sales = _dashboardData['sales'] ?? {};
    final inventory = _dashboardData['inventory'] ?? {};
    final orders = _dashboardData['orders'] ?? {};

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: AppTheme.spacing12,
      mainAxisSpacing: AppTheme.spacing12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Today Revenue',
          '₱${(sales['todayRevenue'] ?? 0).toStringAsFixed(0)}',
          Icons.attach_money,
          Colors.green,
          '${sales['revenueGrowth'] ?? 0}%',
        ),
        _buildStatCard(
          'Today Orders',
          '${sales['todayOrders'] ?? 0}',
          Icons.shopping_bag,
          Colors.blue,
          '${sales['ordersGrowth'] ?? 0}%',
        ),
        _buildStatCard(
          'Total Products',
          '${inventory['totalProducts'] ?? 0}',
          Icons.inventory,
          AppTheme.primaryOrange,
          null,
        ),
        _buildStatCard(
          'Pending Orders',
          '${orders['pendingOrders'] ?? 0}',
          Icons.pending_actions,
          Colors.amber,
          null,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String? growth,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                if (growth != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+$growth',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCriticalAlerts() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  'Critical Alerts',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _viewAllAlerts,
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            ..._criticalAlerts.take(3).map((alert) => _buildAlertTile(alert)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertTile(InventoryAlert alert) {
    Color alertColor;
    switch (alert.priority) {
      case AlertPriority.critical:
        alertColor = Colors.red;
        break;
      case AlertPriority.high:
        alertColor = Colors.orange;
        break;
      default:
        alertColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: alertColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: alertColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  alert.message,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _handleAlert(alert),
            icon: const Icon(Icons.arrow_forward_ios, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final activities = _dashboardData['activity'] ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            ...activities.take(4).map((activity) => _buildActivityTile(activity)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> activity) {
    IconData icon;
    Color color;
    
    switch (activity['type']) {
      case 'order':
        icon = Icons.shopping_cart;
        color = Colors.green;
        break;
      case 'inventory':
        icon = Icons.inventory;
        color = Colors.orange;
        break;
      case 'review':
        icon = Icons.star;
        color = Colors.amber;
        break;
      case 'customer':
        icon = Icons.support_agent;
        color = Colors.blue;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['message'],
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatActivityTime(activity['time']),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.2,
              children: [
                _buildQuickActionTile(
                  'Add Product',
                  Icons.add_shopping_cart,
                  Colors.green,
                  _addProduct,
                ),
                _buildQuickActionTile(
                  'View Orders',
                  Icons.list_alt,
                  Colors.blue,
                  _viewOrders,
                ),
                _buildQuickActionTile(
                  'Scan Barcode',
                  Icons.qr_code_scanner,
                  AppTheme.primaryOrange,
                  _scanBarcode,
                ),
                _buildQuickActionTile(
                  'Reports',
                  Icons.analytics,
                  Colors.purple,
                  _viewReports,
                ),
                _buildQuickActionTile(
                  'Settings',
                  Icons.settings,
                  Colors.grey,
                  _openSettings,
                ),
                _buildQuickActionTile(
                  'Support',
                  Icons.help,
                  Colors.teal,
                  _contactSupport,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionTile(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersTab() {
    return const Center(
      child: Text('Orders management will be implemented'),
    );
  }

  Widget _buildInventoryTab() {
    return const Center(
      child: Text('Inventory management will be implemented'),
    );
  }

  Widget _buildAnalyticsTab() {
    return const Center(
      child: Text('Analytics dashboard will be implemented'),
    );
  }

  // Event handlers
  Future<void> _refreshDashboard() async {
    _refreshAnimationController.forward();
    await _loadDashboardData();
    _refreshAnimationController.reset();
  }

  void _showNotifications() {
    // Navigate to notifications screen
  }

  void _viewAllAlerts() {
    // Navigate to alerts screen
  }

  void _handleAlert(InventoryAlert alert) {
    // Handle specific alert
  }

  void _addProduct() {
    // Navigate to add product screen
  }

  void _viewOrders() {
    // Navigate to orders screen
  }

  void _scanBarcode() {
    // Open barcode scanner
  }

  void _viewReports() {
    // Navigate to reports screen
  }

  void _openSettings() {
    // Navigate to settings screen
  }

  void _contactSupport() {
    // Open support chat or email
  }

  String _formatActivityTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshAnimationController.dispose();
    _realTimeSubscription?.cancel();
    _alertsSubscription?.cancel();
    super.dispose();
  }
}