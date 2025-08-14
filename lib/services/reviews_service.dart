import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/review.dart';

class ReviewsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Add a new review
  static Future<void> addReview({
    required String productId,
    required int rating,
    required String comment,
    List<String> imageUrls = const [],
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Check if user has already reviewed this product
    final existingReview = await _firestore
        .collection('reviews')
        .where('productId', isEqualTo: productId)
        .where('userId', isEqualTo: user.uid)
        .get();

    if (existingReview.docs.isNotEmpty) {
      throw Exception('You have already reviewed this product');
    }

    // Check if user has purchased this product (for verified review)
    final hasOrdered = await _hasUserOrderedProduct(productId, user.uid);

    // Get user profile data
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};

    final reviewData = {
      'productId': productId,
      'userId': user.uid,
      'userName': userData['name'] ?? user.displayName ?? 'Anonymous User',
      'userProfileImage': userData['profileImageUrl'],
      'rating': rating,
      'comment': comment,
      'imageUrls': imageUrls,
      'createdAt': Timestamp.now(),
      'isVerified': hasOrdered,
      'helpfulCount': 0,
      'helpfulUsers': [],
    };

    await _firestore.collection('reviews').add(reviewData);

    // Update product's average rating
    await _updateProductRating(productId);
  }

  // Get reviews for a product
  static Stream<List<Review>> getProductReviews(String productId) {
    return _firestore
        .collection('reviews')
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Review.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  // Get product rating summary
  static Future<Map<String, dynamic>> getProductRatingSummary(String productId) async {
    final reviews = await _firestore
        .collection('reviews')
        .where('productId', isEqualTo: productId)
        .get();

    if (reviews.docs.isEmpty) {
      return {
        'averageRating': 0.0,
        'totalReviews': 0,
        'ratingBreakdown': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      };
    }

    int totalReviews = reviews.docs.length;
    int totalRating = 0;
    Map<int, int> ratingBreakdown = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    for (var doc in reviews.docs) {
      final rating = doc.data()['rating'] as int;
      totalRating += rating;
      ratingBreakdown[rating] = (ratingBreakdown[rating] ?? 0) + 1;
    }

    double averageRating = totalRating / totalReviews;

    return {
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'ratingBreakdown': ratingBreakdown,
    };
  }

  // Mark review as helpful
  static Future<void> markReviewHelpful(String reviewId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final reviewDoc = _firestore.collection('reviews').doc(reviewId);
    
    await _firestore.runTransaction((transaction) async {
      final review = await transaction.get(reviewDoc);
      final data = review.data() ?? {};
      
      List<String> helpfulUsers = List<String>.from(data['helpfulUsers'] ?? []);
      int helpfulCount = data['helpfulCount'] ?? 0;

      if (helpfulUsers.contains(user.uid)) {
        // Remove helpful vote
        helpfulUsers.remove(user.uid);
        helpfulCount--;
      } else {
        // Add helpful vote
        helpfulUsers.add(user.uid);
        helpfulCount++;
      }

      transaction.update(reviewDoc, {
        'helpfulUsers': helpfulUsers,
        'helpfulCount': helpfulCount,
      });
    });
  }

  // Delete review (user can delete their own review)
  static Future<void> deleteReview(String reviewId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final reviewDoc = await _firestore.collection('reviews').doc(reviewId).get();
    final reviewData = reviewDoc.data();

    if (reviewData == null) throw Exception('Review not found');
    
    if (reviewData['userId'] != user.uid) {
      throw Exception('You can only delete your own reviews');
    }

    await _firestore.collection('reviews').doc(reviewId).delete();

    // Update product's average rating
    await _updateProductRating(reviewData['productId']);
  }

  // Update review
  static Future<void> updateReview({
    required String reviewId,
    required int rating,
    required String comment,
    List<String> imageUrls = const [],
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final reviewDoc = _firestore.collection('reviews').doc(reviewId);
    final review = await reviewDoc.get();
    final reviewData = review.data();

    if (reviewData == null) throw Exception('Review not found');
    
    if (reviewData['userId'] != user.uid) {
      throw Exception('You can only edit your own reviews');
    }

    await reviewDoc.update({
      'rating': rating,
      'comment': comment,
      'imageUrls': imageUrls,
      'updatedAt': Timestamp.now(),
    });

    // Update product's average rating
    await _updateProductRating(reviewData['productId']);
  }

  // Get user's reviews
  static Stream<List<Review>> getUserReviews() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('reviews')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Review.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  // Private helper methods
  static Future<bool> _hasUserOrderedProduct(String productId, String userId) async {
    final orders = await _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'delivered')
        .get();

    for (var order in orders.docs) {
      final items = order.data()['items'] as List<dynamic>? ?? [];
      for (var item in items) {
        if (item['productId'] == productId) {
          return true;
        }
      }
    }
    return false;
  }

  static Future<void> _updateProductRating(String productId) async {
    final reviews = await _firestore
        .collection('reviews')
        .where('productId', isEqualTo: productId)
        .get();

    if (reviews.docs.isEmpty) {
      await _firestore.collection('products').doc(productId).update({
        'averageRating': 0.0,
        'totalReviews': 0,
      });
      return;
    }

    int totalRating = 0;
    for (var doc in reviews.docs) {
      totalRating += doc.data()['rating'] as int;
    }

    double averageRating = totalRating / reviews.docs.length;

    await _firestore.collection('products').doc(productId).update({
      'averageRating': averageRating,
      'totalReviews': reviews.docs.length,
    });
  }
}