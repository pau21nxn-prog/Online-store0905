import 'package:cloud_firestore/cloud_firestore.dart';

enum StockPolicy { deny, continuePolicy }

class InventoryInfo {
  final int available;
  final int reserved;

  const InventoryInfo({
    this.available = 0,
    this.reserved = 0,
  });

  factory InventoryInfo.fromMap(Map<String, dynamic> data) {
    return InventoryInfo(
      available: data['available'] ?? 0,
      reserved: data['reserved'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'available': available,
      'reserved': reserved,
    };
  }

  int get total => available + reserved;
  bool get isInStock => available > 0;
  bool get isLowStock => available <= 5; // Configurable threshold
}

class ProductVariant {
  final String id;
  final String productId;
  final String sku;
  final String? barcode;
  final Map<String, String> optionValues; // e.g., {"color": "Red", "size": "M"}
  final double price;
  final double? compareAtPrice;
  final StockPolicy stockPolicy;
  final InventoryInfo inventory;
  final List<String> mediaOrder; // Optional per-variant media override
  final bool isDefault;
  final double weight;
  final Map<String, dynamic> dimensions;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductVariant({
    required this.id,
    required this.productId,
    required this.sku,
    this.barcode,
    this.optionValues = const {},
    required this.price,
    this.compareAtPrice,
    this.stockPolicy = StockPolicy.deny,
    this.inventory = const InventoryInfo(),
    this.mediaOrder = const [],
    this.isDefault = false,
    this.weight = 0.0,
    this.dimensions = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductVariant.fromFirestore(String id, Map<String, dynamic> data) {
    return ProductVariant(
      id: id,
      productId: data['productId'] ?? '',
      sku: data['sku'] ?? '',
      barcode: data['barcode'],
      optionValues: Map<String, String>.from(data['optionValues'] ?? {}),
      price: (data['price'] ?? 0).toDouble(),
      compareAtPrice: data['compareAtPrice']?.toDouble(),
      stockPolicy: StockPolicy.values.firstWhere(
        (policy) => policy.name == data['stockPolicy'],
        orElse: () => StockPolicy.deny,
      ),
      inventory: InventoryInfo.fromMap(data['inventory'] ?? {}),
      mediaOrder: List<String>.from(data['mediaOrder'] ?? []),
      isDefault: data['isDefault'] ?? false,
      weight: (data['weight'] ?? 0).toDouble(),
      dimensions: Map<String, dynamic>.from(data['dimensions'] ?? {}),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'sku': sku,
      'barcode': barcode,
      'optionValues': optionValues,
      'price': price,
      'compareAtPrice': compareAtPrice,
      'stockPolicy': stockPolicy.name,
      'inventory': inventory.toMap(),
      'mediaOrder': mediaOrder,
      'isDefault': isDefault,
      'weight': weight,
      'dimensions': dimensions,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  String get formattedPrice => '₱${price.toStringAsFixed(2)}';
  
  String get formattedCompareAtPrice => 
      compareAtPrice != null ? '₱${compareAtPrice!.toStringAsFixed(2)}' : '';

  double? get discountAmount => 
      compareAtPrice != null ? compareAtPrice! - price : null;

  double? get discountPercentage => 
      compareAtPrice != null && compareAtPrice! > 0 
          ? ((compareAtPrice! - price) / compareAtPrice!) * 100 
          : null;

  String get variantDisplayName {
    if (optionValues.isEmpty) return sku;
    return optionValues.values.join(' / ');
  }

  bool get hasDiscount => compareAtPrice != null && compareAtPrice! > price;
  bool get isInStock => inventory.isInStock;
  bool get isLowStock => inventory.isLowStock;
  bool get canSellWhenOutOfStock => stockPolicy == StockPolicy.continuePolicy;

  ProductVariant copyWith({
    String? sku,
    String? barcode,
    Map<String, String>? optionValues,
    double? price,
    double? compareAtPrice,
    StockPolicy? stockPolicy,
    InventoryInfo? inventory,
    List<String>? mediaOrder,
    bool? isDefault,
    double? weight,
    Map<String, dynamic>? dimensions,
  }) {
    return ProductVariant(
      id: id,
      productId: productId,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      optionValues: optionValues ?? this.optionValues,
      price: price ?? this.price,
      compareAtPrice: compareAtPrice ?? this.compareAtPrice,
      stockPolicy: stockPolicy ?? this.stockPolicy,
      inventory: inventory ?? this.inventory,
      mediaOrder: mediaOrder ?? this.mediaOrder,
      isDefault: isDefault ?? this.isDefault,
      weight: weight ?? this.weight,
      dimensions: dimensions ?? this.dimensions,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class ProductOption {
  final String name; // e.g., "Color", "Size"
  final List<String> values; // e.g., ["Red", "Blue", "Green"]
  final int position;

  ProductOption({
    required this.name,
    required this.values,
    this.position = 0,
  });

  factory ProductOption.fromMap(Map<String, dynamic> data) {
    return ProductOption(
      name: data['name'] ?? '',
      values: List<String>.from(data['values'] ?? []),
      position: data['position'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'values': values,
      'position': position,
    };
  }
}

class VariantGenerator {
  static List<Map<String, String>> generateCombinations(List<ProductOption> options) {
    if (options.isEmpty) return [{}];
    
    List<Map<String, String>> combinations = [{}];
    
    for (final option in options) {
      final newCombinations = <Map<String, String>>[];
      
      for (final combination in combinations) {
        for (final value in option.values) {
          newCombinations.add({
            ...combination,
            option.name: value,
          });
        }
      }
      
      combinations = newCombinations;
    }
    
    return combinations;
  }

  static String generateSku(String baseCode, Map<String, String> optionValues) {
    final parts = [baseCode];
    
    // Sort by option name for consistency
    final sortedOptions = optionValues.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    for (final entry in sortedOptions) {
      // Take first 3 characters of each value, uppercase
      final shortValue = entry.value.toUpperCase().substring(0, 
          entry.value.length > 3 ? 3 : entry.value.length);
      parts.add(shortValue);
    }
    
    return parts.join('-');
  }
}