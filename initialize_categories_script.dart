import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/services/category_service.dart';

/// Standalone script to initialize the 26 comprehensive categories in Firestore
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCzLCN9qWXH6_yWQUIFE71YYckqjxj4-jI",
      authDomain: "annedfinds-9e5b4.firebaseapp.com",
      projectId: "annedfinds-9e5b4",
      storageBucket: "annedfinds-9e5b4.appspot.com",
      messagingSenderId: "48916413018",
      appId: "1:48916413018:web:92d9ba8b0ad1e6f8dd65b9",
      measurementId: "G-6XDFT3LY0Q",
    ),
  );

  print('🔥 Firebase initialized successfully');
  print('🚀 Starting to initialize 26 comprehensive categories...');

  try {
    // First, check if categories already exist
    final existingCategories = await FirebaseFirestore.instance
        .collection('categories')
        .get();
    
    if (existingCategories.docs.isNotEmpty) {
      print('⚠️  Found ${existingCategories.docs.length} existing categories.');
      print('🗑️  Clearing existing categories first...');
      
      // Clear existing categories
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in existingCategories.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('✅ Cleared ${existingCategories.docs.length} existing categories.');
    }

    // Initialize new categories using CategoryService
    await CategoryService.initializeCategoriesFromList();
    
    // Verify categories were added
    final newCategories = await FirebaseFirestore.instance
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
  }
}