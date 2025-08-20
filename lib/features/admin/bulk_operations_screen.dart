import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../common/theme.dart';
import '../../models/product.dart';
import '../../models/category.dart';
import '../../services/bulk_operations_service.dart';

class BulkOperationsScreen extends StatefulWidget {
  final List<String>? preSelectedProductIds;

  const BulkOperationsScreen({super.key, this.preSelectedProductIds});

  @override
  State<BulkOperationsScreen> createState() => _BulkOperationsScreenState();
}

class _BulkOperationsScreenState extends State<BulkOperationsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  // Product selection
  final Set<String> _selectedProductIds = {};
  List<Product> _products = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  bool _selectAll = false;
  
  // Filters
  String? _selectedCategoryId;
  ProductStatus? _selectedStatus;
  String _searchQuery = '';
  
  // Operation state
  BulkOperationResult? _currentOperation;
  bool _isOperationRunning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    if (widget.preSelectedProductIds != null) {
      _selectedProductIds.addAll(widget.preSelectedProductIds!);
    }
    
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadProducts(),
        _loadCategories(),
      ]);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProducts() async {
    Query query = FirebaseFirestore.instance
        .collection('products')
        .orderBy('updatedAt', descending: true)
        .limit(1000); // Load more products for bulk operations

    // Apply filters
    if (_selectedCategoryId != null) {
      query = query.where('primaryCategoryId', isEqualTo: _selectedCategoryId);
    }
    if (_selectedStatus != null) {
      query = query.where('workflow.stage', isEqualTo: _selectedStatus!.name);
    }

    final snapshot = await query.get();
    
    setState(() {
      _products = snapshot.docs
          .map((doc) => Product.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
          .where((product) {
            if (_searchQuery.isNotEmpty) {
              return product.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                     product.description.toLowerCase().contains(_searchQuery.toLowerCase());
            }
            return true;
          })
          .toList();
    });
  }

  Future<void> _loadCategories() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('categories')
        .get();
    
    setState(() {
      _categories = snapshot.docs
          .map((doc) => Category.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bulk Operations (${_selectedProductIds.length} selected)'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Select'),
            Tab(icon: Icon(Icons.edit), text: 'Update'),
            Tab(icon: Icon(Icons.inventory), text: 'Inventory'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
        actions: [
          if (_selectedProductIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () {
                setState(() {
                  _selectedProductIds.clear();
                  _selectAll = false;
                });
              },
              tooltip: 'Clear Selection',
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSelectionTab(),
          _buildUpdateTab(),
          _buildInventoryTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildSelectionTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Filters
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
              // Search bar
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                  _loadProducts();
                },
              ),
              
              const SizedBox(height: AppTheme.spacing8),
              
              // Filter row
              Row(
                children: [
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
                        _loadProducts();
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
                        _loadProducts();
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppTheme.spacing8),
              
              // Selection controls
              Row(
                children: [
                  Checkbox(
                    value: _selectAll,
                    onChanged: (value) {
                      setState(() {
                        _selectAll = value ?? false;
                        if (_selectAll) {
                          _selectedProductIds.addAll(_products.map((p) => p.id));
                        } else {
                          _selectedProductIds.clear();
                        }
                      });
                    },
                  ),
                  Text('Select all ${_products.length} products'),
                  
                  const Spacer(),
                  
                  Text('${_selectedProductIds.length} selected'),
                ],
              ),
            ],
          ),
        ),
        
        // Product list
        Expanded(
          child: _products.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No products found'),
                      Text('Try adjusting your filters'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    final isSelected = _selectedProductIds.contains(product.id);
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing16,
                        vertical: AppTheme.spacing4,
                      ),
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedProductIds.add(product.id);
                            } else {
                              _selectedProductIds.remove(product.id);
                              _selectAll = false;
                            }
                          });
                        },
                        title: Text(
                          product.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.formattedPriceRange),
                            Row(
                              children: [
                                _buildStatusChip(product.workflow.stage),
                                const SizedBox(width: 8),
                                if (product.isLowStock)
                                  Chip(
                                    label: const Text('Low Stock'),
                                    backgroundColor: Colors.orange.shade100,
                                    labelStyle: TextStyle(color: Colors.orange.shade800),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        secondary: product.totalStock > 0
                            ? CircleAvatar(
                                backgroundColor: AppTheme.primaryOrange,
                                child: Text(
                                  '${product.totalStock}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : const CircleAvatar(
                                backgroundColor: Colors.grey,
                                child: Text('0', style: TextStyle(color: Colors.white)),
                              ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUpdateTab() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      children: [
        if (_selectedProductIds.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                children: [
                  Icon(Icons.info_outline, size: 48, color: Colors.blue),
                  SizedBox(height: 8),
                  Text(
                    'No products selected',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text('Go to the Select tab to choose products for bulk updates'),
                ],
              ),
            ),
          )
        else ...[
          // Status update
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update Status',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Text('Update status for ${_selectedProductIds.length} products'),
                  const SizedBox(height: AppTheme.spacing16),
                  Row(
                    children: ProductStatus.values.map((status) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ElevatedButton.icon(
                            onPressed: _isOperationRunning 
                                ? null 
                                : () => _updateStatus(status),
                            icon: _getStatusIcon(status),
                            label: Text(_getStatusDisplayName(status)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getStatusColor(status),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          
          // Category update
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update Category',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'New Category',
                            border: OutlineInputBorder(),
                          ),
                          items: _categories.map((category) {
                            return DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            );
                          }).toList(),
                          onChanged: _isOperationRunning ? null : (categoryId) {
                            if (categoryId != null) {
                              _updateCategory(categoryId);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Price update
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update Prices',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  _buildPriceUpdateForm(),
                ],
              ),
            ),
          ),
        ],
        
        // Operation progress
        if (_currentOperation != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: _buildOperationProgress(_currentOperation!),
            ),
          ),
      ],
    );
  }

  Widget _buildInventoryTab() {
    if (_selectedProductIds.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No products selected'),
            Text('Select products to manage inventory'),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventory Operations (${_selectedProductIds.length} products)',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppTheme.spacing16),
                
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isOperationRunning ? null : () => _showInventoryDialog('add'),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Stock'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isOperationRunning ? null : () => _showInventoryDialog('subtract'),
                        icon: const Icon(Icons.remove),
                        label: const Text('Remove Stock'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isOperationRunning ? null : () => _showInventoryDialog('set'),
                        icon: const Icon(Icons.edit),
                        label: const Text('Set Stock'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return FutureBuilder<List<BulkOperationResult>>(
      future: BulkOperationsService.getOperationHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No operations yet'),
                Text('Bulk operations will appear here'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final operation = snapshot.data![index];
            return Card(
              child: ListTile(
                leading: _getOperationIcon(operation.type),
                title: Text(_getOperationDisplayName(operation.type)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${operation.totalItems} items'),
                    Text('${operation.successCount} success, ${operation.failureCount} failed'),
                    Text(_formatDateTime(operation.startedAt)),
                  ],
                ),
                trailing: _buildOperationStatusChip(operation.status),
                onTap: () => _showOperationDetails(operation),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPriceUpdateForm() {
    final strategyController = TextEditingController();
    final valueController = TextEditingController();
    PriceUpdateStrategy selectedStrategy = PriceUpdateStrategy.percentage;

    return Column(
      children: [
        DropdownButtonFormField<PriceUpdateStrategy>(
          value: selectedStrategy,
          decoration: const InputDecoration(
            labelText: 'Update Strategy',
            border: OutlineInputBorder(),
          ),
          items: PriceUpdateStrategy.values.map((strategy) {
            return DropdownMenuItem(
              value: strategy,
              child: Text(_getPriceStrategyDisplayName(strategy)),
            );
          }).toList(),
          onChanged: (value) {
            selectedStrategy = value!;
          },
        ),
        
        const SizedBox(height: AppTheme.spacing16),
        
        TextField(
          controller: valueController,
          decoration: const InputDecoration(
            labelText: 'Value',
            border: OutlineInputBorder(),
            helperText: 'Enter percentage (10) or amount (100)',
          ),
          keyboardType: TextInputType.number,
        ),
        
        const SizedBox(height: AppTheme.spacing16),
        
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isOperationRunning ? null : () {
              final value = double.tryParse(valueController.text);
              if (value != null) {
                _updatePrices(selectedStrategy, value);
              }
            },
            child: const Text('Update Prices'),
          ),
        ),
      ],
    );
  }

  // Helper methods for operations
  Future<void> _updateStatus(ProductStatus status) async {
    setState(() {
      _isOperationRunning = true;
    });

    try {
      final result = await BulkOperationsService.updateProductStatus(
        _selectedProductIds.toList(),
        status,
        reason: 'Bulk status update',
      );
      
      setState(() {
        _currentOperation = result;
      });
      
      _showOperationResult(result);
    } finally {
      setState(() {
        _isOperationRunning = false;
      });
    }
  }

  Future<void> _updateCategory(String categoryId) async {
    final category = _categories.firstWhere((c) => c.id == categoryId);
    
    setState(() {
      _isOperationRunning = true;
    });

    try {
      final result = await BulkOperationsService.updateProductCategory(
        _selectedProductIds.toList(),
        categoryId,
        [category.name], // Simplified category path
        reason: 'Bulk category update',
      );
      
      setState(() {
        _currentOperation = result;
      });
      
      _showOperationResult(result);
    } finally {
      setState(() {
        _isOperationRunning = false;
      });
    }
  }

  Future<void> _updatePrices(PriceUpdateStrategy strategy, double value) async {
    final config = PriceUpdateConfig(
      strategy: strategy,
      value: value,
      updateCompareAtPrice: true,
    );
    
    setState(() {
      _isOperationRunning = true;
    });

    try {
      final result = await BulkOperationsService.updatePrices(
        _selectedProductIds.toList(),
        config,
        reason: 'Bulk price update',
      );
      
      setState(() {
        _currentOperation = result;
      });
      
      _showOperationResult(result);
    } finally {
      setState(() {
        _isOperationRunning = false;
      });
    }
  }

  void _showInventoryDialog(String operation) {
    final quantityController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${operation.toUpperCase()} Inventory'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('This will ${operation} inventory for ${_selectedProductIds.length} products'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
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
            onPressed: () {
              final quantity = int.tryParse(quantityController.text);
              if (quantity != null) {
                Navigator.pop(context);
                _updateInventory(operation, quantity);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateInventory(String operation, int quantity) async {
    setState(() {
      _isOperationRunning = true;
    });

    try {
      final result = await BulkOperationsService.updateInventory(
        _selectedProductIds.toList(),
        {
          'operation': operation,
          'quantity': quantity,
        },
        reason: 'Bulk inventory update',
      );
      
      setState(() {
        _currentOperation = result;
      });
      
      _showOperationResult(result);
    } finally {
      setState(() {
        _isOperationRunning = false;
      });
    }
  }

  void _showOperationResult(BulkOperationResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Operation Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Operation: ${_getOperationDisplayName(result.type)}'),
            Text('Total items: ${result.totalItems}'),
            Text('Successful: ${result.successCount}'),
            if (result.failureCount > 0)
              Text('Failed: ${result.failureCount}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          if (result.failureCount > 0)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showOperationDetails(result);
              },
              child: const Text('View Details'),
            ),
        ],
      ),
    );
  }

  void _showOperationDetails(BulkOperationResult operation) {
    // Implementation for showing detailed operation results
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Operation details view will be implemented')),
    );
  }

  Widget _buildOperationProgress(BulkOperationResult operation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Operation in Progress',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text('${operation.progressPercentage.toStringAsFixed(1)}%'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: operation.progressPercentage / 100),
        const SizedBox(height: 8),
        Text('${operation.successCount + operation.failureCount} of ${operation.totalItems} completed'),
      ],
    );
  }

  // UI Helper methods
  Widget _buildStatusChip(ProductStatus status) {
    return Chip(
      label: Text(_getStatusDisplayName(status)),
      backgroundColor: _getStatusColor(status).withOpacity(0.1),
      labelStyle: TextStyle(
        color: _getStatusColor(status),
        fontSize: 12,
      ),
    );
  }

  Widget _getStatusIcon(ProductStatus status) {
    switch (status) {
      case ProductStatus.draft:
        return const Icon(Icons.edit, size: 16);
      case ProductStatus.review:
        return const Icon(Icons.rate_review, size: 16);
      case ProductStatus.approved:
        return const Icon(Icons.check_circle, size: 16);
      case ProductStatus.published:
        return const Icon(Icons.public, size: 16);
      case ProductStatus.archived:
        return const Icon(Icons.archive, size: 16);
    }
  }

  Color _getStatusColor(ProductStatus status) {
    switch (status) {
      case ProductStatus.draft:
        return Colors.grey;
      case ProductStatus.review:
        return Colors.orange;
      case ProductStatus.approved:
        return Colors.green;
      case ProductStatus.published:
        return Colors.blue;
      case ProductStatus.archived:
        return Colors.red;
    }
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

  Widget _getOperationIcon(BulkOperationType type) {
    switch (type) {
      case BulkOperationType.updateStatus:
        return const Icon(Icons.update);
      case BulkOperationType.updateCategory:
        return const Icon(Icons.category);
      case BulkOperationType.updatePrices:
        return const Icon(Icons.attach_money);
      case BulkOperationType.updateInventory:
        return const Icon(Icons.inventory);
      case BulkOperationType.updateVisibility:
        return const Icon(Icons.visibility);
      case BulkOperationType.delete:
        return const Icon(Icons.delete);
      case BulkOperationType.archive:
        return const Icon(Icons.archive);
      case BulkOperationType.export:
        return const Icon(Icons.download);
    }
  }

  String _getOperationDisplayName(BulkOperationType type) {
    switch (type) {
      case BulkOperationType.updateStatus:
        return 'Update Status';
      case BulkOperationType.updateCategory:
        return 'Update Category';
      case BulkOperationType.updatePrices:
        return 'Update Prices';
      case BulkOperationType.updateInventory:
        return 'Update Inventory';
      case BulkOperationType.updateVisibility:
        return 'Update Visibility';
      case BulkOperationType.delete:
        return 'Delete Products';
      case BulkOperationType.archive:
        return 'Archive Products';
      case BulkOperationType.export:
        return 'Export Data';
    }
  }

  String _getPriceStrategyDisplayName(PriceUpdateStrategy strategy) {
    switch (strategy) {
      case PriceUpdateStrategy.percentage:
        return 'Percentage Change';
      case PriceUpdateStrategy.fixedAmount:
        return 'Fixed Amount';
      case PriceUpdateStrategy.setPrice:
        return 'Set Price';
      case PriceUpdateStrategy.addMargin:
        return 'Add Margin';
    }
  }

  Widget _buildOperationStatusChip(String status) {
    Color color;
    switch (status) {
      case 'completed':
        color = Colors.green;
        break;
      case 'running':
        color = Colors.blue;
        break;
      case 'failed':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(status.toUpperCase()),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color, fontSize: 12),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}