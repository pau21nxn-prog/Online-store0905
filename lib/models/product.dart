import 'package:cloud_firestore/cloud_firestore.dart';
import 'variant_option.dart';

enum ProductStatus { draft, review, approved, published, archived }

class PriceRange {
  final double min;
  final double max;
  final String currency;

  PriceRange({
    required this.min,
    required this.max,
    this.currency = 'PHP',
  });

  factory PriceRange.fromMap(Map<String, dynamic> data) {
    return PriceRange(
      min: (data['min'] ?? 0).toDouble(),
      max: (data['max'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'PHP',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'min': min,
      'max': max,
      'currency': currency,
    };
  }
}

class MediaCounts {
  final int images;
  final int videos;

  const MediaCounts({
    this.images = 0,
    this.videos = 0,
  });

  factory MediaCounts.fromMap(Map<String, dynamic> data) {
    return MediaCounts(
      images: data['images'] ?? 0,
      videos: data['videos'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'images': images,
      'videos': videos,
    };
  }
}

class WorkflowState {
  final ProductStatus stage;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime? publishSchedule;

  const WorkflowState({
    this.stage = ProductStatus.draft,
    this.reviewedBy,
    this.reviewedAt,
    this.publishSchedule,
  });

  factory WorkflowState.fromMap(Map<String, dynamic> data) {
    return WorkflowState(
      stage: ProductStatus.values.firstWhere(
        (s) => s.name == data['stage'],
        orElse: () => ProductStatus.draft,
      ),
      reviewedBy: data['reviewedBy'],
      reviewedAt: data['reviewedAt']?.toDate(),
      publishSchedule: data['publishSchedule']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'stage': stage.name,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt,
      'publishSchedule': publishSchedule,
    };
  }
}

class ProductPerformance {
  final int viewCount;
  final double conversionRate;
  final int avgSessionDuration;

  const ProductPerformance({
    this.viewCount = 0,
    this.conversionRate = 0.0,
    this.avgSessionDuration = 0,
  });

  factory ProductPerformance.fromMap(Map<String, dynamic> data) {
    return ProductPerformance(
      viewCount: data['viewCount'] ?? 0,
      conversionRate: (data['conversionRate'] ?? 0).toDouble(),
      avgSessionDuration: data['avgSessionDuration'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'viewCount': viewCount,
      'conversionRate': conversionRate,
      'avgSessionDuration': avgSessionDuration,
    };
  }
}

class Product {
  final String id;
  final String title;
  final String slug;
  final String description;
  final String detailedDescription;
  final String? brandId;
  final String primaryCategoryId;
  final List<String> categoryPath;
  final Map<String, dynamic> attributes;
  final Map<String, dynamic> specs;
  final List<String> searchTokens;
  final PriceRange priceRange;
  final String? defaultVariantId;
  final MediaCounts mediaCounts;
  final double ratingAvg;
  final int reviewCount;
  final int soldCount;
  final Map<String, dynamic> shipping;
  final Map<String, dynamic> seo;
  final Map<String, dynamic> visibility;
  final WorkflowState workflow;
  final ProductPerformance performance;
  final String tenantId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  
  // Computed fields for admin efficiency
  final int variantCount;
  final int totalStock;
  final int reservedStock;
  final bool isLowStock;
  final bool hasIssues;
  final List<String> issues;
  final double qualityScore;
  
  // New customizable variant system
  final List<VariantAttribute> variantAttributes;
  final List<VariantConfiguration> variantConfigurations;
  final bool hasCustomizableVariants;
  
  // Image URLs loaded from Firestore
  final List<String> _imageUrls;

  Product({
    required this.id,
    required this.title,
    required this.slug,
    required this.description,
    this.detailedDescription = '',
    this.brandId,
    required this.primaryCategoryId,
    this.categoryPath = const [],
    this.attributes = const {},
    this.specs = const {},
    this.searchTokens = const [],
    required this.priceRange,
    this.defaultVariantId,
    this.mediaCounts = const MediaCounts(),
    this.ratingAvg = 0.0,
    this.reviewCount = 0,
    this.soldCount = 0,
    this.shipping = const {},
    this.seo = const {},
    this.visibility = const {},
    this.workflow = const WorkflowState(),
    this.performance = const ProductPerformance(),
    this.tenantId = 'default',
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
    this.variantCount = 0,
    this.totalStock = 0,
    this.reservedStock = 0,
    this.isLowStock = false,
    this.hasIssues = false,
    this.issues = const [],
    this.qualityScore = 0.0,
    this.variantAttributes = const [],
    this.variantConfigurations = const [],
    this.hasCustomizableVariants = false,
    List<String>? imageUrls,
  }) : _imageUrls = imageUrls ?? [];

  factory Product.fromFirestore(String id, Map<String, dynamic> data) {
    return Product(
      id: id,
      title: data['title'] ?? data['name'] ?? '',
      slug: data['slug'] ?? '',
      description: data['description'] ?? '',
      detailedDescription: data['detailedDescription'] ?? '',
      brandId: data['brandId'],
      primaryCategoryId: data['primaryCategoryId'] ?? data['categoryId'] ?? '',
      categoryPath: List<String>.from(data['categoryPath'] ?? []),
      attributes: Map<String, dynamic>.from(data['attributes'] ?? {}),
      specs: Map<String, dynamic>.from(data['specs'] ?? {}),
      searchTokens: List<String>.from(data['searchTokens'] ?? []),
      priceRange: PriceRange.fromMap(data['priceRange'] ?? {
        'min': data['price'] ?? 0,
        'max': data['price'] ?? 0,
      }),
      defaultVariantId: data['defaultVariantId'],
      mediaCounts: MediaCounts.fromMap(data['mediaCounts'] ?? {}),
      ratingAvg: (data['ratingAvg'] ?? 0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      soldCount: data['soldCount'] ?? 0,
      shipping: Map<String, dynamic>.from(data['shipping'] ?? {}),
      seo: Map<String, dynamic>.from(data['seo'] ?? {}),
      visibility: Map<String, dynamic>.from(data['visibility'] ?? {}),
      workflow: WorkflowState.fromMap(data['workflow'] ?? {}),
      performance: ProductPerformance.fromMap(data['performance'] ?? {}),
      tenantId: data['tenantId'] ?? 'default',
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? data['sellerId'] ?? '',
      updatedBy: data['updatedBy'] ?? data['sellerId'] ?? '',
      variantCount: data['computed']?['variantCount'] ?? 0,
      totalStock: data['computed']?['totalStock'] ?? data['stockQty'] ?? 0,
      reservedStock: data['computed']?['reservedStock'] ?? 0,
      isLowStock: data['computed']?['isLowStock'] ?? false,
      hasIssues: data['computed']?['hasIssues'] ?? false,
      issues: List<String>.from(data['computed']?['issues'] ?? []),
      qualityScore: (data['computed']?['qualityScore'] ?? 0).toDouble(),
      // Parse variant attributes and configurations
      variantAttributes: _parseVariantAttributes(data['variantAttributes']),
      variantConfigurations: _parseVariantConfigurations(data['variantConfigurations']),
      hasCustomizableVariants: data['hasCustomizableVariants'] ?? false,
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'slug': slug,
      'description': description,
      'detailedDescription': detailedDescription,
      'brandId': brandId,
      'primaryCategoryId': primaryCategoryId,
      'categoryPath': categoryPath,
      'attributes': attributes,
      'specs': specs,
      'searchTokens': searchTokens,
      'priceRange': priceRange.toMap(),
      'defaultVariantId': defaultVariantId,
      'mediaCounts': mediaCounts.toMap(),
      'ratingAvg': ratingAvg,
      'reviewCount': reviewCount,
      'soldCount': soldCount,
      'shipping': shipping,
      'seo': seo,
      'visibility': visibility,
      'workflow': workflow.toMap(),
      'performance': performance.toMap(),
      'tenantId': tenantId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'computed': {
        'variantCount': variantCount,
        'totalStock': totalStock,
        'reservedStock': reservedStock,
        'isLowStock': isLowStock,
        'hasIssues': hasIssues,
        'issues': issues,
        'qualityScore': qualityScore,
      },
      // Include variant system data
      'variantAttributes': variantAttributes.map((attr) => attr.toMap()).toList(),
      'variantConfigurations': variantConfigurations.map((config) => config.toMap()).toList(),
      'hasCustomizableVariants': hasCustomizableVariants,
    };
  }

  // Removed duplicate - see formattedPriceRange getter below in admin section

  String get statusDisplayName {
    switch (workflow.stage) {
      case ProductStatus.draft:
        return 'Draft';
      case ProductStatus.review:
        return 'Under Review';
      case ProductStatus.approved:
        return 'Approved';
      case ProductStatus.published:
        return 'Published';
      case ProductStatus.archived:
        return 'Archived';
    }
  }

  bool get isPublished => workflow.stage == ProductStatus.published;
  bool get isDraft => workflow.stage == ProductStatus.draft;
  bool get needsReview => workflow.stage == ProductStatus.review;

  // Compatibility getter for existing code
  String get name => title;
  double get price => priceRange.min;
  String get categoryId => primaryCategoryId;
  List<String> get imageUrls => _imageUrls; // Load from Firestore data
  int get stockQty => totalStock;
  bool get isActive => isPublished;
  String? get sellerId => createdBy;

  // Additional getters for mobile product card compatibility
  bool get hasDiscount => priceRange.max > priceRange.min;
  double get originalPrice => priceRange.max;
  double get discountPercent => hasDiscount ? ((originalPrice - price) / originalPrice) * 100 : 0.0;
  bool get isNew => DateTime.now().difference(createdAt).inDays <= 30;
  int get ratingCount => reviewCount;

  // Compatibility getter for existing code - show only lowest price (sale price) to customers
  String get formattedPrice {
    // Always show the minimum price (sale price) to customers
    return '₱${priceRange.min.toStringAsFixed(2)}';
  }
  
  // Admin getter to show full price range for management purposes
  String get formattedPriceRange {
    if (priceRange.max > priceRange.min) {
      return '₱${priceRange.min.toStringAsFixed(2)} - ₱${priceRange.max.toStringAsFixed(2)}';
    }
    return '₱${priceRange.min.toStringAsFixed(2)}';
  }

  Product copyWith({
    String? id,
    String? title,
    String? slug,
    String? description,
    String? brandId,
    String? primaryCategoryId,
    List<String>? categoryPath,
    Map<String, dynamic>? attributes,
    Map<String, dynamic>? specs,
    List<String>? searchTokens,
    PriceRange? priceRange,
    String? defaultVariantId,
    MediaCounts? mediaCounts,
    double? ratingAvg,
    int? reviewCount,
    int? soldCount,
    Map<String, dynamic>? shipping,
    Map<String, dynamic>? seo,
    Map<String, dynamic>? visibility,
    WorkflowState? workflow,
    ProductPerformance? performance,
    String? tenantId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    int? variantCount,
    int? totalStock,
    int? reservedStock,
    bool? isLowStock,
    bool? hasIssues,
    List<String>? issues,
    double? qualityScore,
    List<VariantAttribute>? variantAttributes,
    List<VariantConfiguration>? variantConfigurations,
    bool? hasCustomizableVariants,
    List<String>? imageUrls,
  }) {
    return Product(
      id: id ?? this.id,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      brandId: brandId ?? this.brandId,
      primaryCategoryId: primaryCategoryId ?? this.primaryCategoryId,
      categoryPath: categoryPath ?? this.categoryPath,
      attributes: attributes ?? this.attributes,
      specs: specs ?? this.specs,
      searchTokens: searchTokens ?? this.searchTokens,
      priceRange: priceRange ?? this.priceRange,
      defaultVariantId: defaultVariantId ?? this.defaultVariantId,
      mediaCounts: mediaCounts ?? this.mediaCounts,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      reviewCount: reviewCount ?? this.reviewCount,
      soldCount: soldCount ?? this.soldCount,
      shipping: shipping ?? this.shipping,
      seo: seo ?? this.seo,
      visibility: visibility ?? this.visibility,
      workflow: workflow ?? this.workflow,
      performance: performance ?? this.performance,
      tenantId: tenantId ?? this.tenantId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      variantCount: variantCount ?? this.variantCount,
      totalStock: totalStock ?? this.totalStock,
      reservedStock: reservedStock ?? this.reservedStock,
      isLowStock: isLowStock ?? this.isLowStock,
      hasIssues: hasIssues ?? this.hasIssues,
      issues: issues ?? this.issues,
      qualityScore: qualityScore ?? this.qualityScore,
      variantAttributes: variantAttributes ?? this.variantAttributes,
      variantConfigurations: variantConfigurations ?? this.variantConfigurations,
      hasCustomizableVariants: hasCustomizableVariants ?? this.hasCustomizableVariants,
      imageUrls: imageUrls ?? this._imageUrls,
    );
  }
  
  // Helper methods for variant system
  List<VariantAttribute> get activeVariantAttributes => 
      variantAttributes.where((attr) => attr.isActive).toList();
      
  List<VariantConfiguration> get activeVariantConfigurations => 
      variantConfigurations.where((config) => config.isActive).toList();
      
  int get totalVariantStock => 
      variantConfigurations.fold(0, (sum, config) => sum + config.quantity);
      
  bool get hasVariantStock => totalVariantStock > 0;
  
  VariantConfiguration? get defaultVariantConfiguration {
    if (variantConfigurations.isEmpty) return null;
    return variantConfigurations.isNotEmpty ? variantConfigurations.first : null;
  }
  
  // Get price range from variant configurations
  PriceRange get variantPriceRange {
    if (variantConfigurations.isEmpty) return priceRange;
    
    final prices = variantConfigurations.map((config) => config.price).toList();
    prices.sort();
    
    return PriceRange(
      min: prices.first,
      max: prices.last,
      currency: priceRange.currency,
    );
  }
  
  // Static helper methods for parsing Firestore data
  static List<VariantAttribute> _parseVariantAttributes(dynamic data) {
    if (data == null) return [];
    
    final list = data as List<dynamic>? ?? [];
    return list.asMap().entries.map((entry) {
      if (entry.value is Map<String, dynamic>) {
        return VariantAttribute.fromMap(entry.value, entry.key.toString());
      } else {
        throw FormatException('Invalid variant attribute format');
      }
    }).toList();
  }
  
  static List<VariantConfiguration> _parseVariantConfigurations(dynamic data) {
    if (data == null) return [];
    
    final list = data as List<dynamic>? ?? [];
    return list.asMap().entries.map((entry) {
      if (entry.value is Map<String, dynamic>) {
        return VariantConfiguration.fromMap(entry.value, entry.key.toString());
      } else {
        throw FormatException('Invalid variant configuration format');
      }
    }).toList();
  }
}