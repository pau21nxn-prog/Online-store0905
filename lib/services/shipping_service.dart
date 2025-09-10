import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/shipping_zone.dart';

class ShippingConfig {
  final double freeShippingThreshold;
  final double fallbackRate;
  final bool enableFreeShipping;
  final ShippingZone defaultFromZone;

  const ShippingConfig({
    this.freeShippingThreshold = 3000.0,  // Updated to match your global settings
    this.fallbackRate = 49.0,             // Updated to match your global settings
    this.enableFreeShipping = true,
    this.defaultFromZone = ShippingZone.manila,
  });

  factory ShippingConfig.fromFirestore(Map<String, dynamic> data) {
    return ShippingConfig(
      freeShippingThreshold: (data['freeShippingThreshold'] ?? 3000.0).toDouble(),  // Updated to match your global settings
      fallbackRate: (data['fallbackRate'] ?? 49.0).toDouble(),                      // Updated to match your global settings
      enableFreeShipping: data['enableFreeShipping'] ?? true,
      defaultFromZone: ShippingZone.fromString(data['defaultFromZone'] ?? 'manila'),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'freeShippingThreshold': freeShippingThreshold,
      'fallbackRate': fallbackRate,
      'enableFreeShipping': enableFreeShipping,
      'defaultFromZone': defaultFromZone.name,
    };
  }
}

class ProductShippingOverride {
  final String productId;
  final double? customRate;
  final bool? freeShipping;
  final double? customWeight;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductShippingOverride({
    required this.productId,
    this.customRate,
    this.freeShipping,
    this.customWeight,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductShippingOverride.fromFirestore(String id, Map<String, dynamic> data) {
    return ProductShippingOverride(
      productId: id,
      customRate: data['customRate']?.toDouble(),
      freeShipping: data['freeShipping'],
      customWeight: data['customWeight']?.toDouble(),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customRate': customRate,
      'freeShipping': freeShipping,
      'customWeight': customWeight,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class ShippingService {
  static final ShippingService _instance = ShippingService._internal();
  factory ShippingService() => _instance;
  ShippingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache for shipping rates and config
  Map<String, ShippingRate>? _ratesCache;
  ShippingConfig? _configCache;
  Map<String, ProductShippingOverride>? _overridesCache;
  DateTime? _cacheTimestamp;
  
  // Cache duration (5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Calculate shipping fee for a given order
  Future<ShippingCalculation> calculateShippingFee({
    required double subtotal,
    required double totalWeight,
    required String destinationProvince,
    String? destinationCity,
    String fromZone = 'manila',
    String? productId,
  }) async {
    try {
      debugPrint('Calculating shipping for: weight=$totalWeight, destination=$destinationProvince');
      
      // Get shipping configuration
      final config = await getShippingConfig();
      
      // Check for free shipping threshold
      if (config.enableFreeShipping && subtotal >= config.freeShippingThreshold) {
        return ShippingCalculation(
          weight: totalWeight,
          fromZone: ShippingZone.fromString(fromZone),
          toZone: ProvinceMapping.getZoneForProvince(destinationProvince),
          weightTier: WeightTier.getWeightTier(totalWeight),
          shippingFee: 0.0,
          isFreeShipping: true,
          calculationMethod: 'Free shipping threshold (₱${config.freeShippingThreshold}+)',
          calculatedAt: DateTime.now(),
        );
      }

      // Check for product-specific override
      if (productId != null) {
        final override = await getProductShippingOverride(productId);
        if (override != null && override.isActive) {
          if (override.freeShipping == true) {
            return ShippingCalculation(
              weight: totalWeight,
              fromZone: ShippingZone.fromString(fromZone),
              toZone: ProvinceMapping.getZoneForProvince(destinationProvince),
              weightTier: WeightTier.getWeightTier(totalWeight),
              shippingFee: 0.0,
              isFreeShipping: true,
              calculationMethod: 'Product override - Free shipping',
              calculatedAt: DateTime.now(),
            );
          } else if (override.customRate != null) {
            return ShippingCalculation(
              weight: totalWeight,
              fromZone: ShippingZone.fromString(fromZone),
              toZone: ProvinceMapping.getZoneForProvince(destinationProvince),
              weightTier: WeightTier.getWeightTier(totalWeight),
              shippingFee: override.customRate!,
              isFreeShipping: false,
              calculationMethod: 'Product override - Custom rate',
              calculatedAt: DateTime.now(),
            );
          }
        }
      }

      // Determine zones
      final fromShippingZone = ShippingZone.fromString(fromZone);
      final toZone = ProvinceMapping.getZoneForProvince(destinationProvince);
      final weightTier = WeightTier.getWeightTier(totalWeight);

      // Get shipping rate
      final shippingRate = await getShippingRate(fromShippingZone, toZone, weightTier);
      
      if (shippingRate != null) {
        return ShippingCalculation(
          weight: totalWeight,
          fromZone: fromShippingZone,
          toZone: toZone,
          weightTier: weightTier,
          shippingFee: shippingRate.rate,
          isFreeShipping: false,
          calculationMethod: 'Zone-based calculation (${fromShippingZone.displayName} → ${toZone.displayName})',
          calculatedAt: DateTime.now(),
        );
      }

      // Fallback to configured default rate
      debugPrint('Using fallback rate: ${config.fallbackRate}');
      return ShippingCalculation(
        weight: totalWeight,
        fromZone: fromShippingZone,
        toZone: toZone,
        weightTier: weightTier,
        shippingFee: config.fallbackRate,
        isFreeShipping: false,
        calculationMethod: 'Fallback rate (no specific rate found)',
        calculatedAt: DateTime.now(),
      );

    } catch (e) {
      debugPrint('Error calculating shipping: $e');
      
      // Emergency fallback
      return ShippingCalculation(
        weight: totalWeight,
        fromZone: ShippingZone.manila,
        toZone: ProvinceMapping.getZoneForProvince(destinationProvince),
        weightTier: WeightTier.getWeightTier(totalWeight),
        shippingFee: 49.0, // Emergency fallback updated to match your settings
        isFreeShipping: false,
        calculationMethod: 'Emergency fallback due to error',
        calculatedAt: DateTime.now(),
      );
    }
  }

  /// Get shipping rate for specific zones and weight tier
  Future<ShippingRate?> getShippingRate(
    ShippingZone fromZone,
    ShippingZone toZone,
    WeightTier weightTier,
  ) async {
    try {
      await _ensureCacheLoaded();
      
      // Create lookup key
      final key = '${fromZone.name}_${toZone.name}_${weightTier.name}';
      return _ratesCache?[key];
    } catch (e) {
      debugPrint('Error getting shipping rate: $e');
      return null;
    }
  }

  /// Get all shipping rates
  Future<List<ShippingRate>> getAllShippingRates({bool activeOnly = true}) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('shipping_rates')
          .where('isActive', isEqualTo: activeOnly)
          .get();

      return snapshot.docs
          .map((doc) => ShippingRate.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting all shipping rates: $e');
      return [];
    }
  }

  /// Save or update shipping rate
  Future<void> saveShippingRate(ShippingRate rate) async {
    try {
      final docRef = rate.id.isEmpty 
          ? _firestore.collection('shipping_rates').doc()
          : _firestore.collection('shipping_rates').doc(rate.id);

      final updatedRate = rate.copyWith(
        id: docRef.id,
        updatedAt: DateTime.now(),
      );

      await docRef.set(updatedRate.toFirestore());
      _clearCache(); // Clear cache to force reload
      
      debugPrint('Saved shipping rate: ${updatedRate.id}');
    } catch (e) {
      debugPrint('Error saving shipping rate: $e');
      rethrow;
    }
  }

  /// Delete shipping rate
  Future<void> deleteShippingRate(String rateId) async {
    try {
      await _firestore.collection('shipping_rates').doc(rateId).delete();
      _clearCache(); // Clear cache to force reload
      debugPrint('Deleted shipping rate: $rateId');
    } catch (e) {
      debugPrint('Error deleting shipping rate: $e');
      rethrow;
    }
  }

  /// Get shipping configuration
  Future<ShippingConfig> getShippingConfig() async {
    try {
      await _ensureCacheLoaded();
      final config = _configCache ?? const ShippingConfig();
      debugPrint('ShippingService: Config loaded - threshold: ₱${config.freeShippingThreshold}, fallback: ₱${config.fallbackRate}, free shipping enabled: ${config.enableFreeShipping}');
      return config;
    } catch (e) {
      debugPrint('Error getting shipping config: $e');
      final defaultConfig = const ShippingConfig();
      debugPrint('ShippingService: Using default config - threshold: ₱${defaultConfig.freeShippingThreshold}, fallback: ₱${defaultConfig.fallbackRate}');
      return defaultConfig; // Return default config
    }
  }
  
  /// Ensure shipping configuration exists and is properly initialized
  Future<ShippingConfig> ensureConfigurationExists() async {
    try {
      // Try to get configuration from database directly
      final configDoc = await _firestore
          .collection('shipping_config')
          .doc('default')
          .get();
      
      ShippingConfig config;
      if (configDoc.exists) {
        config = ShippingConfig.fromFirestore(configDoc.data()!);
        debugPrint('ShippingService: Found existing config - threshold: ₱${config.freeShippingThreshold}, fallback: ₱${config.fallbackRate}');
      } else {
        // Create default configuration if it doesn't exist
        config = const ShippingConfig();
        await saveShippingConfig(config);
        debugPrint('ShippingService: Created default config - threshold: ₱${config.freeShippingThreshold}, fallback: ₱${config.fallbackRate}');
      }
      
      _configCache = config;
      return config;
    } catch (e) {
      debugPrint('Error ensuring shipping configuration exists: $e');
      final defaultConfig = const ShippingConfig();
      debugPrint('ShippingService: Using fallback default config due to error');
      return defaultConfig;
    }
  }

  /// Save shipping configuration
  Future<void> saveShippingConfig(ShippingConfig config) async {
    try {
      await _firestore
          .collection('shipping_config')
          .doc('default')
          .set(config.toFirestore());
      
      _configCache = config;
      debugPrint('Saved shipping config');
    } catch (e) {
      debugPrint('Error saving shipping config: $e');
      rethrow;
    }
  }

  /// Get product shipping override
  Future<ProductShippingOverride?> getProductShippingOverride(String productId) async {
    try {
      await _ensureCacheLoaded();
      return _overridesCache?[productId];
    } catch (e) {
      debugPrint('Error getting product shipping override: $e');
      return null;
    }
  }

  /// Save product shipping override
  Future<void> saveProductShippingOverride(ProductShippingOverride override) async {
    try {
      await _firestore
          .collection('shipping_overrides')
          .doc(override.productId)
          .set(override.toFirestore());
      
      _overridesCache?[override.productId] = override;
      debugPrint('Saved product shipping override: ${override.productId}');
    } catch (e) {
      debugPrint('Error saving product shipping override: $e');
      rethrow;
    }
  }

  /// Delete product shipping override
  Future<void> deleteProductShippingOverride(String productId) async {
    try {
      await _firestore.collection('shipping_overrides').doc(productId).delete();
      _overridesCache?.remove(productId);
      debugPrint('Deleted product shipping override: $productId');
    } catch (e) {
      debugPrint('Error deleting product shipping override: $e');
      rethrow;
    }
  }

  /// Initialize default shipping rates (for first-time setup)
  Future<void> initializeDefaultRates() async {
    try {
      // Check if rates already exist
      final existingRates = await getAllShippingRates();
      if (existingRates.isNotEmpty) {
        debugPrint('Shipping rates already exist, skipping initialization');
        return;
      }

      debugPrint('Initializing default shipping rates...');
      
      // Sample J&T Express inspired rates (you can adjust these)
      final defaultRates = <Map<String, dynamic>>[
        // Manila to all zones
        {'from': 'manila', 'to': 'manila', 'tier': 'tier0_500g', 'rate': 85.0},
        {'from': 'manila', 'to': 'manila', 'tier': 'tier500g_1kg', 'rate': 95.0},
        {'from': 'manila', 'to': 'manila', 'tier': 'tier1_2kg', 'rate': 105.0},
        
        {'from': 'manila', 'to': 'luzon', 'tier': 'tier0_500g', 'rate': 95.0},
        {'from': 'manila', 'to': 'luzon', 'tier': 'tier500g_1kg', 'rate': 110.0},
        {'from': 'manila', 'to': 'luzon', 'tier': 'tier1_2kg', 'rate': 125.0},
        
        {'from': 'manila', 'to': 'visayas', 'tier': 'tier0_500g', 'rate': 120.0},
        {'from': 'manila', 'to': 'visayas', 'tier': 'tier500g_1kg', 'rate': 140.0},
        {'from': 'manila', 'to': 'visayas', 'tier': 'tier1_2kg', 'rate': 160.0},
        
        {'from': 'manila', 'to': 'mindanao', 'tier': 'tier0_500g', 'rate': 130.0},
        {'from': 'manila', 'to': 'mindanao', 'tier': 'tier500g_1kg', 'rate': 155.0},
        {'from': 'manila', 'to': 'mindanao', 'tier': 'tier1_2kg', 'rate': 180.0},
        
        {'from': 'manila', 'to': 'islands', 'tier': 'tier0_500g', 'rate': 200.0},
        {'from': 'manila', 'to': 'islands', 'tier': 'tier500g_1kg', 'rate': 240.0},
        {'from': 'manila', 'to': 'islands', 'tier': 'tier1_2kg', 'rate': 280.0},
      ];

      for (final rateData in defaultRates) {
        final rate = ShippingRate(
          id: '',
          fromZone: ShippingZone.fromString(rateData['from']),
          toZone: ShippingZone.fromString(rateData['to']),
          weightTier: WeightTier.values.firstWhere((tier) => tier.name == rateData['tier']),
          rate: rateData['rate'].toDouble(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await saveShippingRate(rate);
      }

      debugPrint('Default shipping rates initialized successfully');
    } catch (e) {
      debugPrint('Error initializing default rates: $e');
      rethrow;
    }
  }

  /// Clear cached data
  void _clearCache() {
    _ratesCache = null;
    _configCache = null;
    _overridesCache = null;
    _cacheTimestamp = null;
  }

  /// Ensure cache is loaded and not expired
  Future<void> _ensureCacheLoaded() async {
    final now = DateTime.now();
    
    if (_cacheTimestamp == null || 
        now.difference(_cacheTimestamp!).compareTo(_cacheDuration) > 0) {
      await _loadCache();
    }
  }

  /// Load all shipping data into cache
  Future<void> _loadCache() async {
    try {
      debugPrint('Loading shipping data cache...');
      
      // Load shipping rates
      final ratesSnapshot = await _firestore
          .collection('shipping_rates')
          .where('isActive', isEqualTo: true)
          .get();
      
      _ratesCache = {};
      for (final doc in ratesSnapshot.docs) {
        final rate = ShippingRate.fromFirestore(doc.id, doc.data());
        final key = '${rate.fromZone.name}_${rate.toZone.name}_${rate.weightTier.name}';
        _ratesCache![key] = rate;
      }

      // Load shipping config
      final configDoc = await _firestore
          .collection('shipping_config')
          .doc('default')
          .get();
      
      if (configDoc.exists) {
        _configCache = ShippingConfig.fromFirestore(configDoc.data()!);
      } else {
        _configCache = const ShippingConfig();
        // Save default config
        await saveShippingConfig(_configCache!);
      }

      // Load shipping overrides
      final overridesSnapshot = await _firestore
          .collection('shipping_overrides')
          .where('isActive', isEqualTo: true)
          .get();
      
      _overridesCache = {};
      for (final doc in overridesSnapshot.docs) {
        final override = ProductShippingOverride.fromFirestore(doc.id, doc.data());
        _overridesCache![doc.id] = override;
      }

      _cacheTimestamp = DateTime.now();
      debugPrint('Shipping cache loaded: ${_ratesCache!.length} rates, ${_overridesCache!.length} overrides');
      
    } catch (e) {
      debugPrint('Error loading shipping cache: $e');
      // Initialize empty cache to prevent repeated failures
      _ratesCache = {};
      _overridesCache = {};
      _configCache = const ShippingConfig();
      _cacheTimestamp = DateTime.now();
    }
  }

  /// Get shipping zones list
  static List<ShippingZone> getAllZones() {
    return ShippingZone.values;
  }

  /// Get weight tiers list
  static List<WeightTier> getAllWeightTiers() {
    return WeightTier.values;
  }

  /// Get provinces for a zone
  static List<String> getProvincesForZone(ShippingZone zone) {
    return ProvinceMapping.getProvincesForZone(zone);
  }

  /// Get zone for a province
  static ShippingZone getZoneForProvince(String province) {
    return ProvinceMapping.getZoneForProvince(province);
  }
}