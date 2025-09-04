// Payment Failed Screen
// use context7

import 'package:flutter/material.dart';
import '../../models/payment_models.dart';
import '../../common/theme.dart';
import '../../common/mobile_layout_utils.dart';

class PaymentFailedScreen extends StatelessWidget {
  final PaymentIntent paymentIntent;
  final PaymentOrder order;

  const PaymentFailedScreen({
    super.key,
    required this.paymentIntent,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _buildMobileConstrainedBody(context),
    );
  }

  Widget _buildMobileConstrainedBody(BuildContext context) {
    final shouldUseWrapper = MobileLayoutUtils.shouldUseViewportWrapper(context);
    final bodyContent = SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              
              // Failed Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFDC3545).withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.error,
                  size: 80,
                  color: Color(0xFFDC3545),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Failed Message
              Text(
                'Payment Failed',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFDC3545),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                _getFailureMessage(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 48),
              
              // Error Details Card
              _buildErrorDetailsCard(context),
              
              const SizedBox(height: 24),
              
              // Troubleshooting Card
              _buildTroubleshootingCard(context),
              
              const Spacer(),
              
              // Action Buttons
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );

    if (shouldUseWrapper) {
      return Center(
        child: Container(
          width: MobileLayoutUtils.getEffectiveViewportWidth(context),
          decoration: MobileLayoutUtils.getMobileViewportDecoration(),
          child: bodyContent,
        ),
      );
    }
    
    return bodyContent;
  }

  String _getFailureMessage() {
    switch (paymentIntent.status) {
      case PaymentStatus.expired:
        return 'Your payment session has expired. Please try again.';
      case PaymentStatus.cancelled:
        return 'Payment was cancelled. Your order is still reserved.';
      case PaymentStatus.failed:
        return paymentIntent.failureReason ?? 'Payment could not be processed. Please try again.';
      default:
        return 'Something went wrong with your payment. Please try again.';
    }
  }

  Widget _buildErrorDetailsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                Icons.info_outline,
                color: Color(0xFFDC3545),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Payment Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFDC3545),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          _buildDetailRow(context, 'Order ID', order.id),
          _buildDetailRow(context, 'Payment Method', paymentIntent.displayMethod),
          _buildDetailRow(context, 'Amount', paymentIntent.formattedAmount),
          _buildDetailRow(context, 'Status', _getStatusText()),
          if (paymentIntent.failureReason != null)
            _buildDetailRow(context, 'Reason', paymentIntent.failureReason!),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                Icons.help_outline,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Troubleshooting Tips',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          ..._getTroubleshootingTips(context),
        ],
      ),
    );
  }

  List<Widget> _getTroubleshootingTips(BuildContext context) {
    List<String> tips = [];
    
    switch (paymentIntent.method) {
      case PaymentMethod.gcash:
        tips = [
          'Check your GCash wallet balance',
          'Ensure your GCash account is verified',
          'Try again in a few minutes',
          'Check your internet connection',
        ];
        break;
      case PaymentMethod.card:
        tips = [
          'Verify your card details are correct',
          'Check if your card supports online payments',
          'Ensure sufficient balance or credit limit',
          'Contact your bank if 3D Secure fails',
        ];
        break;
      case PaymentMethod.bank_transfer:
        tips = [
          'Check your online banking credentials',
          'Ensure your account has sufficient balance',
          'Try during banking hours for better success',
          'Contact your bank for assistance',
        ];
        break;
      default:
        tips = [
          'Check your internet connection',
          'Try a different payment method',
          'Contact customer support for assistance',
        ];
    }

    return tips.map((tip) => _buildTipItem(context, tip)).toList();
  }

  Widget _buildTipItem(BuildContext context, String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '•',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6C757D),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6C757D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
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
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText() {
    switch (paymentIntent.status) {
      case PaymentStatus.expired:
        return 'Expired';
      case PaymentStatus.cancelled:
        return 'Cancelled';
      case PaymentStatus.failed:
        return 'Failed';
      default:
        return 'Unknown';
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              // Navigate back to checkout to retry
              Navigator.pop(context);
              Navigator.pop(context);
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
              'Try Again',
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
          child: OutlinedButton(
            onPressed: () {
              // Try different payment method
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey[400]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Try Different Payment Method',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        TextButton(
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/',
              (route) => false,
            );
          },
          child: Text(
            'Back to Home',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }
}