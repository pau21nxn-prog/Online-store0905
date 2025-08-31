import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../common/theme.dart';
import '../../common/mobile_layout_utils.dart';
import '../../models/address.dart';
import '../../services/address_service.dart';

class AddEditAddressScreen extends StatefulWidget {
  final Address? address; // null for add, populated for edit
  
  const AddEditAddressScreen({super.key, this.address});

  @override
  State<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // Form controllers
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _streetAddressController;
  late TextEditingController _apartmentController;
  late TextEditingController _cityController;
  late TextEditingController _provinceController;
  late TextEditingController _postalCodeController;
  late TextEditingController _deliveryInstructionsController;
  
  bool _isDefault = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.address != null;
    _initializeControllers();
    _loadUserEmail();
  }

  void _initializeControllers() {
    final address = widget.address;
    
    _fullNameController = TextEditingController(text: address?.fullName ?? '');
    _emailController = TextEditingController(text: address?.email ?? '');
    _phoneController = TextEditingController(text: address?.phoneNumber ?? '');
    _streetAddressController = TextEditingController(text: address?.streetAddress ?? '');
    _apartmentController = TextEditingController(text: address?.apartmentSuite ?? '');
    _cityController = TextEditingController(text: address?.city ?? '');
    _provinceController = TextEditingController(text: address?.province ?? '');
    _postalCodeController = TextEditingController(text: address?.postalCode ?? '');
    _deliveryInstructionsController = TextEditingController(text: address?.deliveryInstructions ?? '');
    
    _isDefault = address?.isDefault ?? false;
  }

  void _loadUserEmail() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null && _emailController.text.isEmpty) {
      _emailController.text = user!.email!;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _streetAddressController.dispose();
    _apartmentController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    _deliveryInstructionsController.dispose();
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
          _isEditing ? 'Edit Address' : 'Add Address',
          style: TextStyle(color: AppTheme.textPrimaryColor(context)),
        ),
        backgroundColor: AppTheme.backgroundColor(context),
        foregroundColor: AppTheme.textPrimaryColor(context),
        elevation: 0,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _showDeleteDialog,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Contact Information'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _fullNameController,
              label: 'Full Name',
              icon: Icons.person,
              validator: (value) => value?.trim().isEmpty == true ? 'Full name is required' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: 'Email Address *',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value?.trim().isEmpty == true) return 'Email is required';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number (Philippines)',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value?.trim().isEmpty == true) return 'Phone number is required';
                final phoneRegex = RegExp(r'^(\+63|0)(9\d{9})$');
                if (!phoneRegex.hasMatch(value!.replaceAll(RegExp(r'[^\d+]'), ''))) {
                  return 'Please enter a valid Philippine mobile number';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 32),
            _buildSectionTitle('Shipping Address'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _streetAddressController,
              label: 'Street Address',
              icon: Icons.location_on,
              maxLines: 2,
              validator: (value) => value?.trim().isEmpty == true ? 'Street address is required' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _apartmentController,
              label: 'Apartment, Suite, etc. (Optional)',
              icon: Icons.apartment,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _cityController,
                    label: 'City',
                    icon: Icons.location_city,
                    validator: (value) => value?.trim().isEmpty == true ? 'City is required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _provinceController,
                    label: 'Province',
                    icon: Icons.map,
                    validator: (value) => value?.trim().isEmpty == true ? 'Province is required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _postalCodeController,
              label: 'Postal Code',
              icon: Icons.markunread_mailbox,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.trim().isEmpty == true) return 'Postal code is required';
                if (!RegExp(r'^\d{4}$').hasMatch(value!.trim())) {
                  return 'Please enter a valid 4-digit postal code';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _deliveryInstructionsController,
              label: 'Delivery Instructions (Optional)',
              icon: Icons.note,
              maxLines: 3,
            ),

            const SizedBox(height: 24),
            _buildDefaultCheckbox(),
            
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimaryColor(context),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(color: AppTheme.textPrimaryColor(context)),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryOrange),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primaryOrange),
        ),
        filled: true,
        fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
        labelStyle: TextStyle(color: AppTheme.textSecondaryColor(context)),
      ),
    );
  }

  Widget _buildDefaultCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _isDefault,
          onChanged: (value) => setState(() => _isDefault = value ?? false),
          activeColor: AppTheme.primaryOrange,
        ),
        Expanded(
          child: Text(
            'Set as default address',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveAddress,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryOrange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                _isEditing ? 'Update Address' : 'Save Address',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  void _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final address = Address(
        id: widget.address?.id ?? '',
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        streetAddress: _streetAddressController.text.trim(),
        apartmentSuite: _apartmentController.text.trim(),
        city: _cityController.text.trim(),
        province: _provinceController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        deliveryInstructions: _deliveryInstructionsController.text.trim(),
        isDefault: _isDefault,
        createdAt: widget.address?.createdAt ?? DateTime.now(),
      );

      if (_isEditing) {
        await AddressService.updateAddress(widget.address!.id, address);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Address updated successfully'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      } else {
        await AddressService.addAddress(address);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Address saved successfully'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving address: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        title: Text(
          'Delete Address',
          style: TextStyle(color: AppTheme.textPrimaryColor(context)),
        ),
        content: Text(
          'Are you sure you want to delete this address?',
          style: TextStyle(color: AppTheme.textSecondaryColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondaryColor(context)),
            ),
          ),
          ElevatedButton(
            onPressed: _deleteAddress,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteAddress() async {
    Navigator.of(context).pop(); // Close dialog
    setState(() => _isLoading = true);

    try {
      await AddressService.deleteAddress(widget.address!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address deleted successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.of(context).pop(true); // Return to addresses list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting address: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}