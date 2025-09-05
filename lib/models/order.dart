import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum OrderStatus {
  pending,
  confirmed,
  processing,
  shipped,
  delivered,
  cancelled,
  refunded
}

// Note: PaymentMethod is now imported from payment.dart to avoid conflicts
// We'll import PaymentMethodType and convert as needed

class UserOrder {
  final String id;
  final String userId;
  final List<OrderItem> items;
  final double subtotal;
  final double shippingFee;
  final double tax;
  final double total;
  final OrderStatus status;
  final String paymentMethod; // Changed to String to avoid enum conflicts
  final bool isPaid;
  final Map<String, dynamic> shippingAddress; // Changed to Map for compatibility
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? confirmedAt;
  final DateTime? processingAt;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final String? trackingNumber;
  final String? notes;

  UserOrder({
    required this.id,
    required this.userId,
    required this.items,
    required this.subtotal,
    required this.shippingFee,
    this.tax = 0.0,
    required this.total,
    required this.status,
    required this.paymentMethod,
    this.isPaid = false,
    required this.shippingAddress,
    required this.createdAt,
    this.updatedAt,
    this.confirmedAt,
    this.processingAt,
    this.shippedAt,
    this.deliveredAt,
    this.cancelledAt,
    this.trackingNumber,
    this.notes,
  });

  factory UserOrder.fromFirestore(String id, Map<String, dynamic> data) {
    // DEBUG: Log UserOrder deserialization from Firestore
    debugPrint('🔍 DEBUG - EMAIL TRACKING: UserOrder.fromFirestore() called for order: $id');
    debugPrint('  - Firestore data keys: ${data.keys.toList()}');
    debugPrint('  - Contains shippingAddress: ${data.containsKey('shippingAddress')}');
    
    // DEBUG: Inspect shippingAddress field specifically
    if (data['shippingAddress'] != null) {
      final shippingAddressData = data['shippingAddress'] as Map<String, dynamic>;
      debugPrint('  - ShippingAddress data type: ${shippingAddressData.runtimeType}');
      debugPrint('  - ShippingAddress keys: ${shippingAddressData.keys.toList()}');
      debugPrint('  - ShippingAddress contains email: ${shippingAddressData.containsKey('email')}');
      debugPrint('  - ShippingAddress email value: "${shippingAddressData['email']}"');
    } else {
      debugPrint('  - ShippingAddress is null in Firestore data!');
    }

    final shippingAddressMap = Map<String, dynamic>.from(data['shippingAddress'] ?? {});
    
    final order = UserOrder(
      id: id,
      userId: data['userId'] ?? '',
      items: (data['items'] as List<dynamic>?)
          ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
          .toList() ?? [],
      subtotal: (data['subtotal'] ?? 0).toDouble(),
      shippingFee: (data['shippingFee'] ?? 0).toDouble(),
      tax: (data['tax'] ?? 0).toDouble(),
      total: (data['total'] ?? 0).toDouble(),
      status: OrderStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => OrderStatus.pending,
      ),
      paymentMethod: data['paymentMethod'] ?? 'cod',
      isPaid: data['isPaid'] ?? false,
      shippingAddress: shippingAddressMap,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      confirmedAt: (data['confirmedAt'] as Timestamp?)?.toDate(),
      processingAt: (data['processingAt'] as Timestamp?)?.toDate(),
      shippedAt: (data['shippedAt'] as Timestamp?)?.toDate(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
      trackingNumber: data['trackingNumber'],
      notes: data['notes'],
    );
    
    // DEBUG: Log the final UserOrder shippingAddress
    debugPrint('  - Final UserOrder shippingAddress keys: ${order.shippingAddress.keys.toList()}');
    debugPrint('  - Final UserOrder email: "${order.shippingAddress['email']}"');
    
    return order;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'shippingFee': shippingFee,
      'tax': tax,
      'total': total,
      'status': status.name,
      'paymentMethod': paymentMethod,
      'isPaid': isPaid,
      'shippingAddress': shippingAddress,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'trackingNumber': trackingNumber,
      'notes': notes,
    };
  }

  String get formattedTotal => '₱${total.toStringAsFixed(2)}';
  String get formattedSubtotal => '₱${subtotal.toStringAsFixed(2)}';
  String get formattedShippingFee => '₱${shippingFee.toStringAsFixed(2)}';

  String get statusDisplayName {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.shipped:
        return 'Shipped';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.refunded:
        return 'Refunded';
    }
  }

  String get paymentMethodDisplayName {
    switch (paymentMethod) {
      case 'cod':
        return 'Cash on Delivery';
      case 'gcash':
        return 'GCash';
      case 'card':
      case 'creditCard':
        return 'Credit/Debit Card';
      case 'bankTransfer':
        return 'Bank Transfer';
      case 'paypal':
        return 'PayPal';
      default:
        return paymentMethod.toUpperCase();
    }
  }

  // Helper method to get formatted shipping address
  String get formattedShippingAddress {
    final parts = [
      shippingAddress['addressLine1'] ?? '',
      if (shippingAddress['addressLine2']?.isNotEmpty == true) shippingAddress['addressLine2'],
      shippingAddress['city'] ?? '',
      shippingAddress['province'] ?? '',
      shippingAddress['postalCode'] ?? '',
      shippingAddress['country'] ?? 'Philippines',
    ];
    return parts.where((part) => part.isNotEmpty).join(', ');
  }
}

class OrderItem {
  final String productId;
  final String productName;
  final String productImage;
  final double price;
  final int quantity;
  final double total;
  
  // Variant information
  final String? selectedVariantId;
  final Map<String, String>? selectedOptions;
  final String? variantSku;
  final String? variantDisplayName;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.price,
    required this.quantity,
    double? total,
    this.selectedVariantId,
    this.selectedOptions,
    this.variantSku,
    this.variantDisplayName,
  }) : total = total ?? (price * quantity);

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    final price = (data['price'] ?? 0).toDouble();
    final quantity = data['quantity'] ?? 0;
    return OrderItem(
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      productImage: data['productImage'] ?? '',
      price: price,
      quantity: quantity,
      total: (data['total'] ?? (price * quantity)).toDouble(),
      selectedVariantId: data['selectedVariantId'],
      selectedOptions: data['selectedOptions'] != null 
          ? Map<String, String>.from(data['selectedOptions']) 
          : null,
      variantSku: data['variantSku'],
      variantDisplayName: data['variantDisplayName'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'price': price,
      'quantity': quantity,
      'total': total,
    };
    
    // Only add variant fields if they exist
    if (selectedVariantId != null) map['selectedVariantId'] = selectedVariantId!;
    if (selectedOptions != null) map['selectedOptions'] = selectedOptions!;
    if (variantSku != null) map['variantSku'] = variantSku!;
    if (variantDisplayName != null) map['variantDisplayName'] = variantDisplayName!;
    
    return map;
  }

  String get formattedPrice => '₱${price.toStringAsFixed(2)}';
  String get formattedTotal => '₱${total.toStringAsFixed(2)}';
}

// Simplified Address class for compatibility
class Address {
  final String id;
  final String label;
  final String fullName;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final String phoneNumber;
  final bool isDefault;

  Address({
    this.id = '',
    this.label = '',
    required this.fullName,
    required this.addressLine1,
    this.addressLine2 = '',
    required this.city,
    required this.state,
    required this.postalCode,
    this.country = 'Philippines',
    required this.phoneNumber,
    this.isDefault = false,
  });

  factory Address.fromMap(Map<String, dynamic> data) {
    return Address(
      id: data['id'] ?? '',
      label: data['label'] ?? '',
      fullName: data['fullName'] ?? '',
      addressLine1: data['addressLine1'] ?? '',
      addressLine2: data['addressLine2'] ?? '',
      city: data['city'] ?? '',
      state: data['state'] ?? data['province'] ?? '', // Handle both state and province
      postalCode: data['postalCode'] ?? '',
      country: data['country'] ?? 'Philippines',
      phoneNumber: data['phoneNumber'] ?? '',
      isDefault: data['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'fullName': fullName,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'state': state,
      'province': state, // Add province alias
      'postalCode': postalCode,
      'country': country,
      'phoneNumber': phoneNumber,
      'isDefault': isDefault,
    };
  }

  String get formattedAddress {
    final parts = [
      addressLine1,
      if (addressLine2.isNotEmpty) addressLine2,
      city,
      state,
      postalCode,
      country,
    ];
    return parts.where((part) => part.isNotEmpty).join(', ');
  }
}