// Payment Method Selector Widget
// Modern Flutter UI for AnnedFinds Payment System
// use context7

import 'package:flutter/material.dart';
import '../../models/payment_models.dart';
import '../../common/theme.dart';

class PaymentMethodSelector extends StatefulWidget {
  final PaymentMethod? selectedMethod;
  final Function(PaymentMethod) onMethodSelected;
  final bool isGuest;
  final double orderTotal;

  const PaymentMethodSelector({
    super.key,
    this.selectedMethod,
    required this.onMethodSelected,
    this.isGuest = false,
    required this.orderTotal,
  });

  @override
  State<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector> {
  PaymentMethod? _selectedMethod;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.selectedMethod;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Pumili ng Paraan ng Bayad',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        
        // GCash - Most Popular
        _buildPaymentMethodTile(
          method: PaymentMethod.gcash,
          title: 'GCash',
          subtitle: 'Instant payment • Secure • Most Popular',
          icon: Icons.account_balance_wallet,
          iconColor: const Color(0xFF007CC3),
          badge: 'INSTANT',
          badgeColor: const Color(0xFF4CAF50),
          isRecommended: true,
        ),

        // Credit/Debit Cards
        _buildPaymentMethodTile(
          method: PaymentMethod.card,
          title: 'Credit/Debit Card',
          subtitle: 'Visa, Mastercard • 3D Secure Protection',
          icon: Icons.credit_card,
          iconColor: const Color(0xFF1976D2),
          badge: 'SECURE',
          badgeColor: const Color(0xFF2196F3),
        ),

        // Bank Transfer
        _buildPaymentMethodTile(
          method: PaymentMethod.bank_transfer,
          title: 'Online Banking',
          subtitle: 'InstaPay (Instant) • PESONet (Next day)',
          icon: Icons.account_balance,
          iconColor: const Color(0xFF388E3C),
          badge: 'BANK-GRADE',
          badgeColor: const Color(0xFF4CAF50),
        ),

        // Cash on Delivery (Registered users only)
        if (!widget.isGuest && widget.orderTotal <= 5000)
          _buildPaymentMethodTile(
            method: PaymentMethod.cod,
            title: 'Cash on Delivery',
            subtitle: 'Pay when you receive • Max ₱5,000',
            icon: Icons.local_shipping,
            iconColor: const Color(0xFFFF9800),
            badge: 'CONVENIENCE',
            badgeColor: const Color(0xFFFF9800),
          ),

        // Additional payment methods for future
        if (false) ...[
          _buildPaymentMethodTile(
            method: PaymentMethod.grab_pay,
            title: 'GrabPay',
            subtitle: 'Pay with GrabPay wallet',
            icon: Icons.directions_car,
            iconColor: const Color(0xFF00B14F),
          ),
          
          _buildPaymentMethodTile(
            method: PaymentMethod.maya,
            title: 'Maya',
            subtitle: 'Digital payments made easy',
            icon: Icons.payment,
            iconColor: const Color(0xFF6B46C1),
          ),
        ],

        const SizedBox(height: 16),
        
        // Security Badge
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE9ECEF)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.security,
                color: Color(0xFF28A745),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PCI DSS Level 1 Certified • SSL Encrypted • 3D Secure',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6C757D),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodTile({
    required PaymentMethod method,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    String? badge,
    Color? badgeColor,
    bool isRecommended = false,
  }) {
    final isSelected = _selectedMethod == method;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0F8FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected 
            ? AppTheme.primaryColor 
            : const Color(0xFFE9ECEF),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected ? [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedMethod = method;
            });
            widget.onMethodSelected(method);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Payment Method Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Title and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isSelected 
                                ? AppTheme.primaryColor 
                                : const Color(0xFF212529),
                            ),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6, 
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE0B2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'RECOMMENDED',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFE65100),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6C757D),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Badge and Selection Indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (badge != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, 
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor?.withOpacity(0.1) ?? Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badge,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeColor ?? Colors.grey[600],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    
                    // Radio button
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected 
                            ? AppTheme.primaryColor 
                            : const Color(0xFFCED4DA),
                          width: 2,
                        ),
                        color: isSelected 
                          ? AppTheme.primaryColor 
                          : Colors.transparent,
                      ),
                      child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 12,
                          )
                        : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Payment Method Info Widget
class PaymentMethodInfo extends StatelessWidget {
  final PaymentMethod method;

  const PaymentMethodInfo({
    super.key,
    required this.method,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Payment Information',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._getPaymentInfo(context),
        ],
      ),
    );
  }

  List<Widget> _getPaymentInfo(BuildContext context) {
    switch (method) {
      case PaymentMethod.gcash:
        return [
          _buildInfoItem(context, 'Processing Time', 'Instant (1-2 minutes)'),
          _buildInfoItem(context, 'Fees', 'Free for orders over ₱500'),
          _buildInfoItem(context, 'Security', 'GCash PIN + SMS OTP'),
          _buildInfoItem(context, 'Cancellation', 'Can cancel before payment'),
        ];
        
      case PaymentMethod.card:
        return [
          _buildInfoItem(context, 'Processing Time', '1-2 minutes'),
          _buildInfoItem(context, 'Security', '3D Secure + CVV verification'),
          _buildInfoItem(context, 'Accepted Cards', 'Visa, Mastercard, JCB'),
          _buildInfoItem(context, 'International', 'Foreign cards accepted'),
        ];
        
      case PaymentMethod.bank_transfer:
        return [
          _buildInfoItem(context, 'InstaPay', 'Instant transfer • ₱0.15 fee'),
          _buildInfoItem(context, 'PESONet', 'Next business day • Free'),
          _buildInfoItem(context, 'Bank Hours', 'InstaPay: 24/7 • PESONet: Banking hours'),
          _buildInfoItem(context, 'Confirmation', 'Automatic via webhook'),
        ];
        
      case PaymentMethod.cod:
        return [
          _buildInfoItem(context, 'Service Fee', '₱50 COD fee'),
          _buildInfoItem(context, 'Payment', 'Cash to courier on delivery'),
          _buildInfoItem(context, 'Limit', 'Maximum ₱5,000 per order'),
          _buildInfoItem(context, 'Delivery Time', '2-5 business days'),
        ];
        
      default:
        return [
          _buildInfoItem(context, 'Status', 'Coming soon'),
        ];
    }
  }

  Widget _buildInfoItem(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: const Color(0xFF495057),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF212529),
              ),
            ),
          ),
        ],
      ),
    );
  }
}