import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:io';

enum PerformanceMetricType {
  pageLoad,
  searchQuery,
  databaseQuery,
  imageLoad,
  networkRequest,
  userInteraction,
  memoryUsage,
  frameRate,
  batteryUsage,
}

class PerformanceMetric {
  final String id;
  final PerformanceMetricType type;
  final String name;
  final double value;
  final String unit;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final String? userId;
  final String? sessionId;

  PerformanceMetric({
    required this.id,
    required this.type,
    required this.name,
    required this.value,
    required this.unit,
    required this.timestamp,
    this.metadata = const {},
    this.userId,
    this.sessionId,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'name': name,
      'value': value,
      'unit': unit,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
      'userId': userId,
      'sessionId': sessionId,
      'platform': Platform.operatingSystem,
      'isDebug': kDebugMode,
    };
  }
}

class PerformanceAlert {
  final String id;
  final PerformanceMetricType type;
  final String message;
  final double threshold;
  final double currentValue;
  final String severity;
  final DateTime timestamp;
  final Map<String, dynamic> context;

  PerformanceAlert({
    required this.id,
    required this.type,
    required this.message,
    required this.threshold,
    required this.currentValue,
    required this.severity,
    required this.timestamp,
    this.context = const {},
  });

  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'message': message,
      'threshold': threshold,
      'currentValue': currentValue,
      'severity': severity,
      'timestamp': Timestamp.fromDate(timestamp),
      'context': context,
    };
  }
}

class PerformanceThreshold {
  final PerformanceMetricType type;
  final double warningThreshold;
  final double criticalThreshold;
  final String unit;

  const PerformanceThreshold({
    required this.type,
    required this.warningThreshold,
    required this.criticalThreshold,
    required this.unit,
  });
}

class PerformanceSession {
  final String sessionId;
  final DateTime startTime;
  DateTime? endTime;
  final Map<String, dynamic> deviceInfo;
  final List<PerformanceMetric> metrics;

  PerformanceSession({
    required this.sessionId,
    required this.startTime,
    this.endTime,
    required this.deviceInfo,
    this.metrics = const [],
  });

  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);
}

class PerformanceMonitoringService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Map<String, Stopwatch> _activeTimers = {};
  static final List<PerformanceMetric> _pendingMetrics = [];
  static String? _currentSessionId;
  static PerformanceSession? _currentSession;
  static Timer? _batchUploadTimer;
  static Timer? _memoryMonitorTimer;
  static Timer? _frameRateTimer;

  // Performance thresholds
  static const Map<PerformanceMetricType, PerformanceThreshold> _thresholds = {
    PerformanceMetricType.pageLoad: PerformanceThreshold(
      type: PerformanceMetricType.pageLoad,
      warningThreshold: 3000, // 3 seconds
      criticalThreshold: 5000, // 5 seconds
      unit: 'ms',
    ),
    PerformanceMetricType.searchQuery: PerformanceThreshold(
      type: PerformanceMetricType.searchQuery,
      warningThreshold: 1000, // 1 second
      criticalThreshold: 3000, // 3 seconds
      unit: 'ms',
    ),
    PerformanceMetricType.databaseQuery: PerformanceThreshold(
      type: PerformanceMetricType.databaseQuery,
      warningThreshold: 500, // 0.5 seconds
      criticalThreshold: 2000, // 2 seconds
      unit: 'ms',
    ),
    PerformanceMetricType.imageLoad: PerformanceThreshold(
      type: PerformanceMetricType.imageLoad,
      warningThreshold: 2000, // 2 seconds
      criticalThreshold: 5000, // 5 seconds
      unit: 'ms',
    ),
    PerformanceMetricType.networkRequest: PerformanceThreshold(
      type: PerformanceMetricType.networkRequest,
      warningThreshold: 3000, // 3 seconds
      criticalThreshold: 8000, // 8 seconds
      unit: 'ms',
    ),
    PerformanceMetricType.memoryUsage: PerformanceThreshold(
      type: PerformanceMetricType.memoryUsage,
      warningThreshold: 200, // 200 MB
      criticalThreshold: 500, // 500 MB
      unit: 'MB',
    ),
    PerformanceMetricType.frameRate: PerformanceThreshold(
      type: PerformanceMetricType.frameRate,
      warningThreshold: 45, // Below 45 FPS
      criticalThreshold: 30, // Below 30 FPS
      unit: 'fps',
    ),
  };

  // Initialize monitoring service
  static void initialize() {
    _startNewSession();
    _startBatchUpload();
    _startMemoryMonitoring();
    _startFrameRateMonitoring();
    
    debugPrint('[PerformanceMonitoring] Service initialized');
  }

  // Start a new performance session
  static void _startNewSession() {
    _currentSessionId = _generateSessionId();
    _currentSession = PerformanceSession(
      sessionId: _currentSessionId!,
      startTime: DateTime.now(),
      deviceInfo: _getDeviceInfo(),
    );
    
    debugPrint('[PerformanceMonitoring] Started session: $_currentSessionId');
  }

  // Start timing a performance metric
  static void startTimer(String timerId) {
    _activeTimers[timerId] = Stopwatch()..start();
    debugPrint('[PerformanceMonitoring] Started timer: $timerId');
  }

  // Stop timing and record metric
  static void stopTimer(
    String timerId,
    PerformanceMetricType type,
    String name, {
    Map<String, dynamic>? metadata,
  }) {
    final stopwatch = _activeTimers.remove(timerId);
    if (stopwatch == null) {
      debugPrint('[PerformanceMonitoring] Timer not found: $timerId');
      return;
    }

    stopwatch.stop();
    final duration = stopwatch.elapsedMilliseconds.toDouble();
    
    recordMetric(
      type: type,
      name: name,
      value: duration,
      unit: 'ms',
      metadata: metadata,
    );

    debugPrint('[PerformanceMonitoring] Stopped timer: $timerId (${duration}ms)');
  }

  // Record a performance metric
  static void recordMetric({
    required PerformanceMetricType type,
    required String name,
    required double value,
    required String unit,
    Map<String, dynamic>? metadata,
  }) {
    final metric = PerformanceMetric(
      id: _generateMetricId(),
      type: type,
      name: name,
      value: value,
      unit: unit,
      timestamp: DateTime.now(),
      metadata: metadata ?? {},
      sessionId: _currentSessionId,
    );

    _pendingMetrics.add(metric);
    _checkThresholds(metric);

    debugPrint('[PerformanceMonitoring] Recorded metric: $name = $value $unit');
  }

  // Record page load time
  static void recordPageLoad(String pageName, double loadTime) {
    recordMetric(
      type: PerformanceMetricType.pageLoad,
      name: 'page_load_$pageName',
      value: loadTime,
      unit: 'ms',
      metadata: {'pageName': pageName},
    );
  }

  // Record search query performance
  static void recordSearchQuery(String query, double queryTime, int resultCount) {
    recordMetric(
      type: PerformanceMetricType.searchQuery,
      name: 'search_query',
      value: queryTime,
      unit: 'ms',
      metadata: {
        'query': query,
        'resultCount': resultCount,
        'queryLength': query.length,
      },
    );
  }

  // Record database query performance
  static void recordDatabaseQuery(String collection, String operation, double queryTime) {
    recordMetric(
      type: PerformanceMetricType.databaseQuery,
      name: 'db_query_$collection',
      value: queryTime,
      unit: 'ms',
      metadata: {
        'collection': collection,
        'operation': operation,
      },
    );
  }

  // Record image load performance
  static void recordImageLoad(String imageUrl, double loadTime, int imageSizeBytes) {
    recordMetric(
      type: PerformanceMetricType.imageLoad,
      name: 'image_load',
      value: loadTime,
      unit: 'ms',
      metadata: {
        'imageUrl': imageUrl,
        'imageSizeBytes': imageSizeBytes,
        'imageSizeMB': (imageSizeBytes / 1024 / 1024).toStringAsFixed(2),
      },
    );
  }

  // Record network request performance
  static void recordNetworkRequest(String endpoint, String method, double requestTime, int statusCode) {
    recordMetric(
      type: PerformanceMetricType.networkRequest,
      name: 'network_request',
      value: requestTime,
      unit: 'ms',
      metadata: {
        'endpoint': endpoint,
        'method': method,
        'statusCode': statusCode,
        'isSuccess': statusCode >= 200 && statusCode < 300,
      },
    );
  }

  // Record user interaction timing
  static void recordUserInteraction(String action, double responseTime) {
    recordMetric(
      type: PerformanceMetricType.userInteraction,
      name: 'user_interaction_$action',
      value: responseTime,
      unit: 'ms',
      metadata: {'action': action},
    );
  }

  // Start memory monitoring
  static void _startMemoryMonitoring() {
    _memoryMonitorTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _recordMemoryUsage();
    });
  }

  // Record current memory usage
  static void _recordMemoryUsage() {
    // This is a simplified implementation
    // In a real app, you'd use platform-specific APIs to get actual memory usage
    final estimatedMemoryMB = _estimateMemoryUsage();
    
    recordMetric(
      type: PerformanceMetricType.memoryUsage,
      name: 'memory_usage',
      value: estimatedMemoryMB,
      unit: 'MB',
      metadata: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // Start frame rate monitoring
  static void _startFrameRateMonitoring() {
    if (!kDebugMode) return; // Only monitor in debug mode
    
    _frameRateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _recordFrameRate();
    });
  }

  // Record current frame rate
  static void _recordFrameRate() {
    // This is a simplified implementation
    // In a real app, you'd use WidgetsBinding.instance.addTimingsCallback
    final estimatedFPS = _estimateFrameRate();
    
    recordMetric(
      type: PerformanceMetricType.frameRate,
      name: 'frame_rate',
      value: estimatedFPS,
      unit: 'fps',
      metadata: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // Check performance thresholds and create alerts
  static void _checkThresholds(PerformanceMetric metric) {
    final threshold = _thresholds[metric.type];
    if (threshold == null) return;

    String? severity;
    if (metric.value >= threshold.criticalThreshold) {
      severity = 'critical';
    } else if (metric.value >= threshold.warningThreshold) {
      severity = 'warning';
    }

    if (severity != null) {
      _createPerformanceAlert(metric, threshold, severity);
    }
  }

  // Create performance alert
  static void _createPerformanceAlert(
    PerformanceMetric metric,
    PerformanceThreshold threshold,
    String severity,
  ) {
    final alert = PerformanceAlert(
      id: _generateAlertId(),
      type: metric.type,
      message: _generateAlertMessage(metric, threshold, severity),
      threshold: severity == 'critical' ? threshold.criticalThreshold : threshold.warningThreshold,
      currentValue: metric.value,
      severity: severity,
      timestamp: DateTime.now(),
      context: {
        'metricId': metric.id,
        'sessionId': metric.sessionId,
        'metadata': metric.metadata,
      },
    );

    _uploadAlert(alert);
    debugPrint('[PerformanceMonitoring] Performance alert: ${alert.message}');
  }

  // Generate alert message
  static String _generateAlertMessage(
    PerformanceMetric metric,
    PerformanceThreshold threshold,
    String severity,
  ) {
    final thresholdValue = severity == 'critical' 
        ? threshold.criticalThreshold 
        : threshold.warningThreshold;
        
    return '${metric.name} took ${metric.value}${metric.unit} '
           '(threshold: $thresholdValue${threshold.unit})';
  }

  // Start batch upload timer
  static void _startBatchUpload() {
    _batchUploadTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _uploadPendingMetrics();
    });
  }

  // Upload pending metrics in batch
  static Future<void> _uploadPendingMetrics() async {
    if (_pendingMetrics.isEmpty) return;

    try {
      final batch = _firestore.batch();
      final metricsToUpload = List<PerformanceMetric>.from(_pendingMetrics);
      _pendingMetrics.clear();

      for (final metric in metricsToUpload) {
        final docRef = _firestore.collection('performanceMetrics').doc();
        batch.set(docRef, metric.toFirestore());
      }

      await batch.commit();
      debugPrint('[PerformanceMonitoring] Uploaded ${metricsToUpload.length} metrics');
    } catch (e) {
      debugPrint('[PerformanceMonitoring] Upload failed: $e');
      // Re-add metrics to pending list
      _pendingMetrics.addAll(_pendingMetrics);
    }
  }

  // Upload performance alert
  static Future<void> _uploadAlert(PerformanceAlert alert) async {
    try {
      await _firestore.collection('performanceAlerts').add(alert.toFirestore());
    } catch (e) {
      debugPrint('[PerformanceMonitoring] Alert upload failed: $e');
    }
  }

  // Get performance analytics
  static Future<Map<String, dynamic>> getPerformanceAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    startDate ??= DateTime.now().subtract(const Duration(days: 7));
    endDate ??= DateTime.now();

    try {
      final metricsSnapshot = await _firestore
          .collection('performanceMetrics')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final alertsSnapshot = await _firestore
          .collection('performanceAlerts')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      return _processAnalyticsData(metricsSnapshot, alertsSnapshot);
    } catch (e) {
      debugPrint('[PerformanceMonitoring] Analytics fetch failed: $e');
      return {};
    }
  }

  // Process analytics data
  static Map<String, dynamic> _processAnalyticsData(
    QuerySnapshot metricsSnapshot,
    QuerySnapshot alertsSnapshot,
  ) {
    final metricsByType = <String, List<double>>{};
    final alertsByType = <String, int>{};
    
    // Process metrics
    for (final doc in metricsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final type = data['type'] as String;
      final value = (data['value'] as num).toDouble();
      
      metricsByType.putIfAbsent(type, () => []).add(value);
    }

    // Process alerts
    for (final doc in alertsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final type = data['type'] as String;
      
      alertsByType[type] = (alertsByType[type] ?? 0) + 1;
    }

    // Calculate averages and statistics
    final averages = <String, double>{};
    final p95s = <String, double>{};
    final p99s = <String, double>{};
    
    metricsByType.forEach((type, values) {
      if (values.isNotEmpty) {
        values.sort();
        averages[type] = values.reduce((a, b) => a + b) / values.length;
        p95s[type] = values[(values.length * 0.95).floor().clamp(0, values.length - 1)];
        p99s[type] = values[(values.length * 0.99).floor().clamp(0, values.length - 1)];
      }
    });

    return {
      'totalMetrics': metricsSnapshot.docs.length,
      'totalAlerts': alertsSnapshot.docs.length,
      'averages': averages,
      'p95s': p95s,
      'p99s': p99s,
      'alertsByType': alertsByType,
      'metricCounts': metricsByType.map((k, v) => MapEntry(k, v.length)),
    };
  }

  // Get real-time performance status
  static Map<String, dynamic> getCurrentPerformanceStatus() {
    final currentTime = DateTime.now();
    final sessionDuration = _currentSession?.duration ?? Duration.zero;
    
    return {
      'sessionId': _currentSessionId,
      'sessionDuration': sessionDuration.inMinutes,
      'activeTimers': _activeTimers.length,
      'pendingMetrics': _pendingMetrics.length,
      'lastMetricTime': _pendingMetrics.isNotEmpty 
          ? _pendingMetrics.last.timestamp.toIso8601String()
          : null,
      'estimatedMemoryMB': _estimateMemoryUsage(),
      'estimatedFPS': _estimateFrameRate(),
    };
  }

  // Utility methods
  static String _generateSessionId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
  }

  static String _generateMetricId() {
    return 'metric_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
  }

  static String _generateAlertId() {
    return 'alert_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
  }

  static String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (index) => chars[DateTime.now().millisecondsSinceEpoch % chars.length]).join();
  }

  static Map<String, dynamic> _getDeviceInfo() {
    return {
      'platform': Platform.operatingSystem,
      'isDebugMode': kDebugMode,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  static double _estimateMemoryUsage() {
    // Simplified memory estimation
    // In a real app, you'd use platform-specific APIs
    return 50.0 + (DateTime.now().millisecondsSinceEpoch % 100);
  }

  static double _estimateFrameRate() {
    // Simplified frame rate estimation
    // In a real app, you'd use WidgetsBinding.instance.addTimingsCallback
    return 55.0 + (DateTime.now().millisecondsSinceEpoch % 10);
  }

  // End current session
  static void endSession() {
    if (_currentSession != null) {
      _currentSession!.endTime = DateTime.now();
      _uploadSession(_currentSession!);
    }
    
    _uploadPendingMetrics();
    debugPrint('[PerformanceMonitoring] Session ended: $_currentSessionId');
  }

  // Upload session data
  static Future<void> _uploadSession(PerformanceSession session) async {
    try {
      await _firestore.collection('performanceSessions').add({
        'sessionId': session.sessionId,
        'startTime': Timestamp.fromDate(session.startTime),
        'endTime': session.endTime != null ? Timestamp.fromDate(session.endTime!) : null,
        'duration': session.duration.inMilliseconds,
        'deviceInfo': session.deviceInfo,
        'metricCount': session.metrics.length,
      });
    } catch (e) {
      debugPrint('[PerformanceMonitoring] Session upload failed: $e');
    }
  }

  // Dispose resources
  static void dispose() {
    endSession();
    _batchUploadTimer?.cancel();
    _memoryMonitorTimer?.cancel();
    _frameRateTimer?.cancel();
    _activeTimers.clear();
    _pendingMetrics.clear();
    debugPrint('[PerformanceMonitoring] Service disposed');
  }
}