import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/product_lock.dart';

class ProductLockService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const Duration lockTimeout = Duration(minutes: 15);
  static const Duration lockExtensionThreshold = Duration(minutes: 10);
  static const Duration lockWarningThreshold = Duration(minutes: 2);
  
  // Stream controllers for real-time updates
  static final Map<String, StreamController<ProductLock?>> _lockControllers = {};
  static final StreamController<List<ProductLock>> _allLocksController = 
      StreamController<List<ProductLock>>.broadcast();

  // Initialize the service
  static void initialize() {
    // Listen to all lock changes
    _firestore.collection('productLocks').snapshots().listen((snapshot) {
      final locks = snapshot.docs
          .map((doc) => ProductLock.fromFirestore(doc))
          .where((lock) => !lock.isExpired)
          .toList();
      
      _allLocksController.add(locks);
      
      // Update individual lock streams
      for (final lock in locks) {
        _lockControllers[lock.productId]?.add(lock);
      }
      
      // Handle removed locks
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.removed) {
          final productId = change.doc.id;
          _lockControllers[productId]?.add(null);
        }
      }
    });

    // Clean up expired locks periodically
    Timer.periodic(const Duration(minutes: 1), (_) {
      _cleanupExpiredLocks();
    });
  }

  // Acquire a lock for a product
  static Future<ProductLock?> acquireLock(String productId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final userName = userData['displayName'] ?? userData['name'] ?? 'Unknown User';
    final userEmail = user.email ?? 'unknown@email.com';

    try {
      ProductLock? acquiredLock;
      
      await _firestore.runTransaction((transaction) async {
        final lockRef = _firestore.collection('productLocks').doc(productId);
        final lockDoc = await transaction.get(lockRef);
        
        if (lockDoc.exists) {
          final existingLock = ProductLock.fromFirestore(lockDoc);
          
          if (existingLock.isExpired) {
            // Lock expired, acquire it
            acquiredLock = ProductLock(
              productId: productId,
              userId: user.uid,
              userName: userName,
              userEmail: userEmail,
              acquiredAt: DateTime.now(),
              expiresAt: DateTime.now().add(lockTimeout),
              sessionId: _generateSessionId(),
            );
            transaction.set(lockRef, acquiredLock!.toMap());
            
            _logLockAudit(productId, user.uid, LockOperation.acquire);
          } else if (existingLock.userId == user.uid) {
            // User already has the lock, extend it
            acquiredLock = existingLock.extend(lockTimeout);
            transaction.update(lockRef, acquiredLock!.toMap());
            
            _logLockAudit(productId, user.uid, LockOperation.extend);
          } else {
            // Lock is held by another user
            throw LockConflictException(existingLock.userName, existingLock.expiresAt);
          }
        } else {
          // No existing lock, create new one
          acquiredLock = ProductLock(
            productId: productId,
            userId: user.uid,
            userName: userName,
            userEmail: userEmail,
            acquiredAt: DateTime.now(),
            expiresAt: DateTime.now().add(lockTimeout),
            sessionId: _generateSessionId(),
          );
          transaction.set(lockRef, acquiredLock!.toMap());
          
          _logLockAudit(productId, user.uid, LockOperation.acquire);
        }
      });
      
      return acquiredLock;
    } catch (e) {
      if (e is LockConflictException) {
        rethrow;
      }
      throw Exception('Failed to acquire lock: $e');
    }
  }

  // Try to acquire lock, return null if conflict
  static Future<ProductLock?> tryAcquireLock(String productId) async {
    try {
      return await acquireLock(productId);
    } on LockConflictException {
      return null;
    }
  }

  // Extend an existing lock
  static Future<ProductLock?> extendLock(String productId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      ProductLock? extendedLock;
      
      await _firestore.runTransaction((transaction) async {
        final lockRef = _firestore.collection('productLocks').doc(productId);
        final lockDoc = await transaction.get(lockRef);
        
        if (lockDoc.exists) {
          final existingLock = ProductLock.fromFirestore(lockDoc);
          
          if (existingLock.userId == user.uid && !existingLock.isExpired) {
            extendedLock = existingLock.extend(lockTimeout);
            transaction.update(lockRef, extendedLock!.toMap());
            
            _logLockAudit(productId, user.uid, LockOperation.extend);
          }
        }
      });
      
      return extendedLock;
    } catch (e) {
      debugPrint('Failed to extend lock: $e');
      return null;
    }
  }

  // Release a lock
  static Future<void> releaseLock(String productId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.runTransaction((transaction) async {
        final lockRef = _firestore.collection('productLocks').doc(productId);
        final lockDoc = await transaction.get(lockRef);
        
        if (lockDoc.exists) {
          final existingLock = ProductLock.fromFirestore(lockDoc);
          
          if (existingLock.userId == user.uid) {
            transaction.delete(lockRef);
            _logLockAudit(productId, user.uid, LockOperation.release);
          }
        }
      });
    } catch (e) {
      debugPrint('Failed to release lock: $e');
    }
  }

  // Force release a lock (admin only)
  static Future<void> forceReleaseLock(String productId, String reason) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.runTransaction((transaction) async {
        final lockRef = _firestore.collection('productLocks').doc(productId);
        transaction.delete(lockRef);
        
        _logLockAudit(productId, user.uid, LockOperation.forceRelease, {
          'reason': reason,
        });
      });
    } catch (e) {
      debugPrint('Failed to force release lock: $e');
    }
  }

  // Get current lock for a product
  static Future<ProductLock?> getLock(String productId) async {
    try {
      final lockDoc = await _firestore
          .collection('productLocks')
          .doc(productId)
          .get();
      
      if (lockDoc.exists) {
        final lock = ProductLock.fromFirestore(lockDoc);
        return lock.isExpired ? null : lock;
      }
      
      return null;
    } catch (e) {
      debugPrint('Failed to get lock: $e');
      return null;
    }
  }

  // Watch lock status for a product
  static Stream<ProductLock?> watchLock(String productId) {
    if (!_lockControllers.containsKey(productId)) {
      _lockControllers[productId] = StreamController<ProductLock?>.broadcast();
    }
    
    return _lockControllers[productId]!.stream;
  }

  // Watch all active locks
  static Stream<List<ProductLock>> watchActiveLocks() {
    return _allLocksController.stream;
  }

  // Get locks by user
  static Future<List<ProductLock>> getLocksByUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('productLocks')
          .where('userId', isEqualTo: userId)
          .get();
      
      return snapshot.docs
          .map((doc) => ProductLock.fromFirestore(doc))
          .where((lock) => !lock.isExpired)
          .toList();
    } catch (e) {
      debugPrint('Failed to get user locks: $e');
      return [];
    }
  }

  // Bulk acquire locks
  static Future<BulkLockResult> acquireMultipleLocks(
    List<String> productIds,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final userName = userData['displayName'] ?? userData['name'] ?? 'Unknown User';
    final userEmail = user.email ?? 'unknown@email.com';

    final acquired = <ProductLock>[];
    final conflicts = <LockConflict>[];

    for (final productId in productIds) {
      try {
        final lock = await acquireLock(productId);
        if (lock != null) {
          acquired.add(lock);
        }
      } on LockConflictException catch (e) {
        // Get the existing lock for conflict info
        final existingLock = await getLock(productId);
        if (existingLock != null) {
          conflicts.add(LockConflict(
            productId: productId,
            existingLock: existingLock,
          ));
        }
      }
    }

    return BulkLockResult(acquired: acquired, conflicts: conflicts);
  }

  // Maintain lock with auto-extension
  static Stream<ProductLock?> maintainLock(String productId) async* {
    final lock = await acquireLock(productId);
    if (lock == null) return;

    yield lock;

    while (true) {
      await Future.delayed(const Duration(minutes: 5));
      
      final currentLock = await getLock(productId);
      if (currentLock == null || currentLock.userId != _auth.currentUser?.uid) {
        break; // Lock lost or taken by someone else
      }

      if (currentLock.canExtend(_auth.currentUser!.uid)) {
        final extendedLock = await extendLock(productId);
        yield extendedLock;
      } else {
        break; // Cannot extend
      }
    }
  }

  // Cleanup expired locks
  static Future<void> _cleanupExpiredLocks() async {
    try {
      final snapshot = await _firestore.collection('productLocks').get();
      final batch = _firestore.batch();
      
      int deletedCount = 0;
      for (final doc in snapshot.docs) {
        final lock = ProductLock.fromFirestore(doc);
        if (lock.isExpired) {
          batch.delete(doc.reference);
          deletedCount++;
        }
      }
      
      if (deletedCount > 0) {
        await batch.commit();
        debugPrint('Cleaned up $deletedCount expired locks');
      }
    } catch (e) {
      debugPrint('Failed to cleanup expired locks: $e');
    }
  }

  // Log lock audit events
  static Future<void> _logLockAudit(
    String productId,
    String userId,
    LockOperation operation, [
    Map<String, dynamic> metadata = const {},
  ]) async {
    try {
      final auditEntry = LockAuditEntry(
        productId: productId,
        userId: userId,
        operation: operation,
        timestamp: DateTime.now(),
        metadata: metadata,
      );
      
      await _firestore
          .collection('lockAudits')
          .add(auditEntry.toMap());
    } catch (e) {
      debugPrint('Failed to log lock audit: $e');
    }
  }

  // Generate unique session ID
  static String _generateSessionId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Check if user can edit product
  static Future<bool> canEditProduct(String productId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final lock = await getLock(productId);
    return lock == null || lock.canEdit(user.uid);
  }

  // Get lock status summary
  static Future<Map<String, dynamic>> getLockStatusSummary() async {
    try {
      final snapshot = await _firestore.collection('productLocks').get();
      final activeLocks = snapshot.docs
          .map((doc) => ProductLock.fromFirestore(doc))
          .where((lock) => !lock.isExpired)
          .toList();

      final userLockCounts = <String, int>{};
      for (final lock in activeLocks) {
        userLockCounts[lock.userName] = (userLockCounts[lock.userName] ?? 0) + 1;
      }

      return {
        'totalActiveLocks': activeLocks.length,
        'userLockCounts': userLockCounts,
        'oldestLock': activeLocks.isEmpty 
            ? null 
            : activeLocks.reduce((a, b) => a.acquiredAt.isBefore(b.acquiredAt) ? a : b),
      };
    } catch (e) {
      debugPrint('Failed to get lock status summary: $e');
      return {};
    }
  }

  // Dispose resources
  static void dispose() {
    for (final controller in _lockControllers.values) {
      controller.close();
    }
    _lockControllers.clear();
    _allLocksController.close();
  }

  // For debugging
  static void debugPrint(String message) {
    debugPrint('[ProductLockService] $message');
  }
}