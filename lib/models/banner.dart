class Banner {
  final String id;
  final String imageUrl;
  final int order;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Banner({
    required this.id,
    required this.imageUrl,
    required this.order,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert from Firestore document
  factory Banner.fromFirestore(String id, Map<String, dynamic> data) {
    return Banner(
      id: id,
      imageUrl: data['imageUrl'] ?? '',
      order: data['order'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'imageUrl': imageUrl,
      'order': order,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Create copy with updated fields
  Banner copyWith({
    String? id,
    String? imageUrl,
    int? order,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Banner(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Banner{id: $id, imageUrl: $imageUrl, order: $order, isActive: $isActive}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Banner &&
        other.id == id &&
        other.imageUrl == imageUrl &&
        other.order == order &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return id.hashCode ^ imageUrl.hashCode ^ order.hashCode ^ isActive.hashCode;
  }
}