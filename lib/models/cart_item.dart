import 'package:cloud_firestore/cloud_firestore.dart';

class CartItem {
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final String imageUrl;
  final DateTime addedAt;
  
  // Variant information
  final String? selectedVariantId;
  final Map<String, String>? selectedOptions;
  final String? variantSku;
  final String? variantDisplayName;

  CartItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.addedAt,
    this.selectedVariantId,
    this.selectedOptions,
    this.variantSku,
    this.variantDisplayName,
  });

  factory CartItem.fromFirestore(String id, Map<String, dynamic> data) {
    return CartItem(
      productId: id,
      productName: data['productName'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      quantity: data['quantity'] ?? 1,
      imageUrl: data['imageUrl'] ?? '',
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      selectedVariantId: data['selectedVariantId'],
      selectedOptions: data['selectedOptions'] != null 
          ? Map<String, String>.from(data['selectedOptions']) 
          : null,
      variantSku: data['variantSku'],
      variantDisplayName: data['variantDisplayName'],
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = {
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'addedAt': Timestamp.fromDate(addedAt),
    };
    
    // Only add variant fields if they exist
    if (selectedVariantId != null) map['selectedVariantId'] = selectedVariantId!;
    if (selectedOptions != null) map['selectedOptions'] = selectedOptions!;
    if (variantSku != null) map['variantSku'] = variantSku!;
    if (variantDisplayName != null) map['variantDisplayName'] = variantDisplayName!;
    
    return map;
  }

  CartItem copyWith({
    String? productId,
    String? productName,
    double? price,
    int? quantity,
    String? imageUrl,
    DateTime? addedAt,
    String? selectedVariantId,
    Map<String, String>? selectedOptions,
    String? variantSku,
    String? variantDisplayName,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      addedAt: addedAt ?? this.addedAt,
      selectedVariantId: selectedVariantId ?? this.selectedVariantId,
      selectedOptions: selectedOptions ?? this.selectedOptions,
      variantSku: variantSku ?? this.variantSku,
      variantDisplayName: variantDisplayName ?? this.variantDisplayName,
    );
  }

  double get totalPrice => price * quantity;

  @override
  String toString() {
    return 'CartItem(productId: $productId, productName: $productName, price: $price, quantity: $quantity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItem && other.productId == productId;
  }

  @override
  int get hashCode => productId.hashCode;
}