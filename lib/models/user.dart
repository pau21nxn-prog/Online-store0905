class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String? profileImageUrl;
  final DateTime createdAt;
  final bool isActive;
  final bool isAdmin;
  final UserType userType;
  final bool isAnonymous;
  final List<Address> addresses;
  final DateTime? lastSignIn;
  final bool emailVerified;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.profileImageUrl,
    required this.createdAt,
    required this.isActive,
    this.isAdmin = false,
    this.userType = UserType.buyer,
    this.isAnonymous = false,
    this.addresses = const [],
    this.lastSignIn,
    this.emailVerified = false,
  });

  // Factory for creating anonymous users
  factory UserModel.anonymous({
    required String id,
    required DateTime createdAt,
  }) {
    return UserModel(
      id: id,
      name: 'Guest User',
      email: '', // Anonymous users don't have email
      createdAt: createdAt,
      isActive: true,
      isAdmin: false,
      userType: UserType.guest,
      isAnonymous: true,
      emailVerified: false,
    );
  }

  // Factory for creating from Firebase Auth User
  factory UserModel.fromFirebaseUser(
    String id,
    String? displayName,
    String? email,
    bool isAnonymous,
  ) {
    return UserModel(
      id: id,
      name: displayName ?? (isAnonymous ? 'Guest User' : 'User'),
      email: email ?? '',
      createdAt: DateTime.now(),
      isActive: true,
      isAdmin: false,
      userType: isAnonymous ? UserType.guest : UserType.buyer,
      isAnonymous: isAnonymous,
      emailVerified: false,
    );
  }

  factory UserModel.fromFirestore(String id, Map<String, dynamic> data) {
    return UserModel(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'],
      profileImageUrl: data['profileImageUrl'],
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      isAdmin: data['isAdmin'] ?? false,
      userType: UserType.fromString(data['userType'] ?? 'buyer'),
      isAnonymous: data['isAnonymous'] ?? false,
      emailVerified: data['emailVerified'] ?? false,
      lastSignIn: data['lastSignIn']?.toDate(),
      addresses: (data['addresses'] as List<dynamic>?)
          ?.map((addr) => Address.fromMap(addr))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'createdAt': createdAt,
      'isActive': isActive,
      'isAdmin': isAdmin,
      'userType': userType.value,
      'isAnonymous': isAnonymous,
      'emailVerified': emailVerified,
      'lastSignIn': lastSignIn,
      'addresses': addresses.map((addr) => addr.toMap()).toList(),
    };
  }

  // Check if user has specific role
  bool get isBuyer => userType == UserType.buyer || userType == UserType.guest;
  bool get isGuest => userType == UserType.guest || isAnonymous;
  bool get isSeller => userType == UserType.seller;
  bool get isRegistered => !isAnonymous && email.isNotEmpty;

  // Check if user can perform admin actions
  bool get canAccessAdmin => isAdmin && !isAnonymous;

  // Check if user can make purchases
  bool get canPurchase => isActive && (isBuyer || isGuest);

  // Get user display name
  String get displayName {
    if (isAnonymous || name.isEmpty) {
      return 'Guest User';
    }
    return name;
  }

  // Get user role display text
  String get roleDisplayText {
    if (isAdmin) return 'Administrator';
    return userType.displayName;
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    String? profileImageUrl,
    DateTime? createdAt,
    bool? isActive,
    bool? isAdmin,
    UserType? userType,
    bool? isAnonymous,
    bool? emailVerified,
    DateTime? lastSignIn,
    List<Address>? addresses,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      isAdmin: isAdmin ?? this.isAdmin,
      userType: userType ?? this.userType,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      emailVerified: emailVerified ?? this.emailVerified,
      lastSignIn: lastSignIn ?? this.lastSignIn,
      addresses: addresses ?? this.addresses,
    );
  }
}

// User Type Enum
enum UserType {
  guest('guest', 'Guest User'),
  buyer('buyer', 'Buyer'),
  seller('seller', 'Seller'),
  admin('admin', 'Administrator');

  const UserType(this.value, this.displayName);

  final String value;
  final String displayName;

  static UserType fromString(String value) {
    return UserType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => UserType.buyer,
    );
  }
}

class Address {
  final String id;
  final String label; // Home, Work, etc.
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
    required this.id,
    required this.label,
    required this.fullName,
    required this.addressLine1,
    this.addressLine2 = '',
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
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
      state: data['state'] ?? '',
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
    return parts.join(', ');
  }

  Address copyWith({
    String? id,
    String? label,
    String? fullName,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? phoneNumber,
    bool? isDefault,
  }) {
    return Address(
      id: id ?? this.id,
      label: label ?? this.label,
      fullName: fullName ?? this.fullName,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}