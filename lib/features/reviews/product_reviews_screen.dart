import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../common/theme.dart';
import '../../models/product.dart';
import '../../models/review.dart';
import '../../services/reviews_service.dart';
import 'add_review_screen.dart';

class ProductReviewsScreen extends StatefulWidget {
  final Product product;

  const ProductReviewsScreen({super.key, required this.product});

  @override
  State<ProductReviewsScreen> createState() => _ProductReviewsScreenState();
}

class _ProductReviewsScreenState extends State<ProductReviewsScreen> {
  String _sortBy = 'newest';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews & Ratings'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            initialValue: _sortBy,
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'newest', child: Text('Newest First')),
              const PopupMenuItem(value: 'oldest', child: Text('Oldest First')),
              const PopupMenuItem(value: 'highest', child: Text('Highest Rating')),
              const PopupMenuItem(value: 'lowest', child: Text('Lowest Rating')),
              const PopupMenuItem(value: 'helpful', child: Text('Most Helpful')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Rating Summary
          _buildRatingSummary(),
          
          // Add Review Button
          _buildAddReviewButton(),
          
          // Reviews List
          Expanded(
            child: _buildReviewsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSummary() {
    return FutureBuilder<Map<String, dynamic>>(
      future: ReviewsService.getProductRatingSummary(widget.product.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data!;
        final averageRating = data['averageRating'] as double;
        final totalReviews = data['totalReviews'] as int;
        final breakdown = data['ratingBreakdown'] as Map<int, int>;

        return Container(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Average Rating
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          totalReviews > 0 ? averageRating.toStringAsFixed(1) : '0.0',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryOrange,
                          ),
                        ),
                        _buildStarRating(averageRating),
                        const SizedBox(height: 4),
                        Text(
                          '$totalReviews review${totalReviews != 1 ? 's' : ''}',
                          style: AppTheme.captionStyle,
                        ),
                      ],
                    ),
                  ),
                  
                  // Rating Breakdown
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: List.generate(5, (index) {
                        final star = 5 - index;
                        final count = breakdown[star] ?? 0;
                        final percentage = totalReviews > 0 ? count / totalReviews : 0.0;
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Text('$star'),
                              const SizedBox(width: 4),
                              const Icon(Icons.star, size: 16, color: Colors.amber),
                              const SizedBox(width: 8),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: percentage,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.primaryOrange,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 30,
                                child: Text(
                                  '$count',
                                  style: AppTheme.captionStyle,
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, color: Colors.amber, size: 20);
        } else if (index < rating) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 20);
        } else {
          return const Icon(Icons.star_border, color: Colors.amber, size: 20);
        }
      }),
    );
  }

  Widget _buildAddReviewButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: OutlinedButton.icon(
        onPressed: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please sign in to write a review')),
            );
            return;
          }

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddReviewScreen(product: widget.product),
            ),
          );

          if (result == true) {
            setState(() {}); // Refresh the screen
          }
        },
        icon: const Icon(Icons.edit),
        label: const Text('Write a Review'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primaryOrange,
          side: BorderSide(color: AppTheme.primaryOrange),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildReviewsList() {
    return StreamBuilder<List<Review>>(
      stream: ReviewsService.getProductReviews(widget.product.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading reviews: ${snapshot.error}'),
          );
        }

        List<Review> reviews = snapshot.data ?? [];

        // Sort reviews based on selected option
        reviews = _sortReviews(reviews);

        if (reviews.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rate_review, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No reviews yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Be the first to write a review!',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            return _buildReviewCard(reviews[index]);
          },
        );
      },
    );
  }

  List<Review> _sortReviews(List<Review> reviews) {
    switch (_sortBy) {
      case 'oldest':
        return reviews..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case 'highest':
        return reviews..sort((a, b) => b.rating.compareTo(a.rating));
      case 'lowest':
        return reviews..sort((a, b) => a.rating.compareTo(b.rating));
      case 'helpful':
        return reviews..sort((a, b) => b.helpfulCount.compareTo(a.helpfulCount));
      case 'newest':
      default:
        return reviews..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  Widget _buildReviewCard(Review review) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwnReview = currentUser?.uid == review.userId;
    final hasMarkedHelpful = currentUser != null && 
        review.helpfulUsers.contains(currentUser.uid);

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info and Rating
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                  backgroundImage: review.userProfileImage != null
                      ? NetworkImage(review.userProfileImage!)
                      : null,
                  child: review.userProfileImage == null
                      ? Icon(Icons.person, color: AppTheme.primaryOrange)
                      : null,
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            review.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (review.isVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green, width: 1),
                              ),
                              child: const Text(
                                'Verified',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildStarRating(review.rating.toDouble()),
                          const SizedBox(width: 8),
                          Text(
                            review.formattedDate,
                            style: AppTheme.captionStyle,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isOwnReview)
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleReviewAction(value, review),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacing12),
            
            // Review Comment
            Text(
              review.comment,
              style: AppTheme.bodyStyle,
            ),
            
            // Review Images (if any)
            if (review.imageUrls.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacing12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.imageUrls.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          review.imageUrls[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            
            const SizedBox(height: AppTheme.spacing12),
            
            // Helpful Button
            if (!isOwnReview)
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _markHelpful(review.id),
                    icon: Icon(
                      hasMarkedHelpful ? Icons.thumb_up : Icons.thumb_up_outlined,
                      size: 16,
                      color: hasMarkedHelpful ? AppTheme.primaryOrange : Colors.grey,
                    ),
                    label: Text(
                      'Helpful (${review.helpfulCount})',
                      style: TextStyle(
                        color: hasMarkedHelpful ? AppTheme.primaryOrange : Colors.grey,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _handleReviewAction(String action, Review review) {
    if (action == 'edit') {
      // TODO: Implement edit review functionality
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Edit review feature coming soon!')),
      );
    } else if (action == 'delete') {
      _deleteReview(review);
    }
  }

  Future<void> _deleteReview(Review review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ReviewsService.deleteReview(review.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting review: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _markHelpful(String reviewId) async {
    try {
      await ReviewsService.markReviewHelpful(reviewId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }
}