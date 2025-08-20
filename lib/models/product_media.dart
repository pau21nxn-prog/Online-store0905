import 'package:cloud_firestore/cloud_firestore.dart';

enum MediaType { image, video }
enum MediaRole { gallery, cover, demo, variant }

class MediaVariants {
  final Map<String, String> image;
  final Map<String, String> video;

  const MediaVariants({
    this.image = const {},
    this.video = const {},
  });

  factory MediaVariants.fromMap(Map<String, dynamic> data) {
    return MediaVariants(
      image: Map<String, String>.from(data['image'] ?? {}),
      video: Map<String, String>.from(data['video'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'image': image,
      'video': video,
    };
  }

  String? get thumbnail => image['thumb'];
  String? get medium => image['md'];
  String? get large => image['xl'];
  String? get hlsMaster => video['hlsMaster'];
  String? get mp4 => video['mp4'];
  String? get poster => video['poster'];
}

class ProductMedia {
  final String id;
  final String productId;
  final MediaType type;
  final MediaRole role;
  final String storagePath;
  final MediaVariants variants;
  final double? duration; // seconds if video
  final int order;
  final String? altText; // for accessibility
  final String? caption;
  final Map<String, dynamic> metadata; // width, height, size, etc.
  final bool isProcessed; // true when all variants are generated
  final DateTime createdAt;
  final String createdBy;

  ProductMedia({
    required this.id,
    required this.productId,
    required this.type,
    this.role = MediaRole.gallery,
    required this.storagePath,
    this.variants = const MediaVariants(),
    this.duration,
    this.order = 0,
    this.altText,
    this.caption,
    this.metadata = const {},
    this.isProcessed = false,
    required this.createdAt,
    required this.createdBy,
  });

  factory ProductMedia.fromFirestore(String id, Map<String, dynamic> data) {
    return ProductMedia(
      id: id,
      productId: data['productId'] ?? '',
      type: MediaType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => MediaType.image,
      ),
      role: MediaRole.values.firstWhere(
        (r) => r.name == data['role'],
        orElse: () => MediaRole.gallery,
      ),
      storagePath: data['storagePath'] ?? '',
      variants: MediaVariants.fromMap(data['variants'] ?? {}),
      duration: data['duration']?.toDouble(),
      order: data['order'] ?? 0,
      altText: data['altText'],
      caption: data['caption'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      isProcessed: data['isProcessed'] ?? false,
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'type': type.name,
      'role': role.name,
      'storagePath': storagePath,
      'variants': variants.toMap(),
      'duration': duration,
      'order': order,
      'altText': altText,
      'caption': caption,
      'metadata': metadata,
      'isProcessed': isProcessed,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  String get displayUrl {
    switch (type) {
      case MediaType.image:
        return variants.medium ?? variants.thumbnail ?? storagePath;
      case MediaType.video:
        return variants.poster ?? storagePath;
    }
  }

  String get thumbnailUrl {
    switch (type) {
      case MediaType.image:
        return variants.thumbnail ?? displayUrl;
      case MediaType.video:
        return variants.poster ?? displayUrl;
    }
  }

  String get fullSizeUrl {
    switch (type) {
      case MediaType.image:
        return variants.large ?? variants.medium ?? displayUrl;
      case MediaType.video:
        return variants.mp4 ?? variants.hlsMaster ?? storagePath;
    }
  }

  bool get isImage => type == MediaType.image;
  bool get isVideo => type == MediaType.video;
  bool get isCover => role == MediaRole.cover;
  bool get isDemo => role == MediaRole.demo;

  String get roleDisplayName {
    switch (role) {
      case MediaRole.gallery:
        return 'Gallery';
      case MediaRole.cover:
        return 'Cover';
      case MediaRole.demo:
        return 'Demo';
      case MediaRole.variant:
        return 'Variant';
    }
  }

  String get formattedDuration {
    if (duration == null || duration == 0) return '';
    
    final minutes = (duration! / 60).floor();
    final seconds = (duration! % 60).floor();
    
    if (minutes > 0) {
      return '${minutes}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${seconds}s';
    }
  }

  int? get fileSizeBytes => metadata['size'];
  
  String get formattedFileSize {
    final size = fileSizeBytes;
    if (size == null) return '';
    
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  ProductMedia copyWith({
    MediaType? type,
    MediaRole? role,
    String? storagePath,
    MediaVariants? variants,
    double? duration,
    int? order,
    String? altText,
    String? caption,
    Map<String, dynamic>? metadata,
    bool? isProcessed,
  }) {
    return ProductMedia(
      id: id,
      productId: productId,
      type: type ?? this.type,
      role: role ?? this.role,
      storagePath: storagePath ?? this.storagePath,
      variants: variants ?? this.variants,
      duration: duration ?? this.duration,
      order: order ?? this.order,
      altText: altText ?? this.altText,
      caption: caption ?? this.caption,
      metadata: metadata ?? this.metadata,
      isProcessed: isProcessed ?? this.isProcessed,
      createdAt: createdAt,
      createdBy: createdBy,
    );
  }
}

class MediaUpload {
  final String localPath;
  final String fileName;
  final MediaType type;
  final MediaRole role;
  final int fileSize;
  final String? altText;
  final String? caption;

  MediaUpload({
    required this.localPath,
    required this.fileName,
    required this.type,
    this.role = MediaRole.gallery,
    required this.fileSize,
    this.altText,
    this.caption,
  });

  bool get isValidSize {
    switch (type) {
      case MediaType.image:
        return fileSize <= 5 * 1024 * 1024; // 5MB for images
      case MediaType.video:
        return fileSize <= 120 * 1024 * 1024; // 120MB for videos
    }
  }

  bool get isValidType {
    switch (type) {
      case MediaType.image:
        return fileName.toLowerCase().endsWith('.jpg') ||
               fileName.toLowerCase().endsWith('.jpeg') ||
               fileName.toLowerCase().endsWith('.png') ||
               fileName.toLowerCase().endsWith('.webp');
      case MediaType.video:
        return fileName.toLowerCase().endsWith('.mp4') ||
               fileName.toLowerCase().endsWith('.mov');
    }
  }

  String get validationError {
    if (!isValidType) {
      return type == MediaType.image 
          ? 'Invalid image format. Use JPG, PNG, or WebP.'
          : 'Invalid video format. Use MP4 or MOV.';
    }
    if (!isValidSize) {
      return type == MediaType.image
          ? 'Image size must be under 5MB.'
          : 'Video size must be under 120MB.';
    }
    return '';
  }

  bool get isValid => isValidType && isValidSize;
}

class MediaProcessingJob {
  final String mediaId;
  final String productId;
  final MediaType type;
  final String originalPath;
  final Map<String, dynamic> processingParams;
  final DateTime createdAt;
  final String status; // pending, processing, completed, failed

  MediaProcessingJob({
    required this.mediaId,
    required this.productId,
    required this.type,
    required this.originalPath,
    this.processingParams = const {},
    required this.createdAt,
    this.status = 'pending',
  });

  factory MediaProcessingJob.fromMap(Map<String, dynamic> data) {
    return MediaProcessingJob(
      mediaId: data['mediaId'] ?? '',
      productId: data['productId'] ?? '',
      type: MediaType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => MediaType.image,
      ),
      originalPath: data['originalPath'] ?? '',
      processingParams: Map<String, dynamic>.from(data['processingParams'] ?? {}),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mediaId': mediaId,
      'productId': productId,
      'type': type.name,
      'originalPath': originalPath,
      'processingParams': processingParams,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }
}