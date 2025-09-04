import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/address.dart';
import 'dart:async';

class AddressService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get user's addresses stream
  static Stream<List<Address>> getAddressesStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('addresses')
        .orderBy('isDefault', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Address.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  // Get user's addresses as future
  static Future<List<Address>> getAddresses() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .orderBy('isDefault', descending: true)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Address.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting addresses: $e');
      return [];
    }
  }

  // Get default address
  static Future<Address?> getDefaultAddress() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return Address.fromFirestore(doc.id, doc.data());
      }
      return null;
    } catch (e) {
      debugPrint('Error getting default address: $e');
      return null;
    }
  }

  // Add new address
  static Future<String?> addAddress(Address address) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // If this is the first address or explicitly set as default, make it default
      final existingAddresses = await getAddresses();
      final shouldBeDefault = existingAddresses.isEmpty || address.isDefault;

      // If setting as default, unset other default addresses
      if (shouldBeDefault) {
        await _clearDefaultAddresses();
      }

      final addressData = address.copyWith(
        isDefault: shouldBeDefault,
        createdAt: DateTime.now(),
      ).toFirestore();

      final docRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .add(addressData);

      debugPrint('Address added successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding address: $e');
      rethrow;
    }
  }

  // Update address
  static Future<void> updateAddress(String addressId, Address address) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // If setting as default, unset other default addresses
      if (address.isDefault) {
        await _clearDefaultAddresses();
      }

      final addressData = address.copyWith(
        updatedAt: DateTime.now(),
      ).toFirestore();

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .doc(addressId)
          .update(addressData);

      debugPrint('Address updated successfully');
    } catch (e) {
      debugPrint('Error updating address: $e');
      rethrow;
    }
  }

  // Delete address
  static Future<void> deleteAddress(String addressId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .doc(addressId)
          .delete();

      debugPrint('Address deleted successfully');
    } catch (e) {
      debugPrint('Error deleting address: $e');
      rethrow;
    }
  }

  // Set address as default
  static Future<void> setDefaultAddress(String addressId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // First, unset all default addresses
      await _clearDefaultAddresses();

      // Then set the specified address as default
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .doc(addressId)
          .update({
        'isDefault': true,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('Default address set successfully');
    } catch (e) {
      debugPrint('Error setting default address: $e');
      rethrow;
    }
  }

  // Private method to clear all default addresses
  static Future<void> _clearDefaultAddresses() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .where('isDefault', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isDefault': false});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error clearing default addresses: $e');
    }
  }

  // Validate Philippine address fields
  static Map<String, String?> validateAddress({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String streetAddress,
    required String city,
    required String province,
    required String postalCode,
  }) {
    final errors = <String, String?>{};

    // Full name validation
    if (fullName.trim().isEmpty) {
      errors['fullName'] = 'Full name is required';
    } else if (fullName.trim().length < 2) {
      errors['fullName'] = 'Full name must be at least 2 characters';
    }

    // Email validation
    if (email.trim().isEmpty) {
      errors['email'] = 'Email is required';
    } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      errors['email'] = 'Please enter a valid email address';
    }

    // Phone number validation (Philippine format)
    final phoneRegex = RegExp(r'^(\+63|0)(9\d{9})$');
    if (phoneNumber.trim().isEmpty) {
      errors['phoneNumber'] = 'Phone number is required';
    } else if (!phoneRegex.hasMatch(phoneNumber.replaceAll(RegExp(r'[^\d+]'), ''))) {
      errors['phoneNumber'] = 'Please enter a valid Philippine mobile number';
    }

    // Street address validation
    if (streetAddress.trim().isEmpty) {
      errors['streetAddress'] = 'Street address is required';
    } else if (streetAddress.trim().length < 5) {
      errors['streetAddress'] = 'Please enter a complete street address';
    }

    // City validation
    if (city.trim().isEmpty) {
      errors['city'] = 'City is required';
    }

    // Province validation
    if (province.trim().isEmpty) {
      errors['province'] = 'Province is required';
    }

    // Postal code validation (Philippine format: 4 digits)
    if (postalCode.trim().isEmpty) {
      errors['postalCode'] = 'Postal code is required';
    } else if (!RegExp(r'^\d{4}$').hasMatch(postalCode.trim())) {
      errors['postalCode'] = 'Please enter a valid 4-digit postal code';
    }

    return errors;
  }
}