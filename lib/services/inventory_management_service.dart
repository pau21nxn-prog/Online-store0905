import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/product.dart';
import '../models/product_variant.dart';

enum AlertType {
  lowStock,
  outOfStock,
  overstock,
  slowMoving,
  fastMoving,
  reorderPoint,
  expiringSoon,
}

enum AlertPriority { low, medium, high, critical }

class InventoryAlert {
  final String id;
  final String productId;
  final String? variantId;
  final AlertType type;
  final AlertPriority priority;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final bool isRead;
  final bool isActive;
  final DateTime? acknowledgedAt;
  final String? acknowledgedBy;

  InventoryAlert({
    required this.id,
    required this.productId,
    this.variantId,
    required this.type,
    required this.priority,
    required this.title,
    required this.message,
    this.data = const {},
    required this.createdAt,
    this.isRead = false,
    this.isActive = true,
    this.acknowledgedAt,
    this.acknowledgedBy,
  });

  factory InventoryAlert.fromFirestore(String id, Map<String, dynamic> data) {
    return InventoryAlert(
      id: id,
      productId: data['productId'] ?? '',
      variantId: data['variantId'],
      type: AlertType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => AlertType.lowStock,
      ),
      priority: AlertPriority.values.firstWhere(
        (p) => p.name == data['priority'],
        orElse: () => AlertPriority.medium,
      ),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      isActive: data['isActive'] ?? true,
      acknowledgedAt: data['acknowledgedAt']?.toDate(),
      acknowledgedBy: data['acknowledgedBy'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'variantId': variantId,
      'type': type.name,
      'priority': priority.name,
      'title': title,
      'message': message,
      'data': data,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'isActive': isActive,
      'acknowledgedAt': acknowledgedAt != null ? Timestamp.fromDate(acknowledgedAt!) : null,
      'acknowledgedBy': acknowledgedBy,
    };
  }

  String get priorityDisplayName {
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

  String get typeDisplayName {
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

  bool get isOverdue => DateTime.now().difference(createdAt).inDays > 7;
}

class InventoryThreshold {
  final String productId;
  final String? variantId;
  final int lowStockThreshold;
  final int reorderPoint;
  final int maxStockLevel;
  final int reorderQuantity;
  final bool autoReorderEnabled;
  final int slowMovingDays;
  final double slowMovingThreshold;

  InventoryThreshold({
    required this.productId,
    this.variantId,
    this.lowStockThreshold = 10,
    this.reorderPoint = 5,
    this.maxStockLevel = 1000,
    this.reorderQuantity = 50,
    this.autoReorderEnabled = false,
    this.slowMovingDays = 30,
    this.slowMovingThreshold = 0.1,
  });

  factory InventoryThreshold.fromFirestore(Map<String, dynamic> data) {
    return InventoryThreshold(
      productId: data['productId'] ?? '',
      variantId: data['variantId'],
      lowStockThreshold: data['lowStockThreshold'] ?? 10,
      reorderPoint: data['reorderPoint'] ?? 5,
      maxStockLevel: data['maxStockLevel'] ?? 1000,
      reorderQuantity: data['reorderQuantity'] ?? 50,
      autoReorderEnabled: data['autoReorderEnabled'] ?? false,
      slowMovingDays: data['slowMovingDays'] ?? 30,
      slowMovingThreshold: (data['slowMovingThreshold'] ?? 0.1).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'variantId': variantId,
      'lowStockThreshold': lowStockThreshold,
      'reorderPoint': reorderPoint,
      'maxStockLevel': maxStockLevel,
      'reorderQuantity': reorderQuantity,
      'autoReorderEnabled': autoReorderEnabled,
      'slowMovingDays': slowMovingDays,
      'slowMovingThreshold': slowMovingThreshold,
    };
  }
}

class InventoryMovement {
  final String id;
  final String productId;
  final String? variantId;
  final String type; // sale, restock, adjustment, return, damage
  final int quantity;
  final int previousStock;
  final int newStock;
  final String? orderId;
  final String? reason;
  final DateTime timestamp;
  final String userId;

  InventoryMovement({
    required this.id,
    required this.productId,
    this.variantId,
    required this.type,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    this.orderId,
    this.reason,
    required this.timestamp,
    required this.userId,
  });

  factory InventoryMovement.fromFirestore(String id, Map<String, dynamic> data) {
    return InventoryMovement(
      id: id,
      productId: data['productId'] ?? '',
      variantId: data['variantId'],
      type: data['type'] ?? '',
      quantity: data['quantity'] ?? 0,
      previousStock: data['previousStock'] ?? 0,
      newStock: data['newStock'] ?? 0,
      orderId: data['orderId'],
      reason: data['reason'],
      timestamp: data['timestamp']?.toDate() ?? DateTime.now(),
      userId: data['userId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'variantId': variantId,
      'type': type,
      'quantity': quantity,
      'previousStock': previousStock,
      'newStock': newStock,
      'orderId': orderId,
      'reason': reason,
      'timestamp': Timestamp.fromDate(timestamp),
      'userId': userId,
    };
  }
}

class InventoryStats {
  final int totalProducts;
  final int lowStockProducts;
  final int outOfStockProducts;
  final int overstockProducts;
  final double totalInventoryValue;
  final int totalUnits;
  final int slowMovingProducts;
  final int fastMovingProducts;

  InventoryStats({
    this.totalProducts = 0,
    this.lowStockProducts = 0,
    this.outOfStockProducts = 0,
    this.overstockProducts = 0,
    this.totalInventoryValue = 0.0,
    this.totalUnits = 0,
    this.slowMovingProducts = 0,
    this.fastMovingProducts = 0,
  });
}

class InventoryManagementService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream controllers for real-time updates
  static final StreamController<List<InventoryAlert>> _alertsController =
      StreamController<List<InventoryAlert>>.broadcast();

  // Initialize the service
  static void initialize() {
    // Set up periodic inventory monitoring
    Timer.periodic(const Duration(hours: 1), (_) => _runInventoryMonitoring());
    
    // Listen to product changes for real-time alerts
    _firestore.collection('products').snapshots().listen(_onProductsChanged);
  }

  // Monitor inventory levels and create alerts
  static Future<void> _runInventoryMonitoring() async {
    try {
      // Get all products with variants
      final productsSnapshot = await _firestore.collection('products').get();
      
      for (final productDoc in productsSnapshot.docs) {
        final product = Product.fromFirestore(productDoc.id, productDoc.data());
        
        // Check variants
        final variantsSnapshot = await _firestore
            .collection('products')
            .doc(product.id)
            .collection('variants')
            .get();

        for (final variantDoc in variantsSnapshot.docs) {
          final variant = ProductVariant.fromFirestore(variantDoc.id, variantDoc.data());
          await _checkVariantThresholds(product, variant);
        }

        // Check product-level metrics
        await _checkProductMetrics(product);
      }
    } catch (e) {
      debugPrint('Error running inventory monitoring: $e');
    }
  }

  // Check variant against thresholds
  static Future<void> _checkVariantThresholds(Product product, ProductVariant variant) async {
    final threshold = await _getInventoryThreshold(product.id, variant.id);
    final currentStock = variant.inventory.available;

    // Low stock alert
    if (currentStock <= threshold.lowStockThreshold && currentStock > 0) {
      await _createAlert(
        productId: product.id,
        variantId: variant.id,
        type: AlertType.lowStock,
        priority: AlertPriority.medium,
        title: 'Low Stock Alert',
        message: '${product.title} (${variant.variantDisplayName}) is running low',
        data: {
          'currentStock': currentStock,
          'threshold': threshold.lowStockThreshold,
          'sku': variant.sku,
        },
      );
    }

    // Out of stock alert
    if (currentStock <= 0) {
      await _createAlert(
        productId: product.id,
        variantId: variant.id,
        type: AlertType.outOfStock,
        priority: AlertPriority.high,
        title: 'Out of Stock',
        message: '${product.title} (${variant.variantDisplayName}) is out of stock',
        data: {
          'currentStock': currentStock,
          'sku': variant.sku,
        },
      );
    }

    // Reorder point alert
    if (currentStock <= threshold.reorderPoint) {
      await _createAlert(
        productId: product.id,
        variantId: variant.id,
        type: AlertType.reorderPoint,
        priority: AlertPriority.medium,
        title: 'Reorder Point Reached',
        message: '${product.title} (${variant.variantDisplayName}) needs restocking',
        data: {
          'currentStock': currentStock,
          'reorderPoint': threshold.reorderPoint,
          'reorderQuantity': threshold.reorderQuantity,
          'sku': variant.sku,
        },
      );

      // Auto-reorder if enabled
      if (threshold.autoReorderEnabled) {
        await _createAutoReorderRequest(product, variant, threshold);
      }
    }

    // Overstock alert
    if (currentStock > threshold.maxStockLevel) {
      await _createAlert(
        productId: product.id,
        variantId: variant.id,
        type: AlertType.overstock,
        priority: AlertPriority.low,
        title: 'Overstock Alert',
        message: '${product.title} (${variant.variantDisplayName}) has excess inventory',
        data: {
          'currentStock': currentStock,
          'maxLevel': threshold.maxStockLevel,
          'sku': variant.sku,
        },
      );
    }
  }

  // Check product-level metrics
  static Future<void> _checkProductMetrics(Product product) async {
    // Check for slow-moving products
    final salesData = await _getProductSalesData(product.id, days: 30);
    final averageDailySales = salesData['totalSold'] / 30.0;
    
    if (averageDailySales < 0.1 && product.totalStock > 0) {
      await _createAlert(
        productId: product.id,
        type: AlertType.slowMoving,
        priority: AlertPriority.low,
        title: 'Slow Moving Product',
        message: '${product.title} has low sales velocity',
        data: {
          'averageDailySales': averageDailySales,
          'stockOnHand': product.totalStock,
          'daysOfInventory': product.totalStock / (averageDailySales + 0.001),
        },
      );
    }

    // Check for fast-moving products
    if (averageDailySales > 5 && product.totalStock < averageDailySales * 7) {
      await _createAlert(
        productId: product.id,
        type: AlertType.fastMoving,
        priority: AlertPriority.medium,
        title: 'Fast Moving Product',
        message: '${product.title} may need expedited restocking',
        data: {
          'averageDailySales': averageDailySales,
          'stockOnHand': product.totalStock,
          'daysOfInventory': product.totalStock / averageDailySales,
        },
      );
    }
  }

  // Create inventory alert
  static Future<void> _createAlert({
    required String productId,
    String? variantId,
    required AlertType type,
    required AlertPriority priority,
    required String title,
    required String message,
    Map<String, dynamic> data = const {},
  }) async {
    // Check if similar alert already exists and is active
    final existingQuery = _firestore
        .collection('inventoryAlerts')
        .where('productId', isEqualTo: productId)
        .where('type', isEqualTo: type.name)
        .where('isActive', isEqualTo: true);

    if (variantId != null) {
      existingQuery.where('variantId', isEqualTo: variantId);
    }

    final existingAlerts = await existingQuery.get();
    
    if (existingAlerts.docs.isNotEmpty) {
      // Update existing alert timestamp
      await existingAlerts.docs.first.reference.update({
        'createdAt': Timestamp.now(),
        'data': data,
      });
      return;
    }

    // Create new alert
    final alert = InventoryAlert(
      id: '',
      productId: productId,
      variantId: variantId,
      type: type,
      priority: priority,
      title: title,
      message: message,
      data: data,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('inventoryAlerts').add(alert.toFirestore());
  }

  // Get inventory threshold for product/variant
  static Future<InventoryThreshold> _getInventoryThreshold(String productId, [String? variantId]) async {
    try {
      Query query = _firestore
          .collection('inventoryThresholds')
          .where('productId', isEqualTo: productId);

      if (variantId != null) {
        query = query.where('variantId', isEqualTo: variantId);
      }

      final snapshot = await query.limit(1).get();
      
      if (snapshot.docs.isNotEmpty) {
        return InventoryThreshold.fromFirestore(snapshot.docs.first.data() as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Error getting inventory threshold: $e');
    }

    // Return default threshold
    return InventoryThreshold(productId: productId, variantId: variantId);
  }

  // Get product sales data
  static Future<Map<String, dynamic>> _getProductSalesData(String productId, {int days = 30}) async {
    final startDate = DateTime.now().subtract(Duration(days: days));
    
    try {
      // This would query your orders collection
      // For now, return mock data
      return {
        'totalSold': 10,
        'totalRevenue': 500.0,
        'averageOrderValue': 50.0,
      };
    } catch (e) {
      debugPrint('Error getting sales data: $e');
      return {
        'totalSold': 0,
        'totalRevenue': 0.0,
        'averageOrderValue': 0.0,
      };
    }
  }

  // Create auto-reorder request
  static Future<void> _createAutoReorderRequest(
    Product product, 
    ProductVariant variant, 
    InventoryThreshold threshold
  ) async {
    try {
      await _firestore.collection('autoReorders').add({
        'productId': product.id,
        'variantId': variant.id,
        'quantity': threshold.reorderQuantity,
        'status': 'pending',
        'createdAt': Timestamp.now(),
        'createdBy': 'system',
        'productTitle': product.title,
        'variantSku': variant.sku,
        'currentStock': variant.inventory.available,
      });
    } catch (e) {
      debugPrint('Error creating auto-reorder: $e');
    }
  }

  // Public API methods

  // Get active alerts
  static Future<List<InventoryAlert>> getActiveAlerts({
    AlertPriority? priority,
    AlertType? type,
    bool unreadOnly = false,
  }) async {
    Query query = _firestore
        .collection('inventoryAlerts')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true);

    if (priority != null) {
      query = query.where('priority', isEqualTo: priority.name);
    }
    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }
    if (unreadOnly) {
      query = query.where('isRead', isEqualTo: false);
    }

    final snapshot = await query.limit(100).get();
    
    return snapshot.docs
        .map((doc) => InventoryAlert.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
  }

  // Watch alerts in real-time
  static Stream<List<InventoryAlert>> watchActiveAlerts() {
    return _firestore
        .collection('inventoryAlerts')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InventoryAlert.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  // Mark alert as read
  static Future<void> markAlertAsRead(String alertId) async {
    await _firestore.collection('inventoryAlerts').doc(alertId).update({
      'isRead': true,
    });
  }

  // Acknowledge alert
  static Future<void> acknowledgeAlert(String alertId, String reason) async {
    await _firestore.collection('inventoryAlerts').doc(alertId).update({
      'isActive': false,
      'acknowledgedAt': Timestamp.now(),
      'acknowledgedBy': _auth.currentUser?.uid,
      'reason': reason,
    });
  }

  // Set inventory threshold
  static Future<void> setInventoryThreshold(InventoryThreshold threshold) async {
    final docId = threshold.variantId != null 
        ? '${threshold.productId}_${threshold.variantId}'
        : threshold.productId;

    await _firestore
        .collection('inventoryThresholds')
        .doc(docId)
        .set(threshold.toFirestore(), SetOptions(merge: true));
  }

  // Record inventory movement
  static Future<void> recordInventoryMovement({
    required String productId,
    String? variantId,
    required String type,
    required int quantity,
    required int previousStock,
    required int newStock,
    String? orderId,
    String? reason,
  }) async {
    final movement = InventoryMovement(
      id: '',
      productId: productId,
      variantId: variantId,
      type: type,
      quantity: quantity,
      previousStock: previousStock,
      newStock: newStock,
      orderId: orderId,
      reason: reason,
      timestamp: DateTime.now(),
      userId: _auth.currentUser?.uid ?? 'system',
    );

    await _firestore.collection('inventoryMovements').add(movement.toFirestore());
  }

  // Get inventory stats
  static Future<InventoryStats> getInventoryStats() async {
    try {
      // This would aggregate data from your products
      // For now, return basic stats
      final productsSnapshot = await _firestore.collection('products').get();
      
      int totalProducts = 0;
      int lowStockProducts = 0;
      int outOfStockProducts = 0;
      double totalValue = 0.0;
      int totalUnits = 0;

      for (final doc in productsSnapshot.docs) {
        final product = Product.fromFirestore(doc.id, doc.data());
        totalProducts++;
        
        if (product.totalStock <= 0) {
          outOfStockProducts++;
        } else if (product.isLowStock) {
          lowStockProducts++;
        }
        
        totalUnits += product.totalStock;
        totalValue += product.priceRange.min * product.totalStock;
      }

      return InventoryStats(
        totalProducts: totalProducts,
        lowStockProducts: lowStockProducts,
        outOfStockProducts: outOfStockProducts,
        totalInventoryValue: totalValue,
        totalUnits: totalUnits,
      );
    } catch (e) {
      debugPrint('Error getting inventory stats: $e');
      return InventoryStats();
    }
  }

  // Get inventory movements for a product
  static Future<List<InventoryMovement>> getInventoryMovements(
    String productId, {
    String? variantId,
    int limit = 50,
  }) async {
    Query query = _firestore
        .collection('inventoryMovements')
        .where('productId', isEqualTo: productId)
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (variantId != null) {
      query = query.where('variantId', isEqualTo: variantId);
    }

    final snapshot = await query.get();
    
    return snapshot.docs
        .map((doc) => InventoryMovement.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
  }

  // Event handlers
  static void _onProductsChanged(QuerySnapshot snapshot) {
    // Handle real-time product changes
    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.modified) {
        final product = Product.fromFirestore(change.doc.id, change.doc.data() as Map<String, dynamic>);
        
        // Quick check for critical issues
        if (product.totalStock <= 0) {
          // Could trigger immediate alert
        }
      }
    }
  }

  // Utility methods
  static void debugPrint(String message) {
    debugPrint('[InventoryManagementService] $message');
  }

  // Dispose resources
  static void dispose() {
    _alertsController.close();
  }
}