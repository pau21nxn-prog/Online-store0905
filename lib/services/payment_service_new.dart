// Payment Service for AnnedFinds E-commerce Platform
// PayMongo Integration with PCI DSS SAQ A Compliance
// use context7

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_models.dart';

class PaymentService {
  static const String _payMongoBaseUrl = 'https://api.paymongo.com/v1';
  static const String _secretKey = 'sk_test_your_secret_key'; // TODO: Move to Firebase Remote Config
  static const String _publicKey = 'pk_test_your_public_key'; // TODO: Move to Firebase Remote Config
  static const String _webhookSecret = 'whsec_your_webhook_secret'; // TODO: Move to Firebase Remote Config

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create Payment Intent - Simple version for demo
  Future<PaymentIntent> createPaymentIntent({
    required PaymentOrder order,
    required PaymentMethod paymentMethod,
  }) async {
    try {
      // Create payment intent document in Firestore
      final intentRef = _firestore.collection('payment_intents').doc();
      
      final paymentIntent = PaymentIntent(
        id: intentRef.id,
        orderId: order.id,
        userId: order.userId,
        amount: order.total,
        method: paymentMethod,
        status: PaymentStatus.pending,
        provider: 'paymongo',
        metadata: {
          'orderId': order.id,
          'userId': order.userId,
        },
        createdAt: DateTime.now(),
        expiresAt: _calculateExpiryTime(paymentMethod),
      );

      // Save to Firestore
      await intentRef.set(paymentIntent.toFirestore());

      // For demo purposes, simulate different payment flows
      PaymentIntent updatedIntent;
      switch (paymentMethod) {
        case PaymentMethod.gcash:
          updatedIntent = await _simulateGCashIntent(paymentIntent);
          break;
        case PaymentMethod.card:
          updatedIntent = await _simulateCardIntent(paymentIntent);
          break;
        case PaymentMethod.bank_transfer:
          updatedIntent = await _simulateBankTransferIntent(paymentIntent);
          break;
        case PaymentMethod.cod:
          updatedIntent = await _simulateCODIntent(paymentIntent);
          break;
        default:
          throw Exception('Unsupported payment method: $paymentMethod');
      }

      // Update Firestore
      await intentRef.update(updatedIntent.toFirestore());
      return updatedIntent;

    } catch (e) {
      throw Exception('Failed to create payment intent: $e');
    }
  }

  DateTime _calculateExpiryTime(PaymentMethod method) {
    final now = DateTime.now();
    switch (method) {
      case PaymentMethod.gcash:
        return now.add(const Duration(minutes: 15));
      case PaymentMethod.card:
        return now.add(const Duration(minutes: 10));
      case PaymentMethod.bank_transfer:
        return now.add(const Duration(hours: 24));
      case PaymentMethod.cod:
        return now.add(const Duration(days: 1));
      default:
        return now.add(const Duration(minutes: 10));
    }
  }

  // Simulate GCash Payment Intent
  Future<PaymentIntent> _simulateGCashIntent(PaymentIntent intent) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate API call
    
    return intent.copyWith(
      providerIntentId: 'pi_${Random().nextInt(999999)}',
      clientSecret: 'gcash_client_secret_${Random().nextInt(999999)}',
      redirectUrl: 'https://gcash.com/redirect?payment=${intent.id}',
      metadata: {
        ...intent.metadata,
        'provider_intent_id': 'pi_${Random().nextInt(999999)}',
        'payment_method': 'gcash',
      },
    );
  }

  // Simulate Card Payment Intent
  Future<PaymentIntent> _simulateCardIntent(PaymentIntent intent) async {
    await Future.delayed(const Duration(seconds: 1));
    
    return intent.copyWith(
      providerIntentId: 'pi_${Random().nextInt(999999)}',
      clientSecret: 'card_client_secret_${Random().nextInt(999999)}',
      metadata: {
        ...intent.metadata,
        'provider_intent_id': 'pi_${Random().nextInt(999999)}',
        'payment_method': 'card',
        'requires_3ds': true,
      },
    );
  }

  // Simulate Bank Transfer Intent
  Future<PaymentIntent> _simulateBankTransferIntent(PaymentIntent intent) async {
    await Future.delayed(const Duration(seconds: 1));
    
    return intent.copyWith(
      providerIntentId: 'src_${Random().nextInt(999999)}',
      redirectUrl: 'https://banking.com/payment?source=${intent.id}',
      metadata: {
        ...intent.metadata,
        'source_id': 'src_${Random().nextInt(999999)}',
        'payment_method': 'bank_transfer',
      },
    );
  }

  // Simulate COD Intent
  Future<PaymentIntent> _simulateCODIntent(PaymentIntent intent) async {
    // COD is immediately confirmed for demo
    return intent.copyWith(
      status: PaymentStatus.paid,
      metadata: {
        ...intent.metadata,
        'cod_confirmed': true,
        'cod_fee': 50.0,
        'payment_method': 'cod',
      },
    );
  }

  // Get Payment Intent Status
  Future<PaymentIntent?> getPaymentIntent(String intentId) async {
    try {
      final doc = await _firestore
        .collection('payment_intents')
        .doc(intentId)
        .get();
        
      if (doc.exists) {
        return PaymentIntent.fromFirestore(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get payment intent: $e');
    }
  }

  // Simulate payment success for demo (would be handled by webhooks in production)
  Future<void> simulatePaymentSuccess(String intentId) async {
    try {
      await Future.delayed(const Duration(seconds: 3)); // Simulate processing time
      
      // 90% success rate for demo
      final success = Random().nextDouble() > 0.1;
      
      final status = success ? PaymentStatus.paid : PaymentStatus.failed;
      final failureReason = success ? null : 'Simulated payment failure for demo';
      
      await _firestore
        .collection('payment_intents')
        .doc(intentId)
        .update({
          'status': status.name,
          'failureReason': failureReason,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
    } catch (e) {
      throw Exception('Failed to simulate payment: $e');
    }
  }

  // Calculate fees based on payment method
  double calculateFees(PaymentMethod method, double amount) {
    switch (method) {
      case PaymentMethod.gcash:
        return amount >= 500 ? 0.0 : 15.0; // Free for orders >= ₱500
      case PaymentMethod.card:
        return amount * 0.035; // 3.5% for cards
      case PaymentMethod.bank_transfer:
        return 15.0; // InstaPay fee
      case PaymentMethod.cod:
        return 50.0; // COD service fee
      default:
        return 0.0;
    }
  }

  // Format currency for Philippines
  static String formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }
}