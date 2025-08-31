import 'package:flutter/material.dart';
import '../../common/theme.dart';
import '../../common/mobile_layout_utils.dart';
import '../../models/product.dart';
import '../../models/search_filter.dart';
import '../../services/search_service.dart';
import '../../services/auth_service.dart';
// Wishlist import removed
import '../product/product_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  final String? categoryId;
  final String? categoryName;

  const SearchScreen({
    super.key,
    this.initialQuery,
    this.categoryId,
    this.categoryName,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  SearchFilter _filter = const SearchFilter();
  List<Product> _searchResults = [];
  List<String> _searchSuggestions = [];
  List<String> _searchHistory = [];
  Map<String, dynamic> _filterOptions = {};
  
  bool _isLoading = false;
  bool _isLoadingSuggestions = false;
  bool _showSuggestions = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeSearch();
    _loadSearchHistory();
    _loadFilterOptions();
  }

  void _initializeSearch() {
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _filter = _filter.copyWith(query: widget.initialQuery);
    }
    
    if (widget.categoryId != null) {
      _filter = _filter.copyWith(
        categoryId: widget.categoryId,
        categoryName: widget.categoryName,
      );
    }
    
    if (_filter.query != null || _filter.categoryId != null) {
      _performSearch();
    }
  }

  Future<void> _loadSearchHistory() async {
    final history = await SearchService.getSearchHistory();
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _loadFilterOptions() async {
    final options = await SearchService.getFilterOptions();
    setState(() {
      _filterOptions = options;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shouldUseWrapper = MobileLayoutUtils.shouldUseViewportWrapper(context);
    
    if (shouldUseWrapper) {
      return Center(
        child: Container(
          width: MobileLayoutUtils.getEffectiveViewportWidth(context),
          decoration: MobileLayoutUtils.getMobileViewportDecoration(),
          child: _buildScaffoldContent(context),
        ),
      );
    }
    
    return _buildScaffoldContent(context);
  }

  Widget _buildScaffoldContent(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        title: _buildSearchBar(),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
        actions: [
          if (_filter.hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearAllFilters,
              tooltip: 'Clear all filters',
            ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.tune),
                if (_filter.hasActiveFilters)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${_filter.activeFilterCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showFilterBottomSheet,
            tooltip: 'Filters',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search suggestions or history
          if (_showSuggestions && _searchController.text.isNotEmpty)
            _buildSuggestions()
          else if (_showSuggestions && _searchController.text.isEmpty)
            _buildSearchHistory(),
          
          // Active filters summary
          if (_filter.hasActiveFilters && !_showSuggestions)
            _buildActiveFilters(),
          
          // Sort options
          if (!_showSuggestions && _searchResults.isNotEmpty)
            _buildSortOptions(),
          
          // Search results
          Expanded(
            child: _showSuggestions
                ? Container()
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      autofocus: widget.initialQuery == null,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search products...',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        border: InputBorder.none,
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.white),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _showSuggestions = true;
                    _searchSuggestions.clear();
                  });
                },
              )
            : null,
      ),
      onChanged: _onSearchChanged,
      onSubmitted: _onSearchSubmitted,
      onTap: () {
        setState(() {
          _showSuggestions = true;
        });
      },
    );
  }

  Widget _buildSuggestions() {
    if (_isLoadingSuggestions) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _searchSuggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _searchSuggestions[index];
          return ListTile(
            leading: const Icon(Icons.search, color: Colors.grey),
            title: Text(suggestion),
            onTap: () => _selectSuggestion(suggestion),
          );
        },
      ),
    );
  }

  Widget _buildSearchHistory() {
    if (_searchHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.search, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Start typing to search products',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Searches',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                TextButton(
                  onPressed: _clearSearchHistory,
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _searchHistory.length,
              itemBuilder: (context, index) {
                final query = _searchHistory[index];
                return ListTile(
                  leading: const Icon(Icons.history, color: Colors.grey),
                  title: Text(query),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => _removeFromHistory(query),
                  ),
                  onTap: () => _selectSuggestion(query),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Active Filters (${_filter.activeFilterCount})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearAllFilters,
                child: const Text('Clear All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _buildFilterChips(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFilterChips() {
    List<Widget> chips = [];

    if (_filter.categoryName != null) {
      chips.add(
        FilterChip(
          label: Text(_filter.categoryName!),
          selected: true,
          onSelected: (bool value) {},
          onDeleted: () {
            setState(() {
              _filter = _filter.clearCategory();
            });
            _performSearch();
          },
          deleteIcon: const Icon(Icons.close, size: 16),
        ),
      );
    }

    if (_filter.minPrice != null || _filter.maxPrice != null) {
      String priceText = '';
      if (_filter.minPrice != null && _filter.maxPrice != null) {
        priceText = '₱${_filter.minPrice!.toStringAsFixed(0)} - ₱${_filter.maxPrice!.toStringAsFixed(0)}';
      } else if (_filter.minPrice != null) {
        priceText = 'Above ₱${_filter.minPrice!.toStringAsFixed(0)}';
      } else {
        priceText = 'Below ₱${_filter.maxPrice!.toStringAsFixed(0)}';
      }
      
      chips.add(
        FilterChip(
          label: Text(priceText),
          selected: true,
          onSelected: (bool value) {},
          onDeleted: () {
            setState(() {
              _filter = _filter.clearPrice();
            });
            _performSearch();
          },
          deleteIcon: const Icon(Icons.close, size: 16),
        ),
      );
    }

    if (_filter.minRating != null) {
      chips.add(
        FilterChip(
          label: Text('${_filter.minRating!.toStringAsFixed(1)}+ stars'),
          selected: true,
          onSelected: (bool value) {},
          onDeleted: () {
            setState(() {
              _filter = _filter.clearRating();
            });
            _performSearch();
          },
          deleteIcon: const Icon(Icons.close, size: 16),
        ),
      );
    }

    if (_filter.inStockOnly) {
      chips.add(
        FilterChip(
          label: const Text('In Stock'),
          selected: true,
          onSelected: (bool value) {},
          onDeleted: () {
            setState(() {
              _filter = _filter.clearStock();
            });
            _performSearch();
          },
          deleteIcon: const Icon(Icons.close, size: 16),
        ),
      );
    }

    return chips;
  }

  Widget _buildSortOptions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Found ${_searchResults.length} products',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          DropdownButton<String>(
            value: _filter.sortBy,
            underline: Container(),
            items: const [
              DropdownMenuItem(value: 'relevance', child: Text('Relevance')),
              DropdownMenuItem(value: 'price_low', child: Text('Price: Low to High')),
              DropdownMenuItem(value: 'price_high', child: Text('Price: High to Low')),
              DropdownMenuItem(value: 'newest', child: Text('Newest First')),
              DropdownMenuItem(value: 'rating', child: Text('Best Rated')),
              DropdownMenuItem(value: 'popular', child: Text('Most Popular')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _filter = _filter.copyWith(sortBy: value);
                });
                _performSearch();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty && _lastQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No products found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Search for products',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a keyword to find what you\'re looking for',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Get current user to determine layout
    final currentUser = AuthService.currentUser;
    final isAdmin = currentUser?.canAccessAdmin ?? false;
    
    return GridView.builder(
      controller: _scrollController,
      padding: MobileLayoutUtils.getMobilePadding(),
      gridDelegate: MobileLayoutUtils.getProductGridDelegate(
        isAdmin: isAdmin,
        context: context,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final product = _searchResults[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(Product product) {
    return Stack(
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(product: product),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    color: Colors.grey[100],
                    child: product.imageUrls.isNotEmpty
                        ? Image.network(
                            product.imageUrls.first,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.image_not_supported, color: Colors.grey),
                              );
                            },
                          )
                        : const Center(
                            child: Icon(Icons.shopping_bag, size: 40, color: Colors.grey),
                          ),
                  ),
                ),
                
                // Product Info
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.formattedPrice,
                          style: TextStyle(
                            color: AppTheme.primaryOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            if (product.stockQty > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'In Stock',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Out of Stock',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Wishlist Button
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SizedBox.shrink(), // Wishlist button removed
          ),
        ),
      ],
    );
  }


  void _onSearchChanged(String value) {
    setState(() {
      _showSuggestions = true;
    });

    if (value.trim().isNotEmpty && value != _lastQuery) {
      _getSuggestions(value);
    } else {
      setState(() {
        _searchSuggestions.clear();
      });
    }
  }

  void _onSearchSubmitted(String value) {
    if (value.trim().isNotEmpty) {
      _selectSuggestion(value);
    }
  }

  void _selectSuggestion(String suggestion) {
    _searchController.text = suggestion;
    setState(() {
      _showSuggestions = false;
      _filter = _filter.copyWith(query: suggestion);
    });
    SearchService.saveSearchQuery(suggestion);
    _performSearch();
  }

  Future<void> _getSuggestions(String query) async {
    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      final suggestions = await SearchService.getSearchSuggestions(query);
      setState(() {
        _searchSuggestions = suggestions;
        _isLoadingSuggestions = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSuggestions = false;
      });
    }
  }

  Future<void> _performSearch() async {
    setState(() {
      _isLoading = true;
      _lastQuery = _filter.query ?? '';
    });

    try {
      final results = await SearchService.searchProducts(
        query: _filter.query,
        categoryId: _filter.categoryId,
        minPrice: _filter.minPrice,
        maxPrice: _filter.maxPrice,
        minRating: _filter.minRating,
        inStockOnly: _filter.inStockOnly,
        sortBy: _filter.sortBy,
      );

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching: $e')),
      );
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FilterBottomSheet(
        filter: _filter,
        filterOptions: _filterOptions,
        onFilterChanged: (newFilter) {
          setState(() {
            _filter = newFilter;
          });
          _performSearch();
        },
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _filter = _filter.copyWith(
        categoryId: null,
        categoryName: null,
        minPrice: null,
        maxPrice: null,
        minRating: null,
        inStockOnly: false,
        selectedBrands: [],
      );
    });
    _performSearch();
  }

  Future<void> _clearSearchHistory() async {
    await SearchService.clearSearchHistory();
    setState(() {
      _searchHistory.clear();
    });
  }

  void _removeFromHistory(String query) {
    setState(() {
      _searchHistory.remove(query);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// Filter Bottom Sheet Widget
class FilterBottomSheet extends StatefulWidget {
  final SearchFilter filter;
  final Map<String, dynamic> filterOptions;
  final Function(SearchFilter) onFilterChanged;

  const FilterBottomSheet({
    super.key,
    required this.filter,
    required this.filterOptions,
    required this.onFilterChanged,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late SearchFilter _tempFilter;
  late RangeValues _priceRange;
  late double _minRating;

  @override
  void initState() {
    super.initState();
    _tempFilter = widget.filter;
    
    final priceOptions = widget.filterOptions['priceRange'] ?? {'min': 0, 'max': 100000};
    final minPrice = _tempFilter.minPrice ?? priceOptions['min'].toDouble();
    final maxPrice = _tempFilter.maxPrice ?? priceOptions['max'].toDouble();
    _priceRange = RangeValues(minPrice, maxPrice);
    
    _minRating = _tempFilter.minRating ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _tempFilter = const SearchFilter();
                        _priceRange = RangeValues(
                          widget.filterOptions['priceRange']['min'].toDouble(),
                          widget.filterOptions['priceRange']['max'].toDouble(),
                        );
                        _minRating = 0.0;
                      });
                    },
                    child: const Text('Clear All'),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Filters Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildCategoryFilter(),
                    const SizedBox(height: 24),
                    _buildPriceFilter(),
                    const SizedBox(height: 24),
                    _buildRatingFilter(),
                    const SizedBox(height: 24),
                    _buildStockFilter(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              
              // Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onFilterChanged(_tempFilter);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilter() {
    final categories = widget.filterOptions['categories'] as List? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('All Categories'),
              selected: _tempFilter.categoryId == null,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _tempFilter = _tempFilter.clearCategory();
                  });
                }
              },
            ),
            ...categories.map((category) {
              final isSelected = _tempFilter.categoryId == category['id'];
              return FilterChip(
                label: Text(category['name']),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _tempFilter = _tempFilter.copyWith(
                        categoryId: category['id'],
                        categoryName: category['name'],
                      );
                    } else {
                      _tempFilter = _tempFilter.clearCategory();
                    }
                  });
                },
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceFilter() {
    final priceOptions = widget.filterOptions['priceRange'] ?? {'min': 0, 'max': 100000};
    final minPrice = priceOptions['min'].toDouble();
    final maxPrice = priceOptions['max'].toDouble();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Price Range',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        RangeSlider(
          values: _priceRange,
          min: minPrice,
          max: maxPrice,
          divisions: 20,
          labels: RangeLabels(
            '₱${_priceRange.start.toStringAsFixed(0)}',
            '₱${_priceRange.end.toStringAsFixed(0)}',
          ),
          onChanged: (values) {
            setState(() {
              _priceRange = values;
              _tempFilter = _tempFilter.copyWith(
                minPrice: values.start == minPrice ? null : values.start,
                maxPrice: values.end == maxPrice ? null : values.end,
              );
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('₱${_priceRange.start.toStringAsFixed(0)}'),
            Text('₱${_priceRange.end.toStringAsFixed(0)}'),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Minimum Rating',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('Any Rating'),
              selected: _minRating == 0.0,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _minRating = 0.0;
                    _tempFilter = _tempFilter.clearRating();
                  });
                }
              },
            ),
            ...List.generate(4, (index) {
              final rating = (index + 2).toDouble();
              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${rating.toStringAsFixed(0)}+'),
                    const SizedBox(width: 4),
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                  ],
                ),
                selected: _minRating == rating,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _minRating = rating;
                      _tempFilter = _tempFilter.copyWith(minRating: rating);
                    } else {
                      _minRating = 0.0;
                      _tempFilter = _tempFilter.clearRating();
                    }
                  });
                },
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildStockFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Availability',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('In Stock Only'),
          subtitle: const Text('Show only available products'),
          value: _tempFilter.inStockOnly,
          onChanged: (value) {
            setState(() {
              _tempFilter = _tempFilter.copyWith(inStockOnly: value);
            });
          },
        ),
      ],
    );
  }
}