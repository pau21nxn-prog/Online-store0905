import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentMethodType {
  gcash,
  gotyme,
  metrobank,
  bpi,
}

enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
  refunded,
  cancelled,
}

class Payment {
  final String id;
  final String orderId;
  final String userId;
  final double amount;
  final PaymentMethodType method;
  final PaymentStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final Map<String, dynamic> metadata;
  final String? transactionId;
  final String? referenceNumber;

  Payment({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.metadata = const {},
    this.transactionId,
    this.referenceNumber,
  });

  factory Payment.fromFirestore(String id, Map<String, dynamic> data) {
    return Payment(
      id: id,
      orderId: data['orderId'] ?? '',
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      method: PaymentMethodType.values.firstWhere(
        (e) => e.toString().split('.').last == data['method'],
        orElse: () => PaymentMethodType.gcash,
      ),
      status: PaymentStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => PaymentStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      transactionId: data['transactionId'],
      referenceNumber: data['referenceNumber'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'orderId': orderId,
      'userId': userId,
      'amount': amount,
      'method': method.toString().split('.').last,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'metadata': metadata,
      'transactionId': transactionId,
      'referenceNumber': referenceNumber,
    };
  }

  String get methodDisplayName {
    switch (method) {
      case PaymentMethodType.gcash:
        return 'GCash';
      case PaymentMethodType.gotyme:
        return 'GoTyme Bank';
      case PaymentMethodType.metrobank:
        return 'Metrobank';
      case PaymentMethodType.bpi:
        return 'BPI';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.processing:
        return 'Processing';
      case PaymentStatus.completed:
        return 'Completed';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
      case PaymentStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get statusColor {
    switch (status) {
      case PaymentStatus.pending:
        return Colors.orange;
      case PaymentStatus.processing:
        return Colors.blue;
      case PaymentStatus.completed:
        return Colors.green;
      case PaymentStatus.failed:
        return Colors.red;
      case PaymentStatus.refunded:
        return Colors.purple;
      case PaymentStatus.cancelled:
        return Colors.grey;
    }
  }
}

class ShippingAddress {
  final String fullName;
  final String email;
  final String phoneNumber;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String province;
  final String postalCode;
  final String country;
  final String deliveryInstructions;
  final bool isDefault;

  ShippingAddress({
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.addressLine1,
    this.addressLine2 = '',
    required this.city,
    required this.province,
    required this.postalCode,
    this.country = 'Philippines',
    this.deliveryInstructions = '',
    this.isDefault = false,
  });

  factory ShippingAddress.fromMap(Map<String, dynamic> data) {
    // DEBUG: Log what data is being received for deserialization
    debugPrint('🔍 DEBUG - EMAIL TRACKING: ShippingAddress.fromMap() called');
    debugPrint('  - Input data keys: ${data.keys.toList()}');
    debugPrint('  - Input data contains email: ${data.containsKey('email')}');
    debugPrint('  - Input email value: "${data['email']}"');
    debugPrint('  - Complete input data: $data');
    
    final shippingAddress = ShippingAddress(
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      addressLine1: data['addressLine1'] ?? '',
      addressLine2: data['addressLine2'] ?? '',
      city: data['city'] ?? '',
      province: data['province'] ?? '',
      postalCode: data['postalCode'] ?? '',
      country: data['country'] ?? 'Philippines',
      deliveryInstructions: data['deliveryInstructions'] ?? '',
      isDefault: data['isDefault'] ?? false,
    );
    
    // DEBUG: Log the resulting ShippingAddress object
    debugPrint('  - Created ShippingAddress with email: "${shippingAddress.email}"');
    
    return shippingAddress;
  }

  Map<String, dynamic> toMap() {
    // DEBUG: Validate email field before serialization
    debugPrint('🔍 DEBUG - EMAIL TRACKING: ShippingAddress.toMap() called');
    debugPrint('  - Email field value: "$email"');
    debugPrint('  - Email is empty: ${email.isEmpty}');
    debugPrint('  - Email is null: ${email == null}');
    
    final map = {
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'province': province,
      'postalCode': postalCode,
      'country': country,
      'deliveryInstructions': deliveryInstructions,
      'isDefault': isDefault,
    };
    
    // DEBUG: Verify email is included in the result map
    debugPrint('  - Map contains email key: ${map.containsKey('email')}');
    debugPrint('  - Map email value: "${map['email']}"');
    debugPrint('  - Complete map keys: ${map.keys.toList()}');
    
    // Additional validation: Ensure email is not empty when creating shipping address
    if (email.isEmpty) {
      debugPrint('⚠️ WARNING - EMAIL TRACKING: Email is empty in ShippingAddress.toMap()!');
    }
    
    return map;
  }

  String get formattedAddress {
    final parts = [
      addressLine1,
      if (addressLine2.isNotEmpty) addressLine2,
      city,
      province,
      postalCode,
      country,
    ];
    return parts.join(', ');
  }
}