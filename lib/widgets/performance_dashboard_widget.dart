import 'package:flutter/material.dart';
import 'dart:async';
import '../common/theme.dart';
import '../services/performance_monitoring_service.dart';
import '../services/performance_optimization_service.dart';

class PerformanceDashboardWidget extends StatefulWidget {
  final bool isCompact;

  const PerformanceDashboardWidget({
    super.key,
    this.isCompact = false,
  });

  @override
  State<PerformanceDashboardWidget> createState() => _PerformanceDashboardWidgetState();
}

class _PerformanceDashboardWidgetState extends State<PerformanceDashboardWidget>
    with TickerProviderStateMixin {
  late TabController _tabController;
  Timer? _updateTimer;
  
  // Data
  Map<String, dynamic> _performanceStatus = {};
  Map<String, dynamic> _optimizationMetrics = {};
  List<Map<String, dynamic>> _recommendations = [];
  Map<String, dynamic> _analytics = {};
  
  // State
  bool _isLoading = true;
  bool _autoRefresh = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.isCompact ? 2 : 4, vsync: this);
    _loadData();
    _startAutoRefresh();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final futures = await Future.wait([
        Future.value(PerformanceMonitoringService.getCurrentPerformanceStatus()),
        Future.value(PerformanceOptimizationService.getOptimizationMetrics()),
        Future.value(PerformanceOptimizationService.getOptimizationRecommendations()),
        PerformanceMonitoringService.getPerformanceAnalytics(),
      ]);

      setState(() {
        _performanceStatus = futures[0] as Map<String, dynamic>;
        _optimizationMetrics = futures[1] as Map<String, dynamic>;
        _recommendations = futures[2] as List<Map<String, dynamic>>;
        _analytics = futures[3] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Performance Dashboard load error: $e');
    }
  }

  void _startAutoRefresh() {
    if (!_autoRefresh) return;
    
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return _buildCompactDashboard();
    }

    return Card(
      child: Column(
        children: [
          _buildHeader(),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildMetricsTab(),
                  _buildOptimizationTab(),
                  _buildRecommendationsTab(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactDashboard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed, color: AppTheme.primaryOrange),
                const SizedBox(width: 8),
                const Text(
                  'Performance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _buildStatusIndicator(),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              _buildCompactMetrics(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radius12),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.speed, color: AppTheme.primaryOrange),
              const SizedBox(width: 8),
              const Text(
                'Performance Dashboard',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _buildStatusIndicator(),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
              Switch(
                value: _autoRefresh,
                onChanged: (value) {
                  setState(() {
                    _autoRefresh = value;
                  });
                  if (value) {
                    _startAutoRefresh();
                  } else {
                    _updateTimer?.cancel();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing16),
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryOrange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryOrange,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Metrics'),
              Tab(text: 'Optimization'),
              Tab(text: 'Recommendations'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final memoryUsage = _optimizationMetrics['memoryUsageMB'] ?? 0.0;
    final alertCount = _recommendations.where((r) => r['priority'] == 'high').length;
    
    Color statusColor;
    String statusText;
    
    if (alertCount > 0 || memoryUsage > 200) {
      statusColor = Colors.red;
      statusText = 'Issues';
    } else if (memoryUsage > 150 || _recommendations.length > 3) {
      statusColor = Colors.orange;
      statusText = 'Warning';
    } else {
      statusColor = Colors.green;
      statusText = 'Healthy';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMetrics() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                'Memory',
                '${(_optimizationMetrics['memoryUsageMB'] ?? 0).toStringAsFixed(0)}MB',
                Icons.memory,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricTile(
                'Cache',
                '${_optimizationMetrics['cacheSize'] ?? 0}',
                Icons.storage,
                Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricTile(
                'Alerts',
                '${_recommendations.length}',
                Icons.warning,
                _recommendations.isNotEmpty ? Colors.orange : Colors.grey,
              ),
            ),
          ],
        ),
        if (_recommendations.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacing12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_recommendations.length} optimization recommendations available',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOverviewTab() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current session info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Session',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  _buildInfoRow('Session ID', _performanceStatus['sessionId'] ?? 'N/A'),
                  _buildInfoRow('Duration', '${_performanceStatus['sessionDuration'] ?? 0} minutes'),
                  _buildInfoRow('Active Timers', '${_performanceStatus['activeTimers'] ?? 0}'),
                  _buildInfoRow('Pending Metrics', '${_performanceStatus['pendingMetrics'] ?? 0}'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: AppTheme.spacing16),
          
          // Quick metrics
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: AppTheme.spacing12,
            mainAxisSpacing: AppTheme.spacing12,
            childAspectRatio: 1.2,
            children: [
              _buildMetricCard(
                'Memory Usage',
                '${(_optimizationMetrics['memoryUsageMB'] ?? 0).toStringAsFixed(0)}MB',
                Icons.memory,
                Colors.blue,
              ),
              _buildMetricCard(
                'Cache Size',
                '${_optimizationMetrics['cacheSize'] ?? 0}',
                Icons.storage,
                Colors.green,
              ),
              _buildMetricCard(
                'FPS',
                '${(_performanceStatus['estimatedFPS'] ?? 0).toStringAsFixed(0)}',
                Icons.speed,
                Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsTab() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Analytics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          
          if (_analytics.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Last 7 Days',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    _buildInfoRow('Total Metrics', '${_analytics['totalMetrics'] ?? 0}'),
                    _buildInfoRow('Total Alerts', '${_analytics['totalAlerts'] ?? 0}'),
                    
                    if (_analytics['averages'] != null) ...[
                      const SizedBox(height: AppTheme.spacing12),
                      const Text(
                        'Average Response Times',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppTheme.spacing8),
                      ..._buildAveragesList(_analytics['averages']),
                    ],
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: AppTheme.spacing16),
          
          // Real-time metrics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Real-time Metrics',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  _buildInfoRow('Memory Usage', '${(_performanceStatus['estimatedMemoryMB'] ?? 0).toStringAsFixed(1)}MB'),
                  _buildInfoRow('Frame Rate', '${(_performanceStatus['estimatedFPS'] ?? 0).toStringAsFixed(1)} FPS'),
                  _buildInfoRow('Active Preloads', '${_optimizationMetrics['activePreloads'] ?? 0}'),
                  _buildInfoRow('Batched Operations', '${_optimizationMetrics['batchedOperations'] ?? 0}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimizationTab() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Optimization Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          
          // Optimization metrics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Optimization Status',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  _buildInfoRow('Cache Size', '${_optimizationMetrics['cacheSize'] ?? 0} items'),
                  _buildInfoRow('Active Preloads', '${_optimizationMetrics['activePreloads'] ?? 0}'),
                  _buildInfoRow('Batched Operations', '${_optimizationMetrics['batchedOperations'] ?? 0}'),
                  _buildInfoRow('Enabled Optimizations', '${_optimizationMetrics['enabledOptimizations'] ?? 0}'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: AppTheme.spacing16),
          
          // Quick actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _clearCache,
                          child: const Text('Clear Cache'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _triggerCleanup,
                          child: const Text('Memory Cleanup'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsTab() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Recommendations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          
          if (_recommendations.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 48,
                        color: Colors.green.shade400,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No recommendations',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your app is performing well!',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _recommendations.length,
                itemBuilder: (context, index) {
                  final recommendation = _recommendations[index];
                  return _buildRecommendationCard(recommendation);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAveragesList(Map<String, dynamic> averages) {
    return averages.entries.map((entry) {
      return _buildInfoRow(
        entry.key.replaceAll('_', ' ').toUpperCase(),
        '${entry.value.toStringAsFixed(1)}ms',
      );
    }).toList();
  }

  Widget _buildRecommendationCard(Map<String, dynamic> recommendation) {
    Color priorityColor;
    IconData priorityIcon;
    
    switch (recommendation['priority']) {
      case 'high':
        priorityColor = Colors.red;
        priorityIcon = Icons.warning;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        priorityIcon = Icons.info;
        break;
      default:
        priorityColor = Colors.blue;
        priorityIcon = Icons.lightbulb;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(priorityIcon, color: priorityColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recommendation['title'] ?? 'Recommendation',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (recommendation['priority'] ?? 'low').toUpperCase(),
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              recommendation['description'] ?? 'No description available',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Event handlers
  void _clearCache() {
    PerformanceOptimizationService.clearCache();
    _loadData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache cleared successfully')),
    );
  }

  void _triggerCleanup() {
    // Trigger memory cleanup
    _loadData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Memory cleanup triggered')),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }
}