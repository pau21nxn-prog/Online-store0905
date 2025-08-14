import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentMethodType {
  gcash,
  cod, // Cash on Delivery
  bankTransfer,
  paypal,
  creditCard,
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
        orElse: () => PaymentMethodType.cod,
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
      case PaymentMethodType.cod:
        return 'Cash on Delivery';
      case PaymentMethodType.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethodType.paypal:
        return 'PayPal';
      case PaymentMethodType.creditCard:
        return 'Credit Card';
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
  final String phoneNumber;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String province;
  final String postalCode;
  final String country;
  final bool isDefault;

  ShippingAddress({
    required this.fullName,
    required this.phoneNumber,
    required this.addressLine1,
    this.addressLine2 = '',
    required this.city,
    required this.province,
    required this.postalCode,
    this.country = 'Philippines',
    this.isDefault = false,
  });

  factory ShippingAddress.fromMap(Map<String, dynamic> data) {
    return ShippingAddress(
      fullName: data['fullName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      addressLine1: data['addressLine1'] ?? '',
      addressLine2: data['addressLine2'] ?? '',
      city: data['city'] ?? '',
      province: data['province'] ?? '',
      postalCode: data['postalCode'] ?? '',
      country: data['country'] ?? 'Philippines',
      isDefault: data['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'province': province,
      'postalCode': postalCode,
      'country': country,
      'isDefault': isDefault,
    };
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