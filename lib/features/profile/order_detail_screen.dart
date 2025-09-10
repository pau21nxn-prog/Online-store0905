import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../common/theme.dart';
import '../../common/mobile_layout_utils.dart';

// Order Status Enum
enum OrderStatus {
  pending,
  confirmed,
  processing,
  shipped,
  delivered,
  cancelled,
  refunded;

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.shipped:
        return 'Shipped';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.refunded:
        return 'Refunded';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.processing:
        return Colors.purple;
      case OrderStatus.shipped:
        return Colors.teal;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.refunded:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case OrderStatus.pending:
        return Icons.schedule;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline;
      case OrderStatus.processing:
        return Icons.build_circle_outlined;
      case OrderStatus.shipped:
        return Icons.local_shipping_outlined;
      case OrderStatus.delivered:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.refunded:
        return Icons.undo;
    }
  }

  String get description {
    switch (this) {
      case OrderStatus.pending:
        return 'Your order is being reviewed and will be processed soon';
      case OrderStatus.confirmed:
        return 'Order confirmed and being prepared for shipment';
      case OrderStatus.processing:
        return 'Your order is being processed and packed';
      case OrderStatus.shipped:
        return 'Order is on the way to your delivery address';
      case OrderStatus.delivered:
        return 'Order delivered successfully. Enjoy your purchase!';
      case OrderStatus.cancelled:
        return 'Order has been cancelled and will not be shipped';
      case OrderStatus.refunded:
        return 'Order refund has been processed to your account';
    }
  }
}

// OrderItem Model
class OrderItem {
  final String productId;
  final String productName;
  final String productImage;
  final double price;
  final int quantity;
  final double total;
  final String? variant; // Keep for backward compatibility
  final String? sku;
  
  // Enhanced variant information
  final String? selectedVariantId;
  final Map<String, String>? selectedOptions;
  final String? variantSku;
  final String? variantDisplayName;

  const OrderItem({
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.price,
    required this.quantity,
    required this.total,
    this.variant,
    this.sku,
    this.selectedVariantId,
    this.selectedOptions,
    this.variantSku,
    this.variantDisplayName,
  });

  String get formattedPrice => '₱${price.toStringAsFixed(2)}';
  String get formattedTotal => '₱${total.toStringAsFixed(2)}';

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      productImage: data['productImage'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      quantity: data['quantity'] ?? 0,
      total: (data['total'] ?? 0.0).toDouble(),
      variant: data['variant'],
      sku: data['sku'],
      selectedVariantId: data['selectedVariantId'],
      selectedOptions: data['selectedOptions'] != null 
          ? Map<String, String>.from(data['selectedOptions']) 
          : null,
      variantSku: data['variantSku'],
      variantDisplayName: data['variantDisplayName'],
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = {
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'price': price,
      'quantity': quantity,
      'total': total,
    };
    
    // Legacy fields for backward compatibility
    if (variant != null) map['variant'] = variant!;
    if (sku != null) map['sku'] = sku!;
    
    // Enhanced variant fields
    if (selectedVariantId != null) map['selectedVariantId'] = selectedVariantId!;
    if (selectedOptions != null) map['selectedOptions'] = selectedOptions!;
    if (variantSku != null) map['variantSku'] = variantSku!;
    if (variantDisplayName != null) map['variantDisplayName'] = variantDisplayName!;
    
    return map;
  }
}

// UserOrder Model
class UserOrder {
  final String id;
  final String userId;
  final List<OrderItem> items;
  final double subtotal;
  final double shippingFee;
  final double tax;
  final double total;
  final OrderStatus status;
  final String paymentMethod;
  final bool isPaid;
  final Map<String, dynamic> shippingAddress;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? trackingNumber;
  final String? notes;
  final Map<String, dynamic>? paymentDetails;

  const UserOrder({
    required this.id,
    required this.userId,
    required this.items,
    required this.subtotal,
    required this.shippingFee,
    required this.tax,
    required this.total,
    required this.status,
    required this.paymentMethod,
    required this.isPaid,
    required this.shippingAddress,
    required this.createdAt,
    this.updatedAt,
    this.trackingNumber,
    this.notes,
    this.paymentDetails,
  });

  String get paymentMethodDisplayName {
    switch (paymentMethod.toLowerCase()) {
      case 'cod':
        return 'Cash on Delivery';
      case 'gcash':
        return 'GCash';
      case 'card':
      case 'creditcard':
        return 'Credit Card';
      case 'banktransfer':
        return 'Bank Transfer';
      case 'paymaya':
        return 'PayMaya';
      default:
        return paymentMethod.toUpperCase();
    }
  }

  IconData get paymentIcon {
    switch (paymentMethod.toLowerCase()) {
      case 'cod':
        return Icons.money;
      case 'gcash':
        return Icons.phone_android;
      case 'card':
      case 'creditcard':
        return Icons.credit_card;
      case 'banktransfer':
        return Icons.account_balance;
      case 'paymaya':
        return Icons.payment;
      default:
        return Icons.payment;
    }
  }

  String get formattedTotal => '₱${total.toStringAsFixed(2)}';
  String get formattedSubtotal => '₱${subtotal.toStringAsFixed(2)}';
  String get formattedShippingFee => '₱${shippingFee.toStringAsFixed(2)}';
  String get formattedTax => '₱${tax.toStringAsFixed(2)}';
  String get shortId => id.substring(0, 8).toUpperCase();

  String get formattedShippingAddress {
    final fullName = shippingAddress['fullName'] ?? '';
    final parts = [
      shippingAddress['addressLine1'] ?? '',
      if ((shippingAddress['addressLine2'] ?? '').isNotEmpty) 
        shippingAddress['addressLine2'],
      shippingAddress['city'] ?? '',
      shippingAddress['state'] ?? '',
      shippingAddress['postalCode'] ?? '',
      shippingAddress['country'] ?? '',
    ];
    final address = parts.where((part) => part.isNotEmpty).join(', ');
    return fullName.isNotEmpty ? '$fullName\n$address' : address;
  }

  factory UserOrder.fromFirestore(String id, Map<String, dynamic> data) {
    return UserOrder(
      id: id,
      userId: data['buyerUid'] ?? data['userId'] ?? '',
      items: (data['items'] as List<dynamic>?)
          ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
          .toList() ?? [],
      subtotal: (data['subtotal'] ?? 0.0).toDouble(),
      shippingFee: (data['shippingFee'] ?? 0.0).toDouble(),
      tax: (data['tax'] ?? 0.0).toDouble(),
      total: (data['total'] ?? 0.0).toDouble(),
      status: OrderStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => OrderStatus.pending,
      ),
      paymentMethod: data['paymentMethod'] ?? 'cod',
      isPaid: data['isPaid'] ?? false,
      shippingAddress: Map<String, dynamic>.from(data['shippingAddress'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      trackingNumber: data['trackingNumber'],
      notes: data['notes'],
      paymentDetails: data['paymentDetails'] != null 
          ? Map<String, dynamic>.from(data['paymentDetails']) 
          : null,
    );
  }
}

// Timeline Step Model
class TimelineStep {
  final OrderStatus status;
  final String title;
  final DateTime? timestamp;

  const TimelineStep({
    required this.status,
    required this.title,
    this.timestamp,
  });
}

class OrderDetailScreen extends StatefulWidget {
  final UserOrder order;

  const OrderDetailScreen({
    super.key,
    required this.order,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      appBar: _buildAppBar(),
      backgroundColor: AppTheme.backgroundColor(context),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _refreshOrder,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildOrderStatusCard(),
                    const SizedBox(height: 16),
                    _buildOrderItemsCard(),
                    const SizedBox(height: 16),
                    _buildOrderSummaryCard(),
                    const SizedBox(height: 16),
                    _buildShippingAddressCard(),
                    const SizedBox(height: 16),
                    _buildPaymentInfoCard(),
                    if (widget.order.notes?.isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      _buildNotesCard(),
                    ],
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Order #${widget.order.shortId}',
        style: TextStyle(color: AppTheme.textPrimaryColor(context)),
      ),
      backgroundColor: AppTheme.backgroundColor(context),
      foregroundColor: AppTheme.textPrimaryColor(context),
      elevation: 0,
      actions: [
        if (widget.order.trackingNumber != null)
          IconButton(
            icon: const Icon(Icons.local_shipping),
            onPressed: _showTrackingInfo,
            tooltip: 'Track Package',
          ),
        _buildMenuButton(),
      ],
    );
  }

  Widget _buildMenuButton() {
    return PopupMenuButton<String>(
      onSelected: _handleMenuAction,
      itemBuilder: (context) => [
        if (_canCancelOrder())
          const PopupMenuItem(
            value: 'cancel',
            child: _MenuTile(
              icon: Icons.cancel,
              text: 'Cancel Order',
              color: Colors.red,
            ),
          ),
        const PopupMenuItem(
          value: 'copy_id',
          child: _MenuTile(
            icon: Icons.copy,
            text: 'Copy Order ID',
          ),
        ),
        const PopupMenuItem(
          value: 'share',
          child: _MenuTile(
            icon: Icons.share,
            text: 'Share Order',
          ),
        ),
        const PopupMenuItem(
          value: 'help',
          child: _MenuTile(
            icon: Icons.help,
            text: 'Get Help',
          ),
        ),
      ],
    );
  }

  Widget _buildOrderStatusCard() {
    return _CardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Order Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              _buildStatusChip(),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatusHeader(),
          const SizedBox(height: 16),
          _buildTimeline(),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    final status = widget.order.status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status.color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.displayName.toUpperCase(),
        style: TextStyle(
          color: status.color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    final status = widget.order.status;
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: status.color.withValues(alpha: 0.1),
          child: Icon(status.icon, color: status.color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                status.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              if (widget.order.updatedAt != null)
                Text(
                  'Updated: ${_formatDetailedDate(widget.order.updatedAt!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline() {
    final steps = _getTimelineSteps();
    
    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isCompleted = step.status.index <= widget.order.status.index;
        final isCurrent = step.status == widget.order.status;
        final isLast = index == steps.length - 1;

        return _TimelineTile(
          isCompleted: isCompleted,
          isCurrent: isCurrent,
          isLast: isLast,
          title: step.title,
          timestamp: step.timestamp,
        );
      }).toList(),
    );
  }

  List<TimelineStep> _getTimelineSteps() {
    return [
      TimelineStep(
        status: OrderStatus.pending,
        title: 'Order Placed',
        timestamp: widget.order.createdAt,
      ),
      const TimelineStep(
        status: OrderStatus.confirmed,
        title: 'Order Confirmed',
      ),
      const TimelineStep(
        status: OrderStatus.processing,
        title: 'Processing',
      ),
      const TimelineStep(
        status: OrderStatus.shipped,
        title: 'Shipped',
      ),
      const TimelineStep(
        status: OrderStatus.delivered,
        title: 'Delivered',
      ),
    ];
  }

  Widget _buildOrderItemsCard() {
    return _CardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Items (${widget.order.items.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...widget.order.items.map((item) => _OrderItemTile(item: item)),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    return _CardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Subtotal', value: widget.order.formattedSubtotal),
          _SummaryRow(label: 'Shipping Fee', value: widget.order.formattedShippingFee),
          if (widget.order.tax > 0)
            _SummaryRow(label: 'Tax', value: widget.order.formattedTax),
          const Divider(height: 24),
          _SummaryRow(
            label: 'Total',
            value: widget.order.formattedTotal,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildShippingAddressCard() {
    return _CardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shipping Address',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _AddressDisplay(address: widget.order.shippingAddress),
        ],
      ),
    );
  }

  Widget _buildPaymentInfoCard() {
    return _CardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _PaymentDisplay(order: widget.order),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return _CardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Notes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              widget.order.notes!,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final buttons = <Widget>[];

    if (_canCancelOrder()) {
      buttons.add(
        Expanded(
          child: _ActionButton(
            onPressed: _cancelOrder,
            icon: Icons.cancel,
            label: 'Cancel Order',
            isDestructive: true,
          ),
        ),
      );
    }

    if (widget.order.status == OrderStatus.delivered) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 12));
      buttons.add(
        Expanded(
          child: _ActionButton(
            onPressed: _rateAndReview,
            icon: Icons.star,
            label: 'Rate & Review',
            isPrimary: true,
          ),
        ),
      );
    }

    if (widget.order.status == OrderStatus.shipped && 
        widget.order.trackingNumber != null) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 12));
      buttons.add(
        Expanded(
          child: _ActionButton(
            onPressed: _showTrackingInfo,
            icon: Icons.local_shipping,
            label: 'Track Package',
            isPrimary: true,
          ),
        ),
      );
    }

    if (widget.order.status == OrderStatus.delivered) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 12));
      buttons.add(
        Expanded(
          child: _ActionButton(
            onPressed: _buyAgain,
            icon: Icons.refresh,
            label: 'Buy Again',
          ),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Row(children: buttons);
  }

  bool _canCancelOrder() {
    return widget.order.status == OrderStatus.pending || 
           widget.order.status == OrderStatus.confirmed;
  }

  String _formatDetailedDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final orderDate = DateTime(date.year, date.month, date.day);
    
    if (orderDate == today) {
      return 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (orderDate == yesterday) {
      return 'Yesterday, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  Future<void> _refreshOrder() async {
    // Simulate refresh delay
    await Future.delayed(const Duration(seconds: 1));
    // In a real app, you would fetch updated order data here
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order refreshed'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'cancel':
        _cancelOrder();
        break;
      case 'copy_id':
        _copyOrderId();
        break;
      case 'share':
        _shareOrder();
        break;
      case 'help':
        _getHelp();
        break;
    }
  }

  void _copyOrderId() {
    Clipboard.setData(ClipboardData(text: widget.order.id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Order ID copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _cancelOrder() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text(
          'Are you sure you want to cancel order #${widget.order.shortId}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _showSuccessMessage('Order cancellation request submitted');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
  }

  void _rateAndReview() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate Your Purchase'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('How was your experience with these items?'),
            SizedBox(height: 16),
            Text('Your feedback helps other customers make informed decisions.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showInfoMessage('Rate & Review feature coming soon!');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange),
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }

  void _showTrackingInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Track Your Package'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.local_shipping, color: AppTheme.primaryOrange),
                SizedBox(width: 8),
                Text('Tracking Number:'),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                widget.order.trackingNumber!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Your package is being tracked and will be delivered soon.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showInfoMessage('Opening tracking website...');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange),
            child: const Text('Track Online'),
          ),
        ],
      ),
    );
  }

  void _buyAgain() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buy Again'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add all items from this order to your cart?'),
            const SizedBox(height: 12),
            Text(
              '${widget.order.items.length} items • ${widget.order.formattedTotal}',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
              _showSuccessMessage('Items added to cart!');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange),
            child: const Text('Add to Cart'),
          ),
        ],
      ),
    );
  }

  void _shareOrder() {
    _showInfoMessage('Share order feature coming soon!');
  }

  void _getHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Need Help?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How can we help you with this order?'),
            SizedBox(height: 16),
            Text('• Contact customer support'),
            Text('• Report an issue with your order'),
            Text('• Request a refund or return'),
            Text('• Get delivery updates'),
            Text('• Product questions'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showInfoMessage('Opening support chat...');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange),
            child: const Text('Contact Support'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfoMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// Reusable Widgets
class _CardWrapper extends StatelessWidget {
  final Widget child;

  const _CardWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _MenuTile({
    required this.icon,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: color)),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;
  final String title;
  final DateTime? timestamp;

  const _TimelineTile({
    required this.isCompleted,
    required this.isCurrent,
    required this.isLast,
    required this.title,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? AppTheme.primaryOrange : Colors.grey.shade300,
                border: Border.all(
                  color: isCurrent ? AppTheme.primaryOrange : Colors.transparent,
                  width: 2,
                ),
              ),
              child: isCompleted 
                  ? Icon(
                      isCurrent ? Icons.radio_button_checked : Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted ? AppTheme.primaryOrange : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    color: isCompleted ? Colors.black87 : Colors.grey,
                    fontSize: 14,
                  ),
                ),
                if (timestamp != null)
                  Text(
                    _formatDate(timestamp!),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final orderDate = DateTime(date.year, date.month, date.day);
    
    if (orderDate == today) {
      return 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (orderDate == yesterday) {
      return 'Yesterday, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }
}

class _OrderItemTile extends StatelessWidget {
  final OrderItem item;

  const _OrderItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _buildProductImage(),
          const SizedBox(width: 12),
          Expanded(
            child: _buildProductDetails(),
          ),
          _buildPriceDisplay(),
        ],
      ),
    );
  }

  Widget _buildProductImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 60,
        height: 60,
        child: item.productImage.isNotEmpty
            ? Image.network(
                item.productImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                },
              )
            : Container(
                color: Colors.grey.shade200,
                child: Image.asset(
                  'images/Logo/48x48.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                ),
              ),
      ),
    );
  }

  Widget _buildProductDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.productName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (item.variant != null) ...[
          const SizedBox(height: 2),
          Text(
            item.variant!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              item.formattedPrice,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              ' × ${item.quantity}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceDisplay() {
    return Text(
      item.formattedTotal,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryOrange,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.w600,
              color: isTotal ? AppTheme.primaryOrange : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressDisplay extends StatelessWidget {
  final Map<String, dynamic> address;

  const _AddressDisplay({required this.address});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on, color: AppTheme.primaryOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address['fullName'] ?? 'N/A',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (address['phoneNumber'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    address['phoneNumber'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  _formatAddress(),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAddress() {
    final parts = [
      address['addressLine1'] ?? '',
      if ((address['addressLine2'] ?? '').isNotEmpty) address['addressLine2'],
      address['city'] ?? '',
      address['state'] ?? '',
      address['postalCode'] ?? '',
      address['country'] ?? '',
    ];
    return parts.where((part) => part.isNotEmpty).join(', ');
  }
}

class _PaymentDisplay extends StatelessWidget {
  final UserOrder order;

  const _PaymentDisplay({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            order.paymentIcon,
            color: AppTheme.primaryOrange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.paymentMethodDisplayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  order.isPaid ? 'Payment Successful' : 'Payment Pending',
                  style: TextStyle(
                    fontSize: 12,
                    color: order.isPaid ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: order.isPaid 
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              order.isPaid ? 'PAID' : 'PENDING',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: order.isPaid ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool isPrimary;
  final bool isDestructive;

  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryOrange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDestructive ? Colors.red : AppTheme.primaryOrange,
        side: BorderSide(
          color: isDestructive ? Colors.red : AppTheme.primaryOrange,
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}