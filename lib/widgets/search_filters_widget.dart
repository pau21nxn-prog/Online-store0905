import 'package:flutter/material.dart';
import '../services/advanced_search_service.dart';
import '../common/theme.dart';

class SearchFiltersWidget extends StatefulWidget {
  final SearchQuery searchQuery;
  final Map<String, List<FacetValue>> facets;
  final Function(SearchQuery) onSearchQueryChanged;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  const SearchFiltersWidget({
    super.key,
    required this.searchQuery,
    required this.facets,
    required this.onSearchQueryChanged,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  @override
  State<SearchFiltersWidget> createState() => _SearchFiltersWidgetState();
}

class _SearchFiltersWidgetState extends State<SearchFiltersWidget> {
  late SearchQuery _currentQuery;
  final Map<String, bool> _expandedSections = {};

  @override
  void initState() {
    super.initState();
    _currentQuery = widget.searchQuery;
    
    // Initialize expanded states
    for (final key in widget.facets.keys) {
      _expandedSections[key] = true;
    }
  }

  @override
  void didUpdateWidget(SearchFiltersWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _currentQuery = widget.searchQuery;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCollapsed) {
      return _buildCollapsedView();
    }

    return Card(
      margin: const EdgeInsets.all(AppTheme.spacing8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (_hasActiveFilters()) _buildActiveFilters(),
          _buildFilterSections(),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildCollapsedView() {
    final activeFiltersCount = _currentQuery.filters.length;
    
    return Card(
      margin: const EdgeInsets.all(AppTheme.spacing8),
      child: InkWell(
        onTap: widget.onToggleCollapse,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            children: [
              const Icon(Icons.filter_list, size: 20),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                'Filters${activeFiltersCount > 0 ? ' ($activeFiltersCount active)' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              const Icon(Icons.expand_more),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Row(
        children: [
          const Icon(Icons.filter_list),
          const SizedBox(width: AppTheme.spacing8),
          const Text(
            'Search Filters',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (widget.onToggleCollapse != null)
            IconButton(
              onPressed: widget.onToggleCollapse,
              icon: const Icon(Icons.keyboard_arrow_up),
              tooltip: 'Collapse filters',
            ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active Filters:',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _currentQuery.filters.map((filter) {
              return Chip(
                label: Text(_getFilterDisplayText(filter)),
                onDeleted: () => _removeFilter(filter),
                deleteIcon: const Icon(Icons.close, size: 16),
                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                labelStyle: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 12,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
          const SizedBox(height: AppTheme.spacing16),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildFilterSections() {
    return Column(
      children: widget.facets.entries.map((entry) {
        final sectionKey = entry.key;
        final facetValues = entry.value;
        
        if (facetValues.isEmpty) return const SizedBox.shrink();
        
        return _buildFilterSection(sectionKey, facetValues);
      }).toList(),
    );
  }

  Widget _buildFilterSection(String sectionKey, List<FacetValue> facetValues) {
    final isExpanded = _expandedSections[sectionKey] ?? true;
    final sectionTitle = _getSectionTitle(sectionKey);
    final filterType = _getFilterTypeForSection(sectionKey);
    
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _expandedSections[sectionKey] = !isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing12,
            ),
            child: Row(
              children: [
                Text(
                  sectionTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          if (sectionKey == 'priceRanges')
            _buildPriceRangeFilter(facetValues)
          else if (sectionKey == 'ratings')
            _buildRatingFilter(facetValues)
          else
            _buildCheckboxFilter(filterType, facetValues),
          const SizedBox(height: AppTheme.spacing8),
        ],
      ],
    );
  }

  Widget _buildCheckboxFilter(FilterType filterType, List<FacetValue> facetValues) {
    return Column(
      children: facetValues.map((facetValue) {
        final isSelected = _isFilterSelected(filterType, facetValue.value);
        
        return CheckboxListTile(
          dense: true,
          value: isSelected,
          onChanged: (selected) {
            if (selected == true) {
              _addFilter(filterType, facetValue.value);
            } else {
              _removeFilterByTypeAndValue(filterType, facetValue.value);
            }
          },
          title: Row(
            children: [
              Expanded(
                child: Text(
                  facetValue.label,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${facetValue.count}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        );
      }).toList(),
    );
  }

  Widget _buildPriceRangeFilter(List<FacetValue> facetValues) {
    return Column(
      children: facetValues.map((facetValue) {
        final isSelected = _isPriceRangeSelected(facetValue.value);
        
        return CheckboxListTile(
          dense: true,
          value: isSelected,
          onChanged: (selected) {
            if (selected == true) {
              _addPriceRangeFilter(facetValue.value);
            } else {
              _removePriceRangeFilter(facetValue.value);
            }
          },
          title: Row(
            children: [
              Expanded(
                child: Text(
                  facetValue.label,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${facetValue.count}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        );
      }).toList(),
    );
  }

  Widget _buildRatingFilter(List<FacetValue> facetValues) {
    return Column(
      children: facetValues.map((facetValue) {
        final isSelected = _isFilterSelected(FilterType.rating, facetValue.value);
        final rating = int.tryParse(facetValue.value) ?? 0;
        
        return CheckboxListTile(
          dense: true,
          value: isSelected,
          onChanged: (selected) {
            if (selected == true) {
              _addFilter(FilterType.rating, facetValue.value);
            } else {
              _removeFilterByTypeAndValue(FilterType.rating, facetValue.value);
            }
          },
          title: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 16,
                  );
                }),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: Text(
                  facetValue.label,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${facetValue.count}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        );
      }).toList(),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _hasActiveFilters() ? _clearAllFilters : null,
              child: const Text('Clear All'),
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                widget.onSearchQueryChanged(_currentQuery);
              },
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _getSectionTitle(String sectionKey) {
    switch (sectionKey) {
      case 'categories':
        return 'Categories';
      case 'priceRanges':
        return 'Price Range';
      case 'ratings':
        return 'Customer Rating';
      case 'brands':
        return 'Brands';
      case 'availability':
        return 'Availability';
      default:
        return sectionKey.toUpperCase();
    }
  }

  FilterType _getFilterTypeForSection(String sectionKey) {
    switch (sectionKey) {
      case 'categories':
        return FilterType.category;
      case 'priceRanges':
        return FilterType.price;
      case 'ratings':
        return FilterType.rating;
      case 'brands':
        return FilterType.brand;
      case 'availability':
        return FilterType.availability;
      default:
        return FilterType.features;
    }
  }

  bool _hasActiveFilters() {
    return _currentQuery.filters.isNotEmpty;
  }

  bool _isFilterSelected(FilterType type, String value) {
    return _currentQuery.filters.any((filter) => 
      filter.type == type && filter.value == value);
  }

  bool _isPriceRangeSelected(String priceRange) {
    return _currentQuery.filters.any((filter) => 
      filter.type == FilterType.price && 
      _getPriceRangeKey(filter) == priceRange);
  }

  String _getPriceRangeKey(SearchFilter filter) {
    // Convert price filter back to range key for comparison
    if (filter.operator == 'gte' && filter.value == 0) return '0-100';
    if (filter.operator == 'lte' && filter.value == 100) return '0-100';
    // Add more range mappings as needed
    return '';
  }

  void _addFilter(FilterType type, dynamic value) {
    final newFilter = SearchFilter(
      type: type,
      field: _getFieldForFilterType(type),
      value: value,
    );

    setState(() {
      // Remove existing filter of same type if it exists (for single-select filters)
      if (type == FilterType.category || type == FilterType.rating) {
        _currentQuery = SearchQuery(
          query: _currentQuery.query,
          filters: [
            ..._currentQuery.filters.where((f) => f.type != type),
            newFilter,
          ],
          sortBy: _currentQuery.sortBy,
          page: _currentQuery.page,
          limit: _currentQuery.limit,
          type: _currentQuery.type,
        );
      } else {
        // Multi-select filters
        _currentQuery = SearchQuery(
          query: _currentQuery.query,
          filters: [..._currentQuery.filters, newFilter],
          sortBy: _currentQuery.sortBy,
          page: _currentQuery.page,
          limit: _currentQuery.limit,
          type: _currentQuery.type,
        );
      }
    });
  }

  void _addPriceRangeFilter(String priceRange) {
    // Remove existing price filters
    final filtersWithoutPrice = _currentQuery.filters
        .where((f) => f.type != FilterType.price)
        .toList();

    // Parse price range and add appropriate filters
    List<SearchFilter> priceFilters = [];
    
    switch (priceRange) {
      case '0-100':
        priceFilters = [
          SearchFilter(type: FilterType.price, field: 'priceRange.min', value: 0, operator: 'gte'),
          SearchFilter(type: FilterType.price, field: 'priceRange.max', value: 100, operator: 'lte'),
        ];
        break;
      case '100-500':
        priceFilters = [
          SearchFilter(type: FilterType.price, field: 'priceRange.min', value: 100, operator: 'gte'),
          SearchFilter(type: FilterType.price, field: 'priceRange.max', value: 500, operator: 'lte'),
        ];
        break;
      case '500-1000':
        priceFilters = [
          SearchFilter(type: FilterType.price, field: 'priceRange.min', value: 500, operator: 'gte'),
          SearchFilter(type: FilterType.price, field: 'priceRange.max', value: 1000, operator: 'lte'),
        ];
        break;
      case '1000-5000':
        priceFilters = [
          SearchFilter(type: FilterType.price, field: 'priceRange.min', value: 1000, operator: 'gte'),
          SearchFilter(type: FilterType.price, field: 'priceRange.max', value: 5000, operator: 'lte'),
        ];
        break;
      case '5000+':
        priceFilters = [
          SearchFilter(type: FilterType.price, field: 'priceRange.min', value: 5000, operator: 'gte'),
        ];
        break;
    }

    setState(() {
      _currentQuery = SearchQuery(
        query: _currentQuery.query,
        filters: [...filtersWithoutPrice, ...priceFilters],
        sortBy: _currentQuery.sortBy,
        page: _currentQuery.page,
        limit: _currentQuery.limit,
        type: _currentQuery.type,
      );
    });
  }

  void _removePriceRangeFilter(String priceRange) {
    setState(() {
      _currentQuery = SearchQuery(
        query: _currentQuery.query,
        filters: _currentQuery.filters.where((f) => f.type != FilterType.price).toList(),
        sortBy: _currentQuery.sortBy,
        page: _currentQuery.page,
        limit: _currentQuery.limit,
        type: _currentQuery.type,
      );
    });
  }

  void _removeFilter(SearchFilter filter) {
    setState(() {
      _currentQuery = SearchQuery(
        query: _currentQuery.query,
        filters: _currentQuery.filters.where((f) => f != filter).toList(),
        sortBy: _currentQuery.sortBy,
        page: _currentQuery.page,
        limit: _currentQuery.limit,
        type: _currentQuery.type,
      );
    });
  }

  void _removeFilterByTypeAndValue(FilterType type, dynamic value) {
    setState(() {
      _currentQuery = SearchQuery(
        query: _currentQuery.query,
        filters: _currentQuery.filters
            .where((f) => !(f.type == type && f.value == value))
            .toList(),
        sortBy: _currentQuery.sortBy,
        page: _currentQuery.page,
        limit: _currentQuery.limit,
        type: _currentQuery.type,
      );
    });
  }

  void _clearAllFilters() {
    setState(() {
      _currentQuery = SearchQuery(
        query: _currentQuery.query,
        filters: [],
        sortBy: _currentQuery.sortBy,
        page: _currentQuery.page,
        limit: _currentQuery.limit,
        type: _currentQuery.type,
      );
    });
    widget.onSearchQueryChanged(_currentQuery);
  }

  String _getFieldForFilterType(FilterType type) {
    switch (type) {
      case FilterType.category:
        return 'primaryCategoryId';
      case FilterType.price:
        return 'priceRange.min';
      case FilterType.rating:
        return 'ratingAvg';
      case FilterType.brand:
        return 'brandId';
      case FilterType.availability:
        return 'totalStock';
      case FilterType.features:
        return 'attributes';
    }
  }

  String _getFilterDisplayText(SearchFilter filter) {
    switch (filter.type) {
      case FilterType.category:
        return 'Category: ${filter.value}';
      case FilterType.price:
        return 'Price: ${filter.operator} ${filter.value}';
      case FilterType.rating:
        return '${filter.value}+ stars';
      case FilterType.brand:
        return 'Brand: ${filter.value}';
      case FilterType.availability:
        if (filter.value == 'in_stock') return 'In Stock';
        if (filter.value == 'low_stock') return 'Low Stock';
        return 'Availability: ${filter.value}';
      case FilterType.features:
        return '${filter.field}: ${filter.value}';
    }
  }
}