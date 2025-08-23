import 'package:flutter/material.dart';

/// Enum for variant attribute types
enum VariantAttributeType {
  size,
  color,
  material,
  style,
  custom,
}

/// Extension for VariantAttributeType to provide display names and icons
extension VariantAttributeTypeExtension on VariantAttributeType {
  String get displayName {
    switch (this) {
      case VariantAttributeType.size:
        return 'Size';
      case VariantAttributeType.color:
        return 'Color';
      case VariantAttributeType.material:
        return 'Material';
      case VariantAttributeType.style:
        return 'Style';
      case VariantAttributeType.custom:
        return 'Custom';
    }
  }

  IconData get icon {
    switch (this) {
      case VariantAttributeType.size:
        return Icons.straighten;
      case VariantAttributeType.color:
        return Icons.palette;
      case VariantAttributeType.material:
        return Icons.category;
      case VariantAttributeType.style:
        return Icons.style;
      case VariantAttributeType.custom:
        return Icons.tune;
    }
  }

  /// Get default values for each attribute type
  List<String> get defaultValues {
    switch (this) {
      case VariantAttributeType.size:
        return ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
      case VariantAttributeType.color:
        return ['Red', 'Blue', 'Green', 'Black', 'White', 'Yellow', 'Orange', 'Purple', 'Pink', 'Brown'];
      case VariantAttributeType.material:
        return ['Cotton', 'Polyester', 'Silk', 'Wool', 'Leather', 'Plastic', 'Metal', 'Wood'];
      case VariantAttributeType.style:
        return ['Classic', 'Modern', 'Casual', 'Formal', 'Vintage', 'Minimalist'];
      case VariantAttributeType.custom:
        return [];
    }
  }
}

/// Model for variant option values (e.g., specific size, color)
class VariantOptionValue {
  final String id;
  final String value;
  final String? displayName;
  final String? colorHex; // For color attributes
  final Map<String, dynamic> metadata;
  final bool isActive;
  final int sortOrder;

  const VariantOptionValue({
    required this.id,
    required this.value,
    this.displayName,
    this.colorHex,
    this.metadata = const {},
    this.isActive = true,
    this.sortOrder = 0,
  });

  String get effectiveDisplayName => displayName ?? value;

  factory VariantOptionValue.fromMap(Map<String, dynamic> data, String id) {
    return VariantOptionValue(
      id: id,
      value: data['value'] ?? '',
      displayName: data['displayName'],
      colorHex: data['colorHex'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      isActive: data['isActive'] ?? true,
      sortOrder: data['sortOrder'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'value': value,
      'displayName': displayName,
      'colorHex': colorHex,
      'metadata': metadata,
      'isActive': isActive,
      'sortOrder': sortOrder,
    };
  }

  VariantOptionValue copyWith({
    String? value,
    String? displayName,
    String? colorHex,
    Map<String, dynamic>? metadata,
    bool? isActive,
    int? sortOrder,
  }) {
    return VariantOptionValue(
      id: id,
      value: value ?? this.value,
      displayName: displayName ?? this.displayName,
      colorHex: colorHex ?? this.colorHex,
      metadata: metadata ?? this.metadata,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Color? get color {
    if (colorHex != null && colorHex!.isNotEmpty) {
      try {
        String hexColor = colorHex!.replaceAll('#', '');
        if (hexColor.length == 6) {
          hexColor = 'FF$hexColor'; // Add alpha if not present
        }
        return Color(int.parse(hexColor, radix: 16));
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}

/// Model for variant attributes (e.g., Size, Color)
class VariantAttribute {
  final String id;
  final String name;
  final VariantAttributeType type;
  final List<VariantOptionValue> values;
  final bool isRequired;
  final bool allowCustomValues;
  final int position;
  final bool isActive;

  const VariantAttribute({
    required this.id,
    required this.name,
    required this.type,
    this.values = const [],
    this.isRequired = false,
    this.allowCustomValues = false,
    this.position = 0,
    this.isActive = true,
  });

  factory VariantAttribute.fromMap(Map<String, dynamic> data, String id) {
    final valuesData = data['values'] as List<dynamic>? ?? [];
    final values = valuesData.asMap().entries.map((entry) {
      if (entry.value is Map<String, dynamic>) {
        return VariantOptionValue.fromMap(entry.value, entry.key.toString());
      } else if (entry.value is String) {
        // Support simple string values for backward compatibility
        return VariantOptionValue(
          id: entry.key.toString(),
          value: entry.value,
          sortOrder: entry.key,
        );
      } else {
        throw FormatException('Invalid value format in VariantAttribute');
      }
    }).toList();

    return VariantAttribute(
      id: id,
      name: data['name'] ?? '',
      type: VariantAttributeType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => VariantAttributeType.custom,
      ),
      values: values,
      isRequired: data['isRequired'] ?? false,
      allowCustomValues: data['allowCustomValues'] ?? false,
      position: data['position'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.name,
      'values': values.map((v) => v.toMap()).toList(),
      'isRequired': isRequired,
      'allowCustomValues': allowCustomValues,
      'position': position,
      'isActive': isActive,
    };
  }

  List<VariantOptionValue> get activeValues => 
      values.where((v) => v.isActive).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  VariantAttribute copyWith({
    String? name,
    VariantAttributeType? type,
    List<VariantOptionValue>? values,
    bool? isRequired,
    bool? allowCustomValues,
    int? position,
    bool? isActive,
  }) {
    return VariantAttribute(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      values: values ?? this.values,
      isRequired: isRequired ?? this.isRequired,
      allowCustomValues: allowCustomValues ?? this.allowCustomValues,
      position: position ?? this.position,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Create a default attribute for a given type
  static VariantAttribute createDefault(VariantAttributeType type, {String? customName}) {
    final name = customName ?? type.displayName;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    final values = type.defaultValues.asMap().entries.map((entry) {
      return VariantOptionValue(
        id: entry.key.toString(),
        value: entry.value,
        sortOrder: entry.key,
      );
    }).toList();

    return VariantAttribute(
      id: id,
      name: name,
      type: type,
      values: values,
      isRequired: type == VariantAttributeType.size || type == VariantAttributeType.color,
      allowCustomValues: type == VariantAttributeType.custom,
    );
  }
}

/// Model for configured variant combinations
class VariantConfiguration {
  final String id;
  final Map<String, String> attributeValues; // attribute_id -> value
  final double price;
  final double? compareAtPrice;
  final int quantity;
  final String? sku;
  final bool isActive;
  final int sortOrder;

  const VariantConfiguration({
    required this.id,
    required this.attributeValues,
    required this.price,
    this.compareAtPrice,
    required this.quantity,
    this.sku,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory VariantConfiguration.fromMap(Map<String, dynamic> data, String id) {
    return VariantConfiguration(
      id: id,
      attributeValues: Map<String, String>.from(data['attributeValues'] ?? {}),
      price: (data['price'] ?? 0.0).toDouble(),
      compareAtPrice: data['compareAtPrice']?.toDouble(),
      quantity: data['quantity'] ?? 0,
      sku: data['sku'],
      isActive: data['isActive'] ?? true,
      sortOrder: data['sortOrder'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'attributeValues': attributeValues,
      'price': price,
      'compareAtPrice': compareAtPrice,
      'quantity': quantity,
      'sku': sku,
      'isActive': isActive,
      'sortOrder': sortOrder,
    };
  }

  String get displayName {
    final values = attributeValues.values.toList();
    return values.isEmpty ? 'Default' : values.join(' / ');
  }

  String get formattedPrice => '₱${price.toStringAsFixed(2)}';
  
  String get formattedCompareAtPrice => 
      compareAtPrice != null ? '₱${compareAtPrice!.toStringAsFixed(2)}' : '';

  bool get hasDiscount => compareAtPrice != null && compareAtPrice! > price;
  
  bool get isInStock => quantity > 0;
  
  bool get isLowStock => quantity <= 5 && quantity > 0;

  VariantConfiguration copyWith({
    Map<String, String>? attributeValues,
    double? price,
    double? compareAtPrice,
    int? quantity,
    String? sku,
    bool? isActive,
    int? sortOrder,
  }) {
    return VariantConfiguration(
      id: id,
      attributeValues: attributeValues ?? this.attributeValues,
      price: price ?? this.price,
      compareAtPrice: compareAtPrice ?? this.compareAtPrice,
      quantity: quantity ?? this.quantity,
      sku: sku ?? this.sku,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Generate auto SKU based on base code and attributes
  static String generateSku(String baseCode, Map<String, String> attributeValues) {
    final parts = [baseCode];
    
    // Sort by attribute name for consistency
    final sortedAttributes = attributeValues.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    for (final entry in sortedAttributes) {
      // Take first 3 characters of each value, uppercase
      final value = entry.value.toUpperCase();
      final shortValue = value.length > 3 ? value.substring(0, 3) : value;
      parts.add(shortValue);
    }
    
    return parts.join('-');
  }
}