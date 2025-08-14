import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../models/product.dart';
import '../models/order.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send notification to specific user
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic> data = const {},
    String? imageUrl,
    String? actionUrl,
  }) async {
    try {
      final notification = NotificationModel(
        id: '', // Will be set by Firestore
        userId: userId,
        title: title,
        body: body,
        type: type,
        data: data,
        createdAt: DateTime.now(),
        imageUrl: imageUrl,
        actionUrl: actionUrl,
      );

      await _firestore
          .collection('notifications')
          .add(notification.toFirestore());

      print('Notification sent to user $userId: $title');
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Send notification to multiple users
  static Future<void> sendBulkNotification({
    required List<String> userIds,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic> data = const {},
    String? imageUrl,
    String? actionUrl,
  }) async {
    try {
      final batch = _firestore.batch();
      
      for (String userId in userIds) {
        final notification = NotificationModel(
          id: '', // Will be set by Firestore
          userId: userId,
          title: title,
          body: body,
          type: type,
          data: data,
          createdAt: DateTime.now(),
          imageUrl: imageUrl,
          actionUrl: actionUrl,
        );

        final docRef = _firestore.collection('notifications').doc();
        batch.set(docRef, notification.toFirestore());
      }

      await batch.commit();
      print('Bulk notification sent to ${userIds.length} users');
    } catch (e) {
      print('Error sending bulk notification: $e');
    }
  }

  // Get notifications for current user
  static Stream<List<NotificationModel>> getUserNotifications({int limit = 50}) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  // Get unread notification count
  static Stream<int> getUnreadCount() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read for current user
  static Future<void> markAllAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final unreadDocs = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in unreadDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Delete notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Clear all notifications for current user
  static Future<void> clearAllNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDocs = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .get();

      final batch = _firestore.batch();
      for (var doc in userDocs.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error clearing all notifications: $e');
    }
  }

  // ======================
  // SPECIFIC NOTIFICATION TYPES
  // ======================

  // Order status notifications
  static Future<void> sendOrderNotification({
    required String userId,
    required String orderId,
    required String status,
    String? orderTotal,
  }) async {
    String title = '';
    String body = '';
    
    switch (status.toLowerCase()) {
      case 'pending':
        title = '🛒 Order Placed Successfully!';
        body = 'Your order #${orderId.substring(0, 8)} has been received and is being processed.';
        break;
      case 'confirmed':
        title = '✅ Order Confirmed!';
        body = 'Great news! Your order #${orderId.substring(0, 8)} has been confirmed.';
        break;
      case 'processing':
        title = '📦 Order Processing';
        body = 'Your order #${orderId.substring(0, 8)} is being prepared for shipment.';
        break;
      case 'shipped':
        title = '🚚 Order Shipped!';
        body = 'Your order #${orderId.substring(0, 8)} is on its way to you!';
        break;
      case 'delivered':
        title = '🎉 Order Delivered!';
        body = 'Your order #${orderId.substring(0, 8)} has been delivered. Enjoy your purchase!';
        break;
      case 'cancelled':
        title = '❌ Order Cancelled';
        body = 'Your order #${orderId.substring(0, 8)} has been cancelled.';
        break;
      default:
        title = '📋 Order Update';
        body = 'Your order #${orderId.substring(0, 8)} status has been updated to $status.';
    }

    await sendNotification(
      userId: userId,
      title: title,
      body: body,
      type: 'order',
      data: {
        'orderId': orderId,
        'status': status,
        'total': orderTotal,
      },
      actionUrl: '/orders/$orderId',
    );
  }

  // Product notifications
  static Future<void> sendProductNotification({
    required String userId,
    required String productId,
    required String productName,
    required String type, // 'new_product', 'price_drop', 'low_stock', 'back_in_stock'
    String? oldPrice,
    String? newPrice,
  }) async {
    String title = '';
    String body = '';
    
    switch (type) {
      case 'new_product':
        title = '🆕 New Product Alert!';
        body = 'Check out "$productName" - just added to your favorite category!';
        break;
      case 'price_drop':
        title = '💰 Price Drop Alert!';
        body = '"$productName" is now ₱$newPrice (was ₱$oldPrice). Get it before it\'s gone!';
        break;
      case 'low_stock':
        title = '⚠️ Low Stock Alert!';
        body = 'Only a few left of "$productName" in your wishlist. Order now!';
        break;
      case 'back_in_stock':
        title = '🔄 Back in Stock!';
        body = 'Good news! "$productName" from your wishlist is back in stock!';
        break;
    }

    await sendNotification(
      userId: userId,
      title: title,
      body: body,
      type: 'product',
      data: {
        'productId': productId,
        'productName': productName,
        'notificationType': type,
        'oldPrice': oldPrice,
        'newPrice': newPrice,
      },
      actionUrl: '/product/$productId',
    );
  }

  // Review notifications
  static Future<void> sendReviewNotification({
    required String userId,
    required String productId,
    required String productName,
    required String type, // 'review_helpful', 'new_review', 'review_reminder'
    String? reviewerName,
  }) async {
    String title = '';
    String body = '';
    
    switch (type) {
      case 'review_helpful':
        title = '👍 Your Review Was Helpful!';
        body = 'Someone found your review of "$productName" helpful!';
        break;
      case 'new_review':
        title = '⭐ New Review Available';
        body = 'Someone reviewed "$productName" that you purchased. Check it out!';
        break;
      case 'review_reminder':
        title = '📝 Review Reminder';
        body = 'How was your "$productName"? Share your experience with others!';
        break;
    }

    await sendNotification(
      userId: userId,
      title: title,
      body: body,
      type: 'review',
      data: {
        'productId': productId,
        'productName': productName,
        'notificationType': type,
        'reviewerName': reviewerName,
      },
      actionUrl: '/product/$productId/reviews',
    );
  }

  // Wishlist notifications
  static Future<void> sendWishlistNotification({
    required String userId,
    required String productId,
    required String productName,
    required String type, // 'price_drop', 'low_stock', 'sale'
    String? salePercentage,
  }) async {
    String title = '';
    String body = '';
    
    switch (type) {
      case 'price_drop':
        title = '💝 Wishlist Price Drop!';
        body = 'Great news! "$productName" from your wishlist has dropped in price!';
        break;
      case 'low_stock':
        title = '⏰ Wishlist Item Low Stock!';
        body = 'Hurry! "$productName" from your wishlist is running low on stock.';
        break;
      case 'sale':
        title = '🔥 Wishlist Item on Sale!';
        body = '"$productName" from your wishlist is now $salePercentage% off!';
        break;
    }

    await sendNotification(
      userId: userId,
      title: title,
      body: body,
      type: 'wishlist',
      data: {
        'productId': productId,
        'productName': productName,
        'notificationType': type,
        'salePercentage': salePercentage,
      },
      actionUrl: '/product/$productId',
    );
  }

  // Admin notifications
  static Future<void> sendAdminNotification({
    required String type, // 'new_order', 'low_stock', 'new_user', 'new_review'
    required Map<String, dynamic> data,
  }) async {
    // Get all admin users
    final adminUsers = await _getAdminUsers();
    
    String title = '';
    String body = '';
    
    switch (type) {
      case 'new_order':
        title = '🛒 New Order Received!';
        body = 'Order #${data['orderId']?.substring(0, 8)} for ₱${data['total']} needs your attention.';
        break;
      case 'low_stock':
        title = '📦 Low Stock Alert!';
        body = '${data['productName']} is running low (${data['stockQty']} left).';
        break;
      case 'new_user':
        title = '👤 New User Registered!';
        body = '${data['userName']} just joined AnneDFinds marketplace.';
        break;
      case 'new_review':
        title = '⭐ New Review Posted!';
        body = 'New ${data['rating']}-star review for ${data['productName']}.';
        break;
    }

    if (adminUsers.isNotEmpty) {
      await sendBulkNotification(
        userIds: adminUsers,
        title: title,
        body: body,
        type: 'admin',
        data: data,
      );
    }
  }

  // Get admin user IDs
  static Future<List<String>> _getAdminUsers() async {
    try {
      // This is a simplified version - you might want to have an 'admins' collection
      // or use user roles from your existing user management
      final adminEmails = [
        'test@annedfinds.com',
        'admin@annedfinds.com',
        // Add more admin emails as needed
      ];

      final adminUsers = <String>[];
      
      for (String email in adminEmails) {
        final userQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
            
        if (userQuery.docs.isNotEmpty) {
          adminUsers.add(userQuery.docs.first.id);
        }
      }

      return adminUsers;
    } catch (e) {
      print('Error getting admin users: $e');
      return [];
    }
  }

  // Clean up old notifications (call this periodically)
  static Future<void> cleanupOldNotifications({int daysOld = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      
      final oldNotifications = await _firestore
          .collection('notifications')
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();
      for (var doc in oldNotifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('Cleaned up ${oldNotifications.docs.length} old notifications');
    } catch (e) {
      print('Error cleaning up old notifications: $e');
    }
  }
}