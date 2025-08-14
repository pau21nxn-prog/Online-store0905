import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool isActive;
  final int productCount;

  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.isActive,
    this.productCount = 0,
  });

  factory Category.fromFirestore(String id, Map<String, dynamic> data) {
    return Category(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      icon: _getIconFromString(data['iconName'] ?? 'category'),
      color: _getColorFromString(data['colorName'] ?? 'blue'),
      isActive: data['isActive'] ?? true,
      productCount: data['productCount'] ?? 0,
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
    };
  }

  static IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'phone':
        return Icons.phone_android;
      case 'fashion':
        return Icons.checkroom;
      case 'home':
        return Icons.home;
      case 'beauty':
        return Icons.face;
      case 'sports':
        return Icons.sports_basketball;
      case 'books':
        return Icons.menu_book;
      case 'electronics':
        return Icons.devices;
      case 'automotive':
        return Icons.directions_car;
      case 'food':
        return Icons.restaurant;
      case 'health':
        return Icons.health_and_safety;
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
    if (icon == Icons.phone_android) return 'phone';
    if (icon == Icons.checkroom) return 'fashion';
    if (icon == Icons.home) return 'home';
    if (icon == Icons.face) return 'beauty';
    if (icon == Icons.sports_basketball) return 'sports';
    if (icon == Icons.menu_book) return 'books';
    if (icon == Icons.devices) return 'electronics';
    if (icon == Icons.directions_car) return 'automotive';
    if (icon == Icons.restaurant) return 'food';
    if (icon == Icons.health_and_safety) return 'health';
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