// Payment Models for AnnedFinds E-commerce Platform
// Using PayMongo as primary payment provider for Philippines market
// PCI DSS SAQ A compliant with hosted checkout approach

import 'package:cloud_firestore/cloud_firestore.dart';

// Payment Status Enums
enum PaymentStatus { 
  pending, 
  paid, 
  failed, 
  expired, 
  cancelled,
  refunded,
  disputed
}

enum PaymentMethod { 
  gcash, 
  gotyme,
  metrobank,
  bpi
}

enum OrderStatus {
  draft,
  awaiting_payment,
  paid,
  processing,
  shipped,
  delivered,
  completed,
  cancelled,
  refunded
}

// Core Payment Intent Model
class PaymentIntent {
  final String id;
  final String orderId;
  final String userId;
  final double amount;
  final String currency;
  final PaymentMethod method;
  final PaymentStatus status;
  final String provider;
  final String? providerIntentId;
  final String? clientSecret;
  final String? redirectUrl;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? failureReason;

  const PaymentIntent({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.amount,
    this.currency = 'PHP',
    required this.method,
    this.status = PaymentStatus.pending,
    this.provider = 'paymongo',
    this.providerIntentId,
    this.clientSecret,
    this.redirectUrl,
    this.metadata = const {},
    required this.createdAt,
    this.expiresAt,
    this.failureReason,
  });

  factory PaymentIntent.fromFirestore(String id, Map<String, dynamic> data) {
    return PaymentIntent(
      id: id,
      orderId: data['orderId'] ?? '',
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'PHP',
      method: PaymentMethod.values.firstWhere(
        (e) => e.name == data['method'],
        orElse: () => PaymentMethod.gcash,
      ),
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => PaymentStatus.pending,
      ),
      provider: data['provider'] ?? 'paymongo',
      providerIntentId: data['providerIntentId'],
      clientSecret: data['clientSecret'],
      redirectUrl: data['redirectUrl'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: data['expiresAt'] != null 
        ? (data['expiresAt'] as Timestamp).toDate() 
        : null,
      failureReason: data['failureReason'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'orderId': orderId,
      'userId': userId,
      'amount': amount,
      'currency': currency,
      'method': method.name,
      'status': status.name,
      'provider': provider,
      'providerIntentId': providerIntentId,
      'clientSecret': clientSecret,
      'redirectUrl': redirectUrl,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'failureReason': failureReason,
    };
  }

  PaymentIntent copyWith({
    String? id,
    String? orderId,
    String? userId,
    double? amount,
    String? currency,
    PaymentMethod? method,
    PaymentStatus? status,
    String? provider,
    String? providerIntentId,
    String? clientSecret,
    String? redirectUrl,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? failureReason,
  }) {
    return PaymentIntent(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      method: method ?? this.method,
      status: status ?? this.status,
      provider: provider ?? this.provider,
      providerIntentId: providerIntentId ?? this.providerIntentId,
      clientSecret: clientSecret ?? this.clientSecret,
      redirectUrl: redirectUrl ?? this.redirectUrl,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      failureReason: failureReason ?? this.failureReason,
    );
  }

  // Helper getters
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isPending => status == PaymentStatus.pending && !isExpired;
  bool get isSuccessful => status == PaymentStatus.paid;
  bool get isFailed => status == PaymentStatus.failed || isExpired;
  
  String get displayMethod {
    switch (method) {
      case PaymentMethod.gcash:
        return 'GCash';
      case PaymentMethod.gotyme:
        return 'GoTyme Bank';
      case PaymentMethod.metrobank:
        return 'Metrobank';
      case PaymentMethod.bpi:
        return 'BPI';
    }
  }

  String get formattedAmount => '₱${amount.toStringAsFixed(2)}';
}

// Payment Record Model (for completed payments)
class PaymentRecord {
  final String id;
  final String paymentIntentId;
  final String orderId;
  final String userId;
  final double amount;
  final String currency;
  final PaymentMethod method;
  final PaymentStatus status;
  final String provider;
  final String providerPaymentId;
  final String? providerCustomerId;
  final Map<String, dynamic> providerData;
  final double? fees;
  final double? netAmount;
  final DateTime paidAt;
  final DateTime? settledAt;
  final String? receiptUrl;
  final List<PaymentEvent> events;

  const PaymentRecord({
    required this.id,
    required this.paymentIntentId,
    required this.orderId,
    required this.userId,
    required this.amount,
    this.currency = 'PHP',
    required this.method,
    required this.status,
    this.provider = 'paymongo',
    required this.providerPaymentId,
    this.providerCustomerId,
    this.providerData = const {},
    this.fees,
    this.netAmount,
    required this.paidAt,
    this.settledAt,
    this.receiptUrl,
    this.events = const [],
  });

  factory PaymentRecord.fromFirestore(String id, Map<String, dynamic> data) {
    return PaymentRecord(
      id: id,
      paymentIntentId: data['paymentIntentId'] ?? '',
      orderId: data['orderId'] ?? '',
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'PHP',
      method: PaymentMethod.values.firstWhere(
        (e) => e.name == data['method'],
        orElse: () => PaymentMethod.gcash,
      ),
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => PaymentStatus.pending,
      ),
      provider: data['provider'] ?? 'paymongo',
      providerPaymentId: data['providerPaymentId'] ?? '',
      providerCustomerId: data['providerCustomerId'],
      providerData: Map<String, dynamic>.from(data['providerData'] ?? {}),
      fees: (data['fees'] ?? 0).toDouble(),
      netAmount: (data['netAmount'] ?? 0).toDouble(),
      paidAt: (data['paidAt'] as Timestamp).toDate(),
      settledAt: data['settledAt'] != null 
        ? (data['settledAt'] as Timestamp).toDate() 
        : null,
      receiptUrl: data['receiptUrl'],
      events: (data['events'] as List<dynamic>? ?? [])
        .map((e) => PaymentEvent.fromMap(Map<String, dynamic>.from(e)))
        .toList(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'paymentIntentId': paymentIntentId,
      'orderId': orderId,
      'userId': userId,
      'amount': amount,
      'currency': currency,
      'method': method.name,
      'status': status.name,
      'provider': provider,
      'providerPaymentId': providerPaymentId,
      'providerCustomerId': providerCustomerId,
      'providerData': providerData,
      'fees': fees,
      'netAmount': netAmount,
      'paidAt': Timestamp.fromDate(paidAt),
      'settledAt': settledAt != null ? Timestamp.fromDate(settledAt!) : null,
      'receiptUrl': receiptUrl,
      'events': events.map((e) => e.toMap()).toList(),
    };
  }

  String get formattedAmount => '₱${amount.toStringAsFixed(2)}';
  String get formattedFees => fees != null ? '₱${fees!.toStringAsFixed(2)}' : '₱0.00';
  String get formattedNetAmount => netAmount != null ? '₱${netAmount!.toStringAsFixed(2)}' : formattedAmount;
}

// Payment Event Model (for audit trail)
class PaymentEvent {
  final String type;
  final PaymentStatus? status;
  final String? message;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const PaymentEvent({
    required this.type,
    this.status,
    this.message,
    this.data = const {},
    required this.timestamp,
  });

  factory PaymentEvent.fromMap(Map<String, dynamic> data) {
    return PaymentEvent(
      type: data['type'] ?? '',
      status: data['status'] != null 
        ? PaymentStatus.values.firstWhere(
            (e) => e.name == data['status'],
            orElse: () => PaymentStatus.pending,
          )
        : null,
      message: data['message'],
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'status': status?.name,
      'message': message,
      'data': data,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

// Extended Order Model with Payment Integration
class PaymentOrder {
  final String id;
  final String userId;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double shipping;
  final double tax;
  final double discount;
  final double total;
  final OrderStatus status;
  final PaymentMethod? paymentMethod;
  final String? paymentIntentId;
  final String? paymentRecordId;
  final Map<String, dynamic> shipping_address;
  final Map<String, dynamic> billing_address;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? trackingNumber;
  final DateTime? estimatedDelivery;

  const PaymentOrder({
    required this.id,
    required this.userId,
    required this.items,
    required this.subtotal,
    this.shipping = 0.0,
    this.tax = 0.0,
    this.discount = 0.0,
    required this.total,
    this.status = OrderStatus.draft,
    this.paymentMethod,
    this.paymentIntentId,
    this.paymentRecordId,
    this.shipping_address = const {},
    this.billing_address = const {},
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.trackingNumber,
    this.estimatedDelivery,
  });

  factory PaymentOrder.fromFirestore(String id, Map<String, dynamic> data) {
    return PaymentOrder(
      id: id,
      userId: data['userId'] ?? '',
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
      subtotal: (data['subtotal'] ?? 0).toDouble(),
      shipping: (data['shipping'] ?? 0).toDouble(),
      tax: (data['tax'] ?? 0).toDouble(),
      discount: (data['discount'] ?? 0).toDouble(),
      total: (data['total'] ?? 0).toDouble(),
      status: OrderStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => OrderStatus.draft,
      ),
      paymentMethod: data['paymentMethod'] != null
        ? PaymentMethod.values.firstWhere(
            (e) => e.name == data['paymentMethod'],
            orElse: () => PaymentMethod.gcash,
          )
        : null,
      paymentIntentId: data['paymentIntentId'],
      paymentRecordId: data['paymentRecordId'],
      shipping_address: Map<String, dynamic>.from(data['shipping_address'] ?? {}),
      billing_address: Map<String, dynamic>.from(data['billing_address'] ?? {}),
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      trackingNumber: data['trackingNumber'],
      estimatedDelivery: data['estimatedDelivery'] != null 
        ? (data['estimatedDelivery'] as Timestamp).toDate() 
        : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'items': items,
      'subtotal': subtotal,
      'shipping': shipping,
      'tax': tax,
      'discount': discount,
      'total': total,
      'status': status.name,
      'paymentMethod': paymentMethod?.name,
      'paymentIntentId': paymentIntentId,
      'paymentRecordId': paymentRecordId,
      'shipping_address': shipping_address,
      'billing_address': billing_address,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'trackingNumber': trackingNumber,
      'estimatedDelivery': estimatedDelivery != null 
        ? Timestamp.fromDate(estimatedDelivery!) 
        : null,
    };
  }

  PaymentOrder copyWith({
    String? id,
    String? userId,
    List<Map<String, dynamic>>? items,
    double? subtotal,
    double? shipping,
    double? tax,
    double? discount,
    double? total,
    OrderStatus? status,
    PaymentMethod? paymentMethod,
    String? paymentIntentId,
    String? paymentRecordId,
    Map<String, dynamic>? shipping_address,
    Map<String, dynamic>? billing_address,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? trackingNumber,
    DateTime? estimatedDelivery,
  }) {
    return PaymentOrder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      shipping: shipping ?? this.shipping,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentIntentId: paymentIntentId ?? this.paymentIntentId,
      paymentRecordId: paymentRecordId ?? this.paymentRecordId,
      shipping_address: shipping_address ?? this.shipping_address,
      billing_address: billing_address ?? this.billing_address,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
    );
  }

  // Helper getters
  String get formattedSubtotal => '₱${subtotal.toStringAsFixed(2)}';
  String get formattedShipping => '₱${shipping.toStringAsFixed(2)}';
  String get formattedTax => '₱${tax.toStringAsFixed(2)}';
  String get formattedDiscount => '₱${discount.toStringAsFixed(2)}';
  String get formattedTotal => '₱${total.toStringAsFixed(2)}';
  
  bool get isPaid => status == OrderStatus.paid || 
                    status == OrderStatus.processing ||
                    status == OrderStatus.shipped ||
                    status == OrderStatus.delivered ||
                    status == OrderStatus.completed;
                    
  bool get canBeCancelled => status == OrderStatus.draft || 
                            status == OrderStatus.awaiting_payment;
                            
  bool get isActive => status != OrderStatus.cancelled && 
                      status != OrderStatus.completed &&
                      status != OrderStatus.refunded;

  int get itemCount => items.fold(0, (sum, item) => sum + (item['quantity'] as int? ?? 1));
}

// PayMongo specific models
class PayMongoConfig {
  final String publicKey;
  final String secretKey;
  final String webhookSecret;
  final bool isLiveMode;
  final String baseUrl;

  const PayMongoConfig({
    required this.publicKey,
    required this.secretKey,
    required this.webhookSecret,
    this.isLiveMode = false,
    this.baseUrl = 'https://api.paymongo.com/v1',
  });

  String get apiUrl => isLiveMode 
    ? 'https://api.paymongo.com/v1'
    : 'https://api.paymongo.com/v1';
}

// Webhook Event Model
class WebhookEvent {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final bool processed;
  final String? error;

  const WebhookEvent({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.processed = false,
    this.error,
  });

  factory WebhookEvent.fromMap(Map<String, dynamic> data) {
    return WebhookEvent(
      id: data['id'] ?? '',
      type: data['type'] ?? '',
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      timestamp: data['timestamp'] is Timestamp
        ? (data['timestamp'] as Timestamp).toDate()
        : DateTime.parse(data['timestamp'] ?? DateTime.now().toIso8601String()),
      processed: data['processed'] ?? false,
      error: data['error'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'data': data,
      'timestamp': Timestamp.fromDate(timestamp),
      'processed': processed,
      'error': error,
    };
  }
}