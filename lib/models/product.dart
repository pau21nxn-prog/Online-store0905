class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String categoryId;
  final List<String> imageUrls;
  final int stockQty;
  final bool isActive;
  final DateTime createdAt;
  final String? sellerId;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.imageUrls,
    required this.stockQty,
    required this.isActive,
    required this.createdAt,
    this.sellerId,
  });

  factory Product.fromFirestore(String id, Map<String, dynamic> data) {
    return Product(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      categoryId: data['categoryId'] ?? '',
      imageUrls: _parseImageUrls(data),
      stockQty: data['stockQty'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      sellerId: data['sellerId'],
    );
  }

  static List<String> _parseImageUrls(Map<String, dynamic> data) {
    // Handle different possible formats for images
    if (data['imageUrls'] != null) {
      return List<String>.from(data['imageUrls']);
    } else if (data['images'] != null && data['images'] is List) {
      return List<String>.from(data['images'].map((img) => 
        img is String ? img : (img['url'] ?? '')));
    }
    return [];
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'categoryId': categoryId,
      'imageUrls': imageUrls,
      'stockQty': stockQty,
      'isActive': isActive,
      'createdAt': createdAt,
      'sellerId': sellerId,
    };
  }

  String get formattedPrice => '₱${price.toStringAsFixed(2)}';
}