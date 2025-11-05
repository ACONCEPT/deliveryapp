import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import '../models/menu.dart';
import '../models/customization_template.dart';
import '../services/customization_template_service.dart';
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
  final String? token; // JWT token for image upload and template import
  final String? userType; // User type for template import (admin/vendor)

  const MenuItemFormScreenEnhanced({
    super.key,
    this.item,
    this.token,
    this.userType,
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

    // Debug logging for template import button visibility
    developer.log(
      'MenuItemFormScreenEnhanced initialized - token: ${widget.token != null ? "present" : "null"}, userType: ${widget.userType ?? "null"}',
      name: 'MenuItemFormScreenEnhanced',
    );

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

  /// Import customization template dialog
  Future<void> _importTemplate() async {
    if (widget.token == null || widget.userType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Template import requires authentication'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Fetch available templates
      final templateService = CustomizationTemplateService();
      final templates = widget.userType == 'admin'
          ? await templateService.getAdminTemplates(widget.token!)
          : await templateService.getVendorTemplates(widget.token!);

      if (!mounted) return;

      if (templates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No templates available'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show template selection dialog
      final selected = await showDialog<CustomizationTemplate>(
        context: context,
        builder: (context) => _TemplateSelectionDialog(templates: templates),
      );

      if (selected == null || !mounted) return;

      // Convert CustomizationTemplate to CustomizationOption
      try {
        developer.log(
          'Importing template: ${selected.name}, type: ${selected.type}',
          name: 'MenuItemFormScreenEnhanced._importTemplate',
        );

        // Convert SimpleCustomizationOption list to CustomizationChoice list
        List<CustomizationChoice>? choices;
        if (selected.type != 'text_input' && selected.options.isNotEmpty) {
          choices = selected.options.map((simpleOption) {
            return CustomizationChoice(
              id: simpleOption.name.toLowerCase().replaceAll(' ', '_'),
              name: simpleOption.name,
              priceModifier: simpleOption.priceModifier,
            );
          }).toList();
        }

        // Create CustomizationOption from template data
        final option = CustomizationOption(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: selected.name,
          type: selected.type,
          required: selected.required,
          maxSelections: selected.maxSelections,
          maxLength: selected.maxLength,
          placeholder: selected.placeholder,
          choices: choices,
        );

        developer.log(
          'Created option: ${option.name}, type: ${option.type}, choices: ${option.choices?.length ?? 0}',
          name: 'MenuItemFormScreenEnhanced._importTemplate',
        );
        developer.log(
          'Current customization options count BEFORE add: ${_customizationOptions.length}',
          name: 'MenuItemFormScreenEnhanced._importTemplate',
        );

        // Create a NEW list to ensure the reference changes
        // This triggers didUpdateWidget in CustomizationOptionsBuilder
        setState(() {
          _customizationOptions = [..._customizationOptions, option];
        });

        developer.log(
          'Current customization options count AFTER add: ${_customizationOptions.length}',
          name: 'MenuItemFormScreenEnhanced._importTemplate',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Imported template: ${selected.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        developer.log(
          'Error importing template: $e',
          name: 'MenuItemFormScreenEnhanced',
          error: e,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to import template: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      developer.log(
        'Error fetching templates: $e',
        name: 'MenuItemFormScreenEnhanced',
        error: e,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to load templates: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

              // Customization Options Section with Import Button
              Row(
                children: [
                  Expanded(child: _buildSectionHeader('Customization Options')),
                  if (widget.token != null && widget.userType != null)
                    OutlinedButton.icon(
                      onPressed: _importTemplate,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Import Template'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                ],
              ),
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

/// Template Selection Dialog
///
/// Displays a list of available customization templates for import
class _TemplateSelectionDialog extends StatelessWidget {
  final List<CustomizationTemplate> templates;

  const _TemplateSelectionDialog({required this.templates});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import Customization Template'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: templates.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final template = templates[index];
            return ListTile(
              leading: Icon(
                Icons.layers,
                color: template.isSystemWide ? Colors.blue : Colors.orange,
              ),
              title: Text(template.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (template.description != null)
                    Text(
                      template.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (template.isSystemWide)
                        Chip(
                          label: const Text(
                            'System-wide',
                            style: TextStyle(fontSize: 10),
                          ),
                          backgroundColor: Colors.blue.shade100,
                          labelStyle: TextStyle(color: Colors.blue.shade900),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      if (template.isSystemWide) const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          template.isActive ? 'Active' : 'Inactive',
                          style: const TextStyle(fontSize: 10),
                        ),
                        backgroundColor: template.isActive
                            ? Colors.green.shade100
                            : Colors.grey.shade300,
                        labelStyle: TextStyle(
                          color: template.isActive
                              ? Colors.green.shade900
                              : Colors.grey.shade700,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.pop(context, template),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
