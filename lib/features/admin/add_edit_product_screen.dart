import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'dart:typed_data';
import '../../common/theme.dart';
import '../../models/product.dart';
import '../../models/product_variant.dart';
import '../../models/product_media.dart';
import '../../models/product_lock.dart';
import '../../models/category.dart';
import '../../models/variant_option.dart';
import '../../services/storage_service.dart';
import '../../services/category_service.dart';
import '../../widgets/variant_selector_widgets.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product;
  
  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  // Form controllers
  final _basicInfoFormKey = GlobalKey<FormState>();
  final _variantsFormKey = GlobalKey<FormState>();
  final _specsFormKey = GlobalKey<FormState>();
  
  // Basic Info controllers
  final _titleController = TextEditingController();
  final _slugController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _detailedDescriptionController = TextEditingController();
  final _brandController = TextEditingController();
  
  // Pricing controllers
  final _basePriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  
  // Shipping controllers
  final _shippingWeightController = TextEditingController();
  final _shippingFeeController = TextEditingController();
  final _freeShippingThresholdController = TextEditingController();
  
  // Current product state
  Product? _currentProduct;
  ProductLock? _productLock;
  List<Category> _categories = [];
  List<ProductVariant> _variants = [];
  List<ProductMedia> _media = [];
  List<ProductOption> _options = [];
  Map<String, String> _specs = {};
  
  // New variant system state
  List<VariantAttribute> _variantAttributes = [];
  List<VariantConfiguration> _variantConfigurations = [];
  bool _hasCustomizableVariants = false;
  
  // UI state
  bool _isLoading = false;
  bool _isDirty = false;
  bool _isAutoSaving = false;
  ProductStatus _status = ProductStatus.draft;
  String? _selectedCategoryId;
  Timer? _autosaveTimer;
  
  static const Duration _autosaveDelay = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
    _setupAutosave();
    if (widget.product != null) {
      _loadProductData();
      _tryAcquireLock();
    } else {
      _initializeNewProduct();
    }
  }

  void _setupAutosave() {
    // Listen to form changes for autosave
    _titleController.addListener(_onFormChanged);
    _slugController.addListener(_onFormChanged);
    _descriptionController.addListener(_onFormChanged);
    _detailedDescriptionController.addListener(_onFormChanged);
    _brandController.addListener(_onFormChanged);
    _basePriceController.addListener(_onPricingChanged);
    _salePriceController.addListener(_onPricingChanged);
    _costPriceController.addListener(_onPricingChanged);
    _shippingWeightController.addListener(_onShippingChanged);
    _shippingFeeController.addListener(_onShippingChanged);
    _freeShippingThresholdController.addListener(_onShippingChanged);
  }

  void _onShippingChanged() {
    _onFormChanged();
    // Trigger UI update for shipping summary
    setState(() {});
  }

  void _onPricingChanged() {
    _onFormChanged();
    // Trigger UI update for price summary
    setState(() {});
  }

  void _onFormChanged() {
    if (!_isDirty) {
      setState(() {
        _isDirty = true;
      });
    }
    
    // Disable automatic draft saving - admin must manually click "Save Draft"
    // _autosaveTimer?.cancel();
    // _autosaveTimer = Timer(_autosaveDelay, _performAutosave);
  }

  Future<void> _performAutosave() async {
    if (!_isDirty || _isAutoSaving) return;
    
    setState(() {
      _isAutoSaving = true;
    });
    
    try {
      await _saveDraft();
      setState(() {
        _isDirty = false;
      });
    } catch (e) {
      debugPrint('Autosave failed: $e');
    } finally {
      setState(() {
        _isAutoSaving = false;
      });
    }
  }

  void _initializeNewProduct() {
    _currentProduct = Product(
      id: '',
      title: '',
      slug: '',
      description: '',
      primaryCategoryId: '',
      priceRange: PriceRange(min: 0, max: 0),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'current_user_id', // Replace with actual user ID
      updatedBy: 'current_user_id',
    );
  }

  Future<void> _loadInitialData() async {
    await _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await CategoryService.getAllCategories();
      debugPrint('📋 Loaded ${categories.length} categories in edit product screen');
      
      // If no categories exist, initialize them
      if (categories.isEmpty) {
        debugPrint('⚠️ No categories found. Initializing 26 categories...');
        await CategoryService.initializeCategoriesFromList();
        final newCategories = await CategoryService.getAllCategories();
        debugPrint('✅ Initialized ${newCategories.length} categories!');
        setState(() {
          _categories = newCategories;
        });
      } else {
        setState(() {
          _categories = categories;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading categories: $e')),
      );
    }
  }

  void _loadProductData() {
    final product = widget.product!;
    _currentProduct = product;
    _titleController.text = product.title;
    _slugController.text = product.slug;
    _descriptionController.text = product.description;
    _detailedDescriptionController.text = product.detailedDescription;
    _selectedCategoryId = product.primaryCategoryId;
    _status = product.workflow.stage;
    _specs = Map<String, String>.from(product.specs);
    
    // Load pricing data if available
    if (product.priceRange.min > 0) {
      _basePriceController.text = product.priceRange.max.toStringAsFixed(2);
      if (product.priceRange.min < product.priceRange.max) {
        _salePriceController.text = product.priceRange.min.toStringAsFixed(2);
      }
    }
    
    // Load shipping data if available
    final shippingData = product.shipping;
    if (shippingData.isNotEmpty) {
      if (shippingData['weight'] != null) {
        _shippingWeightController.text = shippingData['weight'].toString();
      }
      if (shippingData['fee'] != null) {
        _shippingFeeController.text = shippingData['fee'].toString();
      }
      if (shippingData['freeShippingThreshold'] != null) {
        _freeShippingThresholdController.text = shippingData['freeShippingThreshold'].toString();
      }
    }
    
    // Load variant system data
    _variantAttributes = List.from(product.variantAttributes);
    _variantConfigurations = List.from(product.variantConfigurations);
    _hasCustomizableVariants = product.hasCustomizableVariants;
    
    // Load media data from product document
    _loadProductMediaFromDocument();
    
    _loadProductVariants();
  }

  Future<void> _loadProductVariants() async {
    if (widget.product == null) return;
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.product!.id)
          .collection('variants')
          .orderBy('isDefault', descending: true)
          .get();
      
      setState(() {
        _variants = snapshot.docs
            .map((doc) => ProductVariant.fromFirestore(doc.id, doc.data()))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading variants: $e');
    }
  }

  void _loadProductMediaFromDocument() async {
    if (widget.product == null) return;
    
    try {
      print('🔍 DEBUG: Loading media from product document...');
      
      // Load fresh product document to get current media data
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.product!.id)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        print('🔍 DEBUG: Product document loaded. Keys: ${data.keys.toList()}');
        
        // Load imageUrls array from document
        final imageUrls = List<String>.from(data['imageUrls'] ?? []);
        print('🔍 DEBUG: Found ${imageUrls.length} image URLs: $imageUrls');
        
        if (imageUrls.isNotEmpty) {
          final List<ProductMedia> loadedMedia = [];
          
          for (int i = 0; i < imageUrls.length; i++) {
            final imageUrl = imageUrls[i];
            print('🔍 DEBUG: Creating media object for: $imageUrl');
            
            final media = ProductMedia(
              id: 'loaded_${DateTime.now().millisecondsSinceEpoch}_$i',
              productId: widget.product!.id,
              storagePath: imageUrl,
              type: MediaType.image,
              role: i == 0 ? MediaRole.cover : MediaRole.gallery,
              order: i,
              altText: 'Product image ${i + 1}',
              metadata: {
                'source': 'loaded_from_document',
                'loadedAt': DateTime.now().toIso8601String(),
              },
              isProcessed: true,
              createdAt: DateTime.now(),
              createdBy: 'system',
            );
            
            loadedMedia.add(media);
          }
          
          setState(() {
            _media = loadedMedia;
          });
          
          print('🔍 DEBUG: Loaded ${loadedMedia.length} media items');
        } else {
          print('🔍 DEBUG: No image URLs found in document');
          setState(() {
            _media = [];
          });
        }
      } else {
        print('🔍 DEBUG: Product document not found');
      }
    } catch (e) {
      print('🔍 DEBUG: Error loading media from document: $e');
      setState(() {
        _media = [];
      });
    }
  }
  
  Future<void> _loadProductMedia() async {
    // This method is no longer used but kept for compatibility
    return;
  }

  Future<void> _tryAcquireLock() async {
    if (widget.product == null) return;
    
    try {
      // Implementation for product locking will be added with the service
      debugPrint('Attempting to acquire lock for product ${widget.product!.id}');
    } catch (e) {
      // Show warning that product is locked by another user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Warning: Product may be edited by another user'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add Product' : 'Edit Product'),
        actions: [
          // Autosave indicator
          if (_isAutoSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          
          // Dirty indicator
          if (_isDirty && !_isAutoSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Icon(Icons.circle, size: 8, color: Colors.orange),
            ),
          
          // Actions menu
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'preview',
                child: ListTile(
                  leading: Icon(Icons.preview),
                  title: Text('Preview'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (widget.product != null)
                const PopupMenuItem(
                  value: 'duplicate',
                  child: ListTile(
                    leading: Icon(Icons.copy),
                    title: Text('Duplicate'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Export Data'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (widget.product != null)
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Delete', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'Basic Info'),
            Tab(icon: Icon(Icons.photo_library), text: 'Media'),
            Tab(icon: Icon(Icons.description), text: 'Details'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBasicInfoTab(),
          _buildMediaTab(),
          _buildDetailsTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildBasicInfoTab() {
    return Form(
      key: _basicInfoFormKey,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        children: [
          // Title
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Product Title *',
              border: OutlineInputBorder(),
              helperText: 'Enter a clear, descriptive product name',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter product title';
              }
              return null;
            },
            onChanged: (_) => _generateSlug(),
          ),
          
          const SizedBox(height: AppTheme.spacing16),
          
          // Slug
          TextFormField(
            controller: _slugController,
            decoration: const InputDecoration(
              labelText: 'URL Slug',
              border: OutlineInputBorder(),
              helperText: 'Auto-generated from title, can be customized',
              prefixText: '/products/',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter URL slug';
              }
              if (!RegExp(r'^[a-z0-9-]+$').hasMatch(value)) {
                return 'Slug can only contain lowercase letters, numbers, and hyphens';
              }
              return null;
            },
          ),
          
          const SizedBox(height: AppTheme.spacing16),
          
          // Category
          DropdownButtonFormField<String>(
            value: _selectedCategoryId,
            decoration: const InputDecoration(
              labelText: 'Category *',
              border: OutlineInputBorder(),
            ),
            items: _categories.map((category) {
              return DropdownMenuItem(
                value: category.id,
                child: Text(category.name),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCategoryId = value;
              });
              _onFormChanged();
            },
            validator: (value) {
              if (value == null) {
                return 'Please select a category';
              }
              return null;
            },
          ),
          
          const SizedBox(height: AppTheme.spacing16),
          
          // Brand
          TextFormField(
            controller: _brandController,
            decoration: const InputDecoration(
              labelText: 'Brand',
              border: OutlineInputBorder(),
              helperText: 'Enter the product brand or manufacturer',
            ),
          ),
          
          const SizedBox(height: AppTheme.spacing16),
          
          // Description
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Short Description *',
              border: OutlineInputBorder(),
              helperText: 'Brief description for product listings (max 160 chars)',
            ),
            maxLines: 3,
            maxLength: 160,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter description';
              }
              return null;
            },
          ),
          
          const SizedBox(height: AppTheme.spacing16),
          
          // Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Product Status',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  DropdownButtonFormField<ProductStatus>(
                    value: _status,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: ProductStatus.values.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Row(
                          children: [
                            _getStatusIcon(status),
                            const SizedBox(width: 8),
                            Text(_getStatusDisplayName(status)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _status = value!;
                      });
                      _onFormChanged();
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: AppTheme.spacing16),
          
          // Pricing Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.attach_money, color: AppTheme.primaryOrange),
                      const SizedBox(width: 8),
                      const Text(
                        'Pricing',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  
                  Row(
                    children: [
                      // Base Price
                      Expanded(
                        child: TextFormField(
                          controller: _basePriceController,
                          decoration: const InputDecoration(
                            labelText: 'Base Price *',
                            border: OutlineInputBorder(),
                            prefixText: '₱ ',
                            helperText: 'Regular selling price',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            final price = double.tryParse(value);
                            if (price == null || price <= 0) {
                              return 'Enter valid price';
                            }
                            return null;
                          },
                        ),
                      ),
                      
                      const SizedBox(width: AppTheme.spacing12),
                      
                      // Sale Price
                      Expanded(
                        child: TextFormField(
                          controller: _salePriceController,
                          decoration: const InputDecoration(
                            labelText: 'Sale Price',
                            border: OutlineInputBorder(),
                            prefixText: '₱ ',
                            helperText: 'Discounted price (optional)',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final salePrice = double.tryParse(value);
                              final basePrice = double.tryParse(_basePriceController.text);
                              if (salePrice == null || salePrice <= 0) {
                                return 'Enter valid price';
                              }
                              if (basePrice != null && salePrice >= basePrice) {
                                return 'Must be less than base price';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppTheme.spacing12),
                  
                  // Cost Price
                  TextFormField(
                    controller: _costPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Cost Price',
                      border: OutlineInputBorder(),
                      prefixText: '₱ ',
                      helperText: 'Your cost for this product (for profit tracking)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final price = double.tryParse(value);
                        if (price == null || price < 0) {
                          return 'Enter valid cost';
                        }
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: AppTheme.spacing12),
                  
                  // Price Summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        _buildPriceSummaryRow('Selling Price:', _getCurrentSellingPrice()),
                        if (_getPotentialSavings() > 0) ...[
                          const SizedBox(height: 4),
                          _buildPriceSummaryRow('You Save:', '₱${_getPotentialSavings().toStringAsFixed(2)}', 
                              isDiscount: true),
                        ],
                        if (_getProfitMargin() != null) ...[
                          const SizedBox(height: 4),
                          _buildPriceSummaryRow('Estimated Profit:', _getProfitMargin()!, 
                              isProfit: true),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaTab() {
    return Column(
      children: [
        // Media upload options
        Container(
          margin: const EdgeInsets.all(AppTheme.spacing16),
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange.withOpacity(0.05),
            border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(AppTheme.radius8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.photo_library, color: AppTheme.primaryOrange),
                  const SizedBox(width: 8),
                  const Text(
                    'Product Images',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing12),
              Text(
                'Upload high-quality images to showcase your product. First image will be used as primary.',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: AppTheme.spacing16),
              
              // Upload options
              Row(
                children: [
                  // Browse Files
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _selectMediaFiles,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Browse Files'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: AppTheme.spacing8),
                  
                  // Add from URL
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addImageFromUrl,
                      icon: const Icon(Icons.link),
                      label: const Text('Add from URL'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: AppTheme.spacing16),
        
        // Media list
        Expanded(
          child: _media.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined, 
                           size: 48, 
                           color: Colors.grey),
                      SizedBox(height: AppTheme.spacing16),
                      Text(
                        'No images uploaded yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: AppTheme.spacing8),
                      Text(
                        'Upload your first image to get started',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                  itemCount: _media.length,
                  onReorder: _reorderMedia,
                  itemBuilder: (context, index) {
                    final media = _media[index];
                    return _buildMediaItem(media, index);
                  },
                ),
        ),
      ],
    );
  }


  Widget _buildDetailsTab() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      children: [
        // Rich text description
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detailed Description',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: AppTheme.spacing8),
                TextFormField(
                  controller: _detailedDescriptionController,
                  maxLines: 8,
                  minLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Enter detailed product description with specifications, features, and usage information...',
                    border: OutlineInputBorder(),
                    helperText: 'This will be displayed on the product detail page',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    // Detailed description is optional, so no validation required
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: AppTheme.spacing16),
        
        // Customizable Variants Toggle
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Product Variants',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: AppTheme.spacing8),
                CheckboxListTile(
                  title: const Text('Enable customizable variants'),
                  subtitle: const Text('Allow customers to select size, color, or other options'),
                  value: _hasCustomizableVariants,
                  onChanged: (value) {
                    setState(() {
                      _hasCustomizableVariants = value ?? false;
                      if (!_hasCustomizableVariants) {
                        _variantAttributes.clear();
                        _variantConfigurations.clear();
                      }
                    });
                    _onFormChanged();
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
        ),
        
        // Variant Attributes Management
        if (_hasCustomizableVariants) ...[
          const SizedBox(height: AppTheme.spacing16),
          VariantAttributeSelector(
            attributes: _variantAttributes,
            onAttributesChanged: (attributes) {
              setState(() {
                _variantAttributes = attributes;
                // Clear configurations when attributes change significantly
                if (_variantConfigurations.isNotEmpty) {
                  _variantConfigurations.clear();
                }
              });
              _onFormChanged();
            },
          ),
          
          const SizedBox(height: AppTheme.spacing16),
          
          // Variant Configurations Management
          VariantConfigurationManager(
            attributes: _variantAttributes,
            configurations: _variantConfigurations,
            baseSkuCode: _slugController.text.toUpperCase(),
            onConfigurationsChanged: (configurations) {
              setState(() {
                _variantConfigurations = configurations;
              });
              _onFormChanged();
            },
          ),
        ],
      ],
    );
  }


  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Save as Draft
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : _saveDraft,
              child: const Text('Save Draft'),
            ),
          ),
          
          const SizedBox(width: AppTheme.spacing8),
          
          // Save & Publish
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveAndPublish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(widget.product == null ? 'Create Product' : 'Update Product'),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for UI
  void _generateSlug() {
    final title = _titleController.text.toLowerCase();
    final slug = title
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .trim();
    _slugController.text = slug;
    _onFormChanged();
  }

  Widget _getStatusIcon(ProductStatus status) {
    switch (status) {
      case ProductStatus.draft:
        return const Icon(Icons.edit, color: Colors.grey);
      case ProductStatus.review:
        return const Icon(Icons.rate_review, color: Colors.orange);
      case ProductStatus.approved:
        return const Icon(Icons.check_circle, color: Colors.green);
      case ProductStatus.published:
        return const Icon(Icons.public, color: Colors.blue);
      case ProductStatus.archived:
        return const Icon(Icons.archive, color: Colors.red);
    }
  }

  String _getStatusDisplayName(ProductStatus status) {
    switch (status) {
      case ProductStatus.draft:
        return 'Draft';
      case ProductStatus.review:
        return 'Under Review';
      case ProductStatus.approved:
        return 'Approved';
      case ProductStatus.published:
        return 'Published';
      case ProductStatus.archived:
        return 'Archived';
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'preview':
        _previewProduct();
        break;
      case 'duplicate':
        _duplicateProduct();
        break;
      case 'export':
        _exportProductData();
        break;
      case 'delete':
        _deleteProduct();
        break;
    }
  }

  void _previewProduct() {
    // Navigate to product detail screen with preview mode
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preview functionality will be implemented')),
    );
  }

  void _duplicateProduct() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Duplicate functionality will be implemented')),
    );
  }

  void _exportProductData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality will be implemented')),
    );
  }

  // Media methods
  void _selectMediaFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        allowedExtensions: null, // Will default to common image types
        withData: true, // Need file data for web
      );
      
      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.bytes != null) {
            await _processSelectedFile(file);
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully added ${result.files.length} image(s)!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting files: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _processSelectedFile(PlatformFile file) async {
    try {
      // Validate file size (max 10MB)
      if (file.size > 10 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File ${file.name} is too large. Maximum size is 10MB.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Validate file type
      if (!_isValidImageFile(file.name)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File ${file.name} is not a supported image format.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Show uploading state
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Uploading ${file.name}...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Upload to Firebase Storage with optimization
      final productId = _currentProduct?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
      
      print('🔍 DEBUG: Starting upload for product ID: $productId');
      print('🔍 DEBUG: File size: ${file.size} bytes');
      print('🔍 DEBUG: File name: ${file.name}');
      
      final imageVariants = await StorageService.uploadProductImages(
        productId: productId,
        imageFiles: [file.bytes!],
        fileNames: [file.name],
        onProgress: (progress) {
          print('📊 Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
        },
      );
      
      print('🔍 DEBUG: Upload completed. Variants received: ${imageVariants.length}');
      if (imageVariants.isNotEmpty) {
        print('🔍 DEBUG: First variant URLs: ${imageVariants.first}');
      }
      
      if (imageVariants.isNotEmpty) {
        final variants = imageVariants.first;
        
        final media = ProductMedia(
          id: 'img_${DateTime.now().millisecondsSinceEpoch}_${_media.length}',
          productId: productId,
          storagePath: variants['medium'] ?? variants['thumb'] ?? '',
          type: MediaType.image,
          role: _media.isEmpty ? MediaRole.cover : MediaRole.gallery,
          order: _media.length,
          altText: file.name.split('.').first,
          variants: MediaVariants(
            image: {
              'thumb': variants['thumb'] ?? '',
              'md': variants['medium'] ?? '',
              'xl': variants['large'] ?? '',
            },
          ),
          metadata: {
            'source': 'firebase_storage',
            'originalName': file.name,
            'size': file.size,
            'uploadedAt': DateTime.now().toIso8601String(),
            'optimized': true,
          },
          isProcessed: true,
          createdAt: DateTime.now(),
          createdBy: 'current_user_id',
        );
        
        setState(() {
          _media.add(media);
        });
        
        _onFormChanged();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ ${file.name} uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading ${file.name}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  bool _isValidImageFile(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(extension);
  }
  
  // Note: In a production app, you would:
  // 1. Upload files to Firebase Storage
  // 2. Get the download URL from Firebase Storage
  // 3. Store only the URL (not the file data) in Firestore
  // This prevents document size limit issues

  void _addImageFromUrl() async {
    final controller = TextEditingController();
    
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Image from URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Image URL',
                hintText: 'https://example.com/image.jpg',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            Text(
              'Supported formats: JPG, PNG, WebP',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty && _isValidImageUrl(url)) {
                Navigator.pop(context, url);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid image URL')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    
    if (url != null) {
      _addImageFromUrlString(url);
    }
  }

  bool _isValidImageUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final isValidScheme = uri.scheme == 'http' || uri.scheme == 'https';
      final hasImageExtension = url.toLowerCase().contains(RegExp(r'\.(jpg|jpeg|png|webp)'));
      return isValidScheme && hasImageExtension;
    } catch (e) {
      return false;
    }
  }

  void _addImageFromUrlString(String url) {
    final media = ProductMedia(
      id: 'url_${DateTime.now().millisecondsSinceEpoch}',
      productId: _currentProduct?.id ?? 'new',
      storagePath: url,
      type: MediaType.image,
      role: _media.isEmpty ? MediaRole.cover : MediaRole.gallery,
      order: _media.length,
      altText: 'Product image',
      metadata: {
        'source': 'url',
        'addedAt': DateTime.now().toIso8601String(),
      },
      createdAt: DateTime.now(),
      createdBy: 'current_user_id',
    );
    
    setState(() {
      _media.add(media);
    });
    
    _onFormChanged();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image added from URL successfully!')),
    );
  }

  void _addSampleImage() {
    final media = ProductMedia(
      id: 'sample_${DateTime.now().millisecondsSinceEpoch}',
      productId: _currentProduct?.id ?? 'new',
      storagePath: 'https://via.placeholder.com/400x400.png?text=Sample+Product+Image',
      type: MediaType.image,
      role: _media.isEmpty ? MediaRole.cover : MediaRole.gallery,
      order: _media.length,
      altText: 'Sample product image',
      metadata: {
        'source': 'sample',
        'addedAt': DateTime.now().toIso8601String(),
      },
      createdAt: DateTime.now(),
      createdBy: 'current_user_id',
    );
    
    setState(() {
      _media.add(media);
    });
    
    _onFormChanged();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sample image added successfully!')),
    );
  }

  void _reorderMedia(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final media = _media.removeAt(oldIndex);
      _media.insert(newIndex, media);
    });
    _onFormChanged();
  }

  Widget _buildMediaItem(ProductMedia media, int index) {
    final isPrimary = media.role == MediaRole.cover || index == 0;
    
    return Card(
      key: ValueKey(media.id),
      elevation: isPrimary ? 4 : 2,
      color: isPrimary ? AppTheme.primaryOrange.withOpacity(0.05) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Image preview
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.grey.shade100,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: media.storagePath.isNotEmpty
                    ? Image.network(
                        media.storagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          print('🖼️ Image load error: $error');
                          return const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 24,
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                      )
                    : const Icon(
                        Icons.image,
                        color: Colors.grey,
                        size: 24,
                      ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Media info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Image ${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (isPrimary) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PRIMARY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    media.roleDisplayName,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  if (media.altText?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      media.altText!,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Set as primary
                if (!isPrimary)
                  IconButton(
                    icon: const Icon(Icons.star_border, size: 20),
                    onPressed: () => _setAsPrimary(index),
                    tooltip: 'Set as primary image',
                  ),
                
                // Edit alt text
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _editMediaAltText(media, index),
                  tooltip: 'Edit alt text',
                ),
                
                // Delete
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () => _removeMedia(index),
                  tooltip: 'Remove image',
                ),
                
                // Drag handle
                const Icon(Icons.drag_handle, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _setAsPrimary(int index) {
    setState(() {
      // Reset all media roles to gallery and update order
      for (int i = 0; i < _media.length; i++) {
        _media[i] = _media[i].copyWith(
          role: MediaRole.gallery,
          order: i,
        );
      }
      
      // Set selected media as cover (primary)
      _media[index] = _media[index].copyWith(role: MediaRole.cover);
      
      // Move to front of list if not already
      if (index != 0) {
        final media = _media.removeAt(index);
        _media.insert(0, media);
        
        // Update order again after reordering
        for (int i = 0; i < _media.length; i++) {
          _media[i] = _media[i].copyWith(order: i);
        }
      }
    });
    
    _onFormChanged();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Primary image updated!')),
    );
  }

  void _editMediaAltText(ProductMedia media, int index) async {
    final controller = TextEditingController(text: media.altText ?? '');
    
    final altText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Alt Text'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Alt Text',
                hintText: 'Describe this image for accessibility',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Text(
              'Alt text helps screen readers and improves SEO',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (altText != null) {
      setState(() {
        _media[index] = _media[index].copyWith(
          altText: altText.isEmpty ? null : altText,
        );
      });
      
      _onFormChanged();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alt text updated!')),
      );
    }
  }

  void _removeMedia(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Image'),
        content: const Text('Are you sure you want to remove this image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() {
        _media.removeAt(index);
        
        // Update order for remaining items
        for (int i = 0; i < _media.length; i++) {
          _media[i] = _media[i].copyWith(order: i);
        }
        
        // If we removed the cover image, make the first image cover
        if (_media.isNotEmpty && !_media.any((m) => m.role == MediaRole.cover)) {
          _media[0] = _media[0].copyWith(role: MediaRole.cover);
        }
      });
      
      _onFormChanged();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image removed successfully!')),
      );
    }
  }

  // Variants methods
  void _addProductOption() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add option dialog will be implemented')),
    );
  }

  Widget _buildOptionRow(ProductOption option) {
    return Card(
      child: ListTile(
        title: Text(option.name),
        subtitle: Text(option.values.join(', ')),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _removeOption(option),
        ),
      ),
    );
  }

  void _removeOption(ProductOption option) {
    setState(() {
      _options.remove(option);
    });
    _onFormChanged();
  }

  Widget _buildVariantCard(ProductVariant variant) {
    return Card(
      child: ListTile(
        title: Text(variant.sku),
        subtitle: Text(variant.variantDisplayName),
        trailing: Text(variant.formattedPrice),
      ),
    );
  }


  // Save methods
  
  Future<void> _saveDraft() async {
    // Skip autosave if required fields are not filled
    if (_titleController.text.trim().isEmpty || 
        _slugController.text.trim().isEmpty || 
        _descriptionController.text.trim().isEmpty ||
        _selectedCategoryId == null) {
      print('🔍 Autosave skipped: Required fields not filled');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final productData = _buildProductData(ProductStatus.draft);
      
      if (widget.product == null) {
        // Create new product
        final docRef = await FirebaseFirestore.instance
            .collection('products')
            .add(productData);
        
        _currentProduct = _currentProduct!.copyWith(id: docRef.id);
      } else {
        // Update existing product
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product!.id)
            .update(productData);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving draft: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAndPublish() async {
    print('🔍 DEBUG: _saveAndPublish called');
    
    // Simple validation first
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a product title')),
      );
      return;
    }
    
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔍 DEBUG: Building simplified product data...');
      
      // Build product data with proper pricing
      final basePrice = double.tryParse(_basePriceController.text) ?? 0.0;
      final salePrice = double.tryParse(_salePriceController.text);
      final finalPrice = salePrice ?? basePrice; // Use sale price if available, otherwise base price
      
      final productData = {
        'title': _titleController.text.trim(),
        'slug': _slugController.text.trim().isEmpty ? 
               _titleController.text.toLowerCase().replaceAll(' ', '-') : 
               _slugController.text.trim(),
        'description': _descriptionController.text.trim(),
        'detailedDescription': _detailedDescriptionController.text.trim(),
        'primaryCategoryId': _selectedCategoryId!,
        'workflow': {
          'stage': 'published',
        },
        'priceRange': {
          'min': finalPrice, // Show sale price to customers (if available)
          'max': basePrice,  // Keep original base price
          'currency': 'PHP',
        },
        'pricing': {
          'basePrice': basePrice,
          'salePrice': salePrice, // Preserve sale price
          'currency': 'PHP',
        },
        'imageUrls': _media.map((m) => m.storagePath).toList(),
        // Variant system data
        'hasCustomizableVariants': _hasCustomizableVariants,
        'variantAttributes': _variantAttributes.map((attr) => attr.toMap()).toList(),
        'variantConfigurations': _variantConfigurations.map((config) => config.toMap()).toList(),
        'updatedAt': Timestamp.now(),
        'updatedBy': 'admin',
      };
      
      // Add creation fields only for new products
      if (widget.product == null) {
        productData['createdAt'] = Timestamp.now();
        productData['createdBy'] = 'admin';
      }
      
      print('🔍 DEBUG: Simplified product data built');
      
      if (widget.product == null) {
        print('🔍 DEBUG: Creating new product...');
        final docRef = await FirebaseFirestore.instance
            .collection('products')
            .add(productData);
        print('🔍 DEBUG: New product created with ID: ${docRef.id}');
      } else {
        print('🔍 DEBUG: Updating existing product ID: ${widget.product!.id}');
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product!.id)
            .update(productData);
        print('🔍 DEBUG: Product updated successfully');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product saved successfully!')),
      );
      
      Navigator.pop(context, true);
    } catch (e) {
      print('🔍 DEBUG: Error in _saveAndPublish: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving product: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _buildProductData(ProductStatus status) {
    print('🔍 DEBUG: Building product data...');
    
    try {
      // Calculate pricing data
      print('🔍 DEBUG: Calculating pricing...');
      final basePrice = double.tryParse(_basePriceController.text) ?? 0.0;
      final salePrice = double.tryParse(_salePriceController.text);
      final finalPrice = salePrice ?? basePrice;
      print('🔍 DEBUG: Base price: $basePrice, Sale price: $salePrice, Final price: $finalPrice');
      
      // Build media data safely
      print('🔍 DEBUG: Processing media... Count: ${_media.length}');
      List<Map<String, dynamic>> mediaData = [];
      List<String> imageUrls = [];
      String? primaryImageUrl;
      
      try {
        for (int i = 0; i < _media.length; i++) {
          final media = _media[i];
          print('🔍 DEBUG: Processing media $i: ${media.id}');
          
          // Add to imageUrls if it's an image
          if (media.isImage) {
            imageUrls.add(media.storagePath);
            print('🔍 DEBUG: Added image URL: ${media.storagePath}');
          }
          
          // Check for primary image
          if (media.role == MediaRole.cover) {
            primaryImageUrl = media.storagePath;
            print('🔍 DEBUG: Found primary image: $primaryImageUrl');
          }
          
          // Build media object safely
          mediaData.add({
            'id': media.id,
            'type': media.type.name,
            'role': media.role.name,
            'storagePath': media.storagePath,
            'order': media.order,
            'altText': media.altText,
            'caption': media.caption,
            'metadata': media.metadata ?? {},
            'createdAt': Timestamp.fromDate(media.createdAt),
            'createdBy': media.createdBy,
          });
        }
        
        // Set primary image if not found
        if (primaryImageUrl == null && imageUrls.isNotEmpty) {
          primaryImageUrl = imageUrls.first;
          print('🔍 DEBUG: Using first image as primary: $primaryImageUrl');
        }
        
        print('🔍 DEBUG: Media processing complete. Images: ${imageUrls.length}, Primary: $primaryImageUrl');
      } catch (e) {
        print('🔍 DEBUG: Error processing media: $e');
        // Fallback to simple image URLs only
        imageUrls = _media.map((m) => m.storagePath).toList();
        primaryImageUrl = imageUrls.isNotEmpty ? imageUrls.first : null;
        mediaData = []; // Skip complex media data if there's an error
      }
      
      print('🔍 DEBUG: Building final product data object...');
      final productData = {
        'title': _titleController.text.trim(),
        'slug': _slugController.text.trim(),
        'description': _descriptionController.text.trim(),
        'detailedDescription': _detailedDescriptionController.text.trim(),
        'brandId': _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
        'primaryCategoryId': _selectedCategoryId ?? '',
        'categoryPath': _getCategoryPath(_selectedCategoryId ?? ''),
        'specs': _specs,
        'workflow': {
          'stage': status.name,
          'reviewedBy': status == ProductStatus.published ? 'current_user_id' : null,
          'reviewedAt': status == ProductStatus.published ? Timestamp.now() : null,
        },
        'searchTokens': _generateSearchTokens(),
        'priceRange': {
          'min': finalPrice,
          'max': basePrice,
          'currency': 'PHP',
        },
        'pricing': {
          'basePrice': basePrice,
          'salePrice': salePrice,
          'costPrice': double.tryParse(_costPriceController.text),
          'currency': 'PHP',
        },
        'shipping': {
          'weight': double.tryParse(_shippingWeightController.text),
          'fee': double.tryParse(_shippingFeeController.text) ?? 0.0,
          'freeShippingThreshold': double.tryParse(_freeShippingThresholdController.text),
          'dimensions': {
            'length': null,
            'width': null,
            'height': null,
            'unit': 'cm',
          },
          'handlingTime': {
            'min': 1,
            'max': 3,
            'unit': 'business_days',
          },
        },
        'mediaCounts': {
          'images': imageUrls.length,
          'videos': 0, // Simplified for now
        },
        // Add media data directly in product document
        'media': mediaData,
        // Add primary image URL for quick access (compatibility with existing code)
        'imageUrls': imageUrls,
        'primaryImageUrl': primaryImageUrl,
        // Variant system data
        'hasCustomizableVariants': _hasCustomizableVariants,
        'variantAttributes': _variantAttributes.map((attr) => attr.toMap()).toList(),
        'variantConfigurations': _variantConfigurations.map((config) => config.toMap()).toList(),
        'updatedAt': Timestamp.now(),
        'updatedBy': 'current_user_id', // Replace with actual user ID
        if (widget.product == null) ...{
          'createdAt': Timestamp.now(),
          'createdBy': 'current_user_id',
          'tenantId': 'default',
        },
      };
      
      print('🔍 DEBUG: Product data built successfully');
      return productData;
      
    } catch (e, stackTrace) {
      print('🔍 DEBUG: Error in _buildProductData: $e');
      print('🔍 DEBUG: Stack trace: $stackTrace');
      rethrow;
    }
  }

  List<String> _getCategoryPath(String categoryId) {
    // Handle empty or null category ID
    if (categoryId.isEmpty) return [];
    // This would need to be implemented based on your category hierarchy
    return [categoryId];
  }

  List<String> _generateSearchTokens() {
    try {
      print('🔍 DEBUG: Generating search tokens...');
      final tokens = <String>{};
      
      // Add title words safely
      if (_titleController.text.isNotEmpty) {
        tokens.addAll(_titleController.text.toLowerCase().split(' '));
      }
      
      // Add brand if provided
      if (_brandController.text.isNotEmpty) {
        tokens.addAll(_brandController.text.toLowerCase().split(' '));
      }
      
      // Add description words safely
      if (_descriptionController.text.isNotEmpty) {
        tokens.addAll(_descriptionController.text.toLowerCase().split(' '));
      }
      
      // Remove empty strings and short words
      final result = tokens.where((token) => token.isNotEmpty && token.length > 2).toList();
      print('🔍 DEBUG: Generated ${result.length} search tokens');
      return result;
    } catch (e) {
      print('🔍 DEBUG: Error generating search tokens: $e');
      return [];
    }
  }

  Future<void> _deleteProduct() async {
    if (widget.product == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product!.id)
            .delete();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted successfully!')),
        );
        
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting product: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Pricing helper methods
  String _getCurrentSellingPrice() {
    final salePrice = double.tryParse(_salePriceController.text);
    final basePrice = double.tryParse(_basePriceController.text);
    final currentPrice = salePrice ?? basePrice ?? 0.0;
    return '₱${currentPrice.toStringAsFixed(2)}';
  }

  double _getPotentialSavings() {
    final salePrice = double.tryParse(_salePriceController.text);
    final basePrice = double.tryParse(_basePriceController.text);
    if (salePrice != null && basePrice != null && salePrice < basePrice) {
      return basePrice - salePrice;
    }
    return 0.0;
  }

  String? _getProfitMargin() {
    final sellingPrice = double.tryParse(_salePriceController.text) ?? 
                        double.tryParse(_basePriceController.text);
    final costPrice = double.tryParse(_costPriceController.text);
    if (sellingPrice != null && costPrice != null && sellingPrice > costPrice) {
      final profit = sellingPrice - costPrice;
      return '₱${profit.toStringAsFixed(2)}';
    }
    return null;
  }

  Widget _buildPriceSummaryRow(String label, String value, {bool isDiscount = false, bool isProfit = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label, 
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        Text(
          value, 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDiscount ? Colors.green : 
                   isProfit ? Colors.blue : 
                   AppTheme.textPrimaryColor(context),
          ),
        ),
      ],
    );
  }

  // Shipping helper methods
  String _getShippingFeeDisplay() {
    final fee = double.tryParse(_shippingFeeController.text);
    if (fee != null) {
      return '₱${fee.toStringAsFixed(2)}';
    }
    return 'Not set';
  }

  String? _getFreeShippingThreshold() {
    final threshold = double.tryParse(_freeShippingThresholdController.text);
    if (threshold != null) {
      return '₱${threshold.toStringAsFixed(2)}';
    }
    return null;
  }

  String? _getShippingWeight() {
    final weight = double.tryParse(_shippingWeightController.text);
    if (weight != null) {
      return '${weight.toStringAsFixed(2)} kg';
    }
    return null;
  }

  Widget _buildShippingSummaryRow(String label, String value, {bool isFreeShipping = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label, 
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        Text(
          value, 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isFreeShipping ? Colors.green : AppTheme.textPrimaryColor(context),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _tabController.dispose();
    _titleController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    _detailedDescriptionController.dispose();
    _brandController.dispose();
    _basePriceController.dispose();
    _salePriceController.dispose();
    _costPriceController.dispose();
    _shippingWeightController.dispose();
    _shippingFeeController.dispose();
    _freeShippingThresholdController.dispose();
    super.dispose();
  }
}