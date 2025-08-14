import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/payment.dart';
import 'dart:math';

class PaymentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a payment record
  static Future<String> createPayment({
    required String orderId,
    required double amount,
    required PaymentMethodType method,
    Map<String, dynamic> metadata = const {},
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final paymentId = _generatePaymentId();
    final payment = Payment(
      id: paymentId,
      orderId: orderId,
      userId: user.uid,
      amount: amount,
      method: method,
      status: PaymentStatus.pending,
      createdAt: DateTime.now(),
      metadata: metadata,
    );

    await _firestore.collection('payments').doc(paymentId).set(payment.toFirestore());
    return paymentId;
  }

  // Process GCash payment
  static Future<bool> processGCashPayment({
    required String paymentId,
    required String gcashNumber,
    required double amount,
  }) async {
    try {
      // In a real app, you'd integrate with GCash API here
      // For demo purposes, we'll simulate the payment process
      
      // Update payment status to processing
      await _firestore.collection('payments').doc(paymentId).update({
        'status': PaymentStatus.processing.toString().split('.').last,
        'metadata.gcashNumber': gcashNumber,
        'transactionId': _generateTransactionId(),
      });

      // Simulate API call delay
      await Future.delayed(const Duration(seconds: 2));

      // Simulate success/failure (90% success rate for demo)
      final success = Random().nextDouble() > 0.1;

      if (success) {
        await _firestore.collection('payments').doc(paymentId).update({
          'status': PaymentStatus.completed.toString().split('.').last,
          'completedAt': Timestamp.fromDate(DateTime.now()),
          'referenceNumber': _generateReferenceNumber(),
        });
        return true;
      } else {
        await _firestore.collection('payments').doc(paymentId).update({
          'status': PaymentStatus.failed.toString().split('.').last,
          'metadata.failureReason': 'Insufficient balance or network error',
        });
        return false;
      }
    } catch (e) {
      await _firestore.collection('payments').doc(paymentId).update({
        'status': PaymentStatus.failed.toString().split('.').last,
        'metadata.error': e.toString(),
      });
      return false;
    }
  }

  // Process COD payment
  static Future<bool> processCODPayment({
    required String paymentId,
    required ShippingAddress address,
  }) async {
    try {
      await _firestore.collection('payments').doc(paymentId).update({
        'status': PaymentStatus.pending.toString().split('.').last,
        'metadata.shippingAddress': address.toMap(),
        'metadata.paymentMethod': 'Cash on Delivery',
        'referenceNumber': _generateReferenceNumber(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get payment by ID
  static Future<Payment?> getPayment(String paymentId) async {
    try {
      final doc = await _firestore.collection('payments').doc(paymentId).get();
      if (doc.exists) {
        return Payment.fromFirestore(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get payments for current user
  static Stream<List<Payment>> getUserPayments() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('payments')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Payment.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  // Calculate shipping fee
  static double calculateShippingFee({
    required String city,
    required String province,
    required double totalWeight,
  }) {
    // Basic shipping calculation for Philippines
    // In a real app, you'd integrate with shipping APIs like LBC, J&T, etc.
    
    const baseFee = 99.0;
    
    // Metro Manila
    if (province.toLowerCase().contains('metro manila') || 
        city.toLowerCase().contains('manila') ||
        city.toLowerCase().contains('quezon') ||
        city.toLowerCase().contains('makati')) {
      return baseFee;
    }
    
    // Luzon
    if (['luzon', 'bulacan', 'cavite', 'laguna', 'rizal', 'batangas'].any(
        (area) => province.toLowerCase().contains(area))) {
      return baseFee + 50;
    }
    
    // Visayas
    if (['cebu', 'bohol', 'negros', 'panay', 'samar', 'leyte'].any(
        (area) => province.toLowerCase().contains(area))) {
      return baseFee + 100;
    }
    
    // Mindanao and other islands
    return baseFee + 150;
  }

  // Helper methods
  static String _generatePaymentId() {
    return 'PAY_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999).toString().padLeft(4, '0')}';
  }

  static String _generateTransactionId() {
    return 'TXN_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999).toString().padLeft(6, '0')}';
  }

  static String _generateReferenceNumber() {
    return 'REF_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}_${Random().nextInt(999999).toString().padLeft(6, '0')}';
  }

  // Get payment methods available in Philippines
  static List<PaymentMethodType> getAvailablePaymentMethods() {
    return [
      PaymentMethodType.gcash,
      PaymentMethodType.cod,
      PaymentMethodType.bankTransfer,
      // PaymentMethodType.paypal, // Can be enabled for international customers
    ];
  }

  // Format currency for Philippines
  static String formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }
}