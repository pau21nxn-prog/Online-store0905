class SearchFilter {
  final String? query;
  final String? categoryId;
  final String? categoryName;
  final double? minPrice;
  final double? maxPrice;
  final bool inStockOnly;
  final String sortBy;
  final List<String> selectedBrands;

  const SearchFilter({
    this.query,
    this.categoryId,
    this.categoryName,
    this.minPrice,
    this.maxPrice,
    this.inStockOnly = false,
    this.sortBy = 'relevance',
    this.selectedBrands = const [],
  });

  // Copy with method for immutable updates
  // Using Object as sentinel value to distinguish between null and not provided
  static const Object _notProvided = Object();
  
  SearchFilter copyWith({
    Object? query = _notProvided,
    Object? categoryId = _notProvided,
    Object? categoryName = _notProvided,
    Object? minPrice = _notProvided,
    Object? maxPrice = _notProvided,
    Object? inStockOnly = _notProvided,
    Object? sortBy = _notProvided,
    Object? selectedBrands = _notProvided,
  }) {
    return SearchFilter(
      query: query == _notProvided ? this.query : query as String?,
      categoryId: categoryId == _notProvided ? this.categoryId : categoryId as String?,
      categoryName: categoryName == _notProvided ? this.categoryName : categoryName as String?,
      minPrice: minPrice == _notProvided ? this.minPrice : minPrice as double?,
      maxPrice: maxPrice == _notProvided ? this.maxPrice : maxPrice as double?,
      inStockOnly: inStockOnly == _notProvided ? this.inStockOnly : inStockOnly as bool,
      sortBy: sortBy == _notProvided ? this.sortBy : sortBy as String,
      selectedBrands: selectedBrands == _notProvided ? this.selectedBrands : selectedBrands as List<String>,
    );
  }

  // Clear all filters
  SearchFilter clearAll() {
    return const SearchFilter();
  }

  // Clear specific filters - using a cleaner approach
  SearchFilter clearCategory() {
    return SearchFilter(
      query: this.query,
      categoryId: null,
      categoryName: null,
      minPrice: this.minPrice,
      maxPrice: this.maxPrice,
      inStockOnly: this.inStockOnly,
      sortBy: this.sortBy,
      selectedBrands: this.selectedBrands,
    );
  }

  SearchFilter clearPrice() {
    return SearchFilter(
      query: this.query,
      categoryId: this.categoryId,
      categoryName: this.categoryName,
      minPrice: null,
      maxPrice: null,
      inStockOnly: this.inStockOnly,
      sortBy: this.sortBy,
      selectedBrands: this.selectedBrands,
    );
  }


  SearchFilter clearStock() {
    return copyWith(inStockOnly: false);
  }

  SearchFilter clearBrands() {
    return copyWith(selectedBrands: []);
  }

  // Check if any filters are active
  bool get hasActiveFilters {
    return categoryId != null ||
           minPrice != null ||
           maxPrice != null ||
           inStockOnly ||
           selectedBrands.isNotEmpty;
  }

  // Get active filter count
  int get activeFilterCount {
    int count = 0;
    if (categoryId != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (inStockOnly) count++;
    if (selectedBrands.isNotEmpty) count++;
    return count;
  }

  // Get filter summary text
  String get filterSummary {
    List<String> filters = [];
    
    if (categoryName != null) {
      filters.add(categoryName!);
    }
    
    if (minPrice != null || maxPrice != null) {
      if (minPrice != null && maxPrice != null) {
        filters.add('₱${minPrice!.toStringAsFixed(0)} - ₱${maxPrice!.toStringAsFixed(0)}');
      } else if (minPrice != null) {
        filters.add('Above ₱${minPrice!.toStringAsFixed(0)}');
      } else if (maxPrice != null) {
        filters.add('Below ₱${maxPrice!.toStringAsFixed(0)}');
      }
    }
    
    
    if (inStockOnly) {
      filters.add('In stock');
    }
    
    if (selectedBrands.isNotEmpty) {
      if (selectedBrands.length == 1) {
        filters.add(selectedBrands.first);
      } else {
        filters.add('${selectedBrands.length} brands');
      }
    }
    
    return filters.join(' • ');
  }

  // Get sort display name
  String get sortDisplayName {
    switch (sortBy) {
      case 'price_low':
        return 'Price: Low to High';
      case 'price_high':
        return 'Price: High to Low';
      case 'newest':
        return 'Newest First';
      case 'rating':
        return 'Best Rated';
      case 'popular':
        return 'Most Popular';
      default:
        return 'Relevance';
    }
  }

  // Convert to map for API calls
  Map<String, dynamic> toMap() {
    return {
      'query': query,
      'categoryId': categoryId,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'inStockOnly': inStockOnly,
      'sortBy': sortBy,
      'selectedBrands': selectedBrands,
    };
  }

  @override
  String toString() {
    return 'SearchFilter{query: $query, categoryId: $categoryId, minPrice: $minPrice, maxPrice: $maxPrice, inStockOnly: $inStockOnly, sortBy: $sortBy, selectedBrands: $selectedBrands}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is SearchFilter &&
      other.query == query &&
      other.categoryId == categoryId &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.inStockOnly == inStockOnly &&
      other.sortBy == sortBy &&
      _listEquals(other.selectedBrands, selectedBrands);
  }

  @override
  int get hashCode {
    return query.hashCode ^
      categoryId.hashCode ^
      minPrice.hashCode ^
      maxPrice.hashCode ^
      inStockOnly.hashCode ^
      sortBy.hashCode ^
      selectedBrands.hashCode;
  }

  // Helper method to compare lists
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    if (identical(a, b)) return true;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}