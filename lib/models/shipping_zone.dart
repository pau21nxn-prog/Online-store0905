import 'package:cloud_firestore/cloud_firestore.dart';

enum ShippingZone {
  manila,
  luzon,
  visayas,
  mindanao,
  islands;

  String get displayName {
    switch (this) {
      case ShippingZone.manila:
        return 'Metro Manila';
      case ShippingZone.luzon:
        return 'Luzon';
      case ShippingZone.visayas:
        return 'Visayas';
      case ShippingZone.mindanao:
        return 'Mindanao';
      case ShippingZone.islands:
        return 'Islands';
    }
  }

  static ShippingZone fromString(String value) {
    return ShippingZone.values.firstWhere(
      (zone) => zone.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ShippingZone.luzon, // Default fallback
    );
  }
}

enum WeightTier {
  tier0_500g,   // 0g - 500g
  tier500g_1kg, // 501g - 1kg
  tier1_2kg,    // 1.1kg - 2kg
  tier2_3kg,    // 2.1kg - 3kg
  tier3_4kg,    // 3.1kg - 4kg
  tier4_5kg,    // 4.1kg - 5kg
  tier5_6kg,    // 5.1kg - 6kg
  tierOver6kg;  // Over 6kg

  String get displayName {
    switch (this) {
      case WeightTier.tier0_500g:
        return '0g - 500g';
      case WeightTier.tier500g_1kg:
        return '501g - 1kg';
      case WeightTier.tier1_2kg:
        return '1.1kg - 2kg';
      case WeightTier.tier2_3kg:
        return '2.1kg - 3kg';
      case WeightTier.tier3_4kg:
        return '3.1kg - 4kg';
      case WeightTier.tier4_5kg:
        return '4.1kg - 5kg';
      case WeightTier.tier5_6kg:
        return '5.1kg - 6kg';
      case WeightTier.tierOver6kg:
        return 'Over 6kg';
    }
  }

  double get maxWeight {
    switch (this) {
      case WeightTier.tier0_500g:
        return 0.5;
      case WeightTier.tier500g_1kg:
        return 1.0;
      case WeightTier.tier1_2kg:
        return 2.0;
      case WeightTier.tier2_3kg:
        return 3.0;
      case WeightTier.tier3_4kg:
        return 4.0;
      case WeightTier.tier4_5kg:
        return 5.0;
      case WeightTier.tier5_6kg:
        return 6.0;
      case WeightTier.tierOver6kg:
        return double.infinity;
    }
  }

  static WeightTier getWeightTier(double weightInKg) {
    if (weightInKg <= 0.5) return WeightTier.tier0_500g;
    if (weightInKg <= 1.0) return WeightTier.tier500g_1kg;
    if (weightInKg <= 2.0) return WeightTier.tier1_2kg;
    if (weightInKg <= 3.0) return WeightTier.tier2_3kg;
    if (weightInKg <= 4.0) return WeightTier.tier3_4kg;
    if (weightInKg <= 5.0) return WeightTier.tier4_5kg;
    if (weightInKg <= 6.0) return WeightTier.tier5_6kg;
    return WeightTier.tierOver6kg;
  }
}

class ShippingRate {
  final String id;
  final ShippingZone fromZone;
  final ShippingZone toZone;
  final WeightTier weightTier;
  final double rate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShippingRate({
    required this.id,
    required this.fromZone,
    required this.toZone,
    required this.weightTier,
    required this.rate,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShippingRate.fromFirestore(String id, Map<String, dynamic> data) {
    return ShippingRate(
      id: id,
      fromZone: ShippingZone.fromString(data['fromZone'] ?? 'luzon'),
      toZone: ShippingZone.fromString(data['toZone'] ?? 'luzon'),
      weightTier: WeightTier.values.firstWhere(
        (tier) => tier.name == data['weightTier'],
        orElse: () => WeightTier.tier0_500g,
      ),
      rate: (data['rate'] ?? 0.0).toDouble(),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fromZone': fromZone.name,
      'toZone': toZone.name,
      'weightTier': weightTier.name,
      'rate': rate,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  String get formattedRate => '₱${rate.toStringAsFixed(2)}';

  ShippingRate copyWith({
    String? id,
    ShippingZone? fromZone,
    ShippingZone? toZone,
    WeightTier? weightTier,
    double? rate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShippingRate(
      id: id ?? this.id,
      fromZone: fromZone ?? this.fromZone,
      toZone: toZone ?? this.toZone,
      weightTier: weightTier ?? this.weightTier,
      rate: rate ?? this.rate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ShippingCalculation {
  final double weight;
  final ShippingZone fromZone;
  final ShippingZone toZone;
  final WeightTier weightTier;
  final double shippingFee;
  final bool isFreeShipping;
  final String calculationMethod;
  final DateTime calculatedAt;

  const ShippingCalculation({
    required this.weight,
    required this.fromZone,
    required this.toZone,
    required this.weightTier,
    required this.shippingFee,
    required this.isFreeShipping,
    required this.calculationMethod,
    required this.calculatedAt,
  });

  String get formattedShippingFee => isFreeShipping ? 'FREE' : '₱${shippingFee.toStringAsFixed(2)}';
  
  Map<String, dynamic> toMap() {
    return {
      'weight': weight,
      'fromZone': fromZone.name,
      'toZone': toZone.name,
      'weightTier': weightTier.name,
      'shippingFee': shippingFee,
      'isFreeShipping': isFreeShipping,
      'calculationMethod': calculationMethod,
      'calculatedAt': calculatedAt.toIso8601String(),
    };
  }
}

class ProvinceMapping {
  static const Map<String, ShippingZone> _provinceToZone = {
    // Metro Manila
    'metro manila': ShippingZone.manila,
    'manila': ShippingZone.manila,
    'quezon city': ShippingZone.manila,
    'makati': ShippingZone.manila,
    'mandaluyong': ShippingZone.manila,
    'pasig': ShippingZone.manila,
    'taguig': ShippingZone.manila,
    'muntinlupa': ShippingZone.manila,
    'paranaque': ShippingZone.manila,
    'las pinas': ShippingZone.manila,
    'caloocan': ShippingZone.manila,
    'malabon': ShippingZone.manila,
    'navotas': ShippingZone.manila,
    'valenzuela': ShippingZone.manila,
    'marikina': ShippingZone.manila,
    'pasay': ShippingZone.manila,
    'san juan': ShippingZone.manila,

    // Luzon
    'bataan': ShippingZone.luzon,
    'batangas': ShippingZone.luzon,
    'bulacan': ShippingZone.luzon,
    'cavite': ShippingZone.luzon,
    'laguna': ShippingZone.luzon,
    'nueva ecija': ShippingZone.luzon,
    'pampanga': ShippingZone.luzon,
    'rizal': ShippingZone.luzon,
    'tarlac': ShippingZone.luzon,
    'zambales': ShippingZone.luzon,
    'albay': ShippingZone.luzon,
    'camarines norte': ShippingZone.luzon,
    'camarines sur': ShippingZone.luzon,
    'catanduanes': ShippingZone.luzon,
    'masbate': ShippingZone.luzon,
    'sorsogon': ShippingZone.luzon,
    'abra': ShippingZone.luzon,
    'apayao': ShippingZone.luzon,
    'benguet': ShippingZone.luzon,
    'ifugao': ShippingZone.luzon,
    'kalinga': ShippingZone.luzon,
    'mountain province': ShippingZone.luzon,
    'ilocos norte': ShippingZone.luzon,
    'ilocos sur': ShippingZone.luzon,
    'la union': ShippingZone.luzon,
    'pangasinan': ShippingZone.luzon,
    'aurora': ShippingZone.luzon,
    'batanes': ShippingZone.luzon,
    'cagayan': ShippingZone.luzon,
    'isabela': ShippingZone.luzon,
    'nueva vizcaya': ShippingZone.luzon,
    'quirino': ShippingZone.luzon,
    'marinduque': ShippingZone.luzon,
    'occidental mindoro': ShippingZone.luzon,
    'oriental mindoro': ShippingZone.luzon,
    'romblon': ShippingZone.luzon,

    // Visayas
    'aklan': ShippingZone.visayas,
    'antique': ShippingZone.visayas,
    'capiz': ShippingZone.visayas,
    'guimaras': ShippingZone.visayas,
    'iloilo': ShippingZone.visayas,
    'negros occidental': ShippingZone.visayas,
    'bohol': ShippingZone.visayas,
    'cebu': ShippingZone.visayas,
    'negros oriental': ShippingZone.visayas,
    'siquijor': ShippingZone.visayas,
    'biliran': ShippingZone.visayas,
    'eastern samar': ShippingZone.visayas,
    'leyte': ShippingZone.visayas,
    'northern samar': ShippingZone.visayas,
    'samar': ShippingZone.visayas,
    'southern leyte': ShippingZone.visayas,

    // Mindanao
    'agusan del norte': ShippingZone.mindanao,
    'agusan del sur': ShippingZone.mindanao,
    'butuan': ShippingZone.mindanao,
    'surigao del norte': ShippingZone.mindanao,
    'surigao del sur': ShippingZone.mindanao,
    'compostela valley': ShippingZone.mindanao,
    'davao del norte': ShippingZone.mindanao,
    'davao del sur': ShippingZone.mindanao,
    'davao occidental': ShippingZone.mindanao,
    'davao oriental': ShippingZone.mindanao,
    'bukidnon': ShippingZone.mindanao,
    'camiguin': ShippingZone.mindanao,
    'lanao del norte': ShippingZone.mindanao,
    'misamis occidental': ShippingZone.mindanao,
    'misamis oriental': ShippingZone.mindanao,
    'cotabato': ShippingZone.mindanao,
    'sarangani': ShippingZone.mindanao,
    'south cotabato': ShippingZone.mindanao,
    'sultan kudarat': ShippingZone.mindanao,
    'lanao del sur': ShippingZone.mindanao,
    'maguindanao': ShippingZone.mindanao,
    'basilan': ShippingZone.mindanao,
    'sulu': ShippingZone.mindanao,
    'tawi-tawi': ShippingZone.mindanao,
    'zamboanga del norte': ShippingZone.mindanao,
    'zamboanga del sur': ShippingZone.mindanao,
    'zamboanga sibugay': ShippingZone.mindanao,

    // Islands (Special cases)
    'palawan': ShippingZone.islands,
  };

  static ShippingZone getZoneForProvince(String province) {
    final normalizedProvince = province.toLowerCase().trim();
    return _provinceToZone[normalizedProvince] ?? ShippingZone.luzon;
  }

  static List<String> getProvincesForZone(ShippingZone zone) {
    return _provinceToZone.entries
        .where((entry) => entry.value == zone)
        .map((entry) => entry.key)
        .toList();
  }

  static Map<String, ShippingZone> get allMappings => _provinceToZone;
}