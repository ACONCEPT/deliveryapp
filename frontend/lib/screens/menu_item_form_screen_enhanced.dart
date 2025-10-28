import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/menu.dart';
import '../widgets/menu_item_builders.dart';
import '../widgets/image_upload_field.dart';

/// Enhanced Menu Item Form Screen
///
/// Comprehensive form for creating and editing menu items with all Phase 5 features:
/// - Basic info (name, description, price)
/// - Product images (URL or upload)
/// - Variants (size, crust type, etc.)
/// - Customization options (toppings, spice levels, notes, etc.)
/// - Dietary flags
/// - Allergens
/// - Tags
/// - Additional metadata (calories, prep time, spice level)
class MenuItemFormScreenEnhanced extends StatefulWidget {
  final MenuItem? item;
  final String? token; // JWT token for image upload

  const MenuItemFormScreenEnhanced({
    super.key,
    this.item,
    this.token,
  });

  @override
  State<MenuItemFormScreenEnhanced> createState() =>
      _MenuItemFormScreenEnhancedState();
}

class _MenuItemFormScreenEnhancedState
    extends State<MenuItemFormScreenEnhanced> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Basic info controllers
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late bool _isActive;
  late bool _isAvailable;

  // Additional info controllers
  late TextEditingController _imageUrlController;
  late TextEditingController _caloriesController;
  late TextEditingController _prepTimeController;
  late int? _spiceLevel;

  // Composable lists
  late List<ItemVariant> _variants;
  late List<CustomizationOption> _customizationOptions;
  late Map<String, bool> _dietaryFlags;
  late List<String> _allergens;
  late List<String> _tags;

  bool get _isEditMode => widget.item != null;

  @override
  void initState() {
    super.initState();

    // Initialize basic fields
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.item?.description ?? '');
    _priceController = TextEditingController(
      text: widget.item?.price.toStringAsFixed(2) ?? '',
    );
    _isActive = widget.item?.isActive ?? true;
    _isAvailable = widget.item?.isAvailable ?? true;

    // Initialize additional fields
    _imageUrlController =
        TextEditingController(text: widget.item?.imageUrl ?? '');
    _caloriesController = TextEditingController(
      text: widget.item?.calories?.toString() ?? '',
    );
    _prepTimeController = TextEditingController(
      text: widget.item?.preparationTimeMinutes?.toString() ?? '',
    );
    _spiceLevel = widget.item?.spiceLevel;

    // Initialize composable lists
    _variants = widget.item?.variants != null
        ? List<ItemVariant>.from(widget.item!.variants!)
        : [];
    _customizationOptions = widget.item?.customizationOptions != null
        ? List<CustomizationOption>.from(widget.item!.customizationOptions!)
        : [];
    _dietaryFlags = widget.item?.dietaryFlags != null
        ? Map<String, bool>.from(widget.item!.dietaryFlags!)
        : {};
    _allergens = widget.item?.allergens != null
        ? List<String>.from(widget.item!.allergens!)
        : [];
    _tags = widget.item?.tags != null
        ? List<String>.from(widget.item!.tags!)
        : [];

    // Listen to image URL changes for preview
    _imageUrlController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    _caloriesController.dispose();
    _prepTimeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors in the form'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final item = MenuItem(
      id: widget.item?.id ?? 'item_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      price: double.parse(_priceController.text.trim()),
      displayOrder: widget.item?.displayOrder ?? 0,
      isActive: _isActive,
      isAvailable: _isAvailable,
      imageUrl: _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim(),
      preparationTimeMinutes: _prepTimeController.text.trim().isEmpty
          ? null
          : int.tryParse(_prepTimeController.text.trim()),
      calories: _caloriesController.text.trim().isEmpty
          ? null
          : int.tryParse(_caloriesController.text.trim()),
      dietaryFlags: _dietaryFlags.isEmpty ? null : _dietaryFlags,
      allergens: _allergens.isEmpty ? null : _allergens,
      variants: _variants.isEmpty ? null : _variants,
      customizationOptions:
          _customizationOptions.isEmpty ? null : _customizationOptions,
      tags: _tags.isEmpty ? null : _tags,
      spiceLevel: _spiceLevel,
    );

    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Menu Item' : 'Add Menu Item'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text(
              'Save',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Scrollbar(
          controller: _scrollController,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16.0),
            children: [
              // Info banner
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Phase 5: Comprehensive menu item builder with all customization options!',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Basic Information Section
              _buildSectionHeader('Basic Information'),
              const SizedBox(height: 12),
              _buildBasicInfoSection(),
              const SizedBox(height: 24),

              // Product Image Section
              _buildSectionHeader('Product Image'),
              const SizedBox(height: 12),
              widget.token != null
                  ? ImageUploadField(
                      controller: _imageUrlController,
                      token: widget.token!,
                    )
                  : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Icon(Icons.warning_amber, size: 48, color: Colors.orange),
                            const SizedBox(height: 12),
                            const Text(
                              'Image upload requires authentication',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _imageUrlController,
                              decoration: const InputDecoration(
                                labelText: 'Image URL (Optional)',
                                hintText: 'https://example.com/image.jpg',
                                prefixIcon: Icon(Icons.link),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.url,
                            ),
                          ],
                        ),
                      ),
                    ),
              const SizedBox(height: 24),

              // Variants Section
              _buildSectionHeader('Variants'),
              const SizedBox(height: 12),
              VariantBuilder(
                variants: _variants,
                onChanged: (variants) {
                  setState(() {
                    _variants = variants;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Customization Options Section
              _buildSectionHeader('Customization Options'),
              const SizedBox(height: 12),
              CustomizationOptionsBuilder(
                options: _customizationOptions,
                onChanged: (options) {
                  setState(() {
                    _customizationOptions = options;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Dietary Flags Section
              _buildSectionHeader('Dietary Information'),
              const SizedBox(height: 12),
              DietaryFlagsBuilder(
                flags: _dietaryFlags,
                onChanged: (flags) {
                  setState(() {
                    _dietaryFlags = flags;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Allergens Section
              _buildSectionHeader('Allergen Information'),
              const SizedBox(height: 12),
              AllergensBuilder(
                allergens: _allergens,
                onChanged: (allergens) {
                  setState(() {
                    _allergens = allergens;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Tags Section
              _buildSectionHeader('Tags'),
              const SizedBox(height: 12),
              TagsBuilder(
                tags: _tags,
                onChanged: (tags) {
                  setState(() {
                    _tags = tags;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Additional Information Section
              _buildSectionHeader('Additional Information'),
              const SizedBox(height: 12),
              AdditionalInfoFields(
                caloriesController: _caloriesController,
                prepTimeController: _prepTimeController,
                spiceLevel: _spiceLevel,
                onSpiceLevelChanged: (level) {
                  setState(() {
                    _spiceLevel = level;
                  });
                },
              ),
              const SizedBox(height: 32),

              // Save Button (bottom)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.save),
                      label: Text(
                        _isEditMode ? 'Update Item' : 'Create Item',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.deepOrange,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.deepOrange,
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Item name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item Name *',
                hintText: 'e.g., Margherita Pizza, Caesar Salad',
                prefixIcon: Icon(Icons.fastfood),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Item name is required';
                }
                if (value.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                if (value.trim().length > 100) {
                  return 'Name must be less than 100 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Brief description of the item',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Price
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Base Price *',
                hintText: '9.99',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
                helperText: 'Price before variants and customizations',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Price is required';
                }
                final price = double.tryParse(value.trim());
                if (price == null) {
                  return 'Please enter a valid price';
                }
                if (price < 0) {
                  return 'Price must be positive';
                }
                if (price > 999.99) {
                  return 'Price must be less than \$1000';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Status toggles
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: _isActive ? Colors.green[50] : Colors.grey[100],
                    child: SwitchListTile(
                      title: const Text('Active'),
                      subtitle: Text(
                        _isActive
                            ? 'Visible in menu'
                            : 'Hidden from menu',
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: _isActive,
                      onChanged: (value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
                      activeTrackColor: Colors.green[200],
                      activeThumbColor: Colors.green,
                      secondary: Icon(
                        _isActive ? Icons.check_circle : Icons.cancel,
                        color: _isActive ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    color: _isAvailable ? Colors.blue[50] : Colors.orange[50],
                    child: SwitchListTile(
                      title: const Text('Available'),
                      subtitle: Text(
                        _isAvailable
                            ? 'In stock'
                            : 'Out of stock',
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: _isAvailable,
                      onChanged: (value) {
                        setState(() {
                          _isAvailable = value;
                        });
                      },
                      activeTrackColor: Colors.blue[200],
                      activeThumbColor: Colors.blue,
                      secondary: Icon(
                        _isAvailable ? Icons.check_box : Icons.block,
                        color: _isAvailable ? Colors.blue : Colors.orange,
                      ),
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
}
