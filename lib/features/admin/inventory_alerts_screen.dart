import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../common/theme.dart';
import '../../models/product.dart';
import '../../services/inventory_management_service.dart';

class InventoryAlertsScreen extends StatefulWidget {
  const InventoryAlertsScreen({super.key});

  @override
  State<InventoryAlertsScreen> createState() => _InventoryAlertsScreenState();
}

class _InventoryAlertsScreenState extends State<InventoryAlertsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  // Filters
  AlertPriority? _selectedPriority;
  AlertType? _selectedType;
  bool _showUnreadOnly = false;
  
  // Data
  List<InventoryAlert> _allAlerts = [];
  List<InventoryAlert> _filteredAlerts = [];
  InventoryStats? _inventoryStats;
  
  // State
  bool _isLoading = true;
  StreamSubscription<List<InventoryAlert>>? _alertsSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
    _subscribeToAlerts();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stats = await InventoryManagementService.getInventoryStats();
      setState(() {
        _inventoryStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading initial data: $e');
    }
  }

  void _subscribeToAlerts() {
    _alertsSubscription = InventoryManagementService.watchActiveAlerts()
        .listen((alerts) {
      setState(() {
        _allAlerts = alerts;
        _applyFilters();
      });
    });
  }

  void _applyFilters() {
    _filteredAlerts = _allAlerts.where((alert) {
      if (_selectedPriority != null && alert.priority != _selectedPriority) {
        return false;
      }
      if (_selectedType != null && alert.type != _selectedType) {
        return false;
      }
      if (_showUnreadOnly && alert.isRead) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Alerts'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.warning), text: 'Alerts'),
            Tab(icon: Icon(Icons.settings), text: 'Thresholds'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _markAllAsRead,
            icon: const Icon(Icons.mark_email_read),
            tooltip: 'Mark All Read',
          ),
          IconButton(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filters',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildAlertsTab(),
          _buildThresholdsTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      children: [
        // Summary cards
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppTheme.spacing16,
          mainAxisSpacing: AppTheme.spacing16,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Total Products',
              '${_inventoryStats?.totalProducts ?? 0}',
              Icons.inventory,
              Colors.blue,
            ),
            _buildStatCard(
              'Low Stock',
              '${_inventoryStats?.lowStockProducts ?? 0}',
              Icons.warning,
              Colors.orange,
            ),
            _buildStatCard(
              'Out of Stock',
              '${_inventoryStats?.outOfStockProducts ?? 0}',
              Icons.error,
              Colors.red,
            ),
            _buildStatCard(
              'Total Value',
              '₱${(_inventoryStats?.totalInventoryValue ?? 0).toStringAsFixed(0)}',
              Icons.attach_money,
              Colors.green,
            ),
          ],
        ),
        
        const SizedBox(height: AppTheme.spacing24),
        
        // Critical alerts
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Critical Alerts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppTheme.spacing16),
                
                if (_getCriticalAlerts().isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppTheme.spacing32),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle, size: 48, color: Colors.green),
                          SizedBox(height: 8),
                          Text('No critical alerts'),
                        ],
                      ),
                    ),
                  )
                else
                  ..._getCriticalAlerts().take(5).map((alert) => _buildAlertListTile(alert)),
                
                if (_getCriticalAlerts().length > 5)
                  TextButton(
                    onPressed: () {
                      _tabController.animateTo(1);
                      setState(() {
                        _selectedPriority = AlertPriority.critical;
                      });
                      _applyFilters();
                    },
                    child: Text('View all ${_getCriticalAlerts().length} critical alerts'),
                  ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: AppTheme.spacing16),
        
        // Recent alerts
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Alerts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppTheme.spacing16),
                
                if (_allAlerts.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppTheme.spacing32),
                      child: Text('No alerts'),
                    ),
                  )
                else
                  ..._allAlerts.take(5).map((alert) => _buildAlertListTile(alert)),
                
                if (_allAlerts.length > 5)
                  TextButton(
                    onPressed: () => _tabController.animateTo(1),
                    child: Text('View all ${_allAlerts.length} alerts'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsTab() {
    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Priority filter
              Expanded(
                child: DropdownButtonFormField<AlertPriority>(
                  value: _selectedPriority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Priorities')),
                    ...AlertPriority.values.map((priority) {
                      return DropdownMenuItem(
                        value: priority,
                        child: Row(
                          children: [
                            _getPriorityIcon(priority),
                            const SizedBox(width: 8),
                            Text(_getPriorityDisplayName(priority)),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedPriority = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
              
              const SizedBox(width: AppTheme.spacing8),
              
              // Type filter
              Expanded(
                child: DropdownButtonFormField<AlertType>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Types')),
                    ...AlertType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_getTypeDisplayName(type)),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
              
              const SizedBox(width: AppTheme.spacing8),
              
              // Unread only toggle
              FilterChip(
                label: const Text('Unread Only'),
                selected: _showUnreadOnly,
                onSelected: (selected) {
                  setState(() {
                    _showUnreadOnly = selected;
                  });
                  _applyFilters();
                },
              ),
            ],
          ),
        ),
        
        // Alerts list
        Expanded(
          child: _filteredAlerts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No alerts match your filters'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredAlerts.length,
                  itemBuilder: (context, index) {
                    final alert = _filteredAlerts[index];
                    return _buildAlertCard(alert);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildThresholdsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Inventory Thresholds'),
          Text('Configure alert thresholds here'),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Alert History'),
          Text('View acknowledged and resolved alerts'),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(InventoryAlert alert) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing4,
      ),
      child: InkWell(
        onTap: () => _showAlertDetails(alert),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            children: [
              // Priority indicator
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: _getPriorityColor(alert.priority),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              const SizedBox(width: AppTheme.spacing16),
              
              // Alert icon
              _getPriorityIcon(alert.priority),
              
              const SizedBox(width: AppTheme.spacing16),
              
              // Alert content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            style: TextStyle(
                              fontWeight: alert.isRead ? FontWeight.normal : FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (!alert.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: AppTheme.spacing4),
                    
                    Text(
                      alert.message,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: AppTheme.spacing8),
                    
                    Row(
                      children: [
                        _buildChip(alert.typeDisplayName, _getTypeColor(alert.type)),
                        const SizedBox(width: 8),
                        _buildChip(alert.priorityDisplayName, _getPriorityColor(alert.priority)),
                        const Spacer(),
                        Text(
                          _formatDateTime(alert.createdAt),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Actions
              PopupMenuButton<String>(
                onSelected: (action) => _handleAlertAction(action, alert),
                itemBuilder: (context) => [
                  if (!alert.isRead)
                    const PopupMenuItem(
                      value: 'mark_read',
                      child: ListTile(
                        leading: Icon(Icons.mark_email_read),
                        title: Text('Mark as Read'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'acknowledge',
                    child: ListTile(
                      leading: Icon(Icons.check),
                      title: Text('Acknowledge'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'view_product',
                    child: ListTile(
                      leading: Icon(Icons.visibility),
                      title: Text('View Product'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertListTile(InventoryAlert alert) {
    return ListTile(
      leading: _getPriorityIcon(alert.priority),
      title: Text(
        alert.title,
        style: TextStyle(
          fontWeight: alert.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(alert.message),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _formatDateTime(alert.createdAt),
            style: const TextStyle(fontSize: 12),
          ),
          if (!alert.isRead)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      onTap: () => _showAlertDetails(alert),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  // Helper methods
  List<InventoryAlert> _getCriticalAlerts() {
    return _allAlerts.where((alert) => 
      alert.priority == AlertPriority.critical || 
      alert.priority == AlertPriority.high
    ).toList();
  }

  Widget _getPriorityIcon(AlertPriority priority) {
    switch (priority) {
      case AlertPriority.low:
        return Icon(Icons.info, color: Colors.blue.shade300);
      case AlertPriority.medium:
        return Icon(Icons.warning, color: Colors.orange.shade300);
      case AlertPriority.high:
        return Icon(Icons.error, color: Colors.red.shade300);
      case AlertPriority.critical:
        return Icon(Icons.dangerous, color: Colors.red.shade700);
    }
  }

  Color _getPriorityColor(AlertPriority priority) {
    switch (priority) {
      case AlertPriority.low:
        return Colors.blue;
      case AlertPriority.medium:
        return Colors.orange;
      case AlertPriority.high:
        return Colors.red;
      case AlertPriority.critical:
        return Colors.red.shade700;
    }
  }

  Color _getTypeColor(AlertType type) {
    switch (type) {
      case AlertType.lowStock:
        return Colors.orange;
      case AlertType.outOfStock:
        return Colors.red;
      case AlertType.overstock:
        return Colors.purple;
      case AlertType.slowMoving:
        return Colors.brown;
      case AlertType.fastMoving:
        return Colors.green;
      case AlertType.reorderPoint:
        return Colors.blue;
      case AlertType.expiringSoon:
        return Colors.amber;
    }
  }

  String _getPriorityDisplayName(AlertPriority priority) {
    switch (priority) {
      case AlertPriority.low:
        return 'Low';
      case AlertPriority.medium:
        return 'Medium';
      case AlertPriority.high:
        return 'High';
      case AlertPriority.critical:
        return 'Critical';
    }
  }

  String _getTypeDisplayName(AlertType type) {
    switch (type) {
      case AlertType.lowStock:
        return 'Low Stock';
      case AlertType.outOfStock:
        return 'Out of Stock';
      case AlertType.overstock:
        return 'Overstock';
      case AlertType.slowMoving:
        return 'Slow Moving';
      case AlertType.fastMoving:
        return 'Fast Moving';
      case AlertType.reorderPoint:
        return 'Reorder Point';
      case AlertType.expiringSoon:
        return 'Expiring Soon';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  // Event handlers
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Alerts'),
        content: const Text('Advanced filtering options will be implemented'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _markAllAsRead() async {
    try {
      // Mark all unread alerts as read
      final batch = FirebaseFirestore.instance.batch();
      
      for (final alert in _allAlerts.where((a) => !a.isRead)) {
        final docRef = FirebaseFirestore.instance
            .collection('inventoryAlerts')
            .doc(alert.id);
        batch.update(docRef, {'isRead': true});
      }
      
      await batch.commit();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All alerts marked as read')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking alerts as read: $e')),
      );
    }
  }

  void _handleAlertAction(String action, InventoryAlert alert) async {
    switch (action) {
      case 'mark_read':
        await InventoryManagementService.markAlertAsRead(alert.id);
        break;
      case 'acknowledge':
        _showAcknowledgeDialog(alert);
        break;
      case 'view_product':
        _viewProduct(alert.productId);
        break;
    }
  }

  void _showAlertDetails(InventoryAlert alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(alert.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.message),
            const SizedBox(height: 16),
            if (alert.data.isNotEmpty) ...[
              const Text(
                'Details:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...alert.data.entries.map((entry) => 
                Text('${entry.key}: ${entry.value}')
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!alert.isRead)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                InventoryManagementService.markAlertAsRead(alert.id);
              },
              child: const Text('Mark Read'),
            ),
        ],
      ),
    );
  }

  void _showAcknowledgeDialog(InventoryAlert alert) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acknowledge Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This will mark the alert as resolved. Please provide a reason:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              InventoryManagementService.acknowledgeAlert(
                alert.id,
                reasonController.text,
              );
            },
            child: const Text('Acknowledge'),
          ),
        ],
      ),
    );
  }

  void _viewProduct(String productId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to product details')),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _alertsSubscription?.cancel();
    super.dispose();
  }
}