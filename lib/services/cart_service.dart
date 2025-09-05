import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cart_item.dart';
import 'dart:async';

class CartService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // In-memory storage for ALL users until payment (including authenticated users)
  static final Map<String, CartItem> _memoryCart = {};
  static final StreamController<List<CartItem>> _cartController = 
      StreamController<List<CartItem>>.broadcast();

  // Initialize the service
  static void initialize() {
    // Listen to auth changes for cart migration and restoration
    _auth.authStateChanges().listen((user) async {
      if (user != null && !user.isAnonymous && _memoryCart.isNotEmpty) {
        // User signed in with a real account - migrate memory cart to Firebase
        await _migrateMemoryCartToFirebase();
      } else if (user != null && !user.isAnonymous) {
        // Load existing Firebase cart for authenticated users (cart persistence across sessions)
        await _loadFirebaseCart();
      } else if (user == null) {
        // User signed out - clear memory cart to ensure fresh start
        _memoryCart.clear();
        _cartController.add([]);
      }
    });

    // Initialize cart stream with current memory data
    _cartController.add(_memoryCart.values.toList());
  }

  // Add item to cart (always uses memory until payment)
  static Future<void> addToCart(
    dynamic product, {
    int quantity = 1,
    String? selectedVariantId,
    Map<String, String>? selectedOptions,
    String? variantSku,
    String? variantDisplayName,
  }) async {
    // Handle both Product object and individual parameters
    String productId, productName, imageUrl;
    double price;
    
    if (product is Map<String, dynamic>) {
      productId = product['id'] ?? '';
      productName = product['name'] ?? '';
      price = (product['price'] ?? 0).toDouble();
      imageUrl = product['imageUrls']?.isNotEmpty == true 
          ? product['imageUrls'][0] 
          : '';
    } else {
      productId = product.id ?? '';
      productName = product.name ?? '';
      price = product.price?.toDouble() ?? 0.0;
      imageUrl = product.imageUrls?.isNotEmpty == true 
          ? product.imageUrls[0] 
          : '';
    }

    _addToMemoryCart(
      productId, 
      productName, 
      price, 
      imageUrl, 
      quantity,
      selectedVariantId: selectedVariantId,
      selectedOptions: selectedOptions,
      variantSku: variantSku,
      variantDisplayName: variantDisplayName,
    );
  }

  // Add item to cart with named parameters
  static Future<void> addToCartWithParams({
    required String productId,
    required String productName,
    required double price,
    required String imageUrl,
    int quantity = 1,
    String? selectedVariantId,
    Map<String, String>? selectedOptions,
    String? variantSku,
    String? variantDisplayName,
  }) async {
    _addToMemoryCart(
      productId, 
      productName, 
      price, 
      imageUrl, 
      quantity,
      selectedVariantId: selectedVariantId,
      selectedOptions: selectedOptions,
      variantSku: variantSku,
      variantDisplayName: variantDisplayName,
    );
  }

  // Private method to add to memory cart
  static void _addToMemoryCart(
    String productId,
    String productName,
    double price,
    String imageUrl,
    int quantity, {
    String? selectedVariantId,
    Map<String, String>? selectedOptions,
    String? variantSku,
    String? variantDisplayName,
  }) {
    // Create unique key for variant products
    String cartKey = selectedVariantId != null ? '${productId}_$selectedVariantId' : productId;
    
    if (_memoryCart.containsKey(cartKey)) {
      // Update existing item
      final existingItem = _memoryCart[cartKey]!;
      _memoryCart[cartKey] = CartItem(
        productId: productId,
        productName: productName,
        price: price,
        quantity: existingItem.quantity + quantity,
        imageUrl: imageUrl,
        addedAt: existingItem.addedAt,
        selectedVariantId: selectedVariantId,
        selectedOptions: selectedOptions,
        variantSku: variantSku,
        variantDisplayName: variantDisplayName,
      );
    } else {
      // Add new item
      _memoryCart[cartKey] = CartItem(
        productId: productId,
        productName: productName,
        price: price,
        quantity: quantity,
        imageUrl: imageUrl,
        addedAt: DateTime.now(),
        selectedVariantId: selectedVariantId,
        selectedOptions: selectedOptions,
        variantSku: variantSku,
        variantDisplayName: variantDisplayName,
      );
    }

    // Notify listeners
    _cartController.add(_memoryCart.values.toList());
    
    // Sync to Firebase if user is authenticated (for persistence across sessions)
    _syncCartToFirebase();
  }

  // Get cart items stream (always returns memory cart)
  static Stream<List<CartItem>> getCartItems() async* {
    // Immediately yield current state
    yield _memoryCart.values.toList();
    
    // Then yield all future updates
    yield* _cartController.stream;
  }

  // Update item quantity
  static Future<void> updateQuantity(String cartKey, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeFromCart(cartKey);
      return;
    }

    if (_memoryCart.containsKey(cartKey)) {
      final item = _memoryCart[cartKey]!;
      _memoryCart[cartKey] = CartItem(
        productId: item.productId,
        productName: item.productName,
        price: item.price,
        quantity: newQuantity,
        imageUrl: item.imageUrl,
        addedAt: item.addedAt,
        selectedVariantId: item.selectedVariantId,
        selectedOptions: item.selectedOptions,
        variantSku: item.variantSku,
        variantDisplayName: item.variantDisplayName,
      );
      _cartController.add(_memoryCart.values.toList());
      _syncCartToFirebase();
    }
  }

  // Remove item from cart
  static Future<void> removeFromCart(String cartKey) async {
    debugPrint('🔍 CartService.removeFromCart called with key: $cartKey');
    debugPrint('📋 Current cart keys before removal: ${_memoryCart.keys.toList()}');
    
    if (_memoryCart.containsKey(cartKey)) {
      final removedItem = _memoryCart.remove(cartKey);
      debugPrint('✅ Successfully removed item: ${removedItem?.productName} (key: $cartKey)');
    } else {
      debugPrint('⚠️ Cart key not found in memory cart: $cartKey');
      debugPrint('📋 Available keys: ${_memoryCart.keys.toList()}');
      throw Exception('Cart key not found: $cartKey');
    }
    
    _cartController.add(_memoryCart.values.toList());
    debugPrint('📋 Cart updated, remaining items: ${_memoryCart.length}');
    
    // CRITICAL: Wait for Firebase sync to complete
    final user = _auth.currentUser;
    if (user != null && !user.isAnonymous) {
      debugPrint('🔄 Starting Firebase sync for authenticated user cart removal...');
      await _syncCartToFirebase();
      debugPrint('✅ Firebase sync completed for cart removal');
    } else {
      debugPrint('⚠️ Skipping Firebase sync - user is anonymous or null');
      // For anonymous users, ensure the memory cart change is immediately reflected
      await Future.delayed(Duration(milliseconds: 100)); // Small delay to ensure stream is updated
      debugPrint('✅ Memory cart updated for anonymous user');
    }
  }

  // Special method for clearing cart after checkout - handles both authenticated and anonymous users
  static Future<void> clearSelectedItemsAfterCheckout(List<String> cartKeysToRemove) async {
    debugPrint('🛒 Starting clearSelectedItemsAfterCheckout with ${cartKeysToRemove.length} keys');
    
    final user = _auth.currentUser;
    final isAuthenticated = user != null && !user.isAnonymous;
    
    debugPrint('👤 User authentication status: ${isAuthenticated ? 'Authenticated' : 'Anonymous/None'}');
    
    // Remove items from memory cart
    int removedCount = 0;
    for (final cartKey in cartKeysToRemove) {
      if (_memoryCart.containsKey(cartKey)) {
        final removedItem = _memoryCart.remove(cartKey);
        removedCount++;
        debugPrint('✅ Removed from memory: ${removedItem?.productName} (key: $cartKey)');
      } else {
        debugPrint('⚠️ Key not found in memory cart: $cartKey');
      }
    }
    
    // Update the stream immediately
    _cartController.add(_memoryCart.values.toList());
    debugPrint('📋 Memory cart updated: removed $removedCount items, ${_memoryCart.length} remaining');
    
    // Handle Firebase sync for authenticated users
    if (isAuthenticated) {
      debugPrint('🔄 Syncing authenticated user cart to Firebase...');
      await _syncCartToFirebase();
      debugPrint('✅ Firebase sync completed');
    } else {
      debugPrint('⚠️ Anonymous user - skipping Firebase sync');
      // For anonymous users, add extra delay to ensure UI updates
      await Future.delayed(Duration(milliseconds: 200));
    }
    
    debugPrint('🎉 clearSelectedItemsAfterCheckout completed successfully');
  }

  // Clear entire cart
  static Future<void> clearCart() async {
    _memoryCart.clear();
    _cartController.add([]);
    _syncCartToFirebase();
  }

  // Get cart item count
  static Stream<int> getCartItemCount() {
    return getCartItems().map((items) => 
        items.fold<int>(0, (sum, item) => sum + item.quantity));
  }

  // Get cart item count stream (for badge)
  static Stream<int> getCartItemCountStream() {
    return getCartItemCount();
  }

  // Get cart total
  static Stream<double> getCartTotal() {
    return getCartItems().map((items) => 
        items.fold<double>(0, (sum, item) => sum + item.totalPrice));
  }

  // Check if product is in cart
  static Future<bool> isInCart(String productId, {String? variantId}) async {
    String cartKey = variantId != null ? '${productId}_$variantId' : productId;
    return _memoryCart.containsKey(cartKey);
  }

  // Sync memory cart to Firebase for authenticated users (for persistence across sessions)
  static Future<void> _syncCartToFirebase() async {
    final user = _auth.currentUser;
    debugPrint('🔄 _syncCartToFirebase called - User: ${user?.uid ?? 'null'}, Anonymous: ${user?.isAnonymous ?? true}');
    
    if (user == null) {
      debugPrint('⚠️ No user found - cart sync skipped');
      return;
    }
    
    if (user.isAnonymous) {
      debugPrint('⚠️ Anonymous user - cart sync skipped');
      return;
    }

    try {
      debugPrint('🔄 Starting Firebase cart sync for user: ${user.uid}');
      final batch = _firestore.batch();
      final userCartRef = _firestore.collection('carts').doc(user.uid);
      
      // First, delete all existing items to ensure clean sync
      debugPrint('🗑️ Clearing existing Firebase cart items...');
      final existingItems = await userCartRef.collection('items').get();
      for (final doc in existingItems.docs) {
        batch.delete(doc.reference);
      }
      debugPrint('🗑️ Scheduled deletion of ${existingItems.docs.length} existing items');
      
      // Add all current memory cart items
      debugPrint('📦 Adding ${_memoryCart.length} memory cart items to Firebase...');
      for (final entry in _memoryCart.entries) {
        final cartKey = entry.key;
        final cartItem = entry.value;
        final itemRef = userCartRef.collection('items').doc(cartKey);
        batch.set(itemRef, cartItem.toFirestore());
        debugPrint('📦 Scheduled add: ${cartItem.productName} (key: $cartKey)');
      }

      debugPrint('💾 Committing Firebase cart sync batch...');
      await batch.commit();
      debugPrint('✅ Firebase cart sync completed successfully');
    } catch (e) {
      debugPrint('❌ CRITICAL ERROR syncing cart to Firebase: $e');
      rethrow; // Don't swallow errors - let the caller handle them
    }
  }

  // Load Firebase cart for authenticated users (when they sign in)
  static Future<void> _loadFirebaseCart() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      final cartSnapshot = await _firestore
          .collection('carts')
          .doc(user.uid)
          .collection('items')
          .get();

      // Clear memory cart first
      _memoryCart.clear();

      // Load Firebase cart into memory with validation
      for (final doc in cartSnapshot.docs) {
        final item = CartItem.fromFirestore(doc.id, doc.data());
        
        // Skip invalid or test items to prevent data corruption
        if (item.productName.toLowerCase().contains('test') || 
            item.productName.toLowerCase().contains('sample') ||
            item.quantity > 10 ||  // Reasonable quantity limit
            item.quantity <= 0 ||  // Invalid quantities
            item.productId.isEmpty) {
          debugPrint('Skipping invalid cart item: ${item.productName} (qty: ${item.quantity})');
          // Optionally delete the invalid item from Firestore
          doc.reference.delete().catchError((e) => debugPrint('Error deleting invalid item: $e'));
          continue;
        }
        
        _memoryCart[doc.id] = item;
      }

      _cartController.add(_memoryCart.values.toList());
    } catch (e) {
      debugPrint('Error loading Firebase cart: $e');
    }
  }

  // Migrate memory cart to Firebase when user signs in with real account
  static Future<void> _migrateMemoryCartToFirebase() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous || _memoryCart.isEmpty) return;

    try {
      final batch = _firestore.batch();
      
      for (final entry in _memoryCart.entries) {
        final cartKey = entry.key;
        final cartItem = entry.value;
        final cartRef = _firestore
            .collection('carts')
            .doc(user.uid)
            .collection('items')
            .doc(cartKey);

        // Check if item already exists in Firebase cart
        final existingItem = await cartRef.get();
        
        if (existingItem.exists) {
          // Merge quantities
          final currentQuantity = existingItem.data()?['quantity'] ?? 0;
          batch.update(cartRef, {
            'quantity': currentQuantity + cartItem.quantity,
          });
        } else {
          // Add new item
          batch.set(cartRef, cartItem.toFirestore());
        }
      }

      await batch.commit();
      debugPrint('Successfully migrated cart to Firebase');
      
    } catch (e) {
      debugPrint('Error migrating cart to Firebase: $e');
    }
  }

  // Get cart items for checkout (returns current memory cart)
  static List<Map<String, dynamic>> getCurrentCartItemsForCheckout() {
    return _memoryCart.values.map((item) => {
      'productId': item.productId,
      'name': item.productName, // Changed from 'productName' to 'name'
      'price': item.price,
      'quantity': item.quantity,
      'imageUrl': item.imageUrl,
      'selectedVariantId': item.selectedVariantId,
      'selectedOptions': item.selectedOptions,
      'variantSku': item.variantSku,
      'variantDisplayName': item.variantDisplayName,
    }).toList();
  }

  // Get cart total for checkout
  static double getCurrentCartTotal() {
    return _memoryCart.values.fold<double>(
      0, 
      (sum, item) => sum + (item.price * item.quantity),
    );
  }

  // Get cart items async (for compatibility)
  static Future<List<Map<String, dynamic>>> getCurrentCartItemsForCheckoutAsync() async {
    return getCurrentCartItemsForCheckout();
  }

  // Get cart total async (for compatibility)
  static Future<double> getCurrentCartTotalAsync() async {
    return getCurrentCartTotal();
  }

  // Save cart to Firebase after successful payment (called after anonymous user creation)
  static Future<void> saveCartToFirebaseAfterPayment(String userId) async {
    if (_memoryCart.isEmpty) return;

    try {
      final batch = _firestore.batch();
      
      for (final entry in _memoryCart.entries) {
        final cartKey = entry.key;
        final cartItem = entry.value;
        final cartRef = _firestore
            .collection('carts')
            .doc(userId)
            .collection('items')
            .doc(cartKey);

        batch.set(cartRef, cartItem.toFirestore());
      }

      await batch.commit();
      debugPrint('Cart saved to Firebase after payment');
      
    } catch (e) {
      debugPrint('Error saving cart to Firebase after payment: $e');
    }
  }

  // Admin method to clean up invalid cart data
  static Future<void> cleanupInvalidCartData() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      final cartSnapshot = await _firestore
          .collection('carts')
          .doc(user.uid)
          .collection('items')
          .get();

      final batch = _firestore.batch();
      int deletedCount = 0;

      for (final doc in cartSnapshot.docs) {
        final data = doc.data();
        final quantity = data['quantity'] ?? 0;
        final productName = data['productName'] ?? '';

        // Delete items with invalid quantities or test data
        if (quantity > 10 || quantity <= 0 || 
            productName.toLowerCase().contains('test') ||
            productName.toLowerCase().contains('sample')) {
          batch.delete(doc.reference);
          deletedCount++;
        }
      }

      if (deletedCount > 0) {
        await batch.commit();
        debugPrint('Cleaned up $deletedCount invalid cart items');
        // Reload clean cart
        await _loadFirebaseCart();
      }
    } catch (e) {
      debugPrint('Error cleaning up cart data: $e');
    }
  }

  // Dispose resources
  static void dispose() {
    _cartController.close();
  }
}