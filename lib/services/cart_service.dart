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
    // Listen to auth changes for cart migration
    _auth.authStateChanges().listen((user) {
      if (user != null && !user.isAnonymous && _memoryCart.isNotEmpty) {
        // User signed in with a real account - migrate memory cart to Firebase
        _migrateMemoryCartToFirebase();
      } else if (user != null && !user.isAnonymous) {
        // Load existing Firebase cart for authenticated users
        _loadFirebaseCart();
      }
    });

    // Initialize cart stream with current memory data
    _cartController.add(_memoryCart.values.toList());
  }

  // Add item to cart (always uses memory until payment)
  static Future<void> addToCart(dynamic product, {int quantity = 1}) async {
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

    _addToMemoryCart(productId, productName, price, imageUrl, quantity);
  }

  // Add item to cart with named parameters
  static Future<void> addToCartWithParams({
    required String productId,
    required String productName,
    required double price,
    required String imageUrl,
    int quantity = 1,
  }) async {
    _addToMemoryCart(productId, productName, price, imageUrl, quantity);
  }

  // Private method to add to memory cart
  static void _addToMemoryCart(
    String productId,
    String productName,
    double price,
    String imageUrl,
    int quantity,
  ) {
    if (_memoryCart.containsKey(productId)) {
      // Update existing item
      final existingItem = _memoryCart[productId]!;
      _memoryCart[productId] = CartItem(
        productId: productId,
        productName: productName,
        price: price,
        quantity: existingItem.quantity + quantity,
        imageUrl: imageUrl,
        addedAt: existingItem.addedAt,
      );
    } else {
      // Add new item
      _memoryCart[productId] = CartItem(
        productId: productId,
        productName: productName,
        price: price,
        quantity: quantity,
        imageUrl: imageUrl,
        addedAt: DateTime.now(),
      );
    }

    // Notify listeners
    _cartController.add(_memoryCart.values.toList());
  }

  // Get cart items stream (always returns memory cart)
  static Stream<List<CartItem>> getCartItems() {
    return _cartController.stream;
  }

  // Update item quantity
  static Future<void> updateQuantity(String productId, int newQuantity) async {
    if (newQuantity <= 0) {
      await removeFromCart(productId);
      return;
    }

    if (_memoryCart.containsKey(productId)) {
      final item = _memoryCart[productId]!;
      _memoryCart[productId] = CartItem(
        productId: item.productId,
        productName: item.productName,
        price: item.price,
        quantity: newQuantity,
        imageUrl: item.imageUrl,
        addedAt: item.addedAt,
      );
      _cartController.add(_memoryCart.values.toList());
    }
  }

  // Remove item from cart
  static Future<void> removeFromCart(String productId) async {
    _memoryCart.remove(productId);
    _cartController.add(_memoryCart.values.toList());
  }

  // Clear entire cart
  static Future<void> clearCart() async {
    _memoryCart.clear();
    _cartController.add([]);
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
  static Future<bool> isInCart(String productId) async {
    return _memoryCart.containsKey(productId);
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

      // Load Firebase cart into memory
      for (final doc in cartSnapshot.docs) {
        final item = CartItem.fromFirestore(doc.id, doc.data());
        _memoryCart[item.productId] = item;
      }

      _cartController.add(_memoryCart.values.toList());
    } catch (e) {
      print('Error loading Firebase cart: $e');
    }
  }

  // Migrate memory cart to Firebase when user signs in with real account
  static Future<void> _migrateMemoryCartToFirebase() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous || _memoryCart.isEmpty) return;

    try {
      final batch = _firestore.batch();
      
      for (final cartItem in _memoryCart.values) {
        final cartRef = _firestore
            .collection('carts')
            .doc(user.uid)
            .collection('items')
            .doc(cartItem.productId);

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
      print('Successfully migrated cart to Firebase');
      
    } catch (e) {
      print('Error migrating cart to Firebase: $e');
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
      
      for (final cartItem in _memoryCart.values) {
        final cartRef = _firestore
            .collection('carts')
            .doc(userId)
            .collection('items')
            .doc(cartItem.productId);

        batch.set(cartRef, cartItem.toFirestore());
      }

      await batch.commit();
      print('Cart saved to Firebase after payment');
      
    } catch (e) {
      print('Error saving cart to Firebase after payment: $e');
    }
  }

  // Dispose resources
  static void dispose() {
    _cartController.close();
  }
}