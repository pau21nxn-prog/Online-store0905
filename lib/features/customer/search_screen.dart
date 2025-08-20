import 'package:flutter/material.dart';
import 'dart:async';
import '../../common/theme.dart';
import '../../models/product.dart';
import '../../services/advanced_search_service.dart';
import '../../widgets/search_filters_widget.dart';
import '../../widgets/enhanced_search_bar.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  final Map<String, dynamic>? initialFilters;

  const SearchScreen({
    super.key,
    this.initialQuery,
    this.initialFilters,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // Search state
  final TextEditingController _searchController = TextEditingController();
  SearchQuery _currentSearchQuery = SearchQuery(query: '');
  SearchResult? _searchResult;
  Timer? _searchDebounce;
  
  // UI state
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _showFilters = false;
  final ScrollController _scrollController = ScrollController();
  
  // Layout state
  bool _isGridView = false;
  SortOption _currentSort = SortOption.relevance;

  @override
  void initState() {
    super.initState();
    
    // Initialize with any provided query or filters
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _currentSearchQuery = SearchQuery(query: widget.initialQuery!);
    }
    
    _setupScrollListener();
    _setupSearchListener();
    
    // Perform initial search if query is provided
    if (widget.initialQuery?.isNotEmpty == true) {
      _performSearch();
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreResults();
      }
    });
  }

  void _setupSearchListener() {
    _searchController.addListener(() {
      if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
        final newQuery = _searchController.text;
        if (newQuery != _currentSearchQuery.query) {
          _updateSearchQuery(SearchQuery(
            query: newQuery,
            filters: _currentSearchQuery.filters,
            sortBy: _currentSearchQuery.sortBy,
          ));
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          IconButton(
            onPressed: _toggleView,
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            tooltip: _isGridView ? 'List View' : 'Grid View',
          ),
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: _changeSortOption,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: SortOption.relevance,
                child: Text('Relevance'),
              ),
              const PopupMenuItem(
                value: SortOption.priceAsc,
                child: Text('Price: Low to High'),
              ),
              const PopupMenuItem(
                value: SortOption.priceDesc,
                child: Text('Price: High to Low'),
              ),
              const PopupMenuItem(
                value: SortOption.rating,
                child: Text('Rating'),
              ),
              const PopupMenuItem(
                value: SortOption.newest,
                child: Text('Newest'),
              ),
              const PopupMenuItem(
                value: SortOption.popularity,
                child: Text('Popularity'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Enhanced search bar
          EnhancedSearchBar(
            controller: _searchController,
            onSearchSubmitted: (query) {
              _updateSearchQuery(SearchQuery(
                query: query,
                filters: _currentSearchQuery.filters,
                sortBy: _currentSearchQuery.sortBy,
              ));
            },
            onSearchChanged: (query) {
              // Real-time search as user types (optional)
            },
            onFiltersPressed: _toggleFilters,
            hasActiveFilters: _currentSearchQuery.filters.isNotEmpty,
            showVoiceSearch: true,
            showCameraSearch: false,
            showBarcode: false,
          ),
          
          // Search summary
          if (_searchResult != null) _buildSearchSummary(),
          
          // Main content
          Expanded(
            child: Row(
              children: [
                // Filters sidebar (desktop) or bottom sheet (mobile)
                if (MediaQuery.of(context).size.width > 768 || _showFilters)
                  SizedBox(
                    width: MediaQuery.of(context).size.width > 768 ? 300 : double.infinity,
                    child: _buildFiltersSection(),
                  ),
                
                // Search results
                Expanded(
                  child: _buildSearchResults(),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: MediaQuery.of(context).size.width <= 768
          ? FloatingActionButton(
              onPressed: _toggleFilters,
              child: Icon(_showFilters ? Icons.close : Icons.filter_list),
              backgroundColor: AppTheme.primaryOrange,
            )
          : null,
    );
  }


  Widget _buildSearchSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${_searchResult!.totalCount} results',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          if (_currentSearchQuery.query.isNotEmpty) ...[
            const Text(' for '),
            Text(
              '"${_currentSearchQuery.query}"',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
          if (_searchResult!.searchTime > 0) ...[
            const Spacer(),
            Text(
              '${_searchResult!.searchTime.toStringAsFixed(2)}s',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    if (_searchResult?.facets.isEmpty ?? true) {
      return const SizedBox.shrink();
    }

    return SearchFiltersWidget(
      searchQuery: _currentSearchQuery,
      facets: _searchResult!.facets,
      onSearchQueryChanged: _updateSearchQuery,
      isCollapsed: false,
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading && (_searchResult?.products.isEmpty ?? true)) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResult == null) {
      return _buildEmptyState();
    }

    if (_searchResult!.isEmpty) {
      return _buildNoResultsState();
    }

    return Column(
      children: [
        // Suggestions (if any)
        if (_searchResult!.suggestions.isNotEmpty) _buildSuggestions(),
        
        // Results
        Expanded(
          child: _isGridView 
              ? _buildGridResults()
              : _buildListResults(),
        ),
      ],
    );
  }

  Widget _buildSuggestions() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      color: Colors.blue.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Did you mean:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Wrap(
            spacing: 8,
            children: _searchResult!.suggestions.map((suggestion) {
              return ActionChip(
                label: Text(suggestion),
                onPressed: () {
                  _searchController.text = suggestion;
                  _updateSearchQuery(SearchQuery(
                    query: suggestion,
                    filters: _currentSearchQuery.filters,
                    sortBy: _currentSearchQuery.sortBy,
                  ));
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGridResults() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppTheme.spacing16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 :
                     MediaQuery.of(context).size.width > 800 ? 3 : 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: AppTheme.spacing16,
        mainAxisSpacing: AppTheme.spacing16,
      ),
      itemCount: _searchResult!.products.length + (_searchResult!.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _searchResult!.products.length) {
          return _isLoadingMore 
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox.shrink();
        }
        
        final product = _searchResult!.products[index];
        return _buildProductGridCard(product);
      },
    );
  }

  Widget _buildListResults() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppTheme.spacing16),
      itemCount: _searchResult!.products.length + (_searchResult!.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _searchResult!.products.length) {
          return _isLoadingMore 
              ? const Padding(
                  padding: EdgeInsets.all(AppTheme.spacing16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : const SizedBox.shrink();
        }
        
        final product = _searchResult!.products[index];
        return _buildProductListCard(product);
      },
    );
  }

  Widget _buildProductGridCard(Product product) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToProduct(product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppTheme.radius8),
                  ),
                ),
                child: const Icon(Icons.shopping_bag, size: 48),
              ),
            ),
            
            // Product details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      product.formattedPriceRange,
                      style: const TextStyle(
                        color: AppTheme.primaryOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _buildRatingStars(product.ratingAvg),
                        const SizedBox(width: 4),
                        Text(
                          '(${product.ratingCount})',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductListCard(Product product) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: InkWell(
        onTap: () => _navigateToProduct(product),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            children: [
              // Product image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: const Icon(Icons.shopping_bag, size: 32),
              ),
              
              const SizedBox(width: AppTheme.spacing16),
              
              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      product.description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Row(
                      children: [
                        _buildRatingStars(product.ratingAvg),
                        const SizedBox(width: 8),
                        Text(
                          '(${product.ratingCount})',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          product.formattedPriceRange,
                          style: const TextStyle(
                            color: AppTheme.primaryOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.floor() 
              ? Icons.star 
              : index < rating 
                  ? Icons.star_half 
                  : Icons.star_border,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: AppTheme.spacing16),
          const Text(
            'Search for products',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            'Find exactly what you\'re looking for',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: AppTheme.spacing16),
          const Text(
            'No results found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: AppTheme.spacing24),
          ElevatedButton(
            onPressed: _clearSearchAndFilters,
            child: const Text('Clear Search'),
          ),
        ],
      ),
    );
  }

  // Event handlers
  void _updateSearchQuery(SearchQuery newQuery) {
    setState(() {
      _currentSearchQuery = newQuery;
    });
    _performSearch();
  }

  Future<void> _performSearch() async {
    if (_currentSearchQuery.query.isEmpty && _currentSearchQuery.filters.isEmpty) {
      setState(() {
        _searchResult = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AdvancedSearchService.search(_currentSearchQuery);
      setState(() {
        _searchResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    }
  }

  Future<void> _loadMoreResults() async {
    if (_isLoadingMore || !(_searchResult?.hasMore ?? false)) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextQuery = SearchQuery(
        query: _currentSearchQuery.query,
        filters: _currentSearchQuery.filters,
        sortBy: _currentSearchQuery.sortBy,
        page: _currentSearchQuery.page + 1,
        limit: _currentSearchQuery.limit,
        type: _currentSearchQuery.type,
      );

      final result = await AdvancedSearchService.search(nextQuery);
      
      setState(() {
        _searchResult = SearchResult(
          products: [..._searchResult!.products, ...result.products],
          totalCount: result.totalCount,
          page: result.page,
          totalPages: result.totalPages,
          searchTime: result.searchTime,
          facets: result.facets,
          suggestions: result.suggestions,
          metadata: result.metadata,
        );
        _currentSearchQuery = nextQuery;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _toggleView() {
    setState(() {
      _isGridView = !_isGridView;
    });
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  void _changeSortOption(SortOption sortBy) {
    setState(() {
      _currentSort = sortBy;
      _currentSearchQuery = SearchQuery(
        query: _currentSearchQuery.query,
        filters: _currentSearchQuery.filters,
        sortBy: sortBy,
        page: 0,
        limit: _currentSearchQuery.limit,
        type: _currentSearchQuery.type,
      );
    });
    _performSearch();
  }

  void _clearSearchAndFilters() {
    _searchController.clear();
    setState(() {
      _currentSearchQuery = SearchQuery(query: '');
      _searchResult = null;
    });
  }

  void _navigateToProduct(Product product) {
    // Track search click
    AdvancedSearchService.trackSearchClick(
      query: _currentSearchQuery.query,
      productId: product.id,
      position: _searchResult!.products.indexOf(product),
    );

    // Navigate to product details
    // Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(product: product)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navigate to ${product.title}')),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}