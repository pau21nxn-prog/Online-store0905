import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';

class SearchService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Generate search tokens from product data
  static List<String> generateSearchTokens(String name, String description, [String? brandId]) {
    final tokens = <String>{};
    
    // Add words from product name
    final nameWords = name.toLowerCase().split(RegExp(r'[\s\-_.,!?]+'));
    tokens.addAll(nameWords.where((word) => word.length >= 2));
    
    // Add words from description  
    final descWords = description.toLowerCase().split(RegExp(r'[\s\-_.,!?]+'));
    tokens.addAll(descWords.where((word) => word.length >= 2));
    
    // Add partial matches for longer words (for better search coverage)
    final longWords = [...nameWords, ...descWords].where((word) => word.length >= 4);
    for (final word in longWords) {
      for (int i = 2; i <= word.length; i++) {
        tokens.add(word.substring(0, i));
      }
    }
    
    // Add brand info if available
    if (brandId != null && brandId.isNotEmpty) {
      tokens.add(brandId.toLowerCase());
    }
    
    // Remove empty strings and short tokens
    return tokens.where((token) => token.length >= 2).toList();
  }

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
      // Start with basic query - only filter by published products (same as home screen)
      Query<Map<String, dynamic>> firestoreQuery = _firestore
          .collection('products')
          .where('workflow.stage', isEqualTo: 'published');

      // Get all published products first
      final snapshot = await firestoreQuery.get();
      List<Product> products = snapshot.docs
          .map((doc) => Product.fromFirestore(doc.id, doc.data()))
          .toList();

      // Apply CLIENT-SIDE filters to avoid complex Firestore indexes
      debugPrint('SearchService: Found ${products.length} published products before filtering');
      
      // Apply text search filter
      if (query != null && query.trim().isNotEmpty) {
        final searchQuery = query.trim().toLowerCase();
        final searchTerms = searchQuery.split(' ').where((term) => term.isNotEmpty).toList();
        debugPrint('SearchService: Searching for terms: $searchTerms');
        
        final initialCount = products.length;
        products = products.where((product) {
          // Use search tokens if available, otherwise fallback to text search
          if (product.searchTokens.isNotEmpty) {
            final matches = searchTerms.any((term) => 
              product.searchTokens.any((token) => token.toLowerCase().contains(term))
            );
            if (matches) {
              debugPrint('SearchService: Token match found - "${product.name}" has tokens containing "$searchQuery"');
            }
            return matches;
          } else {
            // Fallback to text search if no tokens
            final searchableText = [
              product.name,
              product.description,
              product.title,
            ].where((text) => text.isNotEmpty)
             .join(' ')
             .toLowerCase();
            
            final matches = searchTerms.any((term) => searchableText.contains(term));
            if (matches) {
              debugPrint('SearchService: Text match found - "${product.name}" contains "$searchQuery"');
            }
            return matches;
          }
        }).toList();
        
        debugPrint('SearchService: Text search filtered from $initialCount to ${products.length} products');
      }

      // Apply category filter
      if (categoryId != null && categoryId.isNotEmpty) {
        final beforeCount = products.length;
        products = products.where((product) => product.primaryCategoryId == categoryId).toList();
        debugPrint('SearchService: Category filter ($categoryId) filtered from $beforeCount to ${products.length} products');
      }

      // Apply price filters
      if (minPrice != null || maxPrice != null) {
        final beforeCount = products.length;
        products = products.where((product) {
          final price = product.price;
          final min = minPrice ?? 0;
          final max = maxPrice ?? double.infinity;
          return price >= min && price <= max;
        }).toList();
        debugPrint('SearchService: Price filter (₱$minPrice - ₱$maxPrice) filtered from $beforeCount to ${products.length} products');
      }

      // Apply stock filter
      if (inStockOnly == true) {
        final beforeCount = products.length;
        products = products.where((product) => product.stockQty > 0).toList();
        debugPrint('SearchService: Stock filter filtered from $beforeCount to ${products.length} products');
      }

      // Apply rating filter (skip for now - need to calculate from reviews)
      if (minRating != null) {
        // TODO: Calculate average rating from reviews collection
        // For now, skip rating filter
        debugPrint('Rating filter requested but not implemented yet');
      }

      // Apply CLIENT-SIDE sorting (no Firestore indexes needed)
      debugPrint('SearchService: Sorting ${products.length} products by $sortBy');
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
        debugPrint('SearchService: Limiting results from ${products.length} to $limit');
        products = products.take(limit).toList();
      }

      debugPrint('SearchService: Final search result: ${products.length} products');
      if (products.isNotEmpty) {
        debugPrint('SearchService: Sample results: ${products.take(3).map((p) => p.name).join(', ')}');
      }
      
      return products;
    } catch (e) {
      debugPrint('SearchService Error: $e');
      debugPrint('SearchService Error Stack: ${StackTrace.current}');
      rethrow; // Let the UI handle the error display
    }
  }

  // Get search suggestions
  static Future<List<String>> getSearchSuggestions(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final snapshot = await _firestore
          .collection('products')
          .where('workflow.stage', isEqualTo: 'published')
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
      debugPrint('Error getting search suggestions: $e');
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
      debugPrint('Error saving search query: $e');
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
      debugPrint('Error getting search history: $e');
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
      debugPrint('Error getting popular searches: $e');
      return [];
    }
  }

  // Get filter options
  static Future<Map<String, dynamic>> getFilterOptions() async {
    try {
      // Get products to calculate price range and brands
      final productsSnapshot = await _firestore
          .collection('products')
          .where('workflow.stage', isEqualTo: 'published')
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
          debugPrint('Error processing category ${doc.id}: $e');
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
      debugPrint('Error getting filter options: $e');
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
      debugPrint('Error clearing search history: $e');
      // Silent fail
    }
  }

  // Get total product count (for analytics)
  static Future<int> getTotalProductCount() async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('workflow.stage', isEqualTo: 'published')
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting total product count: $e');
      return 0;
    }
  }

  // Get products by category (for category-specific searches)
  static Future<List<Product>> getProductsByCategory(String categoryId, {int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('workflow.stage', isEqualTo: 'published')
          .where('primaryCategoryId', isEqualTo: categoryId)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Product.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting products by category: $e');
      return [];
    }
  }
}