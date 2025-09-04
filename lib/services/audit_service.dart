import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Log an admin action to the audit trail
  static Future<void> logAction({
    required String action,
    required String targetType,
    String? targetId,
    String? targetUserId,
    String? targetOrderId,
    String? description,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final auditLog = {
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'targetUserId': targetUserId,
        'targetOrderId': targetOrderId,
        'adminId': currentUser.uid,
        'adminEmail': currentUser.email,
        'description': description,
        'metadata': metadata,
        'oldValues': oldValues,
        'newValues': newValues,
        'timestamp': FieldValue.serverTimestamp(),
        'ipAddress': null, // Would need additional implementation for IP tracking
        'userAgent': null, // Would need additional implementation for user agent
      };

      await _firestore.collection('auditLogs').add(auditLog);
    } catch (e) {
      debugPrint('Error logging audit action: $e');
      // Don't throw error to avoid breaking the main operation
    }
  }

  /// Log user-related actions
  static Future<void> logUserAction({
    required String action,
    required String userId,
    String? description,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    Map<String, dynamic>? metadata,
  }) async {
    await logAction(
      action: action,
      targetType: 'user',
      targetId: userId,
      targetUserId: userId,
      description: description,
      oldValues: oldValues,
      newValues: newValues,
      metadata: metadata,
    );
  }

  /// Log order-related actions
  static Future<void> logOrderAction({
    required String action,
    required String orderId,
    String? userId,
    String? description,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    Map<String, dynamic>? metadata,
  }) async {
    await logAction(
      action: action,
      targetType: 'order',
      targetId: orderId,
      targetOrderId: orderId,
      targetUserId: userId,
      description: description,
      oldValues: oldValues,
      newValues: newValues,
      metadata: metadata,
    );
  }

  /// Log bulk operations
  static Future<void> logBulkAction({
    required String action,
    required String targetType,
    required List<String> targetIds,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    await logAction(
      action: 'bulk_$action',
      targetType: targetType,
      description: description,
      metadata: {
        'targetCount': targetIds.length,
        'targetIds': targetIds,
        ...?metadata,
      },
    );
  }

  /// Log authentication actions
  static Future<void> logAuthAction({
    required String action,
    String? targetUserId,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    await logAction(
      action: action,
      targetType: 'auth',
      targetUserId: targetUserId,
      description: description,
      metadata: metadata,
    );
  }

  /// Log system actions
  static Future<void> logSystemAction({
    required String action,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    await logAction(
      action: action,
      targetType: 'system',
      description: description,
      metadata: metadata,
    );
  }

  /// Log data export actions
  static Future<void> logExportAction({
    required String exportType,
    required int recordCount,
    Map<String, dynamic>? filters,
  }) async {
    await logAction(
      action: 'export_data',
      targetType: 'data',
      description: 'Exported $recordCount $exportType records',
      metadata: {
        'exportType': exportType,
        'recordCount': recordCount,
        'filters': filters,
        'exportedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Get audit logs for a specific target
  static Stream<QuerySnapshot> getAuditLogs({
    String? targetType,
    String? targetId,
    String? targetUserId,
    String? targetOrderId,
    String? adminId,
    int limit = 100,
  }) {
    Query query = _firestore.collection('auditLogs');

    if (targetType != null) {
      query = query.where('targetType', isEqualTo: targetType);
    }
    if (targetId != null) {
      query = query.where('targetId', isEqualTo: targetId);
    }
    if (targetUserId != null) {
      query = query.where('targetUserId', isEqualTo: targetUserId);
    }
    if (targetOrderId != null) {
      query = query.where('targetOrderId', isEqualTo: targetOrderId);
    }
    if (adminId != null) {
      query = query.where('adminId', isEqualTo: adminId);
    }

    return query
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Get recent admin activity
  static Stream<QuerySnapshot> getRecentActivity({
    int limit = 50,
  }) {
    return _firestore
        .collection('auditLogs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Get audit logs for a date range
  static Stream<QuerySnapshot> getAuditLogsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? targetType,
    String? adminId,
    int limit = 100,
  }) {
    Query query = _firestore.collection('auditLogs');

    if (targetType != null) {
      query = query.where('targetType', isEqualTo: targetType);
    }
    if (adminId != null) {
      query = query.where('adminId', isEqualTo: adminId);
    }

    return query
        .where('timestamp', isGreaterThanOrEqualTo: startDate)
        .where('timestamp', isLessThanOrEqualTo: endDate)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Clean up old audit logs (optional - for data retention)
  static Future<void> cleanupOldLogs({
    required DateTime cutoffDate,
  }) async {
    try {
      final oldLogsQuery = await _firestore
          .collection('auditLogs')
          .where('timestamp', isLessThan: cutoffDate)
          .get();

      final batch = _firestore.batch();
      for (final doc in oldLogsQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      await logSystemAction(
        action: 'cleanup_audit_logs',
        description: 'Cleaned up ${oldLogsQuery.docs.length} old audit log entries',
        metadata: {
          'cutoffDate': cutoffDate.toIso8601String(),
          'deletedCount': oldLogsQuery.docs.length,
        },
      );
    } catch (e) {
      debugPrint('Error cleaning up audit logs: $e');
      throw e;
    }
  }

  /// Get audit statistics
  static Future<Map<String, dynamic>> getAuditStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('auditLogs');

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();
      
      final stats = <String, dynamic>{
        'totalActions': snapshot.docs.length,
        'actionsByType': <String, int>{},
        'actionsByAdmin': <String, int>{},
        'actionsByTarget': <String, int>{},
      };

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Count by action type
        final action = data['action'] as String?;
        if (action != null) {
          stats['actionsByType'][action] = (stats['actionsByType'][action] as int? ?? 0) + 1;
        }

        // Count by admin
        final adminEmail = data['adminEmail'] as String?;
        if (adminEmail != null) {
          stats['actionsByAdmin'][adminEmail] = (stats['actionsByAdmin'][adminEmail] as int? ?? 0) + 1;
        }

        // Count by target type
        final targetType = data['targetType'] as String?;
        if (targetType != null) {
          stats['actionsByTarget'][targetType] = (stats['actionsByTarget'][targetType] as int? ?? 0) + 1;
        }
      }

      return stats;
    } catch (e) {
      debugPrint('Error getting audit statistics: $e');
      throw e;
    }
  }
}