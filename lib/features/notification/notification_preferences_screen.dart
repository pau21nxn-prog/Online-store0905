import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = true;
  Map<String, bool> _preferences = {
    'order_updates': true,
    'order_delivered': true,
    'price_drops': true,
    'wishlist_alerts': true,
    'new_products': false,
    'review_reminders': true,
    'promotional': false,
    'low_stock_alerts': true,
    'back_in_stock': true,
  };

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('notifications')
          .get();

      if (doc.exists) {
        setState(() {
          _preferences = Map<String, bool>.from(doc.data() ?? {});
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notification preferences: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('notifications')
          .set(_preferences);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification preferences saved'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error saving notification preferences: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error saving preferences'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _savePreferences,
            child: const Text(
              'Save',
              style: TextStyle(
                color: Color(0xFFFF6B35),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  
                  // Order Notifications Section
                  _buildSection(
                    title: '📦 Order Notifications',
                    description: 'Stay updated on your orders',
                    preferences: [
                      _PreferenceItem(
                        key: 'order_updates',
                        title: 'Order Status Updates',
                        subtitle: 'Get notified when your order status changes',
                        icon: Icons.shopping_bag,
                      ),
                      _PreferenceItem(
                        key: 'order_delivered',
                        title: 'Delivery Confirmations',
                        subtitle: 'Know when your order has been delivered',
                        icon: Icons.local_shipping,
                      ),
                    ],
                  ),

                  // Wishlist Notifications Section
                  _buildSection(
                    title: '❤️ Wishlist Notifications',
                    description: 'Never miss deals on items you love',
                    preferences: [
                      _PreferenceItem(
                        key: 'price_drops',
                        title: 'Price Drop Alerts',
                        subtitle: 'Get notified when wishlist items go on sale',
                        icon: Icons.trending_down,
                      ),
                      _PreferenceItem(
                        key: 'wishlist_alerts',
                        title: 'Wishlist Updates',
                        subtitle: 'General updates about your wishlist items',
                        icon: Icons.favorite,
                      ),
                      _PreferenceItem(
                        key: 'low_stock_alerts',
                        title: 'Low Stock Alerts',
                        subtitle: 'Know when wishlist items are running low',
                        icon: Icons.warning,
                      ),
                      _PreferenceItem(
                        key: 'back_in_stock',
                        title: 'Back in Stock',
                        subtitle: 'Get notified when items are available again',
                        icon: Icons.refresh,
                      ),
                    ],
                  ),

                  // Product Notifications Section
                  _buildSection(
                    title: '🛍️ Product Notifications',
                    description: 'Discover new products and deals',
                    preferences: [
                      _PreferenceItem(
                        key: 'new_products',
                        title: 'New Product Alerts',
                        subtitle: 'Be first to know about new arrivals',
                        icon: Icons.new_releases,
                      ),
                      _PreferenceItem(
                        key: 'promotional',
                        title: 'Promotional Offers',
                        subtitle: 'Get deals and special offers',
                        icon: Icons.local_offer,
                      ),
                    ],
                  ),

                  // Review Notifications Section
                  _buildSection(
                    title: '⭐ Review Notifications',
                    description: 'Share and discover experiences',
                    preferences: [
                      _PreferenceItem(
                        key: 'review_reminders',
                        title: 'Review Reminders',
                        subtitle: 'Reminders to review your purchases',
                        icon: Icons.rate_review,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Quick Actions
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _enableAll,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B35),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Enable All Notifications'),
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _disableAll,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[600],
                              side: BorderSide(color: Colors.grey[300]!),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Disable All Notifications'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required String description,
    required List<_PreferenceItem> preferences,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ...preferences.map((pref) => _buildPreferenceItem(pref)),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceItem(_PreferenceItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              item.icon,
              size: 20,
              color: const Color(0xFFFF6B35),
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          Switch(
            value: _preferences[item.key] ?? false,
            onChanged: (value) {
              setState(() {
                _preferences[item.key] = value;
              });
            },
            activeColor: const Color(0xFFFF6B35),
          ),
        ],
      ),
    );
  }

  void _enableAll() {
    setState(() {
      for (String key in _preferences.keys) {
        _preferences[key] = true;
      }
    });
    _savePreferences();
  }

  void _disableAll() {
    setState(() {
      for (String key in _preferences.keys) {
        _preferences[key] = false;
      }
    });
    _savePreferences();
  }
}

class _PreferenceItem {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;

  _PreferenceItem({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}