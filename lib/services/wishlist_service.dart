import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/wishlist_item.dart';
import '../models/product.dart';

class WishlistService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Add product to wishlist
  static Future<void> addToWishlist(Product product) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Check if product is already in wishlist
    final existingItem = await _firestore
        .collection('wishlist')
        .where('userId', isEqualTo: user.uid)
        .where('productId', isEqualTo: product.id)
        .get();

    if (existingItem.docs.isNotEmpty) {
      throw Exception('Product is already in your wishlist');
    }

    final wishlistItem = {
      'userId': user.uid,
      'productId': product.id,
      'productName': product.name,
      'price': product.price,
      'imageUrl': product.imageUrls.isNotEmpty ? product.imageUrls.first : '',
      'addedAt': Timestamp.now(),
      'isAvailable': product.isActive && product.stockQty > 0,
    };

    await _firestore.collection('wishlist').add(wishlistItem);
  }

  // Remove product from wishlist
  static Future<void> removeFromWishlist(String productId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final existingItems = await _firestore
        .collection('wishlist')
        .where('userId', isEqualTo: user.uid)
        .where('productId', isEqualTo: productId)
        .get();

    for (var doc in existingItems.docs) {
      await doc.reference.delete();
    }
  }

  // Check if product is in wishlist
  static Future<bool> isInWishlist(String productId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final existingItem = await _firestore
        .collection('wishlist')
        .where('userId', isEqualTo: user.uid)
        .where('productId', isEqualTo: productId)
        .get();

    return existingItem.docs.isNotEmpty;
  }

  // Get user's wishlist
  static Stream<List<WishlistItem>> getUserWishlist() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('wishlist')
        .where('userId', isEqualTo: user.uid)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WishlistItem.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  // Get wishlist count
  static Stream<int> getWishlistCount() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    return _firestore
        .collection('wishlist')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Clear entire wishlist
  static Future<void> clearWishlist() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final wishlistItems = await _firestore
        .collection('wishlist')
        .where('userId', isEqualTo: user.uid)
        .get();

    final batch = _firestore.batch();
    for (var doc in wishlistItems.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Move all wishlist items to cart
  static Future<int> moveAllToCart() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final wishlistItems = await _firestore
        .collection('wishlist')
        .where('userId', isEqualTo: user.uid)
        .where('isAvailable', isEqualTo: true)
        .get();

    int itemsAdded = 0;
    final batch = _firestore.batch();

    for (var doc in wishlistItems.docs) {
      final data = doc.data();
      
      // Add to cart
      final cartItemRef = _firestore
          .collection('carts')
          .doc(user.uid)
          .collection('items')
          .doc();

      batch.set(cartItemRef, {
        'productId': data['productId'],
        'productName': data['productName'],
        'price': data['price'],
        'imageUrl': data['imageUrl'],
        'quantity': 1,
        'addedAt': Timestamp.now(),
      });

      // Remove from wishlist
      batch.delete(doc.reference);
      itemsAdded++;
    }

    if (itemsAdded > 0) {
      await batch.commit();
    }

    return itemsAdded;
  }

  // Update product availability in wishlist
  static Future<void> updateProductAvailability(String productId, bool isAvailable) async {
    final wishlistItems = await _firestore
        .collection('wishlist')
        .where('productId', isEqualTo: productId)
        .get();

    final batch = _firestore.batch();
    for (var doc in wishlistItems.docs) {
      batch.update(doc.reference, {'isAvailable': isAvailable});
    }
    await batch.commit();
  }

  // Get wishlist statistics
  static Future<Map<String, dynamic>> getWishlistStats() async {
    final user = _auth.currentUser;
    if (user == null) return {'totalItems': 0, 'totalValue': 0.0, 'availableItems': 0};

    final wishlistItems = await _firestore
        .collection('wishlist')
        .where('userId', isEqualTo: user.uid)
        .get();

    int totalItems = wishlistItems.docs.length;
    double totalValue = 0.0;
    int availableItems = 0;

    for (var doc in wishlistItems.docs) {
      final data = doc.data();
      totalValue += (data['price'] ?? 0.0).toDouble();
      if (data['isAvailable'] == true) {
        availableItems++;
      }
    }

    return {
      'totalItems': totalItems,
      'totalValue': totalValue,
      'availableItems': availableItems,
    };
  }
}