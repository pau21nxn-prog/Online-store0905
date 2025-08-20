import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../common/theme.dart';
import '../../models/product.dart';
import '../../widgets/mobile_product_card.dart';

class MobileQuickProductManager extends StatefulWidget {
  const MobileQuickProductManager({super.key});

  @override
  State<MobileQuickProductManager> createState() => _MobileQuickProductManagerState();
}

class _MobileQuickProductManagerState extends State<MobileQuickProductManager>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  // State
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  bool _isGridView = false;
  String _searchQuery = '';
  
  // Filters
  ProductStatus? _statusFilter;
  bool? _lowStockFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _loadProducts();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _filterProducts();
    });
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // In a real app, this would fetch from Firestore
      // For now, generate mock products
      _products = _generateMockProducts();
      _filterProducts();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load products: $e');
    }
  }

  List<Product> _generateMockProducts() {
    return List.generate(20, (index) {
      final statuses = ProductStatus.values;
      final status = statuses[index % statuses.length];
      final isLowStock = index % 5 == 0;
      final basePrice = 100.0 + (index * 25);
      
      return Product(
        id: 'quick_product_$index',
        title: 'Product ${index + 1}',
        description: 'Description for product ${index + 1}',
        imageUrls: [],
        priceRange: PriceRange(min: basePrice, max: basePrice),
        originalPrice: basePrice,
        categoryPath: ['electronics'],
        primaryCategoryId: 'electronics',
        brandId: 'brand_${index % 3}',
        tags: [],
        attributes: {},
        searchTokens: [],
        totalStock: isLowStock ? 5 : 50 + (index * 10),
        variantCount: 1,
        soldCount: index * 8,
        ratingAvg: 4.0 + (index % 5) * 0.2,
        ratingCount: 10 + (index * 3),
        isLowStock: isLowStock,
        hasIssues: false,
        isPublished: status == ProductStatus.published,
        isNew: index < 3,
        hasDiscount: index % 4 == 0,
        workflow: WorkflowState(
          stage: status,
          assignedTo: null,
          notes: [],
        ),
        performance: ProductPerformance(
          views: index * 50,
          clicks: index * 10,
          conversions: index * 2,
          revenue: basePrice * (index * 2),
        ),
        computed: ComputedFields(
          isLowStock: isLowStock,
          reorderPoint: 10,
          daysOfInventory: 30,
          searchRelevance: 0.8,
        ),
        media: MediaCounts(images: 1, videos: 0),
        createdAt: DateTime.now().subtract(Duration(days: index)),
        updatedAt: DateTime.now().subtract(Duration(hours: index)),
      );
    });
  }

  void _filterProducts() {
    _filteredProducts = _products.where((product) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!product.title.toLowerCase().contains(query) &&
            !product.description.toLowerCase().contains(query)) {
          return false;
        }
      }
      
      // Status filter
      if (_statusFilter != null && product.workflow.stage != _statusFilter) {
        return false;
      }
      
      // Low stock filter
      if (_lowStockFilter == true && !product.isLowStock) {
        return false;
      }
      
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Product Manager'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _toggleView,
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
          ),
          IconButton(
            onPressed: _showFilters,
            icon: const Icon(Icons.filter_list),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All Products'),
            Tab(text: 'Low Stock'),
            Tab(text: 'Out of Stock'),
            Tab(text: 'Recent'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductsList(_filteredProducts),
                _buildProductsList(_filteredProducts.where((p) => p.isLowStock).toList()),
                _buildProductsList(_filteredProducts.where((p) => p.totalStock == 0).toList()),
                _buildProductsList(_filteredProducts.take(10).toList()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewProduct,
        backgroundColor: AppTheme.primaryOrange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Product', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search products...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                  },
                  icon: const Icon(Icons.clear),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius12),
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
      ),
    );
  }

  Widget _buildProductsList(List<Product> products) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: _isGridView ? _buildGridView(products) : _buildListView(products),
    );
  }

  Widget _buildGridView(List<Product> products) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppTheme.spacing8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: AppTheme.spacing8,
        mainAxisSpacing: AppTheme.spacing8,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return MobileProductCard(
          product: product,
          onTap: () => _showQuickActions(product),
          showQuickActions: false,
          margin: EdgeInsets.zero,
        );
      },
    );
  }

  Widget _buildListView(List<Product> products) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductListTile(product);
      },
    );
  }

  Widget _buildProductListTile(Product product) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing4,
      ),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.shopping_bag_outlined),
        ),
        title: Text(
          product.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.formattedPriceRange,
              style: const TextStyle(
                color: AppTheme.primaryOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                _buildStatusChip(product.workflow.stage),
                const SizedBox(width: 8),
                if (product.isLowStock)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Low Stock: ${product.totalStock}',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleProductAction(action, product),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'quick_edit',
              child: ListTile(
                leading: Icon(Icons.edit, size: 20),
                title: Text('Quick Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'update_stock',
              child: ListTile(
                leading: Icon(Icons.inventory, size: 20),
                title: Text('Update Stock'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'toggle_status',
              child: ListTile(
                leading: Icon(Icons.visibility, size: 20),
                title: Text('Toggle Status'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'view_analytics',
              child: ListTile(
                leading: Icon(Icons.analytics, size: 20),
                title: Text('View Analytics'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        onTap: () => _showQuickActions(product),
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
        label = 'Live';
        break;
      case ProductStatus.archived:
        color = Colors.red;
        label = 'Archived';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Event handlers
  void _toggleView() {
    setState(() {
      _isGridView = !_isGridView;
    });
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildFiltersBottomSheet(),
    );
  }

  Widget _buildFiltersBottomSheet() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              
              // Status filter
              const Text('Status:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _statusFilter == null,
                    onSelected: (selected) {
                      setModalState(() {
                        _statusFilter = selected ? null : _statusFilter;
                      });
                    },
                  ),
                  ...ProductStatus.values.map((status) {
                    return FilterChip(
                      label: Text(_getStatusDisplayName(status)),
                      selected: _statusFilter == status,
                      onSelected: (selected) {
                        setModalState(() {
                          _statusFilter = selected ? status : null;
                        });
                      },
                    );
                  }),
                ],
              ),
              
              const SizedBox(height: AppTheme.spacing16),
              
              // Low stock filter
              CheckboxListTile(
                title: const Text('Low Stock Only'),
                value: _lowStockFilter == true,
                onChanged: (value) {
                  setModalState(() {
                    _lowStockFilter = value == true ? true : null;
                  });
                },
              ),
              
              const SizedBox(height: AppTheme.spacing16),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setModalState(() {
                          _statusFilter = null;
                          _lowStockFilter = null;
                        });
                      },
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filterProducts();
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQuickActions(Product product) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildQuickActionsSheet(product),
    );
  }

  Widget _buildQuickActionsSheet(Product product) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            title: Text(
              product.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.formattedPriceRange),
                Text('Stock: ${product.totalStock}'),
              ],
            ),
          ),
          const Divider(),
          _buildActionTile(
            Icons.edit,
            'Quick Edit',
            'Edit basic product details',
            () => _quickEditProduct(product),
          ),
          _buildActionTile(
            Icons.inventory,
            'Update Stock',
            'Adjust inventory levels',
            () => _updateStock(product),
          ),
          _buildActionTile(
            Icons.visibility,
            'Toggle Status',
            product.isPublished ? 'Unpublish product' : 'Publish product',
            () => _toggleProductStatus(product),
          ),
          _buildActionTile(
            Icons.analytics,
            'View Analytics',
            'See performance metrics',
            () => _viewProductAnalytics(product),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryOrange),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _handleProductAction(String action, Product product) {
    switch (action) {
      case 'quick_edit':
        _quickEditProduct(product);
        break;
      case 'update_stock':
        _updateStock(product);
        break;
      case 'toggle_status':
        _toggleProductStatus(product);
        break;
      case 'view_analytics':
        _viewProductAnalytics(product);
        break;
    }
  }

  void _quickEditProduct(Product product) {
    showDialog(
      context: context,
      builder: (context) => _QuickEditDialog(product: product),
    );
  }

  void _updateStock(Product product) {
    showDialog(
      context: context,
      builder: (context) => _UpdateStockDialog(product: product),
    );
  }

  void _toggleProductStatus(Product product) {
    HapticFeedback.lightImpact();
    // Implement status toggle
    _showSnackBar('${product.title} status updated');
  }

  void _viewProductAnalytics(Product product) {
    // Navigate to product analytics
    _showSnackBar('Analytics for ${product.title}');
  }

  void _addNewProduct() {
    // Navigate to add product screen
    _showSnackBar('Add new product feature');
  }

  String _getStatusDisplayName(ProductStatus status) {
    switch (status) {
      case ProductStatus.draft:
        return 'Draft';
      case ProductStatus.review:
        return 'Review';
      case ProductStatus.approved:
        return 'Approved';
      case ProductStatus.published:
        return 'Published';
      case ProductStatus.archived:
        return 'Archived';
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

// Quick edit dialog
class _QuickEditDialog extends StatefulWidget {
  final Product product;

  const _QuickEditDialog({required this.product});

  @override
  State<_QuickEditDialog> createState() => _QuickEditDialogState();
}

class _QuickEditDialogState extends State<_QuickEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.product.title);
    _priceController = TextEditingController(text: widget.product.priceRange.min.toString());
    _descriptionController = TextEditingController(text: widget.product.description);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quick Edit'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Product Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Price',
                border: OutlineInputBorder(),
                prefixText: '₱',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveChanges,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveChanges() {
    // Implement save logic
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product updated successfully')),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

// Update stock dialog
class _UpdateStockDialog extends StatefulWidget {
  final Product product;

  const _UpdateStockDialog({required this.product});

  @override
  State<_UpdateStockDialog> createState() => _UpdateStockDialogState();
}

class _UpdateStockDialogState extends State<_UpdateStockDialog> {
  late TextEditingController _stockController;
  String _adjustmentType = 'set';

  @override
  void initState() {
    super.initState();
    _stockController = TextEditingController(text: widget.product.totalStock.toString());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Stock'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Current stock: ${widget.product.totalStock}'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _adjustmentType,
            decoration: const InputDecoration(
              labelText: 'Adjustment Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'set', child: Text('Set to')),
              DropdownMenuItem(value: 'add', child: Text('Add')),
              DropdownMenuItem(value: 'subtract', child: Text('Subtract')),
            ],
            onChanged: (value) {
              setState(() {
                _adjustmentType = value!;
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _stockController,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _updateStock,
          child: const Text('Update'),
        ),
      ],
    );
  }

  void _updateStock() {
    // Implement stock update logic
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Stock updated successfully')),
    );
  }

  @override
  void dispose() {
    _stockController.dispose();
    super.dispose();
  }
}