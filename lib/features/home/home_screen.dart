import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../common/theme.dart';
import '../../models/product.dart';
import '../../services/cart_service.dart';
import '../../widgets/wishlist_button.dart';
import '../common/widgets/product_card.dart';
import '../product/product_detail_screen.dart';
import '../categories/category_list_screen.dart';
import '../search/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AnneDFinds'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SearchScreen(initialQuery: value),
                    ),
                  );
                }
              },
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SearchScreen(),
                  ),
                );
              },
              readOnly: true, // Make it read-only so it always navigates to search screen
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Category Pills (Quick Access)
          Container(
            height: 100,
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
              children: [
                _buildCategoryPill('Electronics', Icons.phone_android, Colors.blue, 'electronics'),
                _buildCategoryPill('Fashion', Icons.checkroom, Colors.pink, 'fashion'),
                _buildCategoryPill('Home', Icons.home, Colors.green, 'home'),
                _buildCategoryPill('Beauty', Icons.face, Colors.purple, 'beauty'),
                _buildCategoryPill('Sports', Icons.sports_basketball, Colors.orange, 'sports'),
                _buildCategoryPill('Books', Icons.menu_book, Colors.brown, 'books'),
              ],
            ),
          ),

          // Products Grid
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
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
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final products = snapshot.data!.docs
                    .map((doc) => Product.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
                    .toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _getCrossAxisCount(context),
                    childAspectRatio: 0.75, // Card height vs width ratio
                    crossAxisSpacing: AppTheme.spacing12,
                    mainAxisSpacing: AppTheme.spacing12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _buildProductCardWithWishlist(product);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSampleProduct,
        backgroundColor: AppTheme.primaryOrange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // NEW: Enhanced Product Card with Wishlist Button
  Widget _buildProductCardWithWishlist(Product product) {
    return Stack(
      children: [
        ProductCard(
          product: product,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailScreen(product: product),
              ),
            );
          },
        ),
        // Wishlist Button positioned at top-right
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
            child: WishlistButton(
              product: product,
              size: 20,
              onWishlistChanged: () {
                // Optional: Refresh the UI or show feedback
                setState(() {});
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPill(String name, IconData icon, Color color, String categoryId) {
    return Container(
      margin: const EdgeInsets.only(right: AppTheme.spacing12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryListScreen(
                categoryId: categoryId,
                categoryName: name,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(40),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              name,
              style: AppTheme.captionStyle.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No products yet',
            style: AppTheme.titleStyle,
          ),
          const SizedBox(height: 8),
          Text(
            'Add some products to get started!',
            style: AppTheme.bodyStyle.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addSampleProduct,
            icon: const Icon(Icons.add),
            label: const Text('Add Sample Product'),
          ),
        ],
      ),
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1024) return 6; // Desktop
    if (width > 480) return 4;  // Tablet
    return 2; // Mobile
  }

  void _showProductDetail(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.imageUrls.isNotEmpty)
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade100,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      product.imageUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                              Text('Image not available', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                  ),
                )
              else
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade100,
                  ),
                  child: const Center(
                    child: Icon(Icons.shopping_bag, size: 50, color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 16),
              Text(product.formattedPrice, style: AppTheme.priceStyle),
              const SizedBox(height: 8),
              Text(product.description),
              const SizedBox(height: 8),
              Text('Stock: ${product.stockQty}', style: AppTheme.captionStyle),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // FIXED: Added quantity parameter
                await CartService.addToCart(product, quantity: 1);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.name} added to cart!'),
                      backgroundColor: AppTheme.successGreen,
                      action: SnackBarAction(
                        label: 'View Cart',
                        textColor: Colors.white,
                        onPressed: () {
                          // Navigate to cart tab (index 2)
                          DefaultTabController.of(context)?.animateTo(2);
                        },
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding to cart: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.shopping_cart),
            label: const Text('Add to Cart'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSampleProduct() async {
    final sampleProducts = [
      {
        'name': 'iPhone 15 Pro',
        'description': 'Latest iPhone with titanium design and Action Button',
        'price': 65999.0,
        'categoryId': 'electronics', // Make sure this matches category ID
        'imageUrls': ['https://picsum.photos/400/400?random=1'],
        'stockQty': 25,
        'isActive': true,
        'createdAt': DateTime.now(),
        'sellerId': 'admin',
      },
      {
        'name': 'Samsung Galaxy Buds',
        'description': 'Wireless earbuds with noise cancellation',
        'price': 4999.0,
        'categoryId': 'electronics', // Electronics category
        'imageUrls': ['https://picsum.photos/400/400?random=2'],
        'stockQty': 50,
        'isActive': true,
        'createdAt': DateTime.now(),
        'sellerId': 'admin',
      },
      {
        'name': 'Nike Air Force 1',
        'description': 'Classic white sneakers for everyday wear',
        'price': 5995.0,
        'categoryId': 'fashion', // Fashion category
        'imageUrls': ['https://picsum.photos/400/400?random=3'],
        'stockQty': 30,
        'isActive': true,
        'createdAt': DateTime.now(),
        'sellerId': 'admin',
      },
      {
        'name': 'Wireless Mouse',
        'description': 'Ergonomic wireless mouse with long battery life',
        'price': 1299.0,
        'categoryId': 'electronics', // Electronics category
        'imageUrls': ['https://picsum.photos/400/400?random=4'],
        'stockQty': 75,
        'isActive': true,
        'createdAt': DateTime.now(),
        'sellerId': 'admin',
      },
      {
        'name': 'Coffee Mug',
        'description': 'Ceramic coffee mug with beautiful design',
        'price': 299.0,
        'categoryId': 'home', // Home category
        'imageUrls': ['https://picsum.photos/400/400?random=5'],
        'stockQty': 100,
        'isActive': true,
        'createdAt': DateTime.now(),
        'sellerId': 'admin',
      },
      {
        'name': 'Yoga Mat',
        'description': 'Non-slip yoga mat for comfortable workouts',
        'price': 899.0,
        'categoryId': 'sports', // Sports category
        'imageUrls': ['https://picsum.photos/400/400?random=6'],
        'stockQty': 40,
        'isActive': true,
        'createdAt': DateTime.now(),
        'sellerId': 'admin',
      },
      {
        'name': 'Face Cream',
        'description': 'Moisturizing face cream for all skin types',
        'price': 1599.0,
        'categoryId': 'beauty', // Beauty category
        'imageUrls': ['https://picsum.photos/400/400?random=7'],
        'stockQty': 60,
        'isActive': true,
        'createdAt': DateTime.now(),
        'sellerId': 'admin',
      },
      {
        'name': 'Programming Book',
        'description': 'Learn Flutter development step by step',
        'price': 2199.0,
        'categoryId': 'books', // Books category
        'imageUrls': ['https://picsum.photos/400/400?random=8'],
        'stockQty': 15,
        'isActive': true,
        'createdAt': DateTime.now(),
        'sellerId': 'admin',
      },
    ];

    try {
      for (final productData in sampleProducts) {
        await FirebaseFirestore.instance.collection('products').add(productData);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sample products with categories added!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding products: $e')),
        );
      }
    }
  }
}