import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/variant_option.dart';

/// Widget for selecting and managing variant attributes (Size, Color, etc.)
class VariantAttributeSelector extends StatefulWidget {
  final List<VariantAttribute> attributes;
  final Function(List<VariantAttribute>) onAttributesChanged;
  final bool isReadOnly;

  const VariantAttributeSelector({
    super.key,
    required this.attributes,
    required this.onAttributesChanged,
    this.isReadOnly = false,
  });

  @override
  State<VariantAttributeSelector> createState() => _VariantAttributeSelectorState();
}

class _VariantAttributeSelectorState extends State<VariantAttributeSelector> {
  List<VariantAttribute> _attributes = [];

  @override
  void initState() {
    super.initState();
    _attributes = List.from(widget.attributes);
  }

  void _addAttribute() {
    showDialog(
      context: context,
      builder: (context) => AddVariantAttributeDialog(
        onAttributeAdded: (attribute) {
          setState(() {
            _attributes.add(attribute);
          });
          widget.onAttributesChanged(_attributes);
        },
      ),
    );
  }

  void _editAttribute(int index) {
    showDialog(
      context: context,
      builder: (context) => EditVariantAttributeDialog(
        attribute: _attributes[index],
        onAttributeUpdated: (attribute) {
          setState(() {
            _attributes[index] = attribute;
          });
          widget.onAttributesChanged(_attributes);
        },
      ),
    );
  }

  void _removeAttribute(int index) {
    setState(() {
      _attributes.removeAt(index);
    });
    widget.onAttributesChanged(_attributes);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Product Variants',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!widget.isReadOnly)
                  ElevatedButton.icon(
                    onPressed: _addAttribute,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Attribute'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_attributes.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No variant attributes added',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add attributes like Size, Color, or Material to create product variants',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_attributes.length, (index) {
                final attribute = _attributes[index];
                return VariantAttributeCard(
                  attribute: attribute,
                  onEdit: widget.isReadOnly ? null : () => _editAttribute(index),
                  onDelete: widget.isReadOnly ? null : () => _removeAttribute(index),
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// Card widget displaying a single variant attribute
class VariantAttributeCard extends StatelessWidget {
  final VariantAttribute attribute;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const VariantAttributeCard({
    super.key,
    required this.attribute,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  attribute.type.icon,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    attribute.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: 'Edit attribute',
                  ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, size: 18),
                    color: Colors.red,
                    tooltip: 'Remove attribute',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: attribute.activeValues.map((value) {
                return _buildValueChip(value, context);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueChip(VariantOptionValue value, BuildContext context) {
    return Chip(
      avatar: attribute.type == VariantAttributeType.color && value.color != null
          ? Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: value.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
            )
          : null,
      label: Text(
        value.effectiveDisplayName,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

/// Dialog for adding a new variant attribute
class AddVariantAttributeDialog extends StatefulWidget {
  final Function(VariantAttribute) onAttributeAdded;

  const AddVariantAttributeDialog({
    super.key,
    required this.onAttributeAdded,
  });

  @override
  State<AddVariantAttributeDialog> createState() => _AddVariantAttributeDialogState();
}

class _AddVariantAttributeDialogState extends State<AddVariantAttributeDialog> {
  VariantAttributeType _selectedType = VariantAttributeType.size;
  final _nameController = TextEditingController();
  List<String> _values = [];
  final _valueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _onTypeChanged(_selectedType);
  }

  void _onTypeChanged(VariantAttributeType type) {
    setState(() {
      _selectedType = type;
      _nameController.text = type.displayName;
      _values = List.from(type.defaultValues);
    });
  }

  void _addValue() {
    if (_valueController.text.trim().isNotEmpty) {
      setState(() {
        _values.add(_valueController.text.trim());
        _valueController.clear();
      });
    }
  }

  void _removeValue(int index) {
    setState(() {
      _values.removeAt(index);
    });
  }

  void _saveAttribute() {
    if (_nameController.text.trim().isEmpty || _values.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a name and at least one value')),
      );
      return;
    }

    final values = _values.asMap().entries.map((entry) {
      return VariantOptionValue(
        id: entry.key.toString(),
        value: entry.value,
        sortOrder: entry.key,
      );
    }).toList();

    final attribute = VariantAttribute(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      type: _selectedType,
      values: values,
      isRequired: _selectedType == VariantAttributeType.size || 
                  _selectedType == VariantAttributeType.color,
    );

    widget.onAttributeAdded(attribute);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Variant Attribute',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            // Attribute Type Selection
            Text(
              'Attribute Type',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: VariantAttributeType.values.map((type) {
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(type.icon, size: 16),
                      const SizedBox(width: 4),
                      Text(type.displayName),
                    ],
                  ),
                  selected: _selectedType == type,
                  onSelected: (_) => _onTypeChanged(type),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Attribute Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Attribute Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Values Section
            Text(
              'Values',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            // Add Value Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _valueController,
                    decoration: const InputDecoration(
                      hintText: 'Enter value (e.g., Small, Red)',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addValue(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addValue,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Values List
            Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _values.isEmpty
                  ? const Center(
                      child: Text(
                        'No values added yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _values.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          dense: true,
                          title: Text(_values[index]),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            onPressed: () => _removeValue(index),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 24),
            // Dialog Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveAttribute,
                  child: const Text('Add Attribute'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }
}

/// Dialog for editing an existing variant attribute
class EditVariantAttributeDialog extends StatefulWidget {
  final VariantAttribute attribute;
  final Function(VariantAttribute) onAttributeUpdated;

  const EditVariantAttributeDialog({
    super.key,
    required this.attribute,
    required this.onAttributeUpdated,
  });

  @override
  State<EditVariantAttributeDialog> createState() => _EditVariantAttributeDialogState();
}

class _EditVariantAttributeDialogState extends State<EditVariantAttributeDialog> {
  late TextEditingController _nameController;
  List<VariantOptionValue> _values = [];
  final _valueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.attribute.name);
    _values = List.from(widget.attribute.values);
  }

  void _addValue() {
    if (_valueController.text.trim().isNotEmpty) {
      final newValue = VariantOptionValue(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        value: _valueController.text.trim(),
        sortOrder: _values.length,
      );
      
      setState(() {
        _values.add(newValue);
        _valueController.clear();
      });
    }
  }

  void _removeValue(int index) {
    setState(() {
      _values.removeAt(index);
    });
  }

  void _saveAttribute() {
    if (_nameController.text.trim().isEmpty || _values.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a name and at least one value')),
      );
      return;
    }

    final updatedAttribute = widget.attribute.copyWith(
      name: _nameController.text.trim(),
      values: _values,
    );

    widget.onAttributeUpdated(updatedAttribute);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Variant Attribute',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            // Attribute Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Attribute Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Values Section
            Text(
              'Values',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            // Add Value Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _valueController,
                    decoration: const InputDecoration(
                      hintText: 'Enter value',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addValue(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addValue,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Values List
            Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _values.isEmpty
                  ? const Center(
                      child: Text(
                        'No values added yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _values.length,
                      itemBuilder: (context, index) {
                        final value = _values[index];
                        return ListTile(
                          dense: true,
                          leading: widget.attribute.type == VariantAttributeType.color && 
                                    value.color != null
                              ? Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: value.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey),
                                  ),
                                )
                              : null,
                          title: Text(value.effectiveDisplayName),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            onPressed: () => _removeValue(index),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 24),
            // Dialog Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveAttribute,
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }
}

/// Widget for managing variant configurations (combinations of attributes with prices and quantities)
class VariantConfigurationManager extends StatefulWidget {
  final List<VariantAttribute> attributes;
  final List<VariantConfiguration> configurations;
  final Function(List<VariantConfiguration>) onConfigurationsChanged;
  final String? baseSkuCode;
  final bool isReadOnly;

  const VariantConfigurationManager({
    super.key,
    required this.attributes,
    required this.configurations,
    required this.onConfigurationsChanged,
    this.baseSkuCode,
    this.isReadOnly = false,
  });

  @override
  State<VariantConfigurationManager> createState() => _VariantConfigurationManagerState();
}

class _VariantConfigurationManagerState extends State<VariantConfigurationManager> {
  List<VariantConfiguration> _configurations = [];

  @override
  void initState() {
    super.initState();
    _configurations = List.from(widget.configurations);
  }

  void _generateConfigurations() {
    if (widget.attributes.isEmpty) return;

    // Generate all possible combinations
    final combinations = _generateCombinations(widget.attributes);
    
    final newConfigurations = <VariantConfiguration>[];
    
    for (int i = 0; i < combinations.length; i++) {
      final combination = combinations[i];
      
      // Check if this combination already exists
      final existing = _configurations.cast<VariantConfiguration?>().firstWhere(
        (config) => _mapEquals(config?.attributeValues ?? {}, combination),
        orElse: () => null,
      );
      
      if (existing != null) {
        newConfigurations.add(existing);
      } else {
        // Create new configuration
        final sku = widget.baseSkuCode != null 
            ? VariantConfiguration.generateSku(widget.baseSkuCode!, combination)
            : null;
            
        newConfigurations.add(VariantConfiguration(
          id: '${DateTime.now().millisecondsSinceEpoch}_$i',
          attributeValues: combination,
          price: 0.0,
          quantity: 0,
          sku: sku,
          sortOrder: i,
        ));
      }
    }
    
    setState(() {
      _configurations = newConfigurations;
    });
    widget.onConfigurationsChanged(_configurations);
  }

  List<Map<String, String>> _generateCombinations(List<VariantAttribute> attributes) {
    if (attributes.isEmpty) return [{}];
    
    List<Map<String, String>> combinations = [{}];
    
    for (final attribute in attributes.where((a) => a.isActive && a.activeValues.isNotEmpty)) {
      final newCombinations = <Map<String, String>>[];
      
      for (final combination in combinations) {
        for (final value in attribute.activeValues) {
          newCombinations.add({
            ...combination,
            attribute.id: value.value,
          });
        }
      }
      
      combinations = newCombinations;
    }
    
    return combinations;
  }

  bool _mapEquals(Map<String, String> map1, Map<String, String> map2) {
    if (map1.length != map2.length) return false;
    
    for (final entry in map1.entries) {
      if (map2[entry.key] != entry.value) return false;
    }
    
    return true;
  }

  void _updateConfiguration(int index, VariantConfiguration configuration) {
    setState(() {
      _configurations[index] = configuration;
    });
    widget.onConfigurationsChanged(_configurations);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Variant Configurations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!widget.isReadOnly && widget.attributes.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _generateConfigurations,
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: const Text('Generate'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_configurations.isEmpty && widget.attributes.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.tune,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No variant configurations generated',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Click "Generate" to create all possible combinations',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else if (_configurations.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add variant attributes first',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Define attributes like Size and Color to create variants',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_configurations.length, (index) {
                return VariantConfigurationCard(
                  configuration: _configurations[index],
                  attributes: widget.attributes,
                  isReadOnly: widget.isReadOnly,
                  onConfigurationChanged: (config) => _updateConfiguration(index, config),
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// Card for editing individual variant configuration
class VariantConfigurationCard extends StatefulWidget {
  final VariantConfiguration configuration;
  final List<VariantAttribute> attributes;
  final bool isReadOnly;
  final Function(VariantConfiguration) onConfigurationChanged;

  const VariantConfigurationCard({
    super.key,
    required this.configuration,
    required this.attributes,
    required this.onConfigurationChanged,
    this.isReadOnly = false,
  });

  @override
  State<VariantConfigurationCard> createState() => _VariantConfigurationCardState();
}

class _VariantConfigurationCardState extends State<VariantConfigurationCard> {
  late TextEditingController _priceController;
  late TextEditingController _compareAtPriceController;
  late TextEditingController _quantityController;
  late TextEditingController _skuController;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: widget.configuration.price.toString());
    _compareAtPriceController = TextEditingController(
      text: widget.configuration.compareAtPrice?.toString() ?? '',
    );
    _quantityController = TextEditingController(text: widget.configuration.quantity.toString());
    _skuController = TextEditingController(text: widget.configuration.sku ?? '');
  }

  void _updateConfiguration() {
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final compareAtPrice = _compareAtPriceController.text.isEmpty
        ? null
        : double.tryParse(_compareAtPriceController.text);
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    
    final updatedConfig = widget.configuration.copyWith(
      price: price,
      compareAtPrice: compareAtPrice,
      quantity: quantity,
      sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
    );
    
    widget.onConfigurationChanged(updatedConfig);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Variant Display Name
            Text(
              widget.configuration.displayName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            // Configuration Fields
            Row(
              children: [
                // Price
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price (₱)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    readOnly: widget.isReadOnly,
                    onChanged: (_) => _updateConfiguration(),
                  ),
                ),
                const SizedBox(width: 12),
                // Compare At Price
                Expanded(
                  child: TextField(
                    controller: _compareAtPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Compare Price (₱)',
                      border: OutlineInputBorder(),
                      isDense: true,
                      hintText: 'Optional',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    readOnly: widget.isReadOnly,
                    onChanged: (_) => _updateConfiguration(),
                  ),
                ),
                const SizedBox(width: 12),
                // Quantity
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    readOnly: widget.isReadOnly,
                    onChanged: (_) => _updateConfiguration(),
                  ),
                ),
                const SizedBox(width: 12),
                // SKU
                Expanded(
                  child: TextField(
                    controller: _skuController,
                    decoration: const InputDecoration(
                      labelText: 'SKU',
                      border: OutlineInputBorder(),
                      isDense: true,
                      hintText: 'Auto-generated',
                    ),
                    readOnly: widget.isReadOnly,
                    onChanged: (_) => _updateConfiguration(),
                  ),
                ),
              ],
            ),
            if (widget.configuration.hasDiscount || widget.configuration.isLowStock)
              const SizedBox(height: 8),
            // Status Indicators
            Row(
              children: [
                if (widget.configuration.hasDiscount)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'On Sale',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (widget.configuration.hasDiscount && widget.configuration.isLowStock)
                  const SizedBox(width: 8),
                if (widget.configuration.isLowStock)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Low Stock',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (!widget.configuration.isInStock)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Out of Stock',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _compareAtPriceController.dispose();
    _quantityController.dispose();
    _skuController.dispose();
    super.dispose();
  }
}