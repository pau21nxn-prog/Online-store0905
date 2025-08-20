// Payment Service for AnnedFinds E-commerce Platform
// PayMongo Integration with PCI DSS SAQ A Compliance
// use context7

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import '../models/payment_models.dart';

class PaymentService {
  static const String _payMongoBaseUrl = 'https://api.paymongo.com/v1';
  static const String _secretKey = 'sk_test_your_secret_key'; // TODO: Move to Firebase Remote Config
  static const String _publicKey = 'pk_test_your_public_key'; // TODO: Move to Firebase Remote Config
  static const String _webhookSecret = 'whsec_your_webhook_secret'; // TODO: Move to Firebase Remote Config

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create Payment Intent
  Future<PaymentIntent> createPaymentIntent({
    required PaymentOrder order,
    required PaymentMethod paymentMethod,
  }) async {
    try {
      // Generate idempotency key using order ID
      final idempotencyKey = 'order_${order.id}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Create payment intent document in Firestore first
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
          'idempotencyKey': idempotencyKey,
        },
        createdAt: DateTime.now(),
        expiresAt: _calculateExpiryTime(paymentMethod),
      );

      // Save to Firestore
      await intentRef.set(paymentIntent.toFirestore());

      // Create payment intent with PayMongo based on method
      PaymentIntent updatedIntent;
      switch (paymentMethod) {
        case PaymentMethod.gcash:
          updatedIntent = await _createGCashIntent(paymentIntent, order);
          break;
        case PaymentMethod.card:
          updatedIntent = await _createCardIntent(paymentIntent, order);
          break;
        case PaymentMethod.bank_transfer:
          updatedIntent = await _createBankTransferIntent(paymentIntent, order);
          break;
        case PaymentMethod.cod:
          updatedIntent = await _createCODIntent(paymentIntent, order);
          break;
        default:
          throw Exception('Unsupported payment method: $paymentMethod');
      }

      // Update Firestore with provider response
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
        return now.add(const Duration(days: 1)); // COD orders expire in 1 day
      default:
        return now.add(const Duration(minutes: 10));
    }
  }

  // GCash Payment Intent
  Future<PaymentIntent> _createGCashIntent(PaymentIntent intent, PaymentOrder order) async {
    try {
      final payload = {
        'data': {
          'attributes': {
            'amount': (intent.amount * 100).toInt(), // Convert to centavos
            'currency': 'PHP',
            'description': 'AnnedFinds Order ${order.id}',
            'statement_descriptor': 'ANNEDFINALS',
            'payment_method_allowed': ['gcash'],
            'payment_method_options': {
              'gcash': {
                'redirect': {
                  'success': 'https://annedfinals.com/payment/success',
                  'failed': 'https://annedfinals.com/payment/failed',
                },
              },
            },
            'metadata': {
              'order_id': order.id,
              'user_id': order.userId,
              'payment_intent_id': intent.id,
            },
          },
        },
      };

      final response = await _makePayMongoRequest(
        endpoint: '/payment_intents',
        method: 'POST',
        body: payload,
      );

      final paymentIntentData = response['data'];
      final attributes = paymentIntentData['attributes'];
      
      return intent.copyWith(
        providerIntentId: paymentIntentData['id'],
        clientSecret: attributes['client_key'],
        redirectUrl: attributes['next_action']?['redirect']?['url'],
        metadata: {
          ...intent.metadata,
          'provider_intent_id': paymentIntentData['id'],
          'client_key': attributes['client_key'],
        },
      );

    } catch (e) {
      throw Exception('Failed to create GCash payment intent: $e');
    }
  }

  // Card Payment Intent
  Future<PaymentIntent> _createCardIntent(PaymentIntent intent, PaymentOrder order) async {
    try {
      final payload = {
        'data': {
          'attributes': {
            'amount': (intent.amount * 100).toInt(),
            'currency': 'PHP',
            'description': 'AnnedFinds Order ${order.id}',
            'statement_descriptor': 'ANNEDFINALS',
            'payment_method_allowed': ['card'],
            'payment_method_options': {
              'card': {
                'request_three_d_secure': 'automatic',
              },
            },
            'capture_type': 'automatic',
            'metadata': {
              'order_id': order.id,
              'user_id': order.userId,
              'payment_intent_id': intent.id,
            },
          },
        },
      };

      final response = await _makePayMongoRequest(
        endpoint: '/payment_intents',
        method: 'POST',
        body: payload,
      );

      final paymentIntentData = response['data'];
      final attributes = paymentIntentData['attributes'];
      
      return intent.copyWith(
        providerIntentId: paymentIntentData['id'],
        clientSecret: attributes['client_key'],
        metadata: {
          ...intent.metadata,
          'provider_intent_id': paymentIntentData['id'],
          'client_key': attributes['client_key'],
        },
      );

    } catch (e) {
      throw Exception('Failed to create card payment intent: $e');
    }
  }

  // Bank Transfer Payment Intent
  Future<PaymentIntent> _createBankTransferIntent(PaymentIntent intent, PaymentOrder order) async {
    try {
      // For InstaPay/PESONet, we create a source instead of payment intent
      final payload = {
        'data': {
          'attributes': {
            'amount': (intent.amount * 100).toInt(),
            'currency': 'PHP',
            'type': 'online_banking',
            'redirect': {
              'success': 'https://annedfinals.com/payment/success',
              'failed': 'https://annedfinals.com/payment/failed',
            },
            'metadata': {
              'order_id': order.id,
              'user_id': order.userId,
              'payment_intent_id': intent.id,
            },
          },
        },
      };

      final response = await _makePayMongoRequest(
        endpoint: '/sources',
        method: 'POST',
        body: payload,
      );

      final sourceData = response['data'];
      final attributes = sourceData['attributes'];
      
      return intent.copyWith(
        providerIntentId: sourceData['id'],
        redirectUrl: attributes['redirect']['checkout_url'],
        metadata: {
          ...intent.metadata,
          'source_id': sourceData['id'],
          'checkout_url': attributes['redirect']['checkout_url'],
        },
      );

    } catch (e) {
      throw Exception('Failed to create bank transfer intent: $e');
    }
  }

  // Cash on Delivery Intent (No external provider needed)
  Future<PaymentIntent> _createCODIntent(PaymentIntent intent, PaymentOrder order) async {
    // COD doesn't need external payment provider
    // Just mark as confirmed and update order status
    return intent.copyWith(
      status: PaymentStatus.paid,
      metadata: {
        ...intent.metadata,
        'cod_confirmed': true,
        'cod_fee': 50.0, // ₱50 COD fee
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

  // Helper method to make PayMongo API requests
  Future<Map<String, dynamic>> _makePayMongoRequest({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$_payMongoBaseUrl$endpoint');
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Basic ${base64Encode(utf8.encode('$_secretKey:'))}',
      };

      http.Response response;
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers);
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PUT':
          response = await http.put(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('PayMongo API error: ${errorData['errors']}');
      }

    } catch (e) {
      throw Exception('PayMongo request failed: $e');
    }
  }
}