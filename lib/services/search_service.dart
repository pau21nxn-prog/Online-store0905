import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';

class SearchService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Search products with filters - CLIENT-SIDE SORTING (No Firestore indexes needed)
  static Future<List<Product>> searchProducts({
    String? query,
    String? categoryId,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    bool? inStockOnly,
    String sortBy = 'relevance',
    int limit = 50,
  }) async {
    try {
      // Start with basic query - only filter by isActive to avoid index issues
      Query<Map<String, dynamic>> firestoreQuery = _firestore
          .collection('products')
          .where('isActive', isEqualTo: true);

      // Get all active products first
      final snapshot = await firestoreQuery.get();
      List<Product> products = snapshot.docs
          .map((doc) => Product.fromFirestore(doc.id, doc.data()))
          .toList();

      // Apply CLIENT-SIDE filters to avoid complex Firestore indexes
      
      // Apply text search filter
      if (query != null && query.trim().isNotEmpty) {
        final searchTerms = query.toLowerCase().split(' ');
        products = products.where((product) {
          final productText = '${product.name} ${product.description}'.toLowerCase();
          return searchTerms.any((term) => productText.contains(term));
        }).toList();
      }

      // Apply category filter
      if (categoryId != null && categoryId.isNotEmpty) {
        products = products.where((product) => product.categoryId == categoryId).toList();
      }

      // Apply price filters
      if (minPrice != null || maxPrice != null) {
        products = products.where((product) {
          final price = product.price;
          final min = minPrice ?? 0;
          final max = maxPrice ?? double.infinity;
          return price >= min && price <= max;
        }).toList();
      }

      // Apply stock filter
      if (inStockOnly == true) {
        products = products.where((product) => product.stockQty > 0).toList();
      }

      // Apply rating filter (skip for now - need to calculate from reviews)
      if (minRating != null) {
        // TODO: Calculate average rating from reviews collection
        // For now, skip rating filter
        print('Rating filter requested but not implemented yet');
      }

      // Apply CLIENT-SIDE sorting (no Firestore indexes needed)
      switch (sortBy) {
        case 'price_low':
        case 'price_low_high':
          products.sort((a, b) => a.price.compareTo(b.price));
          break;
        case 'price_high':
        case 'price_high_low':
          products.sort((a, b) => b.price.compareTo(a.price));
          break;
        case 'newest':
          products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case 'rating':
          // TODO: Sort by calculated average rating from reviews
          // For now, sort by creation date as fallback
          products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case 'popular':
          // Sort by stock quantity as a proxy for popularity
          products.sort((a, b) => b.stockQty.compareTo(a.stockQty));
          break;
        case 'relevance':
        default:
          // Keep original order for relevance, or sort by creation date
          products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
      }

      // Apply limit after sorting
      if (products.length > limit) {
        products = products.take(limit).toList();
      }

      return products;
    } catch (e) {
      print('Error searching products: $e');
      throw Exception('Error searching products: $e');
    }
  }

  // Get search suggestions
  static Future<List<String>> getSearchSuggestions(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final snapshot = await _firestore
          .collection('products')
          .where('isActive', isEqualTo: true)
          .limit(50) // Increased limit for better suggestions
          .get();

      Set<String> suggestions = {};
      final queryLower = query.toLowerCase();

      for (var doc in snapshot.docs) {
        final product = Product.fromFirestore(doc.id, doc.data());
        
        // Add exact product names that contain the query
        if (product.name.toLowerCase().contains(queryLower)) {
          suggestions.add(product.name);
        }

        // Add individual words that start with the query
        final words = '${product.name} ${product.description}'.toLowerCase().split(' ');
        for (var word in words) {
          if (word.startsWith(queryLower) && word.length > 2) {
            suggestions.add(word.toLowerCase());
          }
        }

        // Stop when we have enough suggestions
        if (suggestions.length >= 15) break;
      }

      return suggestions.take(10).toList();
    } catch (e) {
      print('Error getting search suggestions: $e');
      return [];
    }
  }

  // Save search history
  static Future<void> saveSearchQuery(String query) async {
    final user = _auth.currentUser;
    if (user == null || query.trim().isEmpty) return;

    try {
      // Check if query already exists in recent history
      final existingQuery = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('search_history')
          .where('query', isEqualTo: query.trim())
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        // Update timestamp of existing query
        await existingQuery.docs.first.reference.update({
          'timestamp': Timestamp.now(),
        });
      } else {
        // Add new query
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('search_history')
            .add({
          'query': query.trim(),
          'timestamp': Timestamp.now(),
        });
      }

      // Keep only last 20 searches
      final history = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('search_history')
          .orderBy('timestamp', descending: true)
          .limit(25)
          .get();

      if (history.docs.length > 20) {
        final batch = _firestore.batch();
        for (int i = 20; i < history.docs.length; i++) {
          batch.delete(history.docs[i].reference);
        }
        await batch.commit();
      }
    } catch (e) {
      print('Error saving search query: $e');
      // Silent fail for search history
    }
  }

  // Get search history
  static Future<List<String>> getSearchHistory() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('search_history')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['query'] as String)
          .where((query) => query.isNotEmpty)
          .toSet() // Remove duplicates
          .toList();
    } catch (e) {
      print('Error getting search history: $e');
      return [];
    }
  }

  // Get popular searches (global)
  static Future<List<String>> getPopularSearches() async {
    try {
      // For now, return curated popular terms
      // In a real app, you'd aggregate search data
      return [
        'iPhone',
        'Samsung',
        'Nike',
        'Laptop',
        'Headphones',
        'Coffee',
        'Wireless',
        'Gaming',
        'Fashion',
        'Electronics',
      ];
    } catch (e) {
      print('Error getting popular searches: $e');
      return [];
    }
  }

  // Get filter options
  static Future<Map<String, dynamic>> getFilterOptions() async {
    try {
      // Get products to calculate price range and brands
      final productsSnapshot = await _firestore
          .collection('products')
          .where('isActive', isEqualTo: true)
          .get();

      // Get categories
      final categoriesSnapshot = await _firestore
          .collection('categories')
          .get();

      // Calculate price range and extract brands
      double minPrice = double.infinity;
      double maxPrice = 0;
      Set<String> brands = {};

      for (var doc in productsSnapshot.docs) {
        final data = doc.data();
        final price = (data['price'] as num?)?.toDouble() ?? 0;
        
        if (price > 0) {
          if (price < minPrice) minPrice = price;
          if (price > maxPrice) maxPrice = price;
        }

        // Extract potential brand from product name (first word)
        final name = data['name'] as String? ?? '';
        final words = name.split(' ');
        if (words.isNotEmpty && words.first.length > 2) {
          brands.add(words.first);
        }
      }

      // Get categories with proper error handling
      final categories = <Map<String, dynamic>>[];
      for (var doc in categoriesSnapshot.docs) {
        try {
          final data = doc.data();
          categories.add({
            'id': doc.id,
            'name': data['name'] ?? 'Unknown Category',
          });
        } catch (e) {
          print('Error processing category ${doc.id}: $e');
        }
      }

      return {
        'priceRange': {
          'min': minPrice == double.infinity ? 0.0 : minPrice,
          'max': maxPrice == 0 ? 100000.0 : maxPrice,
        },
        'categories': categories,
        'brands': brands.take(15).toList(), // Top 15 brands
      };
    } catch (e) {
      print('Error getting filter options: $e');
      return {
        'priceRange': {'min': 0.0, 'max': 100000.0},
        'categories': <Map<String, dynamic>>[],
        'brands': <String>[],
      };
    }
  }

  // Clear search history
  static Future<void> clearSearchHistory() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('search_history')
          .get();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error clearing search history: $e');
      // Silent fail
    }
  }

  // Get total product count (for analytics)
  static Future<int> getTotalProductCount() async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('isActive', isEqualTo: true)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting total product count: $e');
      return 0;
    }
  }

  // Get products by category (for category-specific searches)
  static Future<List<Product>> getProductsByCategory(String categoryId, {int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('isActive', isEqualTo: true)
          .where('categoryId', isEqualTo: categoryId)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Product.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error getting products by category: $e');
      return [];
    }
  }
}