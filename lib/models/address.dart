import 'package:cloud_firestore/cloud_firestore.dart';

class Address {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String streetAddress;
  final String apartmentSuite;
  final String city;
  final String province;
  final String postalCode;
  final String deliveryInstructions;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Address({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.streetAddress,
    this.apartmentSuite = '',
    required this.city,
    required this.province,
    required this.postalCode,
    this.deliveryInstructions = '',
    this.isDefault = false,
    required this.createdAt,
    this.updatedAt,
  });

  // Create from Firestore document
  factory Address.fromFirestore(String id, Map<String, dynamic> data) {
    return Address(
      id: id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      streetAddress: data['streetAddress'] ?? '',
      apartmentSuite: data['apartmentSuite'] ?? '',
      city: data['city'] ?? '',
      province: data['province'] ?? '',
      postalCode: data['postalCode'] ?? '',
      deliveryInstructions: data['deliveryInstructions'] ?? '',
      isDefault: data['isDefault'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'streetAddress': streetAddress,
      'apartmentSuite': apartmentSuite,
      'city': city,
      'province': province,
      'postalCode': postalCode,
      'deliveryInstructions': deliveryInstructions,
      'isDefault': isDefault,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Get formatted address for display
  String get formattedAddress {
    final parts = <String>[];
    parts.add(streetAddress);
    if (apartmentSuite.isNotEmpty) parts.add(apartmentSuite);
    parts.add('$city, $province $postalCode');
    return parts.join(', ');
  }

  // Get short address for cards
  String get shortAddress {
    return '$streetAddress, $city';
  }

  // Copy with method for updates
  Address copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? streetAddress,
    String? apartmentSuite,
    String? city,
    String? province,
    String? postalCode,
    String? deliveryInstructions,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Address(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      streetAddress: streetAddress ?? this.streetAddress,
      apartmentSuite: apartmentSuite ?? this.apartmentSuite,
      city: city ?? this.city,
      province: province ?? this.province,
      postalCode: postalCode ?? this.postalCode,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Address(id: $id, fullName: $fullName, shortAddress: $shortAddress)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Address && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}