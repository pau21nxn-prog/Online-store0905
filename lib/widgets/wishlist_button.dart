import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../common/theme.dart';
import '../../models/product.dart';
import '../../services/wishlist_service.dart';

class WishlistButton extends StatefulWidget {
  final Product product;
  final VoidCallback? onWishlistChanged;
  final double size;
  final bool showLabel;

  const WishlistButton({
    super.key,
    required this.product,
    this.onWishlistChanged,
    this.size = 24,
    this.showLabel = false,
  });

  @override
  State<WishlistButton> createState() => _WishlistButtonState();
}

class _WishlistButtonState extends State<WishlistButton>
    with SingleTickerProviderStateMixin {
  bool _isInWishlist = false;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _checkWishlistStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkWishlistStatus() async {
    try {
      final isInWishlist = await WishlistService.isInWishlist(widget.product.id);
      if (mounted) {
        setState(() {
          _isInWishlist = isInWishlist;
        });
      }
    } catch (e) {
      // Handle error silently for now
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _buildButton(
        onPressed: () => _showSignInPrompt(),
        icon: Icons.favorite_border,
        color: Colors.grey,
      );
    }

    return _buildButton(
      onPressed: _isLoading ? null : _toggleWishlist,
      icon: _isInWishlist ? Icons.favorite : Icons.favorite_border,
      color: _isInWishlist ? Colors.red : Colors.grey,
    );
  }

  Widget _buildButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required Color color,
  }) {
    if (widget.showLabel) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isInWishlist ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          foregroundColor: color,
          elevation: 0,
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
        icon: _isLoading
            ? SizedBox(
                width: widget.size * 0.8,
                height: widget.size * 0.8,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            : AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Icon(icon, size: widget.size * 0.8),
                  );
                },
              ),
        label: Text(_isInWishlist ? 'Remove from Wishlist' : 'Add to Wishlist'),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(widget.size),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: _isLoading
              ? SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Icon(
                        icon,
                        size: widget.size,
                        color: color,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _toggleWishlist() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isInWishlist) {
        await WishlistService.removeFromWishlist(widget.product.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.product.name} removed from wishlist'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        await WishlistService.addToWishlist(widget.product);
        _animationController.forward().then((_) {
          _animationController.reverse();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.product.name} added to wishlist'),
              backgroundColor: AppTheme.successGreen,
              duration: const Duration(seconds: 2),
              action: SnackBarAction(
                label: 'View Wishlist',
                textColor: Colors.white,
                onPressed: () {
                  // Navigate to wishlist - implement this based on your navigation
                },
              ),
            ),
          );
        }
      }

      setState(() {
        _isInWishlist = !_isInWishlist;
      });

      widget.onWishlistChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSignInPrompt() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please sign in to add items to your wishlist'),
        backgroundColor: AppTheme.primaryOrange,
      ),
    );
  }
}