import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/services/category_service.dart';

/// Run this script to initialize the 26 comprehensive categories in Firestore.
/// This should be run once to setup the categories database.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('Starting to initialize 26 comprehensive categories...');

  try {
    // Clear existing categories first
    print('Clearing existing categories...');
    final existingCategories = await FirebaseFirestore.instance
        .collection('categories')
        .get();
    
    if (existingCategories.docs.isNotEmpty) {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in existingCategories.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('Cleared ${existingCategories.docs.length} existing categories.');
    }

    // Initialize new categories using CategoryService
    print('Initializing new 26 categories...');
    await CategoryService.initializeCategoriesFromList();
    
    // Verify categories were added
    final newCategories = await FirebaseFirestore.instance
        .collection('categories')
        .get();
    
    print('Successfully initialized ${newCategories.docs.length} categories!');
    
    // List all categories
    print('\nCategories created:');
    for (final doc in newCategories.docs) {
      final data = doc.data();
      print('- ${data['name']} (${doc.id})');
    }
    
  } catch (e) {
    print('Error initializing categories: $e');
  }
}