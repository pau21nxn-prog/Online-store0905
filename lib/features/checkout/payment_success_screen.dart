// Payment Success Screen
// use context7

import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../models/payment_models.dart';
import '../../common/theme.dart';
import '../../common/mobile_layout_utils.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final PaymentIntent paymentIntent;
  final PaymentOrder order;

  const PaymentSuccessScreen({
    super.key,
    required this.paymentIntent,
    required this.order,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shouldUseWrapper = MobileLayoutUtils.shouldUseViewportWrapper(context);
    
    if (shouldUseWrapper) {
      return Center(
        child: Container(
          width: MobileLayoutUtils.getEffectiveViewportWidth(context),
          decoration: MobileLayoutUtils.getMobileViewportDecoration(),
          child: _buildScaffoldContent(context),
        ),
      );
    }
    
    return _buildScaffoldContent(context);
  }

  Widget _buildScaffoldContent(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Payment Submitted',
          style: TextStyle(color: AppTheme.textPrimaryColor(context)),
        ),
        backgroundColor: AppTheme.successGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBodyContent(context),
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  
                  // Success Icon and Animation
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.successGreen.withOpacity(0.1),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      size: 80,
                      color: AppTheme.successGreen,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Success Message
                  Text(
                    'Payment Notification Sent!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successGreen,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    'Payment notification sent to admin team and order confirmation sent to your email.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondaryColor(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Order Details Card
                  _buildOrderDetailsCard(),
                  
                  const SizedBox(height: 24),
                  
                  // Payment Details Card
                  _buildPaymentDetailsCard(),
                  
                  const SizedBox(height: 24),
                  
                  // What happens next section
                  _buildNextStepsCard(),
                  
                  const SizedBox(height: 40),
                  
                  // Action Buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
        
        // Confetti Animation
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: 1.57, // Downward
            numberOfParticles: 30,
            colors: const [
              Color(0xFF28A745),
              Color(0xFF007BFF),
              Color(0xFFFFC107),
              Color(0xFFDC3545),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Order Summary',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          _buildDetailRow('Order ID', widget.order.id),
          
          // Detailed items breakdown
          _buildOrderItemsList(),
          
          _buildDetailRow('Total Amount', widget.order.formattedTotal),
          _buildDetailRow('Payment Method', widget.paymentIntent.displayMethod),
          _buildDetailRow('Order Date', _formatDate(widget.order.createdAt)),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.payment,
                color: Color(0xFF28A745),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Payment Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF28A745),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          _buildDetailRow('Payment ID', widget.paymentIntent.id),
          _buildDetailRow('Status', 'Paid'),
          _buildDetailRow('Payment Time', _formatDateTime(DateTime.now())),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF28A745).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.security,
                  color: Color(0xFF28A745),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your payment was processed securely with bank-grade encryption',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF28A745),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade700
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What happens next?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 16),
          _buildNextStepItem('Admin will verify your payment'),
          _buildNextStepItem('You will receive an email confirmation once verified'),
          _buildNextStepItem('Your order will then be processed and shipped'),
        ],
      ),
    );
  }

  Widget _buildNextStepItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              color: AppTheme.primaryOrange,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              // Navigate to order tracking
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/orders',
                (route) => route.isFirst,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Track Your Order',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Back to Home',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildOrderItemsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Items Ordered',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        ...widget.order.items.map((item) => _buildSuccessOrderItem(item)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSuccessOrderItem(dynamic item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name ?? item['name'] ?? 'Unknown Item',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                // Show variant information if available
                if (item.selectedOptions != null && item.selectedOptions!.isNotEmpty)
                  _buildSuccessVariantDisplay(item.selectedOptions!)
                else if (item['selectedOptions'] != null && 
                        (item['selectedOptions'] as Map).isNotEmpty)
                  _buildSuccessVariantDisplay(
                    Map<String, String>.from(item['selectedOptions']),
                  ),
                // Show SKU if available
                if ((item.variantSku ?? item['variantSku']) != null)
                  Text(
                    'SKU: ${item.variantSku ?? item['variantSku']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          Text(
            'x${item.quantity ?? item['quantity'] ?? 1}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            item.formattedPrice ?? 
            '₱${((item['price'] ?? 0.0) * (item['quantity'] ?? 1)).toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessVariantDisplay(Map<String, String> options) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        children: options.entries.map((entry) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF28A745).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              entry.value,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF28A745),
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}