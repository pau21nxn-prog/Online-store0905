import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'dart:async';
import '../models/product_media.dart';

enum UploadProgressStatus { queued, uploading, processing, completed, failed }

class UploadProgress {
  final String uploadId;
  final String fileName;
  final UploadProgressStatus status;
  final double progress; // 0.0 to 1.0
  final String? errorMessage;
  final String? downloadUrl;

  UploadProgress({
    required this.uploadId,
    required this.fileName,
    required this.status,
    this.progress = 0.0,
    this.errorMessage,
    this.downloadUrl,
  });

  UploadProgress copyWith({
    UploadProgressStatus? status,
    double? progress,
    String? errorMessage,
    String? downloadUrl,
  }) {
    return UploadProgress(
      uploadId: uploadId,
      fileName: fileName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      downloadUrl: downloadUrl ?? this.downloadUrl,
    );
  }
}

class MediaUploadResult {
  final String mediaId;
  final ProductMedia media;
  final bool success;
  final String? errorMessage;

  MediaUploadResult({
    required this.mediaId,
    required this.media,
    required this.success,
    this.errorMessage,
  });
}

class MediaUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream controllers for upload progress
  static final Map<String, StreamController<UploadProgress>> _progressControllers = {};
  static final StreamController<List<UploadProgress>> _allProgressController = 
      StreamController<List<UploadProgress>>.broadcast();

  // Upload queue management
  static final List<UploadProgress> _uploadQueue = [];
  static int _maxConcurrentUploads = 3;
  static int _currentUploads = 0;

  // Image size configurations
  static const Map<String, int> imageSizes = {
    'thumb': 200,
    'md': 800,
    'xl': 1600,
  };

  // Initialize the service
  static void initialize() {
    // Process upload queue
    Timer.periodic(const Duration(seconds: 1), (_) => _processUploadQueue());
  }

  // Upload single file
  static Future<MediaUploadResult> uploadFile({
    required String productId,
    required File file,
    required MediaType type,
    MediaRole role = MediaRole.gallery,
    String? altText,
    String? caption,
    int order = 0,
  }) async {
    final uploadId = _generateUploadId();
    final fileName = path.basename(file.path);
    
    // Validate file
    final upload = MediaUpload(
      localPath: file.path,
      fileName: fileName,
      type: type,
      role: role,
      fileSize: await file.length(),
      altText: altText,
      caption: caption,
    );

    if (!upload.isValid) {
      return MediaUploadResult(
        mediaId: '',
        media: ProductMedia(
          id: '',
          productId: productId,
          type: type,
          storagePath: '',
          createdAt: DateTime.now(),
          createdBy: _auth.currentUser?.uid ?? '',
        ),
        success: false,
        errorMessage: upload.validationError,
      );
    }

    // Create upload progress
    final progress = UploadProgress(
      uploadId: uploadId,
      fileName: fileName,
      status: UploadProgressStatus.queued,
    );

    _progressControllers[uploadId] = StreamController<UploadProgress>.broadcast();
    _uploadQueue.add(progress);
    _updateProgress(uploadId, progress);

    try {
      // Create media document first
      final mediaId = _firestore.collection('products').doc(productId).collection('media').doc().id;
      final originalPath = 'products/$productId/orig/$fileName';

      final media = ProductMedia(
        id: mediaId,
        productId: productId,
        type: type,
        role: role,
        storagePath: originalPath,
        order: order,
        altText: altText,
        caption: caption,
        metadata: {
          'originalFileName': fileName,
          'fileSize': upload.fileSize,
          'uploadedBy': _auth.currentUser?.uid,
        },
        isProcessed: false,
        createdAt: DateTime.now(),
        createdBy: _auth.currentUser?.uid ?? '',
      );

      // Save media document
      await _firestore
          .collection('products')
          .doc(productId)
          .collection('media')
          .doc(mediaId)
          .set(media.toFirestore());

      // Wait for upload slot
      await _waitForUploadSlot(uploadId);

      // Update status to uploading
      _updateProgress(uploadId, progress.copyWith(status: UploadProgressStatus.uploading));

      // Upload original file
      final originalRef = _storage.ref(originalPath);
      final uploadTask = originalRef.putFile(
        file,
        SettableMetadata(
          contentType: _getContentType(type, fileName),
          customMetadata: {
            'productId': productId,
            'mediaId': mediaId,
            'uploadedBy': _auth.currentUser?.uid ?? '',
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        _updateProgress(uploadId, UploadProgress(
          uploadId: uploadId,
          fileName: fileName,
          status: UploadProgressStatus.uploading,
          progress: progress * 0.7, // 70% for upload, 30% for processing
        ));
      });

      await uploadTask;
      
      // Update status to processing
      _updateProgress(uploadId, progress.copyWith(
        status: UploadProgressStatus.processing,
        progress: 0.7,
      ));

      // Generate derivatives based on file type
      Map<String, String> variants = {};
      
      if (type == MediaType.image) {
        variants = await _generateImageVariants(productId, mediaId, file);
      } else if (type == MediaType.video) {
        variants = await _generateVideoVariants(productId, mediaId, file);
      }

      // Update media document with variants
      await _firestore
          .collection('products')
          .doc(productId)
          .collection('media')
          .doc(mediaId)
          .update({
            'variants': {
              type.name: variants,
            },
            'isProcessed': true,
            'metadata.processedAt': Timestamp.now(),
          });

      // Mark upload as completed
      _updateProgress(uploadId, progress.copyWith(
        status: UploadProgressStatus.completed,
        progress: 1.0,
        downloadUrl: variants['md'] ?? variants['thumb'] ?? originalPath,
      ));

      _currentUploads--;

      return MediaUploadResult(
        mediaId: mediaId,
        media: media.copyWith(
          variants: MediaVariants(
            image: type == MediaType.image ? variants : {},
            video: type == MediaType.video ? variants : {},
          ),
          isProcessed: true,
        ),
        success: true,
      );

    } catch (e) {
      _updateProgress(uploadId, progress.copyWith(
        status: UploadProgressStatus.failed,
        errorMessage: e.toString(),
      ));

      _currentUploads--;

      return MediaUploadResult(
        mediaId: '',
        media: ProductMedia(
          id: '',
          productId: productId,
          type: type,
          storagePath: '',
          createdAt: DateTime.now(),
          createdBy: _auth.currentUser?.uid ?? '',
        ),
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  // Upload multiple files
  static Future<List<MediaUploadResult>> uploadMultipleFiles({
    required String productId,
    required List<File> files,
    required List<MediaType> types,
    List<MediaRole>? roles,
    List<String?>? altTexts,
    List<String?>? captions,
  }) async {
    final results = <MediaUploadResult>[];
    
    for (int i = 0; i < files.length; i++) {
      final result = await uploadFile(
        productId: productId,
        file: files[i],
        type: types[i],
        role: roles?[i] ?? MediaRole.gallery,
        altText: altTexts?[i],
        caption: captions?[i],
        order: i,
      );
      results.add(result);
    }

    return results;
  }

  // Generate image variants
  static Future<Map<String, String>> _generateImageVariants(
    String productId,
    String mediaId,
    File originalFile,
  ) async {
    final variants = <String, String>{};
    final originalImage = img.decodeImage(await originalFile.readAsBytes());
    
    if (originalImage == null) {
      throw Exception('Failed to decode image');
    }

    for (final entry in imageSizes.entries) {
      final sizeName = entry.key;
      final maxSize = entry.value;
      
      // Calculate new dimensions maintaining aspect ratio
      final originalWidth = originalImage.width;
      final originalHeight = originalImage.height;
      late int newWidth, newHeight;
      
      if (originalWidth > originalHeight) {
        newWidth = maxSize;
        newHeight = (originalHeight * maxSize / originalWidth).round();
      } else {
        newHeight = maxSize;
        newWidth = (originalWidth * maxSize / originalHeight).round();
      }

      // Resize image
      final resizedImage = img.copyResize(
        originalImage,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.lanczos,
      );

      // Convert to JPEG with optimization
      final jpegBytes = img.encodeJpg(resizedImage, quality: 85);
      
      // Upload resized image
      final variantPath = 'products/$productId/img/$sizeName/${mediaId}.jpg';
      final variantRef = _storage.ref(variantPath);
      
      await variantRef.putData(
        Uint8List.fromList(jpegBytes),
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000, immutable',
          customMetadata: {
            'productId': productId,
            'mediaId': mediaId,
            'variant': sizeName,
            'originalWidth': originalWidth.toString(),
            'originalHeight': originalHeight.toString(),
            'newWidth': newWidth.toString(),
            'newHeight': newHeight.toString(),
          },
        ),
      );

      variants[sizeName] = await variantRef.getDownloadURL();
    }

    return variants;
  }

  // Generate video variants (placeholder for Cloud Functions implementation)
  static Future<Map<String, String>> _generateVideoVariants(
    String productId,
    String mediaId,
    File originalFile,
  ) async {
    // In a production app, this would trigger Cloud Functions for video processing
    // For now, we'll just store the original and create a placeholder poster
    
    final variants = <String, String>{};
    
    // Store original video path
    final mp4Path = 'products/$productId/vid/mp4/${mediaId}.mp4';
    variants['mp4'] = mp4Path;
    
    // Placeholder for HLS master playlist
    final hlsPath = 'products/$productId/vid/hls/master.m3u8';
    variants['hlsMaster'] = hlsPath;
    
    // Placeholder for poster frame
    final posterPath = 'products/$productId/vid/poster/${mediaId}.jpg';
    variants['poster'] = posterPath;
    
    // TODO: Implement actual video processing with Cloud Functions
    // This would include:
    // - Transcoding to multiple bitrates
    // - Generating HLS segments
    // - Extracting poster frame
    // - Creating thumbnails
    
    return variants;
  }

  // Upload progress management
  static Stream<UploadProgress> watchUploadProgress(String uploadId) {
    if (!_progressControllers.containsKey(uploadId)) {
      _progressControllers[uploadId] = StreamController<UploadProgress>.broadcast();
    }
    return _progressControllers[uploadId]!.stream;
  }

  static Stream<List<UploadProgress>> watchAllUploads() {
    return _allProgressController.stream;
  }

  static void _updateProgress(String uploadId, UploadProgress progress) {
    _progressControllers[uploadId]?.add(progress);
    
    // Update the upload in queue
    final index = _uploadQueue.indexWhere((u) => u.uploadId == uploadId);
    if (index != -1) {
      _uploadQueue[index] = progress;
    }
    
    _allProgressController.add(List.from(_uploadQueue));
  }

  static Future<void> _waitForUploadSlot(String uploadId) async {
    while (_currentUploads >= _maxConcurrentUploads) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _currentUploads++;
  }

  static void _processUploadQueue() {
    // Remove completed or failed uploads from queue after 30 seconds
    _uploadQueue.removeWhere((upload) {
      return (upload.status == UploadProgressStatus.completed || 
              upload.status == UploadProgressStatus.failed) &&
             DateTime.now().millisecondsSinceEpoch - 
             int.parse(upload.uploadId.split('_').last) > 30000;
    });
  }

  // Delete media
  static Future<void> deleteMedia(String productId, String mediaId) async {
    try {
      // Get media document
      final mediaDoc = await _firestore
          .collection('products')
          .doc(productId)
          .collection('media')
          .doc(mediaId)
          .get();

      if (!mediaDoc.exists) return;

      final media = ProductMedia.fromFirestore(mediaId, mediaDoc.data()!);
      
      // Delete original file
      try {
        await _storage.ref(media.storagePath).delete();
      } catch (e) {
        debugPrint('Failed to delete original file: $e');
      }

      // Delete variants
      if (media.type == MediaType.image) {
        for (final sizeName in imageSizes.keys) {
          try {
            final variantPath = 'products/$productId/img/$sizeName/$mediaId.jpg';
            await _storage.ref(variantPath).delete();
          } catch (e) {
            debugPrint('Failed to delete image variant $sizeName: $e');
          }
        }
      } else if (media.type == MediaType.video) {
        // Delete video variants
        final variants = ['mp4', 'poster'];
        for (final variant in variants) {
          try {
            final variantPath = 'products/$productId/vid/$variant/$mediaId.*';
            // Note: This is simplified - in practice you'd need to list and delete all files
            debugPrint('Would delete video variant: $variantPath');
          } catch (e) {
            debugPrint('Failed to delete video variant $variant: $e');
          }
        }
      }

      // Delete media document
      await _firestore
          .collection('products')
          .doc(productId)
          .collection('media')
          .doc(mediaId)
          .delete();

    } catch (e) {
      throw Exception('Failed to delete media: $e');
    }
  }

  // Reorder media
  static Future<void> reorderMedia(
    String productId,
    List<String> mediaIds,
  ) async {
    final batch = _firestore.batch();
    
    for (int i = 0; i < mediaIds.length; i++) {
      final mediaRef = _firestore
          .collection('products')
          .doc(productId)
          .collection('media')
          .doc(mediaIds[i]);
      
      batch.update(mediaRef, {'order': i});
    }
    
    await batch.commit();
  }

  // Update media metadata
  static Future<void> updateMediaMetadata(
    String productId,
    String mediaId, {
    MediaRole? role,
    String? altText,
    String? caption,
  }) async {
    final updates = <String, dynamic>{};
    
    if (role != null) updates['role'] = role.name;
    if (altText != null) updates['altText'] = altText;
    if (caption != null) updates['caption'] = caption;
    
    if (updates.isNotEmpty) {
      await _firestore
          .collection('products')
          .doc(productId)
          .collection('media')
          .doc(mediaId)
          .update(updates);
    }
  }

  // Get media for product
  static Future<List<ProductMedia>> getProductMedia(String productId) async {
    final snapshot = await _firestore
        .collection('products')
        .doc(productId)
        .collection('media')
        .orderBy('order')
        .get();
    
    return snapshot.docs
        .map((doc) => ProductMedia.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  // Utility methods
  static String _getContentType(MediaType type, String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    
    if (type == MediaType.image) {
      switch (extension) {
        case '.jpg':
        case '.jpeg':
          return 'image/jpeg';
        case '.png':
          return 'image/png';
        case '.webp':
          return 'image/webp';
        default:
          return 'image/jpeg';
      }
    } else {
      switch (extension) {
        case '.mp4':
          return 'video/mp4';
        case '.mov':
          return 'video/quicktime';
        default:
          return 'video/mp4';
      }
    }
  }

  static String _generateUploadId() {
    return 'upload_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Configuration
  static void setMaxConcurrentUploads(int max) {
    _maxConcurrentUploads = max;
  }

  // Dispose resources
  static void dispose() {
    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _progressControllers.clear();
    _allProgressController.close();
  }

  // Debug print
  static void debugPrint(String message) {
    debugPrint('[MediaUploadService] $message');
  }
}