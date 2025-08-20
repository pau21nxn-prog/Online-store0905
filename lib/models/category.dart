import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool isActive;
  final int productCount;
  final String? parentId;
  final List<String> childIds;
  final int level;
  final int sortOrder;
  final String slug;
  final Map<String, String> seo;
  final DateTime createdAt;
  final DateTime updatedAt;

  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.isActive,
    this.productCount = 0,
    this.parentId,
    this.childIds = const [],
    this.level = 0,
    this.sortOrder = 0,
    required this.slug,
    this.seo = const {},
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  // Helper getters
  bool get isTopLevel => parentId == null;
  bool get hasChildren => childIds.isNotEmpty;
  String get displayPath => _buildDisplayPath();

  String _buildDisplayPath() {
    // This would be populated by a service that builds the full path
    return name;
  }

  factory Category.fromFirestore(String id, Map<String, dynamic> data) {
    return Category(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      icon: _getIconFromString(data['iconName'] ?? 'category'),
      color: _getColorFromString(data['colorName'] ?? 'blue'),
      isActive: data['isActive'] ?? true,
      productCount: data['productCount'] ?? 0,
      parentId: data['parentId'],
      childIds: List<String>.from(data['childIds'] ?? []),
      level: data['level'] ?? 0,
      sortOrder: data['sortOrder'] ?? 0,
      slug: data['slug'] ?? '',
      seo: Map<String, String>.from(data['seo'] ?? {}),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'iconName': _getIconName(icon),
      'colorName': _getColorName(color),
      'isActive': isActive,
      'productCount': productCount,
      'parentId': parentId,
      'childIds': childIds,
      'level': level,
      'sortOrder': sortOrder,
      'slug': slug,
      'seo': seo,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Copy with method for updates
  Category copyWith({
    String? name,
    String? description,
    IconData? icon,
    Color? color,
    bool? isActive,
    int? productCount,
    String? parentId,
    List<String>? childIds,
    int? level,
    int? sortOrder,
    String? slug,
    Map<String, String>? seo,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      productCount: productCount ?? this.productCount,
      parentId: parentId ?? this.parentId,
      childIds: childIds ?? this.childIds,
      level: level ?? this.level,
      sortOrder: sortOrder ?? this.sortOrder,
      slug: slug ?? this.slug,
      seo: seo ?? this.seo,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  static IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'fashion':
        return Icons.checkroom;
      case 'shoes':
        return Icons.sports_soccer;
      case 'bags':
        return Icons.luggage;
      case 'jewelry':
        return Icons.watch;
      case 'beauty':
        return Icons.face;
      case 'baby':
        return Icons.child_care;
      case 'groceries':
        return Icons.local_grocery_store;
      case 'household':
        return Icons.cleaning_services;
      case 'home':
        return Icons.home;
      case 'furniture':
        return Icons.chair;
      case 'kitchen':
        return Icons.kitchen;
      case 'electronics':
        return Icons.phone_android;
      case 'office':
        return Icons.computer;
      case 'gaming':
        return Icons.games;
      case 'sports':
        return Icons.sports_basketball;
      case 'automotive':
        return Icons.directions_car;
      case 'tools':
        return Icons.build;
      case 'garden':
        return Icons.local_florist;
      case 'pets':
        return Icons.pets;
      case 'books':
        return Icons.menu_book;
      case 'hobbies':
        return Icons.palette;
      case 'gifts':
        return Icons.card_giftcard;
      case 'travel':
        return Icons.flight;
      case 'pharmacy':
        return Icons.medical_services;
      case 'services':
        return Icons.room_service;
      case 'preloved':
        return Icons.recycling;
      default:
        return Icons.category;
    }
  }

  static Color _getColorFromString(String colorName) {
    switch (colorName) {
      case 'blue':
        return Colors.blue;
      case 'pink':
        return Colors.pink;
      case 'green':
        return Colors.green;
      case 'purple':
        return Colors.purple;
      case 'orange':
        return Colors.orange;
      case 'brown':
        return Colors.brown;
      case 'red':
        return Colors.red;
      case 'teal':
        return Colors.teal;
      case 'amber':
        return Colors.amber;
      case 'indigo':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  static String _getIconName(IconData icon) {
    if (icon == Icons.checkroom) return 'fashion';
    if (icon == Icons.sports_soccer) return 'shoes';
    if (icon == Icons.luggage) return 'bags';
    if (icon == Icons.watch) return 'jewelry';
    if (icon == Icons.face) return 'beauty';
    if (icon == Icons.child_care) return 'baby';
    if (icon == Icons.local_grocery_store) return 'groceries';
    if (icon == Icons.cleaning_services) return 'household';
    if (icon == Icons.home) return 'home';
    if (icon == Icons.chair) return 'furniture';
    if (icon == Icons.kitchen) return 'kitchen';
    if (icon == Icons.phone_android) return 'electronics';
    if (icon == Icons.computer) return 'office';
    if (icon == Icons.games) return 'gaming';
    if (icon == Icons.sports_basketball) return 'sports';
    if (icon == Icons.directions_car) return 'automotive';
    if (icon == Icons.build) return 'tools';
    if (icon == Icons.local_florist) return 'garden';
    if (icon == Icons.pets) return 'pets';
    if (icon == Icons.menu_book) return 'books';
    if (icon == Icons.palette) return 'hobbies';
    if (icon == Icons.card_giftcard) return 'gifts';
    if (icon == Icons.flight) return 'travel';
    if (icon == Icons.medical_services) return 'pharmacy';
    if (icon == Icons.room_service) return 'services';
    if (icon == Icons.recycling) return 'preloved';
    return 'category';
  }

  static String _getColorName(Color color) {
    if (color == Colors.blue) return 'blue';
    if (color == Colors.pink) return 'pink';
    if (color == Colors.green) return 'green';
    if (color == Colors.purple) return 'purple';
    if (color == Colors.orange) return 'orange';
    if (color == Colors.brown) return 'brown';
    if (color == Colors.red) return 'red';
    if (color == Colors.teal) return 'teal';
    if (color == Colors.amber) return 'amber';
    if (color == Colors.indigo) return 'indigo';
    return 'grey';
  }
}