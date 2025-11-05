import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/customization_template.dart';
import '../services/customization_template_service.dart';

/// Simplified Customization Template Form Screen
///
/// Create or edit customization templates with a flat, easy-to-understand structure.
/// Each template has:
/// - A title (e.g., "Extra Cheese", "Spice Level")
/// - A list of options (e.g., ["Yes", "No"] or ["Mild", "Medium", "Hot"])
/// - No confusing nested groups!
class CustomizationTemplateFormScreen extends StatefulWidget {
  final String token;
  final String userType; // 'admin' or 'vendor'
  final CustomizationTemplate? template; // null for create, provided for edit

  const CustomizationTemplateFormScreen({
    super.key,
    required this.token,
    required this.userType,
    this.template,
  });

  @override
  State<CustomizationTemplateFormScreen> createState() =>
      _CustomizationTemplateFormScreenState();
}

class _CustomizationTemplateFormScreenState
    extends State<CustomizationTemplateFormScreen> {
  final CustomizationTemplateService _templateService =
      CustomizationTemplateService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _maxSelectionsController;
  late TextEditingController _maxLengthController;
  late TextEditingController _placeholderController;
  late List<SimpleCustomizationOption> _options;
  late bool _isRequired;
  late String _type;
  late bool _isActive;

  bool _isSaving = false;
  bool get _isEditMode => widget.template != null;
  bool get _isAdmin => widget.userType == 'admin';
  bool get _isSystemWide => _isEditMode && widget.template!.isSystemWide;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.template?.description ?? '');
    _maxSelectionsController = TextEditingController(
      text: widget.template?.maxSelections?.toString() ?? '',
    );
    _maxLengthController = TextEditingController(
      text: widget.template?.maxLength?.toString() ?? '200',
    );
    _placeholderController = TextEditingController(
      text: widget.template?.placeholder ?? '',
    );
    _options = widget.template != null
        ? List<SimpleCustomizationOption>.from(widget.template!.options)
        : [];
    _isRequired = widget.template?.required ?? false;
    _type = widget.template?.type ?? 'single_choice';
    _isActive = widget.template?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _maxSelectionsController.dispose();
    _maxLengthController.dispose();
    _placeholderController.dispose();
    super.dispose();
  }

  void _addOption() async {
    final result = await showDialog<SimpleCustomizationOption>(
      context: context,
      builder: (context) => const _OptionFormDialog(),
    );

    if (result != null) {
      setState(() {
        _options.add(result);
      });
    }
  }

  void _editOption(int index) async {
    final result = await showDialog<SimpleCustomizationOption>(
      context: context,
      builder: (context) => _OptionFormDialog(option: _options[index]),
    );

    if (result != null) {
      setState(() {
        _options[index] = result;
      });
    }
  }

  void _deleteOption(int index) {
    setState(() {
      _options.removeAt(index);
    });
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate options for non-text types
    if (_type != 'text_input' && _options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one option'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (_isEditMode) {
        // Update existing template
        final request = UpdateCustomizationTemplateRequest(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          type: _type,
          options: _type != 'text_input' ? _options : null,
          required: _isRequired,
          maxSelections: _type == 'multiple_choice' && _maxSelectionsController.text.isNotEmpty
              ? int.tryParse(_maxSelectionsController.text)
              : null,
          maxLength: _type == 'text_input' && _maxLengthController.text.isNotEmpty
              ? int.tryParse(_maxLengthController.text)
              : null,
          placeholder: _type == 'text_input' && _placeholderController.text.isNotEmpty
              ? _placeholderController.text.trim()
              : null,
          isActive: _isActive,
        );

        if (_isAdmin) {
          await _templateService.updateAdminTemplate(
            widget.token,
            widget.template!.id!,
            request,
          );
        } else {
          await _templateService.updateVendorTemplate(
            widget.token,
            widget.template!.id!,
            request,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Template updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Create new template
        final request = CreateCustomizationTemplateRequest(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          type: _type,
          options: _type != 'text_input' ? _options : [],
          required: _isRequired,
          maxSelections: _type == 'multiple_choice' && _maxSelectionsController.text.isNotEmpty
              ? int.tryParse(_maxSelectionsController.text)
              : null,
          maxLength: _type == 'text_input' && _maxLengthController.text.isNotEmpty
              ? int.tryParse(_maxLengthController.text)
              : null,
          placeholder: _type == 'text_input' && _placeholderController.text.isNotEmpty
              ? _placeholderController.text.trim()
              : null,
          isActive: _isActive,
        );

        if (_isAdmin) {
          await _templateService.createAdminTemplate(widget.token, request);
        } else {
          await _templateService.createVendorTemplate(widget.token, request);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Template created successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      developer.log(
        'Error saving template: $e',
        name: 'CustomizationTemplateFormScreen',
        error: e,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save template: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Template' : 'Create Template'),
        actions: [
          if (_isSystemWide)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Chip(
                label: const Text(
                  'System-wide',
                  style: TextStyle(fontSize: 11, color: Colors.white),
                ),
                backgroundColor: Colors.blue,
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Create ONE customization type per template. '
                        'Example: "Spice Level" with Radio buttons (Mild, Medium, Hot).',
                        style: TextStyle(color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Template name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Customization Title *',
                hintText: 'e.g., Extra Cheese, Spice Level, Add Bacon',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
                helperText: 'This is what customers will see',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Brief description of this customization',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Customization type
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Customization Type *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
                helperText: 'Choose ONE type for this template',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'single_choice',
                  child: Text('Single Choice (Radio Buttons)'),
                ),
                DropdownMenuItem(
                  value: 'multiple_choice',
                  child: Text('Multiple Choice (Checkboxes)'),
                ),
                DropdownMenuItem(
                  value: 'text_input',
                  child: Text('Text Input (Notes/Instructions)'),
                ),
                DropdownMenuItem(
                  value: 'spice_level',
                  child: Text('Spice Level Selector'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _type = value!;
                  // Clear options when switching to text_input
                  if (_type == 'text_input') {
                    _options.clear();
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            // Type-specific fields
            if (_type == 'multiple_choice') ...[
              TextFormField(
                controller: _maxSelectionsController,
                decoration: const InputDecoration(
                  labelText: 'Max Selections (Optional)',
                  hintText: 'e.g., 5',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                  helperText: 'Leave empty for unlimited',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
            ],
            if (_type == 'text_input') ...[
              TextFormField(
                controller: _maxLengthController,
                decoration: const InputDecoration(
                  labelText: 'Max Length',
                  hintText: '200',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.text_fields),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _placeholderController,
                decoration: const InputDecoration(
                  labelText: 'Placeholder Text',
                  hintText: 'e.g., Any special requests?',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_note),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Required toggle
            SwitchListTile(
              title: const Text('Required'),
              subtitle: const Text('Customer must select at least one option'),
              value: _isRequired,
              onChanged: (value) {
                setState(() {
                  _isRequired = value;
                });
              },
            ),
            const SizedBox(height: 8),

            // Active toggle
            SwitchListTile(
              title: const Text('Active'),
              subtitle: const Text('Inactive templates are hidden from selection'),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
            const SizedBox(height: 24),

            // Options section (only for non-text types)
            if (_type != 'text_input') ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.list, color: Colors.deepOrange),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Options',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Add the choices customers can select',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _addOption,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Option'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_options.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No options added yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _options.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final option = _options[index];
                            return ListTile(
                              leading: const Icon(Icons.check_circle_outline, size: 20),
                              title: Text(option.name),
                              subtitle: Text(
                                option.priceModifier == 0
                                    ? 'No price change'
                                    : '${option.priceModifier > 0 ? '+' : ''}\$${option.priceModifier.toStringAsFixed(2)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () => _editOption(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                    onPressed: () => _deleteOption(index),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Save button
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveTemplate,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving
                  ? 'Saving...'
                  : _isEditMode
                      ? 'Update Template'
                      : 'Create Template'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Cancel button
            OutlinedButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple dialog for adding/editing an option
class _OptionFormDialog extends StatefulWidget {
  final SimpleCustomizationOption? option;

  const _OptionFormDialog({this.option});

  @override
  State<_OptionFormDialog> createState() => _OptionFormDialogState();
}

class _OptionFormDialogState extends State<_OptionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;

  bool get _isEditMode => widget.option != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.option?.name ?? '');
    _priceController = TextEditingController(
      text: widget.option?.priceModifier.toStringAsFixed(2) ?? '0.00',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final option = SimpleCustomizationOption(
      name: _nameController.text.trim(),
      priceModifier: double.parse(_priceController.text.trim()),
    );

    Navigator.pop(context, option);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditMode ? 'Edit Option' : 'Add Option'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Option Name *',
                  hintText: 'e.g., Yes, No, Small, Medium, Large',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Option name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price Modifier',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.attach_money),
                  helperText: 'Extra cost for this option (0.00 for no change)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Price modifier is required';
                  }
                  final price = double.tryParse(value.trim());
                  if (price == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
          ),
          child: Text(_isEditMode ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
