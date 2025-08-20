import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/product.dart';
import '../models/product_variant.dart';

enum BulkOperationType {
  updateStatus,
  updateCategory,
  updatePrices,
  updateInventory,
  updateVisibility,
  delete,
  archive,
  export,
}

enum PriceUpdateStrategy {
  percentage,
  fixedAmount,
  setPrice,
  addMargin,
}

class BulkOperationRequest {
  final BulkOperationType type;
  final List<String> productIds;
  final Map<String, dynamic> parameters;
  final String? reason;

  BulkOperationRequest({
    required this.type,
    required this.productIds,
    this.parameters = const {},
    this.reason,
  });
}

class BulkOperationResult {
  final String operationId;
  final BulkOperationType type;
  final int totalItems;
  final int successCount;
  final int failureCount;
  final Map<String, BulkItemResult> itemResults;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String status; // pending, running, completed, failed, cancelled
  final String? errorMessage;

  BulkOperationResult({
    required this.operationId,
    required this.type,
    required this.totalItems,
    this.successCount = 0,
    this.failureCount = 0,
    this.itemResults = const {},
    required this.startedAt,
    this.completedAt,
    this.status = 'pending',
    this.errorMessage,
  });

  factory BulkOperationResult.fromMap(Map<String, dynamic> data) {
    return BulkOperationResult(
      operationId: data['operationId'] ?? '',
      type: BulkOperationType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => BulkOperationType.updateStatus,
      ),
      totalItems: data['totalItems'] ?? 0,
      successCount: data['successCount'] ?? 0,
      failureCount: data['failureCount'] ?? 0,
      itemResults: Map<String, BulkItemResult>.from(
        (data['itemResults'] ?? {}).map((k, v) => 
          MapEntry(k, BulkItemResult.fromMap(v))),
      ),
      startedAt: data['startedAt']?.toDate() ?? DateTime.now(),
      completedAt: data['completedAt']?.toDate(),
      status: data['status'] ?? 'pending',
      errorMessage: data['errorMessage'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'operationId': operationId,
      'type': type.name,
      'totalItems': totalItems,
      'successCount': successCount,
      'failureCount': failureCount,
      'itemResults': itemResults.map((k, v) => MapEntry(k, v.toMap())),
      'startedAt': Timestamp.fromDate(startedAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'status': status,
      'errorMessage': errorMessage,
    };
  }

  double get progressPercentage => 
      totalItems > 0 ? ((successCount + failureCount) / totalItems) * 100 : 0;

  bool get isCompleted => status == 'completed';
  bool get isRunning => status == 'running';
  bool get hasFailed => status == 'failed';
}

class BulkItemResult {
  final String itemId;
  final bool success;
  final String? errorMessage;
  final Map<String, dynamic> changes;

  BulkItemResult({
    required this.itemId,
    required this.success,
    this.errorMessage,
    this.changes = const {},
  });

  factory BulkItemResult.success({
    required String itemId,
    Map<String, dynamic> changes = const {},
  }) {
    return BulkItemResult(
      itemId: itemId,
      success: true,
      changes: changes,
    );
  }

  factory BulkItemResult.error({
    required String itemId,
    required String errorMessage,
  }) {
    return BulkItemResult(
      itemId: itemId,
      success: false,
      errorMessage: errorMessage,
    );
  }

  factory BulkItemResult.fromMap(Map<String, dynamic> data) {
    return BulkItemResult(
      itemId: data['itemId'] ?? '',
      success: data['success'] ?? false,
      errorMessage: data['errorMessage'],
      changes: Map<String, dynamic>.from(data['changes'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'success': success,
      'errorMessage': errorMessage,
      'changes': changes,
    };
  }
}

class PriceUpdateConfig {
  final PriceUpdateStrategy strategy;
  final double value;
  final bool updateCompareAtPrice;
  final double? minPrice;
  final double? maxPrice;

  PriceUpdateConfig({
    required this.strategy,
    required this.value,
    this.updateCompareAtPrice = false,
    this.minPrice,
    this.maxPrice,
  });

  double calculateNewPrice(double currentPrice) {
    double newPrice;
    
    switch (strategy) {
      case PriceUpdateStrategy.percentage:
        newPrice = currentPrice * (1 + value / 100);
        break;
      case PriceUpdateStrategy.fixedAmount:
        newPrice = currentPrice + value;
        break;
      case PriceUpdateStrategy.setPrice:
        newPrice = value;
        break;
      case PriceUpdateStrategy.addMargin:
        newPrice = currentPrice * (1 + value / 100);
        break;
    }

    // Apply min/max constraints
    if (minPrice != null && newPrice < minPrice!) {
      newPrice = minPrice!;
    }
    if (maxPrice != null && newPrice > maxPrice!) {
      newPrice = maxPrice!;
    }

    return newPrice;
  }
}

class BulkOperationsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Maximum items per batch operation to prevent timeouts
  static const int maxBatchSize = 500;
  static const int maxConcurrentBatches = 3;

  // Stream controller for operation progress
  static final StreamController<BulkOperationResult> _progressController = 
      StreamController<BulkOperationResult>.broadcast();

  // Update product status in bulk
  static Future<BulkOperationResult> updateProductStatus(
    List<String> productIds,
    ProductStatus newStatus, {
    String? reason,
  }) async {
    final request = BulkOperationRequest(
      type: BulkOperationType.updateStatus,
      productIds: productIds,
      parameters: {'status': newStatus.name},
      reason: reason,
    );

    return _executeBulkOperation(request, (batch, productId, params) async {
      final productRef = _firestore.collection('products').doc(productId);
      
      batch.update(productRef, {
        'workflow.stage': params['status'],
        'workflow.reviewedBy': newStatus == ProductStatus.published 
            ? _auth.currentUser?.uid 
            : null,
        'workflow.reviewedAt': newStatus == ProductStatus.published 
            ? Timestamp.now() 
            : null,
        'updatedAt': Timestamp.now(),
        'updatedBy': _auth.currentUser?.uid,
      });

      return {'status': params['status']};
    });
  }

  // Update category in bulk
  static Future<BulkOperationResult> updateProductCategory(
    List<String> productIds,
    String newCategoryId,
    List<String> categoryPath, {
    String? reason,
  }) async {
    final request = BulkOperationRequest(
      type: BulkOperationType.updateCategory,
      productIds: productIds,
      parameters: {
        'categoryId': newCategoryId,
        'categoryPath': categoryPath,
      },
      reason: reason,
    );

    return _executeBulkOperation(request, (batch, productId, params) async {
      final productRef = _firestore.collection('products').doc(productId);
      
      batch.update(productRef, {
        'primaryCategoryId': params['categoryId'],
        'categoryPath': params['categoryPath'],
        'updatedAt': Timestamp.now(),
        'updatedBy': _auth.currentUser?.uid,
      });

      return {
        'categoryId': params['categoryId'],
        'categoryPath': params['categoryPath'],
      };
    });
  }

  // Update prices in bulk
  static Future<BulkOperationResult> updatePrices(
    List<String> productIds,
    PriceUpdateConfig config, {
    String? reason,
  }) async {
    final request = BulkOperationRequest(
      type: BulkOperationType.updatePrices,
      productIds: productIds,
      parameters: {
        'strategy': config.strategy.name,
        'value': config.value,
        'updateCompareAtPrice': config.updateCompareAtPrice,
        'minPrice': config.minPrice,
        'maxPrice': config.maxPrice,
      },
      reason: reason,
    );

    return _executeBulkOperation(request, (batch, productId, params) async {
      // Get current product to calculate new price
      final productDoc = await _firestore.collection('products').doc(productId).get();
      if (!productDoc.exists) {
        throw Exception('Product not found');
      }

      final productData = productDoc.data()!;
      final currentMin = (productData['priceRange']?['min'] ?? 0).toDouble();
      final currentMax = (productData['priceRange']?['max'] ?? 0).toDouble();

      final newMin = config.calculateNewPrice(currentMin);
      final newMax = config.calculateNewPrice(currentMax);

      final productRef = _firestore.collection('products').doc(productId);
      
      batch.update(productRef, {
        'priceRange.min': newMin,
        'priceRange.max': newMax,
        'updatedAt': Timestamp.now(),
        'updatedBy': _auth.currentUser?.uid,
      });

      // Also update variants if they exist
      final variantsSnapshot = await _firestore
          .collection('products')
          .doc(productId)
          .collection('variants')
          .get();

      for (final variantDoc in variantsSnapshot.docs) {
        final variantData = variantDoc.data();
        final currentPrice = (variantData['price'] ?? 0).toDouble();
        final newPrice = config.calculateNewPrice(currentPrice);

        final variantRef = _firestore
            .collection('products')
            .doc(productId)
            .collection('variants')
            .doc(variantDoc.id);

        final updateData = <String, dynamic>{
          'price': newPrice,
          'updatedAt': Timestamp.now(),
        };

        if (config.updateCompareAtPrice && variantData['compareAtPrice'] != null) {
          final currentCompareAt = (variantData['compareAtPrice']).toDouble();
          updateData['compareAtPrice'] = config.calculateNewPrice(currentCompareAt);
        }

        batch.update(variantRef, updateData);
      }

      return {
        'oldPriceRange': {'min': currentMin, 'max': currentMax},
        'newPriceRange': {'min': newMin, 'max': newMax},
        'variantsUpdated': variantsSnapshot.docs.length,
      };
    });
  }

  // Update inventory in bulk
  static Future<BulkOperationResult> updateInventory(
    List<String> productIds,
    Map<String, dynamic> inventoryUpdates, {
    String? reason,
  }) async {
    final request = BulkOperationRequest(
      type: BulkOperationType.updateInventory,
      productIds: productIds,
      parameters: inventoryUpdates,
      reason: reason,
    );

    return _executeBulkOperation(request, (batch, productId, params) async {
      // Update variants inventory
      final variantsSnapshot = await _firestore
          .collection('products')
          .doc(productId)
          .collection('variants')
          .get();

      int totalStock = 0;
      bool isLowStock = false;

      for (final variantDoc in variantsSnapshot.docs) {
        final variantData = variantDoc.data();
        final currentAvailable = variantData['inventory']?['available'] ?? 0;
        
        int newAvailable = currentAvailable;
        
        if (params['operation'] == 'add') {
          newAvailable += (params['quantity'] ?? 0) as int;
        } else if (params['operation'] == 'set') {
          newAvailable = (params['quantity'] ?? 0) as int;
        } else if (params['operation'] == 'subtract') {
          newAvailable = (currentAvailable - (params['quantity'] ?? 0)).clamp(0, double.infinity).toInt();
        }

        totalStock += newAvailable;
        if (newAvailable <= 5) isLowStock = true; // Configurable threshold

        final variantRef = _firestore
            .collection('products')
            .doc(productId)
            .collection('variants')
            .doc(variantDoc.id);

        batch.update(variantRef, {
          'inventory.available': newAvailable,
          'updatedAt': Timestamp.now(),
        });
      }

      // Update product computed fields
      final productRef = _firestore.collection('products').doc(productId);
      batch.update(productRef, {
        'computed.totalStock': totalStock,
        'computed.isLowStock': isLowStock,
        'updatedAt': Timestamp.now(),
        'updatedBy': _auth.currentUser?.uid,
      });

      return {
        'operation': params['operation'],
        'quantity': params['quantity'],
        'newTotalStock': totalStock,
        'isLowStock': isLowStock,
      };
    });
  }

  // Delete products in bulk
  static Future<BulkOperationResult> deleteProducts(
    List<String> productIds, {
    String? reason,
  }) async {
    final request = BulkOperationRequest(
      type: BulkOperationType.delete,
      productIds: productIds,
      reason: reason,
    );

    return _executeBulkOperation(request, (batch, productId, params) async {
      // Delete product and all subcollections
      final productRef = _firestore.collection('products').doc(productId);
      
      // Delete variants
      final variantsSnapshot = await _firestore
          .collection('products')
          .doc(productId)
          .collection('variants')
          .get();
      
      for (final variantDoc in variantsSnapshot.docs) {
        batch.delete(variantDoc.reference);
      }

      // Delete media
      final mediaSnapshot = await _firestore
          .collection('products')
          .doc(productId)
          .collection('media')
          .get();
      
      for (final mediaDoc in mediaSnapshot.docs) {
        batch.delete(mediaDoc.reference);
      }

      // Delete product
      batch.delete(productRef);

      return {
        'deletedVariants': variantsSnapshot.docs.length,
        'deletedMedia': mediaSnapshot.docs.length,
      };
    });
  }

  // Archive products in bulk
  static Future<BulkOperationResult> archiveProducts(
    List<String> productIds, {
    String? reason,
  }) async {
    return updateProductStatus(productIds, ProductStatus.archived, reason: reason);
  }

  // Generic bulk operation executor
  static Future<BulkOperationResult> _executeBulkOperation(
    BulkOperationRequest request,
    Future<Map<String, dynamic>> Function(WriteBatch, String, Map<String, dynamic>) operation,
  ) async {
    final operationId = _generateOperationId();
    final result = BulkOperationResult(
      operationId: operationId,
      type: request.type,
      totalItems: request.productIds.length,
      startedAt: DateTime.now(),
      status: 'running',
    );

    // Save operation to Firestore for tracking
    await _firestore.collection('bulkOperations').doc(operationId).set(result.toMap());

    try {
      final itemResults = <String, BulkItemResult>{};
      int successCount = 0;
      int failureCount = 0;

      // Process in chunks to avoid batch size limits
      final chunks = _chunkList(request.productIds, maxBatchSize);
      
      for (int i = 0; i < chunks.length; i += maxConcurrentBatches) {
        final batchGroup = chunks.skip(i).take(maxConcurrentBatches);
        
        await Future.wait(batchGroup.map((chunk) async {
          final batch = _firestore.batch();
          
          for (final productId in chunk) {
            try {
              final changes = await operation(batch, productId, request.parameters);
              itemResults[productId] = BulkItemResult.success(
                itemId: productId,
                changes: changes,
              );
              successCount++;
            } catch (e) {
              itemResults[productId] = BulkItemResult.error(
                itemId: productId,
                errorMessage: e.toString(),
              );
              failureCount++;
            }
          }

          await batch.commit();
        }));

        // Update progress
        final updatedResult = BulkOperationResult(
          operationId: operationId,
          type: request.type,
          totalItems: request.productIds.length,
          successCount: successCount,
          failureCount: failureCount,
          itemResults: itemResults,
          startedAt: result.startedAt,
          status: 'running',
        );

        _progressController.add(updatedResult);
        await _firestore.collection('bulkOperations').doc(operationId).update(updatedResult.toMap());
      }

      // Final result
      final finalResult = BulkOperationResult(
        operationId: operationId,
        type: request.type,
        totalItems: request.productIds.length,
        successCount: successCount,
        failureCount: failureCount,
        itemResults: itemResults,
        startedAt: result.startedAt,
        completedAt: DateTime.now(),
        status: 'completed',
      );

      _progressController.add(finalResult);
      await _firestore.collection('bulkOperations').doc(operationId).update(finalResult.toMap());

      return finalResult;

    } catch (e) {
      final errorResult = BulkOperationResult(
        operationId: operationId,
        type: request.type,
        totalItems: request.productIds.length,
        startedAt: result.startedAt,
        completedAt: DateTime.now(),
        status: 'failed',
        errorMessage: e.toString(),
      );

      _progressController.add(errorResult);
      await _firestore.collection('bulkOperations').doc(operationId).update(errorResult.toMap());

      return errorResult;
    }
  }

  // Watch operation progress
  static Stream<BulkOperationResult> watchOperationProgress(String operationId) {
    return _firestore
        .collection('bulkOperations')
        .doc(operationId)
        .snapshots()
        .map((doc) => BulkOperationResult.fromMap(doc.data() ?? {}));
  }

  // Get operation history
  static Future<List<BulkOperationResult>> getOperationHistory({
    int limit = 50,
  }) async {
    final snapshot = await _firestore
        .collection('bulkOperations')
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => BulkOperationResult.fromMap(doc.data()))
        .toList();
  }

  // Utility methods
  static List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (int i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, (i + chunkSize).clamp(0, list.length)));
    }
    return chunks;
  }

  static String _generateOperationId() {
    return 'bulk_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Stream for all operation progress updates
  static Stream<BulkOperationResult> get operationProgressStream => _progressController.stream;

  // Dispose resources
  static void dispose() {
    _progressController.close();
  }
}