import 'package:cloud_firestore/cloud_firestore.dart';

class WishlistItem {
  final String id;
  final String userId;
  final String productId;
  final String productName;
  final double price;
  final String imageUrl;
  final DateTime addedAt;
  final bool isAvailable;

  WishlistItem({
    required this.id,
    required this.userId,
    required this.productId,
    required this.productName,
    required this.price,
    required this.imageUrl,
    required this.addedAt,
    required this.isAvailable,
  });

  factory WishlistItem.fromFirestore(String id, Map<String, dynamic> data) {
    return WishlistItem(
      id: id,
      userId: data['userId'] ?? '',
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      imageUrl: data['imageUrl'] ?? '',
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAvailable: data['isAvailable'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'productId': productId,
      'productName': productName,
      'price': price,
      'imageUrl': imageUrl,
      'addedAt': Timestamp.fromDate(addedAt),
      'isAvailable': isAvailable,
    };
  }

  String get formattedPrice => '₱${price.toStringAsFixed(2)}';

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(addedAt);

    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${difference.inDays > 60 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return 'Just added';
    }
  }
}