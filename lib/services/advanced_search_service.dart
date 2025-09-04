import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/product.dart';

enum SearchType { products, suggestions, autocomplete }
enum SortOption { relevance, priceAsc, priceDesc, rating, newest, popularity, name }
enum FilterType { category, price, rating, brand, availability, features }

class SearchQuery {
  final String query;
  final List<SearchFilter> filters;
  final SortOption sortBy;
  final int page;
  final int limit;
  final SearchType type;

  SearchQuery({
    required this.query,
    this.filters = const [],
    this.sortBy = SortOption.relevance,
    this.page = 0,
    this.limit = 20,
    this.type = SearchType.products,
  });

  Map<String, dynamic> toMap() {
    return {
      'query': query,
      'filters': filters.map((f) => f.toMap()).toList(),
      'sortBy': sortBy.name,
      'page': page,
      'limit': limit,
      'type': type.name,
    };
  }
}

class SearchFilter {
  final FilterType type;
  final String field;
  final dynamic value;
  final String? operator; // eq, gte, lte, in, contains

  SearchFilter({
    required this.type,
    required this.field,
    required this.value,
    this.operator = 'eq',
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'field': field,
      'value': value,
      'operator': operator,
    };
  }
}

class SearchResult {
  final List<Product> products;
  final int totalCount;
  final int page;
  final int totalPages;
  final double searchTime;
  final Map<String, List<FacetValue>> facets;
  final List<String> suggestions;
  final Map<String, dynamic> metadata;

  SearchResult({
    required this.products,
    required this.totalCount,
    required this.page,
    required this.totalPages,
    required this.searchTime,
    this.facets = const {},
    this.suggestions = const [],
    this.metadata = const {},
  });

  bool get hasMore => page < totalPages - 1;
  bool get isEmpty => products.isEmpty;
}

class FacetValue {
  final String value;
  final String label;
  final int count;
  final bool selected;

  FacetValue({
    required this.value,
    required this.label,
    required this.count,
    this.selected = false,
  });
}

class SearchSuggestion {
  final String text;
  final SearchType type;
  final int popularity;
  final Map<String, dynamic> metadata;

  SearchSuggestion({
    required this.text,
    required this.type,
    required this.popularity,
    this.metadata = const {},
  });
}

class SearchAnalytics {
  final String query;
  final int resultCount;
  final int clickPosition;
  final String? selectedProductId;
  final double searchTime;
  final DateTime timestamp;

  SearchAnalytics({
    required this.query,
    required this.resultCount,
    this.clickPosition = -1,
    this.selectedProductId,
    required this.searchTime,
    required this.timestamp,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'query': query,
      'resultCount': resultCount,
      'clickPosition': clickPosition,
      'selectedProductId': selectedProductId,
      'searchTime': searchTime,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class AdvancedSearchService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Search index collections
  static const String _searchIndex = 'searchIndex';
  static const String _searchAnalytics = 'searchAnalytics';
  static const String _searchSuggestions = 'searchSuggestions';
  static const String _popularQueries = 'popularQueries';

  // Search configuration
  static const int _maxSuggestions = 10;
  static const double _relevanceThreshold = 0.3;
  
  // Cache for frequently accessed data
  static final Map<String, List<String>> _categoryCache = {};
  static final Map<String, List<String>> _brandCache = {};
  static Timer? _cacheRefreshTimer;

  // Initialize search service
  static void initialize() {
    _buildSearchIndex();
    _refreshCache();
    
    // Set up periodic cache refresh
    _cacheRefreshTimer = Timer.periodic(
      const Duration(hours: 1), 
      (_) => _refreshCache(),
    );
  }

  // Main search function
  static Future<SearchResult> search(SearchQuery searchQuery) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Prepare query
      Query query = _firestore.collection('products');
      
      // Apply text search
      if (searchQuery.query.isNotEmpty) {
        query = _applyTextSearch(query, searchQuery.query);
      }
      
      // Apply filters
      for (final filter in searchQuery.filters) {
        query = _applyFilter(query, filter);
      }
      
      // Apply sorting
      query = _applySorting(query, searchQuery.sortBy);
      
      // Execute query with pagination
      final snapshot = await query
          .limit(searchQuery.limit)
          .offset(searchQuery.page * searchQuery.limit)
          .get();
      
      // Convert to products
      final products = snapshot.docs
          .map((doc) => Product.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
      
      // Apply relevance scoring if text search
      if (searchQuery.query.isNotEmpty) {
        _scoreResults(products, searchQuery.query);
        products.sort((a, b) => _getRelevanceScore(b, searchQuery.query)
            .compareTo(_getRelevanceScore(a, searchQuery.query)));
      }
      
      // Get total count (simplified - in production, use aggregation)
      final totalCount = math.min(snapshot.docs.length, 1000);
      final totalPages = (totalCount / searchQuery.limit).ceil();
      
      // Generate facets
      final facets = await _generateFacets(searchQuery);
      
      // Generate suggestions if no results
      final suggestions = products.isEmpty 
          ? await _generateSuggestions(searchQuery.query)
          : <String>[];
      
      stopwatch.stop();
      
      // Track analytics
      _trackSearchAnalytics(SearchAnalytics(
        query: searchQuery.query,
        resultCount: products.length,
        searchTime: stopwatch.elapsedMilliseconds / 1000.0,
        timestamp: DateTime.now(),
      ));
      
      return SearchResult(
        products: products,
        totalCount: totalCount,
        page: searchQuery.page,
        totalPages: totalPages,
        searchTime: stopwatch.elapsedMilliseconds / 1000.0,
        facets: facets,
        suggestions: suggestions,
        metadata: {
          'originalQuery': searchQuery.query,
          'appliedFilters': searchQuery.filters.length,
        },
      );
      
    } catch (e) {
      debugPrint('Search error: $e');
      stopwatch.stop();
      
      return SearchResult(
        products: [],
        totalCount: 0,
        page: 0,
        totalPages: 0,
        searchTime: stopwatch.elapsedMilliseconds / 1000.0,
      );
    }
  }

  // Apply text search using multiple strategies
  static Query _applyTextSearch(Query query, String searchText) {
    final searchTerms = _preprocessSearchQuery(searchText);
    
    // Strategy 1: Search in search tokens (primary)
    query = query.where('searchTokens', arrayContainsAny: searchTerms);
    
    return query;
  }

  // Preprocess search query
  static List<String> _preprocessSearchQuery(String query) {
    final tokens = <String>[];
    
    // Basic tokenization
    final words = query.toLowerCase()
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ')
        .split(' ')
        .where((word) => word.isNotEmpty && word.length > 2)
        .toList();
    
    tokens.addAll(words);
    
    // Add partial matches for autocomplete
    for (final word in words) {
      if (word.length > 3) {
        for (int i = 3; i <= word.length; i++) {
          tokens.add(word.substring(0, i));
        }
      }
    }
    
    // Add synonyms and variations
    tokens.addAll(_expandWithSynonyms(words));
    
    return tokens.toSet().toList();
  }

  // Expand query with synonyms
  static List<String> _expandWithSynonyms(List<String> words) {
    final synonyms = <String, List<String>>{
      'phone': ['mobile', 'smartphone', 'cell'],
      'laptop': ['computer', 'notebook', 'pc'],
      'shirt': ['top', 'blouse', 'tee'],
      'shoes': ['footwear', 'sneakers', 'boots'],
      'watch': ['timepiece', 'clock'],
    };
    
    final expanded = <String>[];
    for (final word in words) {
      if (synonyms.containsKey(word)) {
        expanded.addAll(synonyms[word]!);
      }
    }
    
    return expanded;
  }

  // Apply search filters
  static Query _applyFilter(Query query, SearchFilter filter) {
    switch (filter.type) {
      case FilterType.category:
        return query.where('primaryCategoryId', isEqualTo: filter.value);
        
      case FilterType.price:
        if (filter.operator == 'gte') {
          return query.where('priceRange.min', isGreaterThanOrEqualTo: filter.value);
        } else if (filter.operator == 'lte') {
          return query.where('priceRange.max', isLessThanOrEqualTo: filter.value);
        }
        break;
        
      case FilterType.rating:
        return query.where('ratingAvg', isGreaterThanOrEqualTo: filter.value);
        
      case FilterType.brand:
        return query.where('brandId', isEqualTo: filter.value);
        
      case FilterType.availability:
        if (filter.value == 'in_stock') {
          return query.where('totalStock', isGreaterThan: 0);
        } else if (filter.value == 'low_stock') {
          return query.where('computed.isLowStock', isEqualTo: true);
        }
        break;
        
      case FilterType.features:
        return query.where('attributes.${filter.field}', isEqualTo: filter.value);
    }
    
    return query;
  }

  // Apply sorting
  static Query _applySorting(Query query, SortOption sortBy) {
    switch (sortBy) {
      case SortOption.relevance:
        // Relevance sorting is handled after query execution
        return query.orderBy('updatedAt', descending: true);
        
      case SortOption.priceAsc:
        return query.orderBy('priceRange.min');
        
      case SortOption.priceDesc:
        return query.orderBy('priceRange.min', descending: true);
        
      case SortOption.rating:
        return query.orderBy('ratingAvg', descending: true);
        
      case SortOption.newest:
        return query.orderBy('createdAt', descending: true);
        
      case SortOption.popularity:
        return query.orderBy('soldCount', descending: true);
        
      case SortOption.name:
        return query.orderBy('title');
    }
  }

  // Score search results for relevance
  static void _scoreResults(List<Product> products, String searchQuery) {
    final queryTerms = _preprocessSearchQuery(searchQuery);
    
    for (final product in products) {
      final score = _calculateRelevanceScore(product, queryTerms);
      // Store score in product metadata or use a map
    }
  }

  // Calculate relevance score
  static double _calculateRelevanceScore(Product product, List<String> queryTerms) {
    double score = 0;
    
    // Title match (highest weight)
    final titleWords = product.title.toLowerCase().split(' ');
    for (final term in queryTerms) {
      if (titleWords.any((word) => word.contains(term))) {
        score += 3.0;
        if (titleWords.any((word) => word == term)) {
          score += 2.0; // Exact match bonus
        }
      }
    }
    
    // Description match
    final descWords = product.description.toLowerCase().split(' ');
    for (final term in queryTerms) {
      if (descWords.any((word) => word.contains(term))) {
        score += 1.0;
      }
    }
    
    // Search tokens match
    for (final term in queryTerms) {
      if (product.searchTokens.any((token) => token.contains(term))) {
        score += 1.5;
      }
    }
    
    // Popularity boost
    score += product.soldCount * 0.01;
    score += product.ratingAvg * 0.1;
    
    // Availability boost
    if (product.totalStock > 0) {
      score += 0.5;
    }
    
    return score;
  }

  // Get relevance score for product
  static double _getRelevanceScore(Product product, String searchQuery) {
    final queryTerms = _preprocessSearchQuery(searchQuery);
    return _calculateRelevanceScore(product, queryTerms);
  }

  // Generate search facets
  static Future<Map<String, List<FacetValue>>> _generateFacets(SearchQuery searchQuery) async {
    final facets = <String, List<FacetValue>>{};
    
    try {
      // Category facets
      if (!_hasFilter(searchQuery, FilterType.category)) {
        facets['categories'] = await _getCategoryFacets(searchQuery);
      }
      
      // Price range facets
      if (!_hasFilter(searchQuery, FilterType.price)) {
        facets['priceRanges'] = _getPriceRangeFacets();
      }
      
      // Rating facets
      if (!_hasFilter(searchQuery, FilterType.rating)) {
        facets['ratings'] = _getRatingFacets();
      }
      
      // Brand facets
      if (!_hasFilter(searchQuery, FilterType.brand)) {
        facets['brands'] = await _getBrandFacets(searchQuery);
      }
      
      // Availability facets
      facets['availability'] = _getAvailabilityFacets();
      
    } catch (e) {
      debugPrint('Error generating facets: $e');
    }
    
    return facets;
  }

  // Check if query has specific filter type
  static bool _hasFilter(SearchQuery query, FilterType type) {
    return query.filters.any((filter) => filter.type == type);
  }

  // Get category facets
  static Future<List<FacetValue>> _getCategoryFacets(SearchQuery searchQuery) async {
    final facets = <FacetValue>[];
    
    try {
      // Get categories from cache or fetch
      final categories = _categoryCache['all'] ?? await _fetchCategories();
      
      for (final categoryId in categories) {
        // In production, you'd count products per category
        facets.add(FacetValue(
          value: categoryId,
          label: categoryId.toUpperCase(),
          count: math.Random().nextInt(50) + 10, // Mock count
        ));
      }
    } catch (e) {
      debugPrint('Error getting category facets: $e');
    }
    
    return facets;
  }

  // Get price range facets
  static List<FacetValue> _getPriceRangeFacets() {
    return [
      FacetValue(value: '0-100', label: 'Under ₱100', count: 45),
      FacetValue(value: '100-500', label: '₱100 - ₱500', count: 120),
      FacetValue(value: '500-1000', label: '₱500 - ₱1,000', count: 85),
      FacetValue(value: '1000-5000', label: '₱1,000 - ₱5,000', count: 65),
      FacetValue(value: '5000+', label: 'Over ₱5,000', count: 25),
    ];
  }

  // Get rating facets
  static List<FacetValue> _getRatingFacets() {
    return [
      FacetValue(value: '4', label: '4 stars & up', count: 150),
      FacetValue(value: '3', label: '3 stars & up', count: 200),
      FacetValue(value: '2', label: '2 stars & up', count: 250),
      FacetValue(value: '1', label: '1 star & up', count: 280),
    ];
  }

  // Get brand facets
  static Future<List<FacetValue>> _getBrandFacets(SearchQuery searchQuery) async {
    return [
      FacetValue(value: 'apple', label: 'Apple', count: 45),
      FacetValue(value: 'samsung', label: 'Samsung', count: 38),
      FacetValue(value: 'nike', label: 'Nike', count: 62),
      FacetValue(value: 'adidas', label: 'Adidas', count: 41),
    ];
  }

  // Get availability facets
  static List<FacetValue> _getAvailabilityFacets() {
    return [
      FacetValue(value: 'in_stock', label: 'In Stock', count: 245),
      FacetValue(value: 'low_stock', label: 'Low Stock', count: 23),
      FacetValue(value: 'out_of_stock', label: 'Out of Stock', count: 12),
    ];
  }

  // Generate search suggestions
  static Future<List<String>> _generateSuggestions(String query) async {
    try {
      final suggestions = <String>[];
      
      // Get popular queries similar to current query
      final popularQueries = await _getPopularQueries(query);
      suggestions.addAll(popularQueries);
      
      // Add spell-corrected suggestions
      final corrected = _getSpellCorrections(query);
      suggestions.addAll(corrected);
      
      // Add related product suggestions
      final related = await _getRelatedProductSuggestions(query);
      suggestions.addAll(related);
      
      return suggestions.take(_maxSuggestions).toList();
    } catch (e) {
      debugPrint('Error generating suggestions: $e');
      return [];
    }
  }

  // Get popular queries
  static Future<List<String>> _getPopularQueries(String query) async {
    // This would query your analytics data
    return [
      'smartphone',
      'laptop',
      'shoes',
      'shirt',
      'watch',
    ].where((q) => q.contains(query.toLowerCase())).toList();
  }

  // Get spell corrections
  static List<String> _getSpellCorrections(String query) {
    final corrections = <String, String>{
      'iphone': 'iPhone',
      'smasung': 'Samsung',
      'adidas': 'Adidas',
      'nike': 'Nike',
    };
    
    final corrected = <String>[];
    for (final word in query.split(' ')) {
      if (corrections.containsKey(word.toLowerCase())) {
        corrected.add(corrections[word.toLowerCase()]!);
      }
    }
    
    return corrected;
  }

  // Get related product suggestions
  static Future<List<String>> _getRelatedProductSuggestions(String query) async {
    // This would use ML or collaborative filtering
    return [
      'Related suggestion 1',
      'Related suggestion 2',
    ];
  }

  // Autocomplete functionality
  static Future<List<SearchSuggestion>> getAutocomplete(String query) async {
    if (query.length < 2) return [];
    
    try {
      final suggestions = <SearchSuggestion>[];
      
      // Product name suggestions
      final productQuery = _firestore
          .collection('products')
          .where('searchTokens', arrayContains: query.toLowerCase())
          .limit(5);
      
      final productSnapshot = await productQuery.get();
      
      for (final doc in productSnapshot.docs) {
        final product = Product.fromFirestore(doc.id, doc.data());
        suggestions.add(SearchSuggestion(
          text: product.title,
          type: SearchType.products,
          popularity: product.soldCount,
          metadata: {'productId': product.id},
        ));
      }
      
      // Add popular search suggestions
      final popularSuggestions = await _getPopularSuggestions(query);
      suggestions.addAll(popularSuggestions);
      
      // Sort by popularity and relevance
      suggestions.sort((a, b) => b.popularity.compareTo(a.popularity));
      
      return suggestions.take(_maxSuggestions).toList();
    } catch (e) {
      debugPrint('Error getting autocomplete: $e');
      return [];
    }
  }

  // Get popular suggestions for autocomplete
  static Future<List<SearchSuggestion>> _getPopularSuggestions(String query) async {
    // This would query your search analytics
    return [
      SearchSuggestion(
        text: 'smartphone',
        type: SearchType.suggestions,
        popularity: 100,
      ),
      SearchSuggestion(
        text: 'smart watch',
        type: SearchType.suggestions,
        popularity: 80,
      ),
    ].where((s) => s.text.toLowerCase().contains(query.toLowerCase())).toList();
  }

  // Track search analytics
  static Future<void> _trackSearchAnalytics(SearchAnalytics analytics) async {
    try {
      await _firestore.collection(_searchAnalytics).add(analytics.toFirestore());
      
      // Update popular queries counter
      await _updatePopularQuery(analytics.query);
    } catch (e) {
      debugPrint('Error tracking search analytics: $e');
    }
  }

  // Update popular query counter
  static Future<void> _updatePopularQuery(String query) async {
    final docRef = _firestore.collection(_popularQueries).doc(query);
    
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      
      if (doc.exists) {
        final currentCount = doc.data()?['count'] ?? 0;
        transaction.update(docRef, {
          'count': currentCount + 1,
          'lastSearched': Timestamp.now(),
        });
      } else {
        transaction.set(docRef, {
          'query': query,
          'count': 1,
          'firstSearched': Timestamp.now(),
          'lastSearched': Timestamp.now(),
        });
      }
    });
  }

  // Track search result click
  static Future<void> trackSearchClick({
    required String query,
    required String productId,
    required int position,
  }) async {
    try {
      await _firestore.collection('searchClicks').add({
        'query': query,
        'productId': productId,
        'position': position,
        'timestamp': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error tracking search click: $e');
    }
  }

  // Build search index (for products without external search service)
  static Future<void> _buildSearchIndex() async {
    try {
      // This would typically be done via Cloud Functions
      debugPrint('Building search index...');
      
      // Update search tokens for all products
      final productsSnapshot = await _firestore.collection('products').get();
      final batch = _firestore.batch();
      
      for (final doc in productsSnapshot.docs) {
        final product = Product.fromFirestore(doc.id, doc.data());
        final searchTokens = _generateSearchTokens(product);
        
        batch.update(doc.reference, {'searchTokens': searchTokens});
      }
      
      await batch.commit();
      debugPrint('Search index built successfully');
    } catch (e) {
      debugPrint('Error building search index: $e');
    }
  }

  // Generate search tokens for a product
  static List<String> _generateSearchTokens(Product product) {
    final tokens = <String>{};
    
    // Add title words
    tokens.addAll(_tokenize(product.title));
    
    // Add description words
    tokens.addAll(_tokenize(product.description));
    
    // Add category path
    tokens.addAll(product.categoryPath);
    
    // Add brand if available
    if (product.brandId != null) {
      tokens.add(product.brandId!.toLowerCase());
    }
    
    // Add attribute values
    for (final value in product.attributes.values) {
      if (value is String) {
        tokens.addAll(_tokenize(value));
      }
    }
    
    return tokens.where((token) => token.length > 2).toList();
  }

  // Tokenize text for search
  static List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ')
        .split(' ')
        .where((word) => word.isNotEmpty && word.length > 2)
        .toList();
  }

  // Refresh cache
  static Future<void> _refreshCache() async {
    try {
      _categoryCache['all'] = await _fetchCategories();
      _brandCache['all'] = await _fetchBrands();
    } catch (e) {
      debugPrint('Error refreshing cache: $e');
    }
  }

  // Fetch categories
  static Future<List<String>> _fetchCategories() async {
    final snapshot = await _firestore.collection('categories').get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  // Fetch brands
  static Future<List<String>> _fetchBrands() async {
    // This would query distinct brands from products
    return ['apple', 'samsung', 'nike', 'adidas', 'sony'];
  }

  // Utility methods
  static void debugPrint(String message) {
    debugPrint('[AdvancedSearchService] $message');
  }

  // Dispose resources
  static void dispose() {
    _cacheRefreshTimer?.cancel();
  }
}