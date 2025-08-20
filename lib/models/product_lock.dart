import 'package:cloud_firestore/cloud_firestore.dart';

class ProductLock {
  final String productId;
  final String userId;
  final String userName;
  final String userEmail;
  final DateTime acquiredAt;
  final DateTime expiresAt;
  final String? sessionId;

  ProductLock({
    required this.productId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.acquiredAt,
    required this.expiresAt,
    this.sessionId,
  });

  factory ProductLock.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductLock(
      productId: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      acquiredAt: data['acquiredAt']?.toDate() ?? DateTime.now(),
      expiresAt: data['expiresAt']?.toDate() ?? DateTime.now(),
      sessionId: data['sessionId'],
    );
  }

  factory ProductLock.fromMap(String productId, Map<String, dynamic> data) {
    return ProductLock(
      productId: productId,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      acquiredAt: data['acquiredAt']?.toDate() ?? DateTime.now(),
      expiresAt: data['expiresAt']?.toDate() ?? DateTime.now(),
      sessionId: data['sessionId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'acquiredAt': Timestamp.fromDate(acquiredAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'sessionId': sessionId,
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  bool get isAboutToExpire {
    final now = DateTime.now();
    final warningTime = expiresAt.subtract(const Duration(minutes: 2));
    return now.isAfter(warningTime) && now.isBefore(expiresAt);
  }

  Duration get timeRemaining {
    final now = DateTime.now();
    if (isExpired) return Duration.zero;
    return expiresAt.difference(now);
  }

  String get formattedTimeRemaining {
    final remaining = timeRemaining;
    if (remaining == Duration.zero) return 'Expired';
    
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  bool canEdit(String currentUserId) {
    return !isExpired && userId == currentUserId;
  }

  bool canExtend(String currentUserId) {
    return userId == currentUserId && timeRemaining.inMinutes < 10;
  }

  ProductLock extend(Duration extension) {
    return ProductLock(
      productId: productId,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      acquiredAt: acquiredAt,
      expiresAt: expiresAt.add(extension),
      sessionId: sessionId,
    );
  }
}

class LockConflictException implements Exception {
  final String lockedByUser;
  final DateTime expiresAt;

  LockConflictException(this.lockedByUser, this.expiresAt);

  @override
  String toString() {
    return 'Product is currently being edited by $lockedByUser. '
           'Lock expires at ${expiresAt.toLocal().toString().substring(11, 16)}.';
  }
}

class BulkLockRequest {
  final List<String> productIds;
  final String userId;
  final String userName;
  final String userEmail;
  final Duration lockDuration;

  BulkLockRequest({
    required this.productIds,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.lockDuration = const Duration(minutes: 15),
  });
}

class BulkLockResult {
  final List<ProductLock> acquired;
  final List<LockConflict> conflicts;

  BulkLockResult({
    required this.acquired,
    required this.conflicts,
  });

  bool get hasConflicts => conflicts.isNotEmpty;
  bool get allAcquired => conflicts.isEmpty;
  int get acquiredCount => acquired.length;
  int get conflictCount => conflicts.length;
}

class LockConflict {
  final String productId;
  final ProductLock existingLock;

  LockConflict({
    required this.productId,
    required this.existingLock,
  });
}

enum LockOperation { acquire, extend, release, forceRelease }

class LockAuditEntry {
  final String productId;
  final String userId;
  final LockOperation operation;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  LockAuditEntry({
    required this.productId,
    required this.userId,
    required this.operation,
    required this.timestamp,
    this.metadata = const {},
  });

  factory LockAuditEntry.fromMap(Map<String, dynamic> data) {
    return LockAuditEntry(
      productId: data['productId'] ?? '',
      userId: data['userId'] ?? '',
      operation: LockOperation.values.firstWhere(
        (op) => op.name == data['operation'],
        orElse: () => LockOperation.acquire,
      ),
      timestamp: data['timestamp']?.toDate() ?? DateTime.now(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'userId': userId,
      'operation': operation.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }
}