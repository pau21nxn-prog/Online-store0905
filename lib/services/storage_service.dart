import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  
  /// Upload product images with automatic optimization
  static Future<List<Map<String, String>>> uploadProductImages({
    required String productId,
    required List<Uint8List> imageFiles,
    required List<String> fileNames,
    Function(double)? onProgress,
  }) async {
    debugPrint('🚀 StorageService: Starting upload for ${imageFiles.length} files');
    final List<Map<String, String>> imageVariants = [];
    
    for (int i = 0; i < imageFiles.length; i++) {
      try {
        final imageData = imageFiles[i];
        final fileName = fileNames[i];
        
        debugPrint('📁 StorageService: Processing file $i: $fileName (${imageData.length} bytes)');
        
        // Generate unique image ID
        final imageId = '${DateTime.now().millisecondsSinceEpoch}_$i';
        final extension = fileName.split('.').last.toLowerCase();
        
        debugPrint('🔧 StorageService: Generated imageId: $imageId, extension: $extension');
        
        // Optimize image
        debugPrint('🖼️ StorageService: Starting image optimization...');
        final optimizedImages = await _optimizeImage(imageData, extension);
        debugPrint('✅ StorageService: Image optimization complete. Variants: ${optimizedImages.keys}');
        
        // Upload original and optimized versions
        debugPrint('☁️ StorageService: Starting Firebase upload...');
        final urls = await _uploadImageVariants(
          productId: productId,
          imageId: imageId,
          extension: extension,
          originalData: imageData,
          optimizedImages: optimizedImages,
          onProgress: onProgress,
        );
        
        debugPrint('✅ StorageService: Upload complete. URLs: $urls');
        
        // Add all variants to the list
        imageVariants.add(urls);
        
      } catch (e) {
        debugPrint('❌ StorageService: Error uploading image $i: $e');
        debugPrint('❌ StorageService: Error details: ${e.toString()}');
        rethrow;
      }
    }
    
    debugPrint('🎉 StorageService: All uploads complete. Total variants: ${imageVariants.length}');
    return imageVariants;
  }
  
  /// Optimize image into multiple sizes
  static Future<Map<String, Uint8List>> _optimizeImage(
    Uint8List originalData, 
    String extension
  ) async {
    final image = img.decodeImage(originalData);
    if (image == null) throw Exception('Invalid image format');
    
    final Map<String, Uint8List> optimizedImages = {};
    
    // Thumbnail (300x300) - for product cards
    final thumbnail = img.copyResize(image, width: 300, height: 300);
    optimizedImages['thumb'] = _encodeImage(thumbnail, extension);
    
    // Medium (800x800) - for product detail view
    final medium = img.copyResize(image, width: 800, height: 800);
    optimizedImages['medium'] = _encodeImage(medium, extension);
    
    // Large (1200x1200) - for zoom/full screen
    final large = img.copyResize(image, width: 1200, height: 1200);
    optimizedImages['large'] = _encodeImage(large, extension);
    
    return optimizedImages;
  }
  
  /// Encode image with appropriate format and quality
  static Uint8List _encodeImage(img.Image image, String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return Uint8List.fromList(img.encodePng(image));
      case 'webp':
        // WebP encoding not available in current image package version
        return Uint8List.fromList(img.encodeJpg(image, quality: 85));
      default:
        return Uint8List.fromList(img.encodeJpg(image, quality: 85));
    }
  }
  
  /// Upload all image variants (thumb, medium, large)
  static Future<Map<String, String>> _uploadImageVariants({
    required String productId,
    required String imageId,
    required String extension,
    required Uint8List originalData,
    required Map<String, Uint8List> optimizedImages,
    Function(double)? onProgress,
  }) async {
    debugPrint('🔥 Firebase: Starting upload to Firebase Storage');
    debugPrint('🔥 Firebase: Product ID: $productId');
    debugPrint('🔥 Firebase: Image ID: $imageId');
    debugPrint('🔥 Firebase: Extension: $extension');
    debugPrint('🔥 Firebase: Variants to upload: ${optimizedImages.keys}');
    
    final Map<String, String> urls = {};
    
    // Upload optimized versions
    for (final entry in optimizedImages.entries) {
      final size = entry.key;
      final data = entry.value;
      
      final path = 'products/$productId/${imageId}_$size.$extension';
      debugPrint('🔥 Firebase: Uploading $size variant to path: $path (${data.length} bytes)');
      
      try {
        final ref = _storage.ref().child(path);
        
        final uploadTask = ref.putData(
          data,
          SettableMetadata(
            contentType: 'image/$extension',
            customMetadata: {
              'productId': productId,
              'imageId': imageId,
              'size': size,
              'uploadedAt': DateTime.now().toIso8601String(),
            },
          ),
        );
        
        // Monitor progress
        uploadTask.snapshotEvents.listen((snapshot) {
          if (onProgress != null) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            onProgress(progress);
          }
          debugPrint('🔥 Firebase: Upload progress for $size: ${(snapshot.bytesTransferred / snapshot.totalBytes * 100).toStringAsFixed(1)}%');
        });
        
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        urls[size] = downloadUrl;
        
        debugPrint('✅ Firebase: Successfully uploaded $size variant');
        debugPrint('✅ Firebase: Download URL: $downloadUrl');
        
      } catch (e) {
        debugPrint('❌ Firebase: Error uploading $size variant: $e');
        debugPrint('❌ Firebase: Error type: ${e.runtimeType}');
        rethrow;
      }
    }
    
    debugPrint('🎉 Firebase: All variants uploaded successfully');
    return urls;
  }
  
  /// Get image URL with specific size
  static String getImageUrl(String baseUrl, {String size = 'medium'}) {
    // If it's already a Firebase Storage URL, try to modify it
    if (baseUrl.contains('firebase')) {
      try {
        // Replace the size in the URL if it exists
        final uri = Uri.parse(baseUrl);
        final pathSegments = uri.pathSegments.toList();
        
        if (pathSegments.length >= 3) {
          final fileName = pathSegments.last;
          final parts = fileName.split('_');
          if (parts.length >= 2) {
            final newFileName = '${parts[0]}_$size.${fileName.split('.').last}';
            pathSegments[pathSegments.length - 1] = newFileName;
            
            return uri.replace(pathSegments: pathSegments).toString();
          }
        }
      } catch (e) {
        // If URL manipulation fails, return original
        return baseUrl;
      }
    }
    
    return baseUrl;
  }
  
  /// Delete product images
  static Future<void> deleteProductImages(String productId, List<String> imageUrls) async {
    for (final url in imageUrls) {
      try {
        // Extract the path from Firebase Storage URL
        final ref = _storage.refFromURL(url);
        await ref.delete();
        
        // Also delete other size variants
        final pathParts = ref.fullPath.split('/');
        final fileName = pathParts.last;
        final baseName = fileName.split('_').first;
        
        // Delete all size variants
        for (final size in ['thumb', 'medium', 'large']) {
          try {
            final extension = fileName.split('.').last;
            final variantPath = pathParts.sublist(0, pathParts.length - 1).join('/') + 
                              '/${baseName}_$size.$extension';
            await _storage.ref(variantPath).delete();
          } catch (e) {
            // Variant might not exist, continue
          }
        }
      } catch (e) {
        debugPrint('Error deleting image: $e');
      }
    }
  }
  
  /// Get storage usage statistics
  static Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final ref = _storage.ref().child('products');
      final result = await ref.listAll();
      
      int totalFiles = 0;
      int totalSize = 0;
      
      for (final item in result.items) {
        totalFiles++;
        try {
          final metadata = await item.getMetadata();
          totalSize += metadata.size ?? 0;
        } catch (e) {
          // Continue if can't get metadata
        }
      }
      
      return {
        'totalFiles': totalFiles,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }
}