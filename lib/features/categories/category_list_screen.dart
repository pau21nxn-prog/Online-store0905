import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../common/theme.dart';
import '../../common/mobile_layout_utils.dart';
import '../../models/product.dart';
import '../../services/auth_service.dart';
import '../common/widgets/product_card.dart';
import '../product/product_detail_screen.dart';
import '../search/search_screen.dart';

class CategoryListScreen extends StatelessWidget {
  final String categoryId;
  final String categoryName;

  const CategoryListScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName),
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
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('primaryCategoryId', isEqualTo: categoryId)
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(context);
          }

          final products = snapshot.data!.docs
              .map((doc) => Product.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
              .toList();

          return Column(
            children: [
              // Category Stats
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacing16),
                color: AppTheme.surfaceGray,
                child: Text(
                  '${products.length} products found in $categoryName',
                  style: AppTheme.bodyStyle.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),

              // Products Grid
              Expanded(
                child: Builder(
                  builder: (context) {
                    final currentUser = AuthService.currentUser;
                    final isAdmin = currentUser?.canAccessAdmin ?? false;
                    
                    return GridView.builder(
                      padding: MobileLayoutUtils.getMobilePadding(),
                      gridDelegate: MobileLayoutUtils.getProductGridDelegate(
                        isAdmin: isAdmin,
                        context: context,
                      ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ProductCard(
                      product: product,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailScreen(product: product),
                          ),
                        );
                      },
                    );
                  },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            'No products in $categoryName',
            style: AppTheme.titleStyle.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            'Check back later for new arrivals!',
            style: AppTheme.bodyStyle.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: AppTheme.spacing24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Browse Other Categories'),
          ),
        ],
      ),
    );
  }

}