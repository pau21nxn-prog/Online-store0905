import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../common/theme.dart';
import '../../models/banner.dart' as banner_model;
import '../../services/banner_service.dart';

class BannerManagementScreen extends StatefulWidget {
  const BannerManagementScreen({super.key});

  @override
  State<BannerManagementScreen> createState() => _BannerManagementScreenState();
}

class _BannerManagementScreenState extends State<BannerManagementScreen> {
  List<banner_model.Banner> _banners = [];
  bool _loading = true;
  bool _uploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    try {
      setState(() => _loading = true);
      final banners = await BannerService.getAllBanners();
      setState(() {
        _banners = banners;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showErrorSnackBar('Failed to load banners: $e');
    }
  }

  Future<void> _uploadBanner() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _uploading = true;
          _uploadProgress = 0.0;
        });

        final file = result.files.single;
        final nextOrder = await BannerService.getNextOrder();

        final bannerId = await BannerService.uploadBanner(
          imageData: file.bytes!,
          fileName: file.name,
          order: nextOrder,
          onProgress: (progress) {
            setState(() {
              _uploadProgress = progress;
            });
          },
        );

        if (bannerId != null) {
          _showSuccessSnackBar('Banner uploaded successfully');
          await _loadBanners();
        } else {
          _showErrorSnackBar('Failed to upload banner');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error uploading banner: $e');
    } finally {
      setState(() {
        _uploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  Future<void> _deleteBanner(banner_model.Banner banner) async {
    final confirmed = await _showConfirmDialog(
      'Delete Banner',
      'Are you sure you want to delete this banner? This action cannot be undone.',
    );

    if (confirmed) {
      final success = await BannerService.deleteBanner(banner.id);
      if (success) {
        _showSuccessSnackBar('Banner deleted successfully');
        await _loadBanners();
      } else {
        _showErrorSnackBar('Failed to delete banner');
      }
    }
  }

  Future<void> _toggleBannerStatus(banner_model.Banner banner) async {
    final success = await BannerService.toggleBannerStatus(banner.id, !banner.isActive);
    if (success) {
      _showSuccessSnackBar('Banner ${!banner.isActive ? 'activated' : 'deactivated'}');
      await _loadBanners();
    } else {
      _showErrorSnackBar('Failed to update banner status');
    }
  }

  Future<void> _reorderBanners(List<banner_model.Banner> newOrder) async {
    final bannerIds = newOrder.map((b) => b.id).toList();
    final success = await BannerService.reorderBanners(bannerIds);
    if (success) {
      _showSuccessSnackBar('Banners reordered successfully');
      await _loadBanners();
    } else {
      _showErrorSnackBar('Failed to reorder banners');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.image,
                  color: AppTheme.primaryOrange,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Banner Management',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    Text(
                      'Manage homepage banner carousel images',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Upload Button
                ElevatedButton.icon(
                  onPressed: _uploading ? null : _uploadBanner,
                  icon: _uploading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_photo_alternate),
                  label: Text(_uploading ? 'Uploading...' : 'Upload Banner'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),

          // Upload Progress
          if (_uploading && _uploadProgress > 0)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryOrange),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Uploading: ${(_uploadProgress * 100).toInt()}%',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor(context),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _banners.isEmpty
                    ? _buildEmptyState()
                    : _buildBannersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 80,
            color: AppTheme.primaryOrange.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'No banners uploaded yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload your first banner image to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _uploadBanner,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Upload Banner'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannersList() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Banners (${_banners.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _banners.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                final banners = List<banner_model.Banner>.from(_banners);
                final item = banners.removeAt(oldIndex);
                banners.insert(newIndex, item);
                _reorderBanners(banners);
              },
              itemBuilder: (context, index) {
                final banner = _banners[index];
                return Card(
                  key: Key(banner.id),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 80,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(banner.imageUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    title: Text(
                      'Banner ${banner.order}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status: ${banner.isActive ? 'Active' : 'Inactive'}'),
                        Text('Created: ${banner.createdAt.day}/${banner.createdAt.month}/${banner.createdAt.year}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Status Toggle
                        IconButton(
                          icon: Icon(
                            banner.isActive ? Icons.visibility : Icons.visibility_off,
                            color: banner.isActive ? Colors.green : Colors.grey,
                          ),
                          onPressed: () => _toggleBannerStatus(banner),
                          tooltip: banner.isActive ? 'Deactivate' : 'Activate',
                        ),
                        // Delete Button
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteBanner(banner),
                          tooltip: 'Delete',
                        ),
                        // Reorder Handle
                        const Icon(Icons.drag_handle),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}