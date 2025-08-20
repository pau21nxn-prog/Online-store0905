import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../common/theme.dart';
import '../../models/product.dart';
import '../../models/category.dart';
import '../../models/product_lock.dart';
import '../../services/product_lock_service.dart';
import '../../services/category_service.dart';
import 'add_edit_product_screen.dart';
import 'bulk_operations_screen.dart';

class ProductsManagementScreen extends StatefulWidget {
  const ProductsManagementScreen({super.key});

  @override
  State<ProductsManagementScreen> createState() => _ProductsManagementScreenState();
}

class _ProductsManagementScreenState extends State<ProductsManagementScreen> {
  // Search and filtering
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;
  
  // Filters
  List<Category> _categories = [];
  String? _selectedCategoryId;
  ProductStatus? _selectedStatus;
  bool? _isLowStock;
  String _sortBy = 'updatedAt';
  bool _sortDescending = true;
  
  // Pagination
  static const int _pageSize = 50;
  final List<Product> _products = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();
  
  // Selection for bulk operations
  final Set<String> _selectedProductIds = {};
  bool _isSelectionMode = false;
  bool _selectAll = false;
  
  // Real-time updates
  StreamSubscription<List<ProductLock>>? _locksSubscription;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
    _setupScrollListener();
    _setupSearchListener();
    _subscribeToLocks();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 500) {
        _loadMoreProducts();
      }
    });
  }

  void _setupSearchListener() {
    _searchController.addListener(() {
      if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
        if (_searchQuery != _searchController.text) {
          setState(() {
            _searchQuery = _searchController.text;
          });
          _refreshProducts();
        }
      });
    });
  }

  void _subscribeToLocks() {
    _locksSubscription = ProductLockService.watchActiveLocks().listen((locks) {
      // Update UI when locks change
      if (mounted) {
        setState(() {
          // This will trigger a rebuild to show lock indicators
        });
      }
    });
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await CategoryService.getAllCategories();
      debugPrint('📋 Loaded ${categories.length} categories from database:');
      for (int i = 0; i < categories.length; i++) {
        debugPrint('${i + 1}. ${categories[i].name} (${categories[i].slug})');
      }
      
      // If no categories exist, initialize them
      if (categories.isEmpty) {
        debugPrint('⚠️ No categories found. Initializing 26 categories...');
        await CategoryService.initializeCategoriesFromList();
        final newCategories = await CategoryService.getAllCategories();
        debugPrint('✅ Initialized ${newCategories.length} categories!');
        setState(() {
          _categories = newCategories;
        });
      } else {
        setState(() {
          _categories = categories;
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header with actions
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Title and main actions
                Row(
                  children: [
                    Text(
                      _isSelectionMode 
                          ? '${_selectedProductIds.length} selected'
                          : 'Products (${_products.length})',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    
                    if (_isSelectionMode) ...[
                      IconButton(
                        onPressed: _clearSelection,
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear Selection',
                      ),
                      ElevatedButton.icon(
                        onPressed: _selectedProductIds.isEmpty ? null : _openBulkOperations,
                        icon: const Icon(Icons.edit),
                        label: Text('Bulk Edit (${_selectedProductIds.length})'),
                      ),
                    ] else ...[
                      IconButton(
                        onPressed: _toggleSelectionMode,
                        icon: const Icon(Icons.checklist),
                        tooltip: 'Selection Mode',
                      ),
                      ElevatedButton.icon(
                        onPressed: _navigateToAddProduct,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Product'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                        ),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: AppTheme.spacing16),
                
                // Search and filters
                Row(
                  children: [
                    // Search
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search by title, description, SKU...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: AppTheme.spacing8),
                    
                    // Category filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Categories')),
                          ..._categories.map((category) {
                            return DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCategoryId = value;
                          });
                          _refreshProducts();
                        },
                      ),
                    ),
                    
                    const SizedBox(width: AppTheme.spacing8),
                    
                    // Status filter
                    Expanded(
                      child: DropdownButtonFormField<ProductStatus>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Statuses')),
                          ...ProductStatus.values.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(_getStatusDisplayName(status)),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value;
                          });
                          _refreshProducts();
                        },
                      ),
                    ),
                    
                    const SizedBox(width: AppTheme.spacing8),
                    
                    // More filters button
                    IconButton(
                      onPressed: _showAdvancedFilters,
                      icon: const Icon(Icons.filter_list),
                      tooltip: 'More Filters',
                    ),
                    
                    // Sort options
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.sort),
                      tooltip: 'Sort Options',
                      onSelected: _changeSortOption,
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'updatedAt', child: Text('Recently Updated')),
                        const PopupMenuItem(value: 'createdAt', child: Text('Recently Created')),
                        const PopupMenuItem(value: 'title', child: Text('Name A-Z')),
                        const PopupMenuItem(value: 'priceRange.min', child: Text('Price Low-High')),
                        const PopupMenuItem(value: 'totalStock', child: Text('Stock Level')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Products list
          Expanded(
            child: _products.isEmpty && !_isLoading
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _products.length + (_hasMoreData ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _products.length) {
                        return _buildLoadingIndicator();
                      }
                      
                      final product = _products[index];
                      return _buildEnhancedProductCard(product);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Load products with pagination
  Future<void> _loadProducts() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance.collection('products');
      
      // Apply filters
      if (_selectedCategoryId != null) {
        query = query.where('primaryCategoryId', isEqualTo: _selectedCategoryId);
      }
      if (_selectedStatus != null) {
        query = query.where('workflow.stage', isEqualTo: _selectedStatus!.name);
      }
      if (_isLowStock == true) {
        query = query.where('computed.isLowStock', isEqualTo: true);
      }
      
      // Apply sorting
      query = query.orderBy(_sortBy, descending: _sortDescending);
      
      // Apply pagination
      query = query.limit(_pageSize);
      
      final snapshot = await query.get();
      
      setState(() {
        _products.clear();
        _products.addAll(
          snapshot.docs.map((doc) => 
            Product.fromFirestore(doc.id, doc.data() as Map<String, dynamic>)
          ).where(_filterProduct),
        );
        
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMoreData = snapshot.docs.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading products: $e');
    }
  }

  // Load more products for pagination
  Future<void> _loadMoreProducts() async {
    if (_isLoading || !_hasMoreData || _lastDocument == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance.collection('products');
      
      // Apply same filters as initial load
      if (_selectedCategoryId != null) {
        query = query.where('primaryCategoryId', isEqualTo: _selectedCategoryId);
      }
      if (_selectedStatus != null) {
        query = query.where('workflow.stage', isEqualTo: _selectedStatus!.name);
      }
      if (_isLowStock == true) {
        query = query.where('computed.isLowStock', isEqualTo: true);
      }
      
      query = query
          .orderBy(_sortBy, descending: _sortDescending)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize);
      
      final snapshot = await query.get();
      
      setState(() {
        _products.addAll(
          snapshot.docs.map((doc) => 
            Product.fromFirestore(doc.id, doc.data() as Map<String, dynamic>)
          ).where(_filterProduct),
        );
        
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMoreData = snapshot.docs.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading more products: $e');
    }
  }

  // Refresh products (clear and reload)
  Future<void> _refreshProducts() async {
    setState(() {
      _products.clear();
      _lastDocument = null;
      _hasMoreData = true;
    });
    
    await _loadProducts();
  }

  // Filter products based on search query
  bool _filterProduct(Product product) {
    if (_searchQuery.isEmpty) return true;
    
    final query = _searchQuery.toLowerCase();
    return product.title.toLowerCase().contains(query) ||
           product.description.toLowerCase().contains(query) ||
           product.searchTokens.any((token) => token.contains(query));
  }

  // Enhanced product card with selection, lock indicators, and better layout
  Widget _buildEnhancedProductCard(Product product) {
    final isSelected = _selectedProductIds.contains(product.id);
    
    return FutureBuilder<ProductLock?>(
      future: ProductLockService.getLock(product.id),
      builder: (context, lockSnapshot) {
        final lock = lockSnapshot.data;
        final isLocked = lock != null && !lock.isExpired;
        
        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing4,
          ),
          elevation: isSelected ? 4 : 1,
          child: InkWell(
            onTap: _isSelectionMode 
                ? () => _toggleProductSelection(product.id)
                : () => _navigateToEditProduct(product),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Row(
                children: [
                  // Selection checkbox
                  if (_isSelectionMode) ...[
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleProductSelection(product.id),
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                  ],
                  
                  // Product image with lock indicator
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: product.imageUrls.isNotEmpty
                              ? Image.network(
                                  product.imageUrls.first,
                                  fit: BoxFit.cover,
                                  width: 80,
                                  height: 80,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.broken_image, size: 32),
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.shopping_bag, size: 32),
                                ),
                        ),
                      ),
                      if (isLocked)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(width: AppTheme.spacing16),
                  
                  // Product details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isLocked)
                              Tooltip(
                                message: 'Locked by ${lock!.userName}',
                                child: Icon(
                                  Icons.person,
                                  size: 16,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: AppTheme.spacing4),
                        
                        Text(
                          product.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        
                        const SizedBox(height: AppTheme.spacing8),
                        
                        // Status chips
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildStatusChip(product.workflow.stage),
                            if (product.isLowStock)
                              Chip(
                                label: const Text('Low Stock'),
                                backgroundColor: Colors.orange.shade100,
                                labelStyle: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontSize: 10,
                                ),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            if (product.hasIssues)
                              Chip(
                                label: const Text('Issues'),
                                backgroundColor: Colors.red.shade100,
                                labelStyle: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 10,
                                ),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Stats column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        product.formattedPriceRange,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.primaryOrange,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        '${product.variantCount} variants',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Stock: ${product.totalStock}',
                        style: TextStyle(
                          color: product.isLowStock ? Colors.orange : Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: product.isLowStock ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (product.soldCount > 0)
                        Text(
                          '${product.soldCount} sold',
                          style: TextStyle(
                            color: Colors.green.shade600,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(width: AppTheme.spacing16),
                  
                  // Actions
                  if (!_isSelectionMode)
                    PopupMenuButton<String>(
                      onSelected: (action) => _handleProductAction(action, product),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit),
                            title: Text('Edit'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'duplicate',
                          child: ListTile(
                            leading: Icon(Icons.copy),
                            title: Text('Duplicate'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'toggle_status',
                          child: ListTile(
                            leading: Icon(
                              product.isPublished ? Icons.visibility_off : Icons.visibility,
                            ),
                            title: Text(product.isPublished ? 'Unpublish' : 'Publish'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'analytics',
                          child: ListTile(
                            leading: Icon(Icons.analytics),
                            title: Text('Analytics'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete, color: Colors.red),
                            title: Text('Delete', style: TextStyle(color: Colors.red)),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(AppTheme.spacing16),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            _searchQuery.isNotEmpty ? 'No products found' : 'No products yet',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            _searchQuery.isNotEmpty 
                ? 'Try adjusting your search or filters'
                : 'Add your first product to get started',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing24),
          ElevatedButton.icon(
            onPressed: _navigateToAddProduct,
            icon: const Icon(Icons.add),
            label: const Text('Add Product'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ProductStatus status) {
    Color color;
    String label;
    
    switch (status) {
      case ProductStatus.draft:
        color = Colors.grey;
        label = 'Draft';
        break;
      case ProductStatus.review:
        color = Colors.orange;
        label = 'Review';
        break;
      case ProductStatus.approved:
        color = Colors.green;
        label = 'Approved';
        break;
      case ProductStatus.published:
        color = Colors.blue;
        label = 'Published';
        break;
      case ProductStatus.archived:
        color = Colors.red;
        label = 'Archived';
        break;
    }

    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  // UI Event Handlers
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedProductIds.clear();
        _selectAll = false;
      }
    });
  }

  void _toggleProductSelection(String productId) {
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
        _selectAll = false;
      } else {
        _selectedProductIds.add(productId);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedProductIds.clear();
      _selectAll = false;
      _isSelectionMode = false;
    });
  }

  void _changeSortOption(String sortBy) {
    setState(() {
      if (_sortBy == sortBy) {
        _sortDescending = !_sortDescending;
      } else {
        _sortBy = sortBy;
        _sortDescending = true;
      }
    });
    _refreshProducts();
  }

  void _showAdvancedFilters() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Advanced Filters'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text('Low Stock Only'),
              value: _isLowStock == true,
              onChanged: (value) {
                setState(() {
                  _isLowStock = value == true ? true : null;
                });
              },
            ),
            // Add more advanced filters here
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _refreshProducts();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _openBulkOperations() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BulkOperationsScreen(
          preSelectedProductIds: _selectedProductIds.toList(),
        ),
      ),
    ).then((_) {
      // Refresh products after bulk operations
      _refreshProducts();
      _clearSelection();
    });
  }

  void _handleProductAction(String action, Product product) {
    switch (action) {
      case 'edit':
        _navigateToEditProduct(product);
        break;
      case 'duplicate':
        _duplicateProduct(product);
        break;
      case 'toggle_status':
        _toggleProductStatus(product);
        break;
      case 'analytics':
        _showProductAnalytics(product);
        break;
      case 'delete':
        _deleteProduct(product);
        break;
    }
  }

  String _getStatusDisplayName(ProductStatus status) {
    switch (status) {
      case ProductStatus.draft:
        return 'Draft';
      case ProductStatus.review:
        return 'Under Review';
      case ProductStatus.approved:
        return 'Approved';
      case ProductStatus.published:
        return 'Published';
      case ProductStatus.archived:
        return 'Archived';
    }
  }

  // Navigation methods
  void _navigateToAddProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditProductScreen(),
      ),
    ).then((_) => _refreshProducts());
  }

  void _navigateToEditProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditProductScreen(product: product),
      ),
    ).then((_) => _refreshProducts());
  }

  // Product operations
  void _duplicateProduct(Product product) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Duplicate functionality will be implemented')),
    );
  }

  void _showProductAnalytics(Product product) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Analytics functionality will be implemented')),
    );
  }

  Future<void> _toggleProductStatus(Product product) async {
    try {
      final newStatus = product.isPublished 
          ? ProductStatus.draft 
          : ProductStatus.published;
      
      await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .update({
            'workflow.stage': newStatus.name,
            'updatedAt': Timestamp.now(),
          });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Product ${product.isPublished ? 'unpublished' : 'published'} successfully',
            ),
          ),
        );
        _refreshProducts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating product: $e')),
        );
      }
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.title}"?\n\nThis will also delete all variants and media.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete product and all subcollections
        final batch = FirebaseFirestore.instance.batch();
        
        // Delete variants
        final variantsSnapshot = await FirebaseFirestore.instance
            .collection('products')
            .doc(product.id)
            .collection('variants')
            .get();
        
        for (final variantDoc in variantsSnapshot.docs) {
          batch.delete(variantDoc.reference);
        }
        
        // Delete media
        final mediaSnapshot = await FirebaseFirestore.instance
            .collection('products')
            .doc(product.id)
            .collection('media')
            .get();
        
        for (final mediaDoc in mediaSnapshot.docs) {
          batch.delete(mediaDoc.reference);
        }
        
        // Delete product
        batch.delete(FirebaseFirestore.instance
            .collection('products')
            .doc(product.id));
        
        await batch.commit();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deleted successfully')),
          );
          _refreshProducts();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting product: $e')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _locksSubscription?.cancel();
    super.dispose();
  }
}