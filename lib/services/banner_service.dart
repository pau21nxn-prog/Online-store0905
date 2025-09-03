import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/banner.dart';
import 'storage_service.dart';

class BannerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _collection = 'banners';

  /// Get all active banners ordered by their sequence
  static Future<List<Banner>> getBanners() async {
    try {
      print('BannerService: Fetching active banners...');
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      print('BannerService: Found ${querySnapshot.docs.length} active banners');
      
      final banners = querySnapshot.docs
          .map((doc) {
            try {
              return Banner.fromFirestore(doc.id, doc.data());
            } catch (e) {
              print('BannerService: Error parsing banner ${doc.id}: $e');
              return null;
            }
          })
          .where((banner) => banner != null)
          .cast<Banner>()
          .toList();

      print('BannerService: Successfully parsed ${banners.length} banners');
      return banners;
    } catch (e) {
      print('BannerService: Error fetching banners: $e');
      print('BannerService: Error type: ${e.runtimeType}');
      if (e.toString().contains('index')) {
        print('BannerService: This may be due to missing Firestore index. Check Firebase console.');
      }
      return [];
    }
  }

  /// Get all banners (for admin management)
  static Future<List<Banner>> getAllBanners() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .orderBy('order')
          .get();

      return querySnapshot.docs
          .map((doc) => Banner.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching all banners: $e');
      return [];
    }
  }

  /// Upload a new banner
  static Future<String?> uploadBanner({
    required Uint8List imageData,
    required String fileName,
    required int order,
    Function(double)? onProgress,
  }) async {
    try {
      // Generate unique banner ID
      final bannerId = 'banner_${DateTime.now().millisecondsSinceEpoch}';
      final extension = fileName.split('.').last.toLowerCase();
      
      // Upload image to Firebase Storage
      final imagePath = 'banners/$bannerId.$extension';
      final ref = _storage.ref().child(imagePath);
      
      final uploadTask = ref.putData(
        imageData,
        SettableMetadata(
          contentType: 'image/$extension',
          customMetadata: {
            'bannerId': bannerId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Monitor progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Save banner metadata to Firestore
      final banner = Banner(
        id: bannerId,
        imageUrl: downloadUrl,
        order: order,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection(_collection)
          .doc(bannerId)
          .set(banner.toFirestore());

      print('Banner uploaded successfully: $bannerId');
      return bannerId;
    } catch (e) {
      print('Error uploading banner: $e');
      return null;
    }
  }

  /// Update banner properties
  static Future<bool> updateBanner(String bannerId, {
    int? order,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': DateTime.now(),
      };

      if (order != null) updates['order'] = order;
      if (isActive != null) updates['isActive'] = isActive;

      await _firestore
          .collection(_collection)
          .doc(bannerId)
          .update(updates);

      print('Banner updated successfully: $bannerId');
      return true;
    } catch (e) {
      print('Error updating banner: $e');
      return false;
    }
  }

  /// Delete a banner
  static Future<bool> deleteBanner(String bannerId) async {
    try {
      // Get banner data first
      final doc = await _firestore.collection(_collection).doc(bannerId).get();
      
      if (doc.exists) {
        final banner = Banner.fromFirestore(doc.id, doc.data()!);
        
        // Delete image from Storage
        try {
          final ref = _storage.refFromURL(banner.imageUrl);
          await ref.delete();
        } catch (e) {
          print('Error deleting banner image from storage: $e');
          // Continue with Firestore deletion even if storage deletion fails
        }
        
        // Delete from Firestore
        await _firestore.collection(_collection).doc(bannerId).delete();
        
        print('Banner deleted successfully: $bannerId');
        return true;
      } else {
        print('Banner not found: $bannerId');
        return false;
      }
    } catch (e) {
      print('Error deleting banner: $e');
      return false;
    }
  }

  /// Reorder banners by updating their order values
  static Future<bool> reorderBanners(List<String> bannerIds) async {
    try {
      final batch = _firestore.batch();
      
      for (int i = 0; i < bannerIds.length; i++) {
        final bannerRef = _firestore.collection(_collection).doc(bannerIds[i]);
        batch.update(bannerRef, {
          'order': i + 1,
          'updatedAt': DateTime.now(),
        });
      }
      
      await batch.commit();
      print('Banners reordered successfully');
      return true;
    } catch (e) {
      print('Error reordering banners: $e');
      return false;
    }
  }

  /// Get the next available order number
  static Future<int> getNextOrder() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .orderBy('order', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final highestOrder = querySnapshot.docs.first.data()['order'] as int? ?? 0;
        return highestOrder + 1;
      } else {
        return 1;
      }
    } catch (e) {
      print('Error getting next order: $e');
      return 1;
    }
  }

  /// Toggle banner active status
  static Future<bool> toggleBannerStatus(String bannerId, bool isActive) async {
    return await updateBanner(bannerId, isActive: isActive);
  }

  /// Get banner count
  static Future<int> getBannerCount() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();
      
      return querySnapshot.docs.length;
    } catch (e) {
      print('Error getting banner count: $e');
      return 0;
    }
  }
}