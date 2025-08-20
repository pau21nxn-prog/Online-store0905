import 'package:cloud_firestore/cloud_firestore.dart';

/// Script to initialize the 26 comprehensive categories directly in Firestore
Future<void> initializeCategories() async {
  print('🚀 Starting to initialize 26 comprehensive categories...');

  try {
    final firestore = FirebaseFirestore.instance;
    
    // First, check if categories already exist
    final existingCategories = await firestore.collection('categories').get();
    
    if (existingCategories.docs.isNotEmpty) {
      print('⚠️  Found ${existingCategories.docs.length} existing categories.');
      print('🗑️  Clearing existing categories first...');
      
      // Clear existing categories
      final batch = firestore.batch();
      for (final doc in existingCategories.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('✅ Cleared ${existingCategories.docs.length} existing categories.');
    }

    // Define the 26 comprehensive categories
    final categories = _getCategoryList();
    
    // Add new categories
    print('📝 Adding ${categories.length} new categories...');
    final batch = firestore.batch();
    
    for (final categoryData in categories) {
      final docRef = firestore.collection('categories').doc();
      batch.set(docRef, categoryData);
    }

    await batch.commit();
    
    // Verify categories were added
    final newCategories = await firestore
        .collection('categories')
        .orderBy('sortOrder')
        .get();
    
    print('✅ Successfully initialized ${newCategories.docs.length} categories!');
    
    // List all categories for verification
    print('\n📋 Categories created:');
    for (int i = 0; i < newCategories.docs.length; i++) {
      final data = newCategories.docs[i].data();
      print('${i + 1}. ${data['name']} (${data['slug']})');
    }
    
    print('\n🎉 Category initialization completed successfully!');
    
  } catch (e, stackTrace) {
    print('❌ Error initializing categories: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
}

List<Map<String, dynamic>> _getCategoryList() {
  final now = Timestamp.now();
  
  return [
    // 1. Fashion & Apparel
    {
      'name': 'Fashion & Apparel',
      'description': 'Clothing and fashion items for all ages and styles',
      'iconName': 'fashion',
      'colorName': 'pink',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 0,
      'slug': 'fashion-apparel',
      'seo': {
        'title': 'Fashion & Apparel - AnneDFinds',
        'description': 'Discover the latest fashion trends and clothing for men, women, and children.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 2. Shoes & Footwear
    {
      'name': 'Shoes & Footwear',
      'description': 'Comfortable and stylish shoes for every occasion',
      'iconName': 'shoes',
      'colorName': 'brown',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 1,
      'slug': 'shoes-footwear',
      'seo': {
        'title': 'Shoes & Footwear - AnneDFinds',
        'description': 'Find the perfect shoes for men, women, and children.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 3. Bags, Luggage & Travel
    {
      'name': 'Bags, Luggage & Travel',
      'description': 'Travel essentials and stylish bags for every journey',
      'iconName': 'bags',
      'colorName': 'teal',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 2,
      'slug': 'bags-luggage-travel',
      'seo': {
        'title': 'Bags, Luggage & Travel - AnneDFinds',
        'description': 'Quality bags and travel accessories for your adventures.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 4. Jewelry, Watches & Accessories
    {
      'name': 'Jewelry, Watches & Accessories',
      'description': 'Elegant jewelry and accessories to complete your look',
      'iconName': 'jewelry',
      'colorName': 'purple',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 3,
      'slug': 'jewelry-watches-accessories',
      'seo': {
        'title': 'Jewelry, Watches & Accessories - AnneDFinds',
        'description': 'Beautiful jewelry and watches for special occasions.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 5. Beauty, Health & Personal Care
    {
      'name': 'Beauty, Health & Personal Care',
      'description': 'Essential beauty and health products for your wellbeing',
      'iconName': 'beauty',
      'colorName': 'pink',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 4,
      'slug': 'beauty-health-personal-care',
      'seo': {
        'title': 'Beauty, Health & Personal Care - AnneDFinds',
        'description': 'Quality beauty and health products for your daily routine.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 6. Baby, Kids & Maternity
    {
      'name': 'Baby, Kids & Maternity',
      'description': 'Everything for babies, children, and expecting mothers',
      'iconName': 'baby',
      'colorName': 'blue',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 5,
      'slug': 'baby-kids-maternity',
      'seo': {
        'title': 'Baby, Kids & Maternity - AnneDFinds',
        'description': 'Safe and quality products for babies and children.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 7. Groceries & Gourmet
    {
      'name': 'Groceries & Gourmet',
      'description': 'Fresh groceries and gourmet food items',
      'iconName': 'groceries',
      'colorName': 'green',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 6,
      'slug': 'groceries-gourmet',
      'seo': {
        'title': 'Groceries & Gourmet - AnneDFinds',
        'description': 'Fresh groceries and specialty food items delivered to your door.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 8. Household, Cleaning & Laundry
    {
      'name': 'Household, Cleaning & Laundry',
      'description': 'Essential household and cleaning supplies',
      'iconName': 'household',
      'colorName': 'blue',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 7,
      'slug': 'household-cleaning-laundry',
      'seo': {
        'title': 'Household, Cleaning & Laundry - AnneDFinds',
        'description': 'Keep your home clean with our household supplies.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 9. Home & Living
    {
      'name': 'Home & Living',
      'description': 'Decor and essentials to make your house a home',
      'iconName': 'home',
      'colorName': 'brown',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 8,
      'slug': 'home-living',
      'seo': {
        'title': 'Home & Living - AnneDFinds',
        'description': 'Beautiful home decor and living essentials.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 10. Furniture
    {
      'name': 'Furniture',
      'description': 'Quality furniture for every room in your home',
      'iconName': 'furniture',
      'colorName': 'brown',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 9,
      'slug': 'furniture',
      'seo': {
        'title': 'Furniture - AnneDFinds',
        'description': 'Stylish and comfortable furniture for your home.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 11. Kitchen & Appliances
    {
      'name': 'Kitchen & Appliances',
      'description': 'Kitchen essentials and home appliances',
      'iconName': 'kitchen',
      'colorName': 'red',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 10,
      'slug': 'kitchen-appliances',
      'seo': {
        'title': 'Kitchen & Appliances - AnneDFinds',
        'description': 'Modern kitchen appliances and cooking essentials.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 12. Electronics & Mobiles
    {
      'name': 'Electronics & Mobiles',
      'description': 'Latest technology and electronic devices',
      'iconName': 'electronics',
      'colorName': 'blue',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 11,
      'slug': 'electronics-mobiles',
      'seo': {
        'title': 'Electronics & Mobiles - AnneDFinds',
        'description': 'Latest smartphones, gadgets, and electronic devices.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 13. Computers, Office & School
    {
      'name': 'Computers, Office & School',
      'description': 'Computer equipment and office supplies',
      'iconName': 'office',
      'colorName': 'grey',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 12,
      'slug': 'computers-office-school',
      'seo': {
        'title': 'Computers, Office & School - AnneDFinds',
        'description': 'Computer equipment and office supplies for work and study.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 14. Gaming & Esports
    {
      'name': 'Gaming & Esports',
      'description': 'Gaming gear and accessories for gamers',
      'iconName': 'gaming',
      'colorName': 'purple',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 13,
      'slug': 'gaming-esports',
      'seo': {
        'title': 'Gaming & Esports - AnneDFinds',
        'description': 'Gaming consoles, accessories, and gear for esports.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 15. Sports, Fitness & Outdoors
    {
      'name': 'Sports, Fitness & Outdoors',
      'description': 'Sports equipment and outdoor gear',
      'iconName': 'sports',
      'colorName': 'green',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 14,
      'slug': 'sports-fitness-outdoors',
      'seo': {
        'title': 'Sports, Fitness & Outdoors - AnneDFinds',
        'description': 'Sports equipment and outdoor gear for active lifestyles.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 16. Automotive & Moto
    {
      'name': 'Automotive & Moto',
      'description': 'Car and motorcycle parts and accessories',
      'iconName': 'automotive',
      'colorName': 'red',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 15,
      'slug': 'automotive-moto',
      'seo': {
        'title': 'Automotive & Moto - AnneDFinds',
        'description': 'Car and motorcycle parts, accessories, and care products.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 17. Home Improvement & Hardware
    {
      'name': 'Home Improvement & Hardware',
      'description': 'Tools and materials for home improvement projects',
      'iconName': 'tools',
      'colorName': 'orange',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 16,
      'slug': 'home-improvement-hardware',
      'seo': {
        'title': 'Home Improvement & Hardware - AnneDFinds',
        'description': 'Tools and hardware for DIY and professional projects.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 18. Garden & Outdoor Living
    {
      'name': 'Garden & Outdoor Living',
      'description': 'Gardening supplies and outdoor living essentials',
      'iconName': 'garden',
      'colorName': 'green',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 17,
      'slug': 'garden-outdoor-living',
      'seo': {
        'title': 'Garden & Outdoor Living - AnneDFinds',
        'description': 'Plants, gardening tools, and outdoor living accessories.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 19. Pet Supplies
    {
      'name': 'Pet Supplies',
      'description': 'Everything your pets need for health and happiness',
      'iconName': 'pets',
      'colorName': 'brown',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 18,
      'slug': 'pet-supplies',
      'seo': {
        'title': 'Pet Supplies - AnneDFinds',
        'description': 'Food, toys, and supplies for dogs, cats, and other pets.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 20. Books, Media & Music
    {
      'name': 'Books, Media & Music',
      'description': 'Books, entertainment media, and musical instruments',
      'iconName': 'books',
      'colorName': 'indigo',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 19,
      'slug': 'books-media-music',
      'seo': {
        'title': 'Books, Media & Music - AnneDFinds',
        'description': 'Books, music, movies, and educational materials.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 21. Hobbies, Collectibles & Crafts
    {
      'name': 'Hobbies, Collectibles & Crafts',
      'description': 'Supplies for hobbies, crafts, and collectibles',
      'iconName': 'hobbies',
      'colorName': 'purple',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 20,
      'slug': 'hobbies-collectibles-crafts',
      'seo': {
        'title': 'Hobbies, Collectibles & Crafts - AnneDFinds',
        'description': 'Craft supplies, collectibles, and hobby materials.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 22. Gifts, Party & Seasonal
    {
      'name': 'Gifts, Party & Seasonal',
      'description': 'Perfect gifts and party supplies for every occasion',
      'iconName': 'gifts',
      'colorName': 'pink',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 21,
      'slug': 'gifts-party-seasonal',
      'seo': {
        'title': 'Gifts, Party & Seasonal - AnneDFinds',
        'description': 'Thoughtful gifts and party supplies for celebrations.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 23. Travel, Tickets & Vouchers
    {
      'name': 'Travel, Tickets & Vouchers',
      'description': 'Travel accessories and digital vouchers',
      'iconName': 'travel',
      'colorName': 'teal',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 22,
      'slug': 'travel-tickets-vouchers',
      'seo': {
        'title': 'Travel, Tickets & Vouchers - AnneDFinds',
        'description': 'Travel accessories and digital tickets/vouchers.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 24. Pharmacy & Wellness
    {
      'name': 'Pharmacy & Wellness',
      'description': 'Health and wellness products for better living',
      'iconName': 'pharmacy',
      'colorName': 'green',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 23,
      'slug': 'pharmacy-wellness',
      'seo': {
        'title': 'Pharmacy & Wellness - AnneDFinds',
        'description': 'Health products and wellness supplies for better living.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 25. Services
    {
      'name': 'Services',
      'description': 'Professional services and repairs',
      'iconName': 'services',
      'colorName': 'blue',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 24,
      'slug': 'services',
      'seo': {
        'title': 'Services - AnneDFinds',
        'description': 'Professional services for repairs and maintenance.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
    
    // 26. Pre-loved Items
    {
      'name': 'Pre-loved Items',
      'description': 'Quality second-hand and refurbished items',
      'iconName': 'preloved',
      'colorName': 'green',
      'isActive': true,
      'productCount': 0,
      'parentId': null,
      'childIds': [],
      'level': 0,
      'sortOrder': 25,
      'slug': 'pre-loved-items',
      'seo': {
        'title': 'Pre-loved Items - AnneDFinds',
        'description': 'Quality second-hand and refurbished products.',
      },
      'createdAt': now,
      'updatedAt': now,
    },
  ];
}