import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../common/theme.dart';
import '../../common/mobile_layout_utils.dart';
import '../../models/category.dart';
import '../../services/auth_service.dart';
import 'category_list_screen.dart';
import '../search/search_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addSampleCategories(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categories')
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(context);
          }

          final categories = snapshot.data!.docs
              .map((doc) => Category.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Shop by Category',
                  style: AppTheme.titleStyle.copyWith(fontSize: 24),
                ),
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  'Discover products organized by category',
                  style: AppTheme.bodyStyle.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: AppTheme.spacing24),

                // Categories Grid
                Builder(
                  builder: (context) {
                    final currentUser = AuthService.currentUser;
                    final isAdmin = currentUser?.canAccessAdmin ?? false;
                    
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: MobileLayoutUtils.getCategoryGridDelegate(
                        isAdmin: isAdmin,
                        context: context,
                      ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return _buildCategoryCard(context, category);
                  },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Category category) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryListScreen(
                categoryId: category.id,
                categoryName: category.name,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Category Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  category.icon,
                  size: 40,
                  color: category.color,
                ),
              ),
              
              const SizedBox(height: AppTheme.spacing12),
              
              // Category Name
              Text(
                category.name,
                style: AppTheme.subtitleStyle.copyWith(fontSize: 16),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: AppTheme.spacing4),
              
              // Product Count
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .where('categoryId', isEqualTo: category.id)
                    .where('isActive', isEqualTo: true)
                    .snapshots(),
                builder: (context, productSnapshot) {
                  final productCount = productSnapshot.hasData 
                      ? productSnapshot.data!.docs.length 
                      : 0;
                  
                  return Text(
                    '$productCount ${productCount == 1 ? 'product' : 'products'}',
                    style: AppTheme.captionStyle,
                    textAlign: TextAlign.center,
                  );
                },
              ),
              
              const SizedBox(height: AppTheme.spacing8),
              
              // Browse Button
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing12,
                  vertical: AppTheme.spacing4,
                ),
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Browse',
                  style: TextStyle(
                    color: category.color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.category_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No categories yet',
            style: AppTheme.titleStyle,
          ),
          const SizedBox(height: 8),
          Text(
            'Add some categories to organize your products!',
            style: AppTheme.bodyStyle.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _addSampleCategories(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Sample Categories'),
          ),
        ],
      ),
    );
  }


  Future<void> _addSampleCategories(BuildContext context) async {
    final sampleCategories = [
      {
        'id': 'electronics',
        'name': 'Electronics',
        'description': 'Phones, laptops, gadgets and more',
        'iconName': 'electronics',
        'colorName': 'blue',
        'isActive': true,
        'productCount': 0,
      },
      {
        'id': 'fashion',
        'name': 'Fashion',
        'description': 'Clothing, shoes, and accessories',
        'iconName': 'fashion',
        'colorName': 'pink',
        'isActive': true,
        'productCount': 0,
      },
      {
        'id': 'home',
        'name': 'Home & Garden',
        'description': 'Furniture, decor, and garden supplies',
        'iconName': 'home',
        'colorName': 'green',
        'isActive': true,
        'productCount': 0,
      },
      {
        'id': 'beauty',
        'name': 'Beauty',
        'description': 'Cosmetics, skincare, and personal care',
        'iconName': 'beauty',
        'colorName': 'purple',
        'isActive': true,
        'productCount': 0,
      },
      {
        'id': 'sports',
        'name': 'Sports',
        'description': 'Sports equipment and fitness gear',
        'iconName': 'sports',
        'colorName': 'orange',
        'isActive': true,
        'productCount': 0,
      },
      {
        'id': 'books',
        'name': 'Books',
        'description': 'Books, magazines, and educational materials',
        'iconName': 'books',
        'colorName': 'brown',
        'isActive': true,
        'productCount': 0,
      },
      {
        'id': 'automotive',
        'name': 'Automotive',
        'description': 'Car accessories and automotive parts',
        'iconName': 'automotive',
        'colorName': 'red',
        'isActive': true,
        'productCount': 0,
      },
      {
        'id': 'health',
        'name': 'Health',
        'description': 'Health products and medical supplies',
        'iconName': 'health',
        'colorName': 'teal',
        'isActive': true,
        'productCount': 0,
      },
    ];

    try {
      for (final categoryData in sampleCategories) {
        // Use the 'id' field as the document ID
        final categoryId = categoryData['id'] as String;
        final dataWithoutId = Map<String, dynamic>.from(categoryData);
        dataWithoutId.remove('id'); // Remove the id field from the data
        
        await FirebaseFirestore.instance
            .collection('categories')
            .doc(categoryId) // Set the document ID explicitly
            .set(dataWithoutId);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sample categories added with matching IDs!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding categories: $e')),
        );
      }
    }
  }
}