import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../common/theme.dart';
import '../../models/order.dart';

class OrdersManagementScreen extends StatefulWidget {
  const OrdersManagementScreen({super.key});

  @override
  State<OrdersManagementScreen> createState() => _OrdersManagementScreenState();
}

class _OrdersManagementScreenState extends State<OrdersManagementScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _paymentFilter = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isFiltersExpanded = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
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
          
          // Advanced Filters Section
          _buildFiltersSection(),
          const SizedBox(height: AppTheme.spacing16),
          
          // Search with enhanced styling
          TextField(
            decoration: InputDecoration(
              hintText: 'Search orders by ID, customer, or product...',
              prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
              suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.outline),
                      onPressed: () => setState(() => _searchQuery = ''),
                      tooltip: 'Clear search',
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: AppTheme.spacing24),
          
          // Orders Table
          Expanded(
            child: _buildOrdersTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getOrdersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final orders = snapshot.data!.docs
            .map((doc) => UserOrder.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
            .where((order) => _filterOrder(order))
            .toList();

        if (orders.isEmpty) {
          return _buildEmptyState();
        }

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text('Order No.', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer))),
                      Expanded(flex: 3, child: Text('Date/Time', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer))),
                      Expanded(flex: 2, child: Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer))),
                      Expanded(flex: 2, child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer))),
                      Expanded(flex: 2, child: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer))),
                      Expanded(flex: 5, child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer))),
                      Expanded(flex: 1, child: Text('Qty.', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer))),
                      Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer))),
                      Expanded(flex: 3, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer))),
                      Expanded(flex: 2, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer), textAlign: TextAlign.center)),
                    ],
                  ),
                ),
              ),
              // Table Body
              Expanded(
                child: ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _buildOrderRow(order, index);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Stream<QuerySnapshot> _getOrdersStream() {
    Query query = FirebaseFirestore.instance.collection('orders');
    
    // Apply status filter
    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    }
    
    // Apply payment method filter  
    if (_paymentFilter != 'all') {
      query = query.where('paymentMethod', isEqualTo: _paymentFilter);
    }
    
    // Apply date range filter
    if (_startDate != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: _startDate);
    }
    if (_endDate != null) {
      DateTime endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      query = query.where('createdAt', isLessThanOrEqualTo: endOfDay);
    }
    
    return query.orderBy('createdAt', descending: true).snapshots();
  }

  bool _filterOrder(UserOrder order) {
    if (_searchQuery.isEmpty) return true;
    
    final query = _searchQuery.toLowerCase();
    return order.id.toLowerCase().contains(query) ||
           order.items.any((item) => 
               item.productName.toLowerCase().contains(query)) ||
           (order.shippingAddress['fullName'] ?? '').toLowerCase().contains(query);
  }

  Widget _buildOrderRow(UserOrder order, int index) {
    final backgroundColor = index.isEven 
        ? AppTheme.surfaceGrayColor(context)
        : AppTheme.surfaceColor(context);
    
    // DEBUG: Log complete shippingAddress contents for this order
    debugPrint('🔍 DEBUG - EMAIL TRACKING: Order ${order.id} shippingAddress inspection:');
    debugPrint('  - shippingAddress type: ${order.shippingAddress.runtimeType}');
    debugPrint('  - Keys available: ${order.shippingAddress.keys.toList()}');
    debugPrint('  - Complete shippingAddress map: ${order.shippingAddress}');
    debugPrint('  - Direct email access: "${order.shippingAddress['email']}"');
    debugPrint('  - Email key exists: ${order.shippingAddress.containsKey('email')}');
    
    // Get user email from order's shipping address with enhanced fallback logic
    String userEmail = order.shippingAddress['email'] ?? 'N/A';
    
    // Handle legacy orders without email field
    if (userEmail == 'N/A' || userEmail.isEmpty) {
      // Try alternative email storage locations (if any)
      userEmail = order.shippingAddress['customerEmail'] ?? 
                 order.shippingAddress['userEmail'] ?? 
                 'Email not available';
      
      // DEBUG: Log fallback attempt
      debugPrint('  - Email fallback result: "$userEmail"');
      debugPrint('  - This appears to be a legacy order without email field');
    }
    
    // DEBUG: Log final email result
    debugPrint('  - Final userEmail result: "$userEmail"');
    
    // Create detailed items display
    final itemsDisplay = _buildItemsDisplay(order.items);
    
    final totalQuantity = order.items.fold<int>(0, (sum, item) => sum + item.quantity);
    
    // Format order date and time
    final formattedDateTime = _formatDateTime(order.createdAt);
    
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                order.id,
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(context)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                formattedDateTime,
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(context)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                order.shippingAddress['fullName'] ?? 'N/A',
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(context)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                userEmail,
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(context)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                order.shippingAddress['phoneNumber'] ?? 'N/A',
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(context)),
              ),
            ),
            Expanded(
              flex: 5,
              child: Container(
                constraints: const BoxConstraints(minHeight: 50),
                child: Text(
                  itemsDisplay,
                  style: TextStyle(fontSize: 12, color: AppTheme.textPrimary(context)),
                  maxLines: null,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                totalQuantity.toString(),
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(context)),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                order.formattedTotal,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary(context)),
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                '${order.statusDisplayName.toUpperCase()} • ${_formatDateTime(_getStatusTimestamp(order))}',
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimary(context)),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.edit,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () => _editOrder(order),
                    tooltip: 'Edit Order',
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      Icons.cancel,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () => _cancelOrder(order),
                    tooltip: 'Cancel Order',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: AppTheme.textSecondaryColor(context),
          ),
          const SizedBox(height: 16),
          Text(
            'No orders found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Orders will appear here once customers place them',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _editOrder(UserOrder order) async {
    // Simple status update dialog
    final newStatus = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Order Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Order ${order.id}', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: order.status.name,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: ['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled']
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (value) => Navigator.of(context).pop(value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (newStatus != null && newStatus != order.status.name) {
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(order.id)
            .update({'status': newStatus, 'updatedAt': FieldValue.serverTimestamp()});
        
        _showSuccessMessage('Order updated successfully');
      } catch (e) {
        _showErrorMessage('Error updating order: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelOrder(UserOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text('Are you sure you want to cancel Order ${order.id}?', style: TextStyle(fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(order.id)
            .update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        _showSuccessMessage('Order cancelled successfully');
      } catch (e) {
        _showErrorMessage('Error cancelling order: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildFiltersSection() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Filter Header
          InkWell(
            onTap: () => setState(() => _isFiltersExpanded = !_isFiltersExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Advanced Filters',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (_hasActiveFilters())
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_getActiveFilterCount()}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Icon(
                    _isFiltersExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          
          // Filter Content
          if (_isFiltersExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Status Filter
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order Status',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _statusFilter,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('All Orders')),
                                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                                DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                                DropdownMenuItem(value: 'processing', child: Text('Processing')),
                                DropdownMenuItem(value: 'shipped', child: Text('Shipped')),
                                DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _statusFilter = value);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Payment Method Filter
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Method',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _paymentFilter,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('All Methods')),
                                DropdownMenuItem(value: 'cod', child: Text('Cash on Delivery')),
                                DropdownMenuItem(value: 'gcash', child: Text('GCash')),
                                DropdownMenuItem(value: 'card', child: Text('Credit/Debit Card')),
                                DropdownMenuItem(value: 'bankTransfer', child: Text('Bank Transfer')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _paymentFilter = value);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Date Range Filter
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order From',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => _selectDate(true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _startDate != null
                                          ? _formatDate(_startDate!)
                                          : 'Select date',
                                      style: TextStyle(
                                        color: _startDate != null 
                                            ? Theme.of(context).colorScheme.onSurface
                                            : Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_startDate != null)
                                      InkWell(
                                        onTap: () => setState(() => _startDate = null),
                                        child: Icon(
                                          Icons.clear,
                                          size: 16,
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order To',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => _selectDate(false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _endDate != null
                                          ? _formatDate(_endDate!)
                                          : 'Select date',
                                      style: TextStyle(
                                        color: _endDate != null 
                                            ? Theme.of(context).colorScheme.onSurface
                                            : Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_endDate != null)
                                      InkWell(
                                        onTap: () => setState(() => _endDate = null),
                                        child: Icon(
                                          Icons.clear,
                                          size: 16,
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Filter Actions
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Clear Filters'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showSuccessMessage('Filters applied successfully'),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Apply Filters'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _statusFilter != 'all' ||
           _paymentFilter != 'all' ||
           _startDate != null ||
           _endDate != null;
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_statusFilter != 'all') count++;
    if (_paymentFilter != 'all') count++;
    if (_startDate != null) count++;
    if (_endDate != null) count++;
    return count;
  }

  void _clearFilters() {
    setState(() {
      _statusFilter = 'all';
      _paymentFilter = 'all';
      _startDate = null;
      _endDate = null;
      _searchQuery = '';
    });
    _showSuccessMessage('Filters cleared');
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(message),
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
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
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

  // Helper method to format DateTime (already in Philippine timezone from Firestore)
  String _formatDateTime(DateTime dateTime) {
    // Firestore already stores in Philippine timezone (UTC+8), no conversion needed
    
    // Format as yyyy-mm-dd hh:mm am/pm
    final dateFormatter = DateFormat('yyyy-MM-dd');
    final timeFormatter = DateFormat('h:mm a');
    
    final dateStr = dateFormatter.format(dateTime);
    final timeStr = timeFormatter.format(dateTime).toLowerCase();
    
    return '$dateStr $timeStr';
  }

  // Helper method to build multi-line items display (matching admin email format)
  String _buildItemsDisplay(List<OrderItem> items) {
    final List<String> itemDisplays = [];
    
    for (final item in items) {
      // Start with product name
      String productDisplay = item.productName;
      
      // Add variant information if available (format: Product - Variant)
      if (item.variantDisplayName != null && item.variantDisplayName!.isNotEmpty) {
        productDisplay += ' - ${item.variantDisplayName!}';
      }
      
      // Add SKU if available (format: Product - Variant (SKU: XXX))
      if (item.variantSku != null && item.variantSku!.isNotEmpty) {
        productDisplay += ' (SKU: ${item.variantSku!})';
      }
      
      itemDisplays.add(productDisplay);
    }
    
    return itemDisplays.join('\n');
  }
}