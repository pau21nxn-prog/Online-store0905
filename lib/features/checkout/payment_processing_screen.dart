// Payment Processing Screen
// Modern Flutter UI for AnnedFinds Payment System
// use context7

import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/payment_models.dart';
import '../../services/payment_service_new.dart';
import '../../common/theme.dart';
import '../../common/mobile_layout_utils.dart';
import 'payment_success_screen.dart';
import 'payment_failed_screen.dart';

class PaymentProcessingScreen extends StatefulWidget {
  final PaymentIntent paymentIntent;
  final PaymentOrder order;

  const PaymentProcessingScreen({
    super.key,
    required this.paymentIntent,
    required this.order,
  });

  @override
  State<PaymentProcessingScreen> createState() => _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;
  
  Timer? _statusTimer;
  Timer? _timeoutTimer;
  
  PaymentStatus _currentStatus = PaymentStatus.pending;
  String _statusMessage = 'Initializing payment...';
  int _progressStep = 0;
  bool _isProcessing = true;
  
  final PaymentService _paymentService = PaymentService();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startPaymentProcess();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _statusTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.linear,
    ));
    
    _pulseController.repeat(reverse: true);
    _progressController.forward();
  }

  void _startPaymentProcess() async {
    try {
      // Start status monitoring
      _startStatusMonitoring();
      
      // Set timeout based on payment method
      final timeoutDuration = _getTimeoutDuration();
      _timeoutTimer = Timer(timeoutDuration, _handleTimeout);
      
      // Initiate payment based on method
      await _initiatePayment();
      
    } catch (e) {
      _handlePaymentError('Failed to start payment: $e');
    }
  }

  Duration _getTimeoutDuration() {
    switch (widget.paymentIntent.method) {
      case PaymentMethod.gcash:
        return const Duration(minutes: 15);
      case PaymentMethod.card:
        return const Duration(minutes: 10);
      case PaymentMethod.bank_transfer:
        return const Duration(hours: 24);
      case PaymentMethod.cod:
        return const Duration(seconds: 5); // Instant for COD
      default:
        return const Duration(minutes: 10);
    }
  }

  void _startStatusMonitoring() {
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final updatedIntent = await _paymentService.getPaymentIntent(
          widget.paymentIntent.id,
        );
        
        if (updatedIntent != null && updatedIntent.status != _currentStatus) {
          _updatePaymentStatus(updatedIntent);
        }
      } catch (e) {
        debugPrint('Error monitoring payment status: $e');
      }
    });
  }

  void _updatePaymentStatus(PaymentIntent intent) {
    setState(() {
      _currentStatus = intent.status;
      _updateStatusMessage(intent.status);
      _updateProgressStep(intent.status);
    });

    // Handle final states
    if (intent.isSuccessful) {
      _handlePaymentSuccess(intent);
    } else if (intent.isFailed) {
      _handlePaymentFailure(intent);
    }
  }

  void _updateStatusMessage(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        _statusMessage = _getPendingMessage();
        break;
      case PaymentStatus.paid:
        _statusMessage = 'Payment successful! Processing order...';
        break;
      case PaymentStatus.failed:
        _statusMessage = 'Payment failed. Please try again.';
        break;
      case PaymentStatus.expired:
        _statusMessage = 'Payment expired. Please try again.';
        break;
      case PaymentStatus.cancelled:
        _statusMessage = 'Payment cancelled by user.';
        break;
      default:
        _statusMessage = 'Processing payment...';
    }
  }

  String _getPendingMessage() {
    switch (widget.paymentIntent.method) {
      case PaymentMethod.gcash:
        return 'Waiting for GCash confirmation...';
      case PaymentMethod.card:
        return 'Processing card payment...';
      case PaymentMethod.bank_transfer:
        return 'Waiting for bank transfer...';
      case PaymentMethod.cod:
        return 'Confirming cash on delivery...';
      default:
        return 'Processing payment...';
    }
  }

  void _updateProgressStep(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        _progressStep = widget.paymentIntent.method == PaymentMethod.cod ? 2 : 1;
        break;
      case PaymentStatus.paid:
        _progressStep = 3;
        break;
      default:
        _progressStep = 1;
    }
  }

  Future<void> _initiatePayment() async {
    setState(() {
      _statusMessage = 'Connecting to payment provider...';
    });

    try {
      switch (widget.paymentIntent.method) {
        case PaymentMethod.gcash:
          await _initiateGCashPayment();
          break;
        case PaymentMethod.card:
          await _initiateCardPayment();
          break;
        case PaymentMethod.bank_transfer:
          await _initiateBankTransfer();
          break;
        case PaymentMethod.cod:
          await _initiateCODPayment();
          break;
        default:
          throw Exception('Unsupported payment method');
      }
    } catch (e) {
      _handlePaymentError('Payment initiation failed: $e');
    }
  }

  Future<void> _initiateGCashPayment() async {
    setState(() {
      _statusMessage = 'Redirecting to GCash...';
    });
    
    // TODO: Implement GCash payment flow
    // This would typically open a web view or deep link to GCash app
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() {
      _statusMessage = 'Waiting for GCash confirmation...';
      _progressStep = 1;
    });
  }

  Future<void> _initiateCardPayment() async {
    setState(() {
      _statusMessage = 'Securing card payment...';
    });
    
    // TODO: Implement card payment flow with 3D Secure
    await Future.delayed(const Duration(seconds: 3));
    
    setState(() {
      _statusMessage = 'Processing with your bank...';
      _progressStep = 1;
    });
  }

  Future<void> _initiateBankTransfer() async {
    setState(() {
      _statusMessage = 'Generating bank transfer details...';
    });
    
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() {
      _statusMessage = 'Waiting for bank transfer confirmation...';
      _progressStep = 1;
    });
  }

  Future<void> _initiateCODPayment() async {
    setState(() {
      _statusMessage = 'Confirming cash on delivery...';
    });
    
    await Future.delayed(const Duration(seconds: 2));
    
    // COD is immediately confirmed
    final successIntent = widget.paymentIntent.copyWith(
      status: PaymentStatus.paid,
    );
    _updatePaymentStatus(successIntent);
  }

  void _handleTimeout() {
    _statusTimer?.cancel();
    _timeoutTimer?.cancel();
    
    setState(() {
      _isProcessing = false;
      _currentStatus = PaymentStatus.expired;
      _statusMessage = 'Payment timed out. Please try again.';
    });
    
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentFailedScreen(
              paymentIntent: widget.paymentIntent.copyWith(
                status: PaymentStatus.expired,
                failureReason: 'Payment timed out',
              ),
              order: widget.order,
            ),
          ),
        );
      }
    });
  }

  void _handlePaymentSuccess(PaymentIntent intent) {
    _statusTimer?.cancel();
    _timeoutTimer?.cancel();
    _pulseController.stop();
    _progressController.stop();
    
    setState(() {
      _isProcessing = false;
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentSuccessScreen(
              paymentIntent: intent,
              order: widget.order,
            ),
          ),
        );
      }
    });
  }

  void _handlePaymentFailure(PaymentIntent intent) {
    _statusTimer?.cancel();
    _timeoutTimer?.cancel();
    _pulseController.stop();
    _progressController.stop();
    
    setState(() {
      _isProcessing = false;
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentFailedScreen(
              paymentIntent: intent,
              order: widget.order,
            ),
          ),
        );
      }
    });
  }

  void _handlePaymentError(String error) {
    setState(() {
      _isProcessing = false;
      _currentStatus = PaymentStatus.failed;
      _statusMessage = error;
    });
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
    return PopScope(
      canPop: !_isProcessing,
      onPopInvokedWithResult: (didPop, result) async {
        // Prevent back navigation during payment processing
        if (_isProcessing && !didPop) {
          final shouldCancel = await _showCancelDialog();
          if (shouldCancel) {
            _cancelPayment();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor(context),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // App Bar
                Row(
                  children: [
                    if (!_isProcessing)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      'Payment Processing',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
                
                const Spacer(),
                
                // Payment Animation
                _buildPaymentAnimation(),
                
                const SizedBox(height: 48),
                
                // Payment Progress
                _buildPaymentProgress(),
                
                const SizedBox(height: 32),
                
                // Status Message
                _buildStatusMessage(),
                
                const SizedBox(height: 24),
                
                // Payment Details
                _buildPaymentDetails(),
                
                const Spacer(),
                
                // Cancel Button (only during processing)
                if (_isProcessing) _buildCancelButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentAnimation() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isProcessing ? _pulseAnimation.value : 1.0,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStatusColor().withValues(alpha: 0.1),
              border: Border.all(
                color: _getStatusColor(),
                width: 3,
              ),
            ),
            child: Icon(
              _getStatusIcon(),
              size: 48,
              color: _getStatusColor(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentProgress() {
    return Column(
      children: [
        // Progress Steps
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildProgressStep(1, 'Initiate', _progressStep >= 1),
            _buildProgressLine(_progressStep >= 2),
            _buildProgressStep(2, 'Process', _progressStep >= 2),
            _buildProgressLine(_progressStep >= 3),
            _buildProgressStep(3, 'Complete', _progressStep >= 3),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Progress Bar
        if (_isProcessing) ...[
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: _progressAnimation.value,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildProgressStep(int step, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? _getStatusColor() : Colors.grey[300],
          ),
          child: Center(
            child: Text(
              step.toString(),
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? _getStatusColor() : Colors.grey[600],
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(bool isActive) {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 24),
      color: isActive ? _getStatusColor() : Colors.grey[300],
    );
  }

  Widget _buildStatusMessage() {
    return Column(
      children: [
        Text(
          _statusMessage,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: _getStatusColor(),
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 8),
        
        Text(
          _getStatusSubtitle(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getStatusSubtitle() {
    if (!_isProcessing && _currentStatus == PaymentStatus.paid) {
      return 'Your order will be processed shortly';
    }
    
    switch (widget.paymentIntent.method) {
      case PaymentMethod.gcash:
        return 'This usually takes 1-2 minutes';
      case PaymentMethod.card:
        return 'Please wait while we verify your payment';
      case PaymentMethod.bank_transfer:
        return 'Check your banking app for confirmation';
      case PaymentMethod.cod:
        return 'Your order is being confirmed';
      default:
        return 'Please wait...';
    }
  }

  Widget _buildPaymentDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Method',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              Text(
                widget.paymentIntent.displayMethod,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amount',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              Text(
                widget.paymentIntent.formattedAmount,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () async {
          final shouldCancel = await _showCancelDialog();
          if (shouldCancel) {
            _cancelPayment();
          }
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: Colors.grey[400]!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Cancel Payment',
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<bool> _showCancelDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Payment?'),
        content: const Text(
          'Are you sure you want to cancel this payment? You will need to start over.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Payment'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _cancelPayment() {
    _statusTimer?.cancel();
    _timeoutTimer?.cancel();
    
    // TODO: Call payment service to cancel the payment intent
    Navigator.pop(context);
  }

  Color _getStatusColor() {
    switch (_currentStatus) {
      case PaymentStatus.paid:
        return const Color(0xFF28A745);
      case PaymentStatus.failed:
      case PaymentStatus.expired:
      case PaymentStatus.cancelled:
        return const Color(0xFFDC3545);
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _getStatusIcon() {
    switch (_currentStatus) {
      case PaymentStatus.paid:
        return Icons.check_circle;
      case PaymentStatus.failed:
      case PaymentStatus.expired:
        return Icons.error;
      case PaymentStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.payment;
    }
  }
}