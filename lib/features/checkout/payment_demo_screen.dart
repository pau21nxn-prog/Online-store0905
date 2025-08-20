// Payment Demo Screen for Testing
// use context7

import 'package:flutter/material.dart';
import '../../models/payment_models.dart';
import '../../models/cart_item.dart';
import '../../common/theme.dart';
import 'enhanced_checkout_screen.dart';

class PaymentDemoScreen extends StatelessWidget {
  const PaymentDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment System Demo'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AnnedFinds Payment System',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Test our secure payment system with multiple payment methods including GCash, Credit/Debit Cards, Online Banking, and Cash on Delivery.',
            ),
            
            const SizedBox(height: 32),
            
            // Payment Method Cards
            _buildPaymentMethodCard(
              context,
              title: 'GCash Payment',
              subtitle: 'Most popular e-wallet in Philippines',
              icon: Icons.account_balance_wallet,
              color: const Color(0xFF007CC3),
              method: PaymentMethod.gcash,
            ),
            
            const SizedBox(height: 16),
            
            _buildPaymentMethodCard(
              context,
              title: 'Credit/Debit Card',
              subtitle: 'Visa, Mastercard with 3D Secure',
              icon: Icons.credit_card,
              color: const Color(0xFF1976D2),
              method: PaymentMethod.card,
            ),
            
            const SizedBox(height: 16),
            
            _buildPaymentMethodCard(
              context,
              title: 'Online Banking',
              subtitle: 'InstaPay and PESONet transfers',
              icon: Icons.account_balance,
              color: const Color(0xFF388E3C),
              method: PaymentMethod.bank_transfer,
            ),
            
            const SizedBox(height: 16),
            
            _buildPaymentMethodCard(
              context,
              title: 'Cash on Delivery',
              subtitle: 'Pay when you receive your order',
              icon: Icons.local_shipping,
              color: const Color(0xFFFF9800),
              method: PaymentMethod.cod,
            ),
            
            const Spacer(),
            
            // Start Demo Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => _startPaymentDemo(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Start Payment Demo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required PaymentMethod method,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey[400],
          ),
        ],
      ),
    );
  }

  void _startPaymentDemo(BuildContext context) {
    // Create demo cart items
    final demoCartItems = [
      CartItem(
        productId: 'demo_product_1',
        productName: 'Wireless Bluetooth Headphones',
        price: 2999.00,
        quantity: 1,
        imageUrl: '',
        addedAt: DateTime.now(),
      ),
      CartItem(
        productId: 'demo_product_2',
        productName: 'USB-C Fast Charging Cable',
        price: 599.00,
        quantity: 2,
        imageUrl: '',
        addedAt: DateTime.now(),
      ),
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedCheckoutScreen(
          cartItems: demoCartItems,
        ),
      ),
    );
  }
}