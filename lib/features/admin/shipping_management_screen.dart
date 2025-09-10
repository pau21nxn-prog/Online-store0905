import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../common/theme.dart';
import '../../models/shipping_zone.dart';
import '../../services/shipping_service.dart';

class ShippingManagementScreen extends StatefulWidget {
  const ShippingManagementScreen({super.key});

  @override
  State<ShippingManagementScreen> createState() => _ShippingManagementScreenState();
}

class _ShippingManagementScreenState extends State<ShippingManagementScreen>
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  final ShippingService _shippingService = ShippingService();
  
  List<ShippingRate> _shippingRates = [];
  ShippingConfig _shippingConfig = const ShippingConfig();
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadShippingData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadShippingData() async {
    setState(() => _isLoading = true);
    
    try {
      final rates = await _shippingService.getAllShippingRates();
      final config = await _shippingService.getShippingConfig();
      
      setState(() {
        _shippingRates = rates;
        _shippingConfig = config;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading shipping data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shipping Management'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.local_shipping), text: 'Rates'),
            Tab(icon: Icon(Icons.settings), text: 'Configuration'),
            Tab(icon: Icon(Icons.calculate), text: 'Calculator'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRatesTab(),
                _buildConfigurationTab(),
                _buildCalculatorTab(),
              ],
            ),
    );
  }

  Widget _buildRatesTab() {
    final filteredRates = _shippingRates.where((rate) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return rate.fromZone.displayName.toLowerCase().contains(query) ||
             rate.toZone.displayName.toLowerCase().contains(query) ||
             rate.weightTier.displayName.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        // Search and Add Rate
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search rates...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showAddEditRateDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Rate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        
        // Initialize Default Rates Button
        if (_shippingRates.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.info, size: 48, color: Colors.blue),
                    const SizedBox(height: 8),
                    const Text(
                      'No shipping rates found',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Initialize with default J&T Express inspired rates to get started.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _initializeDefaultRates,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Initialize Default Rates'),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Rates List
        Expanded(
          child: filteredRates.isEmpty
              ? const Center(child: Text('No rates found'))
              : ListView.builder(
                  itemCount: filteredRates.length,
                  itemBuilder: (context, index) {
                    final rate = filteredRates[index];
                    return _buildRateCard(rate);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRateCard(ShippingRate rate) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: rate.isActive ? Colors.green : Colors.grey,
          child: Icon(
            Icons.local_shipping,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          '${rate.fromZone.displayName} → ${rate.toZone.displayName}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weight: ${rate.weightTier.displayName}'),
            Text('Rate: ${rate.formattedRate}'),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: const Row(
                children: [Icon(Icons.edit), SizedBox(width: 8), Text('Edit')],
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(rate.isActive ? Icons.visibility_off : Icons.visibility),
                  const SizedBox(width: 8),
                  Text(rate.isActive ? 'Deactivate' : 'Activate'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Delete')],
              ),
            ),
          ],
          onSelected: (value) => _handleRateAction(value.toString(), rate),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildConfigurationTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Global Shipping Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _shippingConfig.freeShippingThreshold.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Free Shipping Threshold',
                            prefixText: '₱',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                          onChanged: (value) {
                            final threshold = double.tryParse(value) ?? _shippingConfig.freeShippingThreshold;
                            _shippingConfig = ShippingConfig(
                              freeShippingThreshold: threshold,
                              fallbackRate: _shippingConfig.fallbackRate,
                              enableFreeShipping: _shippingConfig.enableFreeShipping,
                              defaultFromZone: _shippingConfig.defaultFromZone,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue: _shippingConfig.fallbackRate.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Fallback Rate',
                            prefixText: '₱',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                          onChanged: (value) {
                            final fallback = double.tryParse(value) ?? _shippingConfig.fallbackRate;
                            _shippingConfig = ShippingConfig(
                              freeShippingThreshold: _shippingConfig.freeShippingThreshold,
                              fallbackRate: fallback,
                              enableFreeShipping: _shippingConfig.enableFreeShipping,
                              defaultFromZone: _shippingConfig.defaultFromZone,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  SwitchListTile(
                    title: const Text('Enable Free Shipping'),
                    subtitle: const Text('Allow free shipping for orders above threshold'),
                    value: _shippingConfig.enableFreeShipping,
                    onChanged: (value) {
                      setState(() {
                        _shippingConfig = ShippingConfig(
                          freeShippingThreshold: _shippingConfig.freeShippingThreshold,
                          fallbackRate: _shippingConfig.fallbackRate,
                          enableFreeShipping: value,
                          defaultFromZone: _shippingConfig.defaultFromZone,
                        );
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  ElevatedButton(
                    onPressed: _saveConfiguration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('Save Configuration'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculatorTab() {
    final _weightController = TextEditingController();
    final _subtotalController = TextEditingController();
    String _selectedProvince = 'Manila';
    ShippingCalculation? _calculation;

    return StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Shipping Calculator',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _subtotalController,
                              decoration: const InputDecoration(
                                labelText: 'Subtotal',
                                prefixText: '₱',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _weightController,
                              decoration: const InputDecoration(
                                labelText: 'Weight (kg)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<String>(
                        value: _selectedProvince,
                        decoration: const InputDecoration(
                          labelText: 'Destination Province',
                          border: OutlineInputBorder(),
                        ),
                        items: ProvinceMapping.allMappings.keys
                            .map((province) => DropdownMenuItem(
                                  value: province,
                                  child: Text(province.toUpperCase()),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedProvince = value!),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      ElevatedButton(
                        onPressed: () async {
                          final subtotal = double.tryParse(_subtotalController.text) ?? 0.0;
                          final weight = double.tryParse(_weightController.text) ?? 0.0;
                          
                          if (weight <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid weight')),
                            );
                            return;
                          }
                          
                          try {
                            final calculation = await _shippingService.calculateShippingFee(
                              subtotal: subtotal,
                              totalWeight: weight,
                              destinationProvince: _selectedProvince,
                            );
                            
                            setState(() => _calculation = calculation);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error calculating shipping: $e')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Text('Calculate Shipping'),
                      ),
                    ],
                  ),
                ),
              ),
              
              if (_calculation != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Calculation Result',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        
                        _buildCalculationRow('From Zone', _calculation!.fromZone.displayName),
                        _buildCalculationRow('To Zone', _calculation!.toZone.displayName),
                        _buildCalculationRow('Weight Tier', _calculation!.weightTier.displayName),
                        _buildCalculationRow('Shipping Fee', _calculation!.formattedShippingFee),
                        _buildCalculationRow('Method', _calculation!.calculationMethod),
                        
                        if (_calculation!.isFreeShipping)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Text('FREE SHIPPING', style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                )),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalculationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  void _handleRateAction(String action, ShippingRate rate) {
    switch (action) {
      case 'edit':
        _showAddEditRateDialog(rate: rate);
        break;
      case 'toggle':
        _toggleRateStatus(rate);
        break;
      case 'delete':
        _deleteRate(rate);
        break;
    }
  }

  Future<void> _showAddEditRateDialog({ShippingRate? rate}) async {
    final isEdit = rate != null;
    
    ShippingZone selectedFromZone = rate?.fromZone ?? ShippingZone.manila;
    ShippingZone selectedToZone = rate?.toZone ?? ShippingZone.luzon;
    WeightTier selectedWeightTier = rate?.weightTier ?? WeightTier.tier0_500g;
    final rateController = TextEditingController(text: rate?.rate.toString() ?? '');

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEdit ? 'Edit Shipping Rate' : 'Add Shipping Rate'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<ShippingZone>(
                        value: selectedFromZone,
                        decoration: const InputDecoration(labelText: 'From Zone'),
                        items: ShippingZone.values
                            .map((zone) => DropdownMenuItem(
                                  value: zone,
                                  child: Text(zone.displayName),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => selectedFromZone = value!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<ShippingZone>(
                        value: selectedToZone,
                        decoration: const InputDecoration(labelText: 'To Zone'),
                        items: ShippingZone.values
                            .map((zone) => DropdownMenuItem(
                                  value: zone,
                                  child: Text(zone.displayName),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => selectedToZone = value!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<WeightTier>(
                  value: selectedWeightTier,
                  decoration: const InputDecoration(labelText: 'Weight Tier'),
                  items: WeightTier.values
                      .map((tier) => DropdownMenuItem(
                            value: tier,
                            child: Text(tier.displayName),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => selectedWeightTier = value!),
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: rateController,
                  decoration: const InputDecoration(
                    labelText: 'Rate',
                    prefixText: '₱',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final rateValue = double.tryParse(rateController.text);
                if (rateValue == null || rateValue <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid rate')),
                  );
                  return;
                }

                final newRate = ShippingRate(
                  id: rate?.id ?? '',
                  fromZone: selectedFromZone,
                  toZone: selectedToZone,
                  weightTier: selectedWeightTier,
                  rate: rateValue,
                  createdAt: rate?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                try {
                  await _shippingService.saveShippingRate(newRate);
                  Navigator.pop(context);
                  await _loadShippingData();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${isEdit ? 'Updated' : 'Added'} shipping rate successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving rate: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
              ),
              child: Text(isEdit ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleRateStatus(ShippingRate rate) async {
    try {
      final updatedRate = rate.copyWith(
        isActive: !rate.isActive,
        updatedAt: DateTime.now(),
      );
      
      await _shippingService.saveShippingRate(updatedRate);
      await _loadShippingData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rate ${updatedRate.isActive ? 'activated' : 'deactivated'} successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating rate: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteRate(ShippingRate rate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shipping Rate'),
        content: Text('Are you sure you want to delete the rate for ${rate.fromZone.displayName} → ${rate.toZone.displayName} (${rate.weightTier.displayName})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _shippingService.deleteShippingRate(rate.id);
        await _loadShippingData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rate deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting rate: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _initializeDefaultRates() async {
    try {
      await _shippingService.initializeDefaultRates();
      await _loadShippingData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default rates initialized successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing rates: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveConfiguration() async {
    try {
      await _shippingService.saveShippingConfig(_shippingConfig);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving configuration: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}