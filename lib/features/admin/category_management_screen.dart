import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../common/theme.dart';
import '../../models/category.dart';
import '../../services/category_service.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Category> _allCategories = [];
  List<Category> _filteredCategories = [];
  bool _isLoading = true;
  bool _showHierarchy = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _searchController.addListener(_filterCategories);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categories = await CategoryService.getAllCategories();
      setState(() {
        _allCategories = categories;
        _filteredCategories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading categories: $e')),
      );
    }
  }

  void _filterCategories() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCategories = _allCategories.where((category) {
        return category.name.toLowerCase().contains(query) ||
               category.description.toLowerCase().contains(query);
      }).toList();
    });
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
                Row(
                  children: [
                    Text(
                      'Category Management',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showHierarchy = !_showHierarchy;
                        });
                      },
                      icon: Icon(_showHierarchy ? Icons.list : Icons.account_tree),
                      tooltip: _showHierarchy ? 'Show List View' : 'Show Tree View',
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showInitializeCategoriesDialog(),
                      icon: const Icon(Icons.upload),
                      label: const Text('Initialize Categories'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showAddCategoryDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Category'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing16),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search categories...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          
          // Categories list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCategories.isEmpty
                    ? _buildEmptyState()
                    : _showHierarchy
                        ? _buildHierarchicalView()
                        : _buildFlatView(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            _allCategories.isEmpty ? 'No categories yet' : 'No categories found',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            _allCategories.isEmpty 
                ? 'Initialize the category structure to get started'
                : 'Try adjusting your search query',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing24),
          ElevatedButton.icon(
            onPressed: () => _showInitializeCategoriesDialog(),
            icon: const Icon(Icons.upload),
            label: const Text('Initialize Categories'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchicalView() {
    final topLevelCategories = _filteredCategories
        .where((category) => category.isTopLevel)
        .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      itemCount: topLevelCategories.length,
      itemBuilder: (context, index) {
        return _buildCategoryTreeItem(topLevelCategories[index], 0);
      },
    );
  }

  Widget _buildFlatView() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      itemCount: _filteredCategories.length,
      itemBuilder: (context, index) {
        return _buildCategoryCard(_filteredCategories[index]);
      },
    );
  }

  Widget _buildCategoryTreeItem(Category category, int depth) {
    final hasChildren = category.hasChildren;
    final isExpanded = true; // For simplicity, keep all expanded

    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(left: depth * 24.0),
          child: _buildCategoryCard(category, showLevel: true),
        ),
        if (hasChildren && isExpanded) ...[
          ...category.childIds.map((childId) {
            final child = _allCategories.firstWhere(
              (c) => c.id == childId,
              orElse: () => Category(
                id: childId,
                name: 'Unknown Category',
                description: 'Category not found',
                icon: Icons.error,
                color: Colors.red,
                isActive: false,
                slug: 'unknown',
              ),
            );
            return _buildCategoryTreeItem(child, depth + 1);
          }),
        ],
      ],
    );
  }

  Widget _buildCategoryCard(Category category, {bool showLevel = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: category.color.withOpacity(0.1),
          child: Icon(category.icon, color: category.color),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                category.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (showLevel && category.level > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'L${category.level}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.primaryOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (category.description.isNotEmpty)
              Text(category.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text('${category.productCount} products'),
                  backgroundColor: Colors.grey.shade100,
                  labelStyle: const TextStyle(fontSize: 11),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                if (!category.isActive)
                  Chip(
                    label: const Text('Inactive'),
                    backgroundColor: Colors.red.shade100,
                    labelStyle: TextStyle(color: Colors.red.shade800, fontSize: 11),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (category.hasChildren)
                  Chip(
                    label: Text('${category.childIds.length} subcategories'),
                    backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                    labelStyle: TextStyle(color: AppTheme.primaryOrange, fontSize: 11),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleCategoryAction(action, category),
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
              value: 'add_child',
              child: ListTile(
                leading: Icon(Icons.add_circle),
                title: Text('Add Subcategory'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'toggle_status',
              child: ListTile(
                leading: Icon(category.isActive ? Icons.visibility_off : Icons.visibility),
                title: Text(category.isActive ? 'Deactivate' : 'Activate'),
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
      ),
    );
  }

  void _handleCategoryAction(String action, Category category) {
    switch (action) {
      case 'edit':
        _showEditCategoryDialog(category);
        break;
      case 'add_child':
        _showAddCategoryDialog(parentCategory: category);
        break;
      case 'toggle_status':
        _toggleCategoryStatus(category);
        break;
      case 'delete':
        _deleteCategory(category);
        break;
    }
  }

  void _showInitializeCategoriesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Initialize Category Structure'),
        content: const Text(
          'This will create the comprehensive category structure from CategoryList.md. '
          'Any existing categories will be preserved, but new ones will be added.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeCategories();
            },
            child: const Text('Initialize'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog({Category? parentCategory}) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final slugController = TextEditingController();
    
    IconData selectedIcon = Icons.category;
    Color selectedColor = Colors.blue;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(parentCategory == null ? 'Add Category' : 'Add Subcategory'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (parentCategory != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(parentCategory.icon, color: parentCategory.color),
                        const SizedBox(width: 8),
                        Text('Parent: ${parentCategory.name}'),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: slugController,
                  decoration: const InputDecoration(
                    labelText: 'URL Slug',
                    border: OutlineInputBorder(),
                  ),
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
              onPressed: () {
                if (nameController.text.isNotEmpty && slugController.text.isNotEmpty) {
                  Navigator.pop(context);
                  _addCategory(
                    nameController.text,
                    descriptionController.text,
                    slugController.text,
                    selectedIcon,
                    selectedColor,
                    parentCategory?.id,
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryDialog(Category category) {
    // Implementation for editing categories
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit category functionality will be implemented')),
    );
  }

  Future<void> _initializeCategories() async {
    try {
      await CategoryService.initializeCategoriesFromList();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categories initialized successfully!')),
      );
      _loadCategories();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing categories: $e')),
      );
    }
  }

  Future<void> _addCategory(
    String name,
    String description,
    String slug,
    IconData icon,
    Color color,
    String? parentId,
  ) async {
    try {
      await CategoryService.createCategory(
        name: name,
        description: description,
        slug: slug,
        icon: icon,
        color: color,
        parentId: parentId,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category added successfully!')),
      );
      _loadCategories();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding category: $e')),
      );
    }
  }

  Future<void> _toggleCategoryStatus(Category category) async {
    try {
      await CategoryService.updateCategory(
        category.copyWith(isActive: !category.isActive),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Category ${category.isActive ? 'deactivated' : 'activated'} successfully!',
          ),
        ),
      );
      _loadCategories();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating category: $e')),
      );
    }
  }

  Future<void> _deleteCategory(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Are you sure you want to delete "${category.name}"?\n\n'
          '${category.hasChildren ? 'This will also delete all subcategories.\n\n' : ''}'
          'Products in this category will need to be recategorized.',
        ),
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
        await CategoryService.deleteCategory(category.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category deleted successfully!')),
        );
        _loadCategories();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting category: $e')),
        );
      }
    }
  }
}