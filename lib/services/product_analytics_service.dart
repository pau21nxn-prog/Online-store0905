import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import '../models/product.dart';

enum AnalyticsTimeRange { today, week, month, quarter, year, custom }
enum MetricType { views, sales, revenue, conversion, inventory, ratings }

class ProductMetrics {
  final String productId;
  final DateTime date;
  final int views;
  final int uniqueViews;
  final int addToCarts;
  final int purchases;
  final double revenue;
  final int returns;
  final double averageRating;
  final int reviewCount;
  final int stockLevel;
  final Map<String, dynamic> customMetrics;

  ProductMetrics({
    required this.productId,
    required this.date,
    this.views = 0,
    this.uniqueViews = 0,
    this.addToCarts = 0,
    this.purchases = 0,
    this.revenue = 0.0,
    this.returns = 0,
    this.averageRating = 0.0,
    this.reviewCount = 0,
    this.stockLevel = 0,
    this.customMetrics = const {},
  });

  factory ProductMetrics.fromFirestore(String id, Map<String, dynamic> data) {
    return ProductMetrics(
      productId: data['productId'] ?? '',
      date: data['date']?.toDate() ?? DateTime.now(),
      views: data['views'] ?? 0,
      uniqueViews: data['uniqueViews'] ?? 0,
      addToCarts: data['addToCarts'] ?? 0,
      purchases: data['purchases'] ?? 0,
      revenue: (data['revenue'] ?? 0).toDouble(),
      returns: data['returns'] ?? 0,
      averageRating: (data['averageRating'] ?? 0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      stockLevel: data['stockLevel'] ?? 0,
      customMetrics: Map<String, dynamic>.from(data['customMetrics'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'date': Timestamp.fromDate(date),
      'views': views,
      'uniqueViews': uniqueViews,
      'addToCarts': addToCarts,
      'purchases': purchases,
      'revenue': revenue,
      'returns': returns,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
      'stockLevel': stockLevel,
      'customMetrics': customMetrics,
    };
  }

  double get conversionRate => views > 0 ? (purchases / views) * 100 : 0;
  double get cartConversionRate => addToCarts > 0 ? (purchases / addToCarts) * 100 : 0;
  double get addToCartRate => views > 0 ? (addToCarts / views) * 100 : 0;
  double get returnRate => purchases > 0 ? (returns / purchases) * 100 : 0;
  double get averageOrderValue => purchases > 0 ? revenue / purchases : 0;
}

class AnalyticsInsight {
  final String title;
  final String description;
  final String category; // performance, opportunity, issue, trend
  final double impact; // 0-1 scale
  final Map<String, dynamic> data;
  final List<String> recommendations;

  AnalyticsInsight({
    required this.title,
    required this.description,
    required this.category,
    required this.impact,
    this.data = const {},
    this.recommendations = const [],
  });
}

class ProductPerformanceReport {
  final String productId;
  final AnalyticsTimeRange timeRange;
  final DateTime startDate;
  final DateTime endDate;
  final ProductMetrics totalMetrics;
  final List<ProductMetrics> dailyMetrics;
  final List<AnalyticsInsight> insights;
  final Map<String, dynamic> comparisons;

  ProductPerformanceReport({
    required this.productId,
    required this.timeRange,
    required this.startDate,
    required this.endDate,
    required this.totalMetrics,
    required this.dailyMetrics,
    this.insights = const [],
    this.comparisons = const {},
  });
}

class CategoryAnalytics {
  final String categoryId;
  final String categoryName;
  final int totalProducts;
  final double totalRevenue;
  final int totalViews;
  final int totalSales;
  final double averageConversionRate;
  final double marketShare;

  CategoryAnalytics({
    required this.categoryId,
    required this.categoryName,
    required this.totalProducts,
    required this.totalRevenue,
    required this.totalViews,
    required this.totalSales,
    required this.averageConversionRate,
    required this.marketShare,
  });
}

class TrendAnalysis {
  final MetricType metric;
  final List<double> values;
  final List<DateTime> dates;
  final String trend; // increasing, decreasing, stable, volatile
  final double growthRate;
  final double volatility;

  TrendAnalysis({
    required this.metric,
    required this.values,
    required this.dates,
    required this.trend,
    required this.growthRate,
    required this.volatility,
  });
}

class ProductAnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Track product view
  static Future<void> trackProductView(String productId, {
    String? userId,
    String? sessionId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final viewData = {
        'productId': productId,
        'userId': userId ?? _auth.currentUser?.uid,
        'sessionId': sessionId ?? _generateSessionId(),
        'timestamp': Timestamp.now(),
        'metadata': metadata ?? {},
      };

      await _firestore.collection('productViews').add(viewData);
      await _updateDailyMetrics(productId, 'views', 1);
    } catch (e) {
      debugPrint('Error tracking product view: $e');
    }
  }

  // Track add to cart
  static Future<void> trackAddToCart(String productId, {
    String? variantId,
    int quantity = 1,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final cartData = {
        'productId': productId,
        'variantId': variantId,
        'quantity': quantity,
        'userId': userId ?? _auth.currentUser?.uid,
        'timestamp': Timestamp.now(),
        'metadata': metadata ?? {},
      };

      await _firestore.collection('cartEvents').add(cartData);
      await _updateDailyMetrics(productId, 'addToCarts', 1);
    } catch (e) {
      debugPrint('Error tracking add to cart: $e');
    }
  }

  // Track purchase
  static Future<void> trackPurchase(String productId, {
    String? variantId,
    required int quantity,
    required double revenue,
    String? orderId,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final purchaseData = {
        'productId': productId,
        'variantId': variantId,
        'quantity': quantity,
        'revenue': revenue,
        'orderId': orderId,
        'userId': userId ?? _auth.currentUser?.uid,
        'timestamp': Timestamp.now(),
        'metadata': metadata ?? {},
      };

      await _firestore.collection('purchaseEvents').add(purchaseData);
      await _updateDailyMetrics(productId, 'purchases', quantity);
      await _updateDailyMetrics(productId, 'revenue', revenue);
    } catch (e) {
      debugPrint('Error tracking purchase: $e');
    }
  }

  // Update daily metrics
  static Future<void> _updateDailyMetrics(String productId, String metric, dynamic value) async {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    final docRef = _firestore
        .collection('productMetrics')
        .doc('${productId}_$dateKey');

    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      
      if (doc.exists) {
        final currentValue = doc.data()?[metric] ?? 0;
        final newValue = currentValue + value;
        transaction.update(docRef, {metric: newValue});
      } else {
        final initialData = {
          'productId': productId,
          'date': Timestamp.fromDate(DateTime(today.year, today.month, today.day)),
          metric: value,
        };
        transaction.set(docRef, initialData);
      }
    });
  }

  // Get product performance report
  static Future<ProductPerformanceReport> getProductPerformanceReport(
    String productId,
    AnalyticsTimeRange timeRange, {
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) async {
    final dateRange = _getDateRange(timeRange, customStartDate, customEndDate);
    final startDate = dateRange['start']!;
    final endDate = dateRange['end']!;

    // Get daily metrics
    final dailyMetrics = await _getDailyMetrics(productId, startDate, endDate);
    
    // Calculate total metrics
    final totalMetrics = _aggregateMetrics(dailyMetrics);
    
    // Generate insights
    final insights = await _generateInsights(productId, dailyMetrics, totalMetrics);
    
    // Get comparisons (previous period)
    final comparisons = await _getComparisons(productId, startDate, endDate);

    return ProductPerformanceReport(
      productId: productId,
      timeRange: timeRange,
      startDate: startDate,
      endDate: endDate,
      totalMetrics: totalMetrics,
      dailyMetrics: dailyMetrics,
      insights: insights,
      comparisons: comparisons,
    );
  }

  // Get daily metrics for date range
  static Future<List<ProductMetrics>> _getDailyMetrics(
    String productId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final metrics = <ProductMetrics>[];
    
    try {
      final query = _firestore
          .collection('productMetrics')
          .where('productId', isEqualTo: productId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date');

      final snapshot = await query.get();
      
      for (final doc in snapshot.docs) {
        metrics.add(ProductMetrics.fromFirestore(doc.id, doc.data()));
      }
    } catch (e) {
      debugPrint('Error getting daily metrics: $e');
    }
    
    return metrics;
  }

  // Aggregate metrics from daily data
  static ProductMetrics _aggregateMetrics(List<ProductMetrics> dailyMetrics) {
    if (dailyMetrics.isEmpty) {
      return ProductMetrics(
        productId: '',
        date: DateTime.now(),
      );
    }

    int totalViews = 0;
    int totalUniqueViews = 0;
    int totalAddToCarts = 0;
    int totalPurchases = 0;
    double totalRevenue = 0;
    int totalReturns = 0;
    double totalRating = 0;
    int totalReviews = 0;

    for (final metric in dailyMetrics) {
      totalViews += metric.views;
      totalUniqueViews += metric.uniqueViews;
      totalAddToCarts += metric.addToCarts;
      totalPurchases += metric.purchases;
      totalRevenue += metric.revenue;
      totalReturns += metric.returns;
      totalRating += metric.averageRating * metric.reviewCount;
      totalReviews += metric.reviewCount;
    }

    return ProductMetrics(
      productId: dailyMetrics.first.productId,
      date: dailyMetrics.last.date,
      views: totalViews,
      uniqueViews: totalUniqueViews,
      addToCarts: totalAddToCarts,
      purchases: totalPurchases,
      revenue: totalRevenue,
      returns: totalReturns,
      averageRating: totalReviews > 0 ? totalRating / totalReviews : 0,
      reviewCount: totalReviews,
    );
  }

  // Generate analytics insights
  static Future<List<AnalyticsInsight>> _generateInsights(
    String productId,
    List<ProductMetrics> dailyMetrics,
    ProductMetrics totalMetrics,
  ) async {
    final insights = <AnalyticsInsight>[];

    // Conversion rate analysis
    if (totalMetrics.conversionRate < 1.0 && totalMetrics.views > 100) {
      insights.add(AnalyticsInsight(
        title: 'Low Conversion Rate',
        description: 'This product has a conversion rate of ${totalMetrics.conversionRate.toStringAsFixed(2)}%, which is below average.',
        category: 'issue',
        impact: 0.8,
        recommendations: [
          'Optimize product images and descriptions',
          'Review pricing strategy',
          'Add customer reviews',
          'Improve product positioning',
        ],
      ));
    }

    // High performance detection
    if (totalMetrics.conversionRate > 5.0) {
      insights.add(AnalyticsInsight(
        title: 'High Performing Product',
        description: 'This product has an excellent conversion rate of ${totalMetrics.conversionRate.toStringAsFixed(2)}%.',
        category: 'performance',
        impact: 0.9,
        recommendations: [
          'Consider increasing marketing budget',
          'Cross-sell with related products',
          'Use as a template for other products',
        ],
      ));
    }

    // Inventory insights
    final currentStock = await _getCurrentStock(productId);
    if (currentStock < totalMetrics.purchases * 0.1) {
      insights.add(AnalyticsInsight(
        title: 'Low Inventory Risk',
        description: 'Current stock level is low relative to recent sales velocity.',
        category: 'issue',
        impact: 0.7,
        recommendations: [
          'Restock immediately',
          'Set up low-stock alerts',
          'Review safety stock levels',
        ],
      ));
    }

    // Trend analysis
    if (dailyMetrics.length >= 7) {
      final trendAnalysis = _analyzeTrend(dailyMetrics.map((m) => m.revenue).toList());
      if (trendAnalysis.trend == 'decreasing' && trendAnalysis.growthRate < -10) {
        insights.add(AnalyticsInsight(
          title: 'Declining Revenue Trend',
          description: 'Revenue has been declining over the past period.',
          category: 'trend',
          impact: 0.6,
          recommendations: [
            'Investigate market changes',
            'Review competitor pricing',
            'Consider promotional campaigns',
          ],
        ));
      }
    }

    return insights;
  }

  // Get comparison data (previous period)
  static Future<Map<String, dynamic>> _getComparisons(
    String productId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final duration = endDate.difference(startDate);
    final previousStart = startDate.subtract(duration);
    final previousEnd = startDate;

    final previousMetrics = await _getDailyMetrics(productId, previousStart, previousEnd);
    final previousTotal = _aggregateMetrics(previousMetrics);

    return {
      'previousPeriod': previousTotal,
      'viewsChange': _calculatePercentageChange(previousTotal.views, previousTotal.views),
      'revenueChange': _calculatePercentageChange(previousTotal.revenue, previousTotal.revenue),
      'conversionChange': _calculatePercentageChange(previousTotal.conversionRate, previousTotal.conversionRate),
    };
  }

  // Analyze trend in data
  static TrendAnalysis _analyzeTrend(List<double> values) {
    if (values.length < 2) {
      return TrendAnalysis(
        metric: MetricType.revenue,
        values: values,
        dates: [],
        trend: 'stable',
        growthRate: 0,
        volatility: 0,
      );
    }

    // Simple linear regression for trend
    final n = values.length;
    final x = List.generate(n, (i) => i.toDouble());
    final xSum = x.reduce((a, b) => a + b);
    final ySum = values.reduce((a, b) => a + b);
    final xySum = List.generate(n, (i) => x[i] * values[i]).reduce((a, b) => a + b);
    final x2Sum = x.map((xi) => xi * xi).reduce((a, b) => a + b);

    final slope = (n * xySum - xSum * ySum) / (n * x2Sum - xSum * xSum);
    final growthRate = (slope / (ySum / n)) * 100;

    // Calculate volatility (standard deviation)
    final mean = ySum / n;
    final variance = values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / n;
    final volatility = math.sqrt(variance);

    String trend;
    if (growthRate > 5) {
      trend = 'increasing';
    } else if (growthRate < -5) {
      trend = 'decreasing';
    } else if (volatility > mean * 0.3) {
      trend = 'volatile';
    } else {
      trend = 'stable';
    }

    return TrendAnalysis(
      metric: MetricType.revenue,
      values: values,
      dates: [],
      trend: trend,
      growthRate: growthRate,
      volatility: volatility,
    );
  }

  // Get category analytics
  static Future<List<CategoryAnalytics>> getCategoryAnalytics(AnalyticsTimeRange timeRange) async {
    // This would aggregate data across all products in each category
    // For now, return mock data
    return [
      CategoryAnalytics(
        categoryId: 'electronics',
        categoryName: 'Electronics',
        totalProducts: 150,
        totalRevenue: 45000,
        totalViews: 12000,
        totalSales: 450,
        averageConversionRate: 3.75,
        marketShare: 35.5,
      ),
      CategoryAnalytics(
        categoryId: 'fashion',
        categoryName: 'Fashion',
        totalProducts: 200,
        totalRevenue: 32000,
        totalViews: 18000,
        totalSales: 640,
        averageConversionRate: 3.56,
        marketShare: 25.3,
      ),
    ];
  }

  // Get top performing products
  static Future<List<Map<String, dynamic>>> getTopPerformingProducts(
    MetricType metric,
    AnalyticsTimeRange timeRange, {
    int limit = 10,
  }) async {
    final dateRange = _getDateRange(timeRange);
    
    // This would query and aggregate product performance data
    // For now, return mock data
    return List.generate(limit, (index) => {
      'productId': 'product_$index',
      'productName': 'Product ${index + 1}',
      'value': (1000 - index * 50).toDouble(),
      'change': (math.Random().nextDouble() - 0.5) * 20,
    });
  }

  // Real-time analytics for dashboard
  static Stream<Map<String, dynamic>> getRealTimeAnalytics() {
    return Stream.periodic(const Duration(seconds: 30), (_) {
      return {
        'activeUsers': math.Random().nextInt(100) + 50,
        'todayViews': math.Random().nextInt(1000) + 500,
        'todaySales': math.Random().nextInt(50) + 10,
        'conversionRate': (math.Random().nextDouble() * 5 + 1),
        'timestamp': DateTime.now(),
      };
    });
  }

  // Utility methods
  static Map<String, DateTime> _getDateRange(
    AnalyticsTimeRange timeRange, [
    DateTime? customStart,
    DateTime? customEnd,
  ]) {
    final now = DateTime.now();
    DateTime start, end;

    switch (timeRange) {
      case AnalyticsTimeRange.today:
        start = DateTime(now.year, now.month, now.day);
        end = now;
        break;
      case AnalyticsTimeRange.week:
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        end = now;
        break;
      case AnalyticsTimeRange.month:
        start = DateTime(now.year, now.month, 1);
        end = now;
        break;
      case AnalyticsTimeRange.quarter:
        final quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        start = DateTime(now.year, quarterMonth, 1);
        end = now;
        break;
      case AnalyticsTimeRange.year:
        start = DateTime(now.year, 1, 1);
        end = now;
        break;
      case AnalyticsTimeRange.custom:
        start = customStart ?? now.subtract(const Duration(days: 30));
        end = customEnd ?? now;
        break;
    }

    return {'start': start, 'end': end};
  }

  static double _calculatePercentageChange(double oldValue, double newValue) {
    if (oldValue == 0) return newValue > 0 ? 100 : 0;
    return ((newValue - oldValue) / oldValue) * 100;
  }

  static Future<int> _getCurrentStock(String productId) async {
    try {
      final productDoc = await _firestore.collection('products').doc(productId).get();
      if (productDoc.exists) {
        final product = Product.fromFirestore(productDoc.id, productDoc.data()!);
        return product.totalStock;
      }
    } catch (e) {
      debugPrint('Error getting current stock: $e');
    }
    return 0;
  }

  static String _generateSessionId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  static void debugPrint(String message) {
    print('[ProductAnalyticsService] $message');
  }
}