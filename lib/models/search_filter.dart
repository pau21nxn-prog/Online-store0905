class SearchFilter {
  final String? query;
  final String? categoryId;
  final String? categoryName;
  final double? minPrice;
  final double? maxPrice;
  final double? minRating;
  final bool inStockOnly;
  final String sortBy;
  final List<String> selectedBrands;

  const SearchFilter({
    this.query,
    this.categoryId,
    this.categoryName,
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.inStockOnly = false,
    this.sortBy = 'relevance',
    this.selectedBrands = const [],
  });

  // Copy with method for immutable updates
  SearchFilter copyWith({
    String? query,
    String? categoryId,
    String? categoryName,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    bool? inStockOnly,
    String? sortBy,
    List<String>? selectedBrands,
  }) {
    return SearchFilter(
      query: query ?? this.query,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minRating: minRating ?? this.minRating,
      inStockOnly: inStockOnly ?? this.inStockOnly,
      sortBy: sortBy ?? this.sortBy,
      selectedBrands: selectedBrands ?? this.selectedBrands,
    );
  }

  // Clear all filters
  SearchFilter clearAll() {
    return const SearchFilter();
  }

  // Clear specific filter
  SearchFilter clearCategory() {
    return copyWith(categoryId: null, categoryName: null);
  }

  SearchFilter clearPrice() {
    return copyWith(minPrice: null, maxPrice: null);
  }

  SearchFilter clearRating() {
    return copyWith(minRating: null);
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
           minRating != null ||
           inStockOnly ||
           selectedBrands.isNotEmpty;
  }

  // Get active filter count
  int get activeFilterCount {
    int count = 0;
    if (categoryId != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (minRating != null) count++;
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
    
    if (minRating != null) {
      filters.add('${minRating!.toStringAsFixed(1)}+ stars');
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
      'minRating': minRating,
      'inStockOnly': inStockOnly,
      'sortBy': sortBy,
      'selectedBrands': selectedBrands,
    };
  }

  @override
  String toString() {
    return 'SearchFilter{query: $query, categoryId: $categoryId, minPrice: $minPrice, maxPrice: $maxPrice, minRating: $minRating, inStockOnly: $inStockOnly, sortBy: $sortBy, selectedBrands: $selectedBrands}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is SearchFilter &&
      other.query == query &&
      other.categoryId == categoryId &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.minRating == minRating &&
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
      minRating.hashCode ^
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