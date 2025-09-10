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
  Map<String, dynamic> _filterOptions = {};
  
  bool _isLoading = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeSearch();
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
          // Search instruction when no query
          if (_searchController.text.isEmpty && _searchResults.isEmpty)
            _buildSearchInstruction(),
          
          // Active filters summary
          if (_filter.hasActiveFilters)
            _buildActiveFilters(),
          
          // Sort options
          if (_searchResults.isNotEmpty)
            _buildSortOptions(),
          
          // Search results
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      autofocus: false,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search products...',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        border: InputBorder.none,
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.white),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchResults.clear();
                    _lastQuery = '';
                  });
                },
              )
            : null,
      ),
      onSubmitted: _onSearchSubmitted,
    );
  }

  Widget _buildSearchInstruction() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Search Products',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter keywords to find products',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
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
                        : Center(
                            child: Image.asset(
                              'images/Logo/72x72.png',
                              width: 40,
                              height: 40,
                              fit: BoxFit.contain,
                              color: Colors.grey,
                              colorBlendMode: BlendMode.srcIn,
                            ),
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
                                  color: Colors.green.withValues(alpha: 0.1),
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
                                  color: Colors.red.withValues(alpha: 0.1),
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
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
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


  void _onSearchSubmitted(String value) {
    if (value.trim().isNotEmpty) {
      setState(() {
        _filter = _filter.copyWith(query: value.trim());
      });
      _performSearch();
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
        inStockOnly: false,
        selectedBrands: [],
      );
    });
    _performSearch();
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
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tempFilter = widget.filter;
    
    // Initialize price text controllers with current filter values
    _minPriceController.text = _tempFilter.minPrice?.toStringAsFixed(0) ?? '';
    _maxPriceController.text = _tempFilter.maxPrice?.toStringAsFixed(0) ?? '';
    
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
                        _minPriceController.clear();
                        _maxPriceController.clear();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Price Range',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Min Price Input
            Expanded(
              child: TextFormField(
                controller: _minPriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Min Price',
                  prefixText: '₱',
                  border: OutlineInputBorder(),
                  hintText: '0',
                ),
                onChanged: (value) {
                  _updatePriceFilter();
                },
              ),
            ),
            const SizedBox(width: 16),
            // Max Price Input
            Expanded(
              child: TextFormField(
                controller: _maxPriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max Price',
                  prefixText: '₱',
                  border: OutlineInputBorder(),
                  hintText: 'No limit',
                ),
                onChanged: (value) {
                  _updatePriceFilter();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _updatePriceFilter() {
    setState(() {
      final minPriceText = _minPriceController.text.trim();
      final maxPriceText = _maxPriceController.text.trim();
      
      double? minPrice;
      double? maxPrice;
      
      // Parse min price
      if (minPriceText.isNotEmpty) {
        minPrice = double.tryParse(minPriceText);
        if (minPrice != null && minPrice < 0) {
          minPrice = 0; // Ensure non-negative
        }
      }
      
      // Parse max price
      if (maxPriceText.isNotEmpty) {
        maxPrice = double.tryParse(maxPriceText);
        if (maxPrice != null && maxPrice < 0) {
          maxPrice = null; // Invalid max price
        }
      }
      
      // Validate that max >= min
      if (minPrice != null && maxPrice != null && maxPrice < minPrice) {
        maxPrice = minPrice; // Adjust max to be at least min
      }
      
      _tempFilter = _tempFilter.copyWith(
        minPrice: minPrice,
        maxPrice: maxPrice,
      );
    });
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

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }
}