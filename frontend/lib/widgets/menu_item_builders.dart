import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/menu.dart';

/// Variant Builder Widget
///
/// Composable widget for building item variants (size, crust type, etc.)
class VariantBuilder extends StatefulWidget {
  final List<ItemVariant> variants;
  final Function(List<ItemVariant>) onChanged;

  const VariantBuilder({
    super.key,
    required this.variants,
    required this.onChanged,
  });

  @override
  State<VariantBuilder> createState() => _VariantBuilderState();
}

class _VariantBuilderState extends State<VariantBuilder> {
  late List<ItemVariant> _variants;

  @override
  void initState() {
    super.initState();
    _variants = List<ItemVariant>.from(widget.variants);
  }

  @override
  void didUpdateWidget(VariantBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update internal list when widget.variants changes
    if (widget.variants != oldWidget.variants || widget.variants.length != oldWidget.variants.length) {
      setState(() {
        _variants = List<ItemVariant>.from(widget.variants);
      });
    }
  }

  void _addVariant() async {
    final result = await showDialog<ItemVariant>(
      context: context,
      builder: (context) => const _VariantFormDialog(),
    );

    if (result != null) {
      setState(() {
        _variants.add(result);
        widget.onChanged(_variants);
      });
    }
  }

  void _editVariant(int index) async {
    final result = await showDialog<ItemVariant>(
      context: context,
      builder: (context) => _VariantFormDialog(variant: _variants[index]),
    );

    if (result != null) {
      setState(() {
        _variants[index] = result;
        widget.onChanged(_variants);
      });
    }
  }

  void _deleteVariant(int index) {
    setState(() {
      _variants.removeAt(index);
      widget.onChanged(_variants);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.tune, color: Colors.deepOrange),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Variants',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Pre-configured options like size, crust type, flavor',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _addVariant,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          if (_variants.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
              child: Center(
                child: Text(
                  'No variants added',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _variants.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final variant = _variants[index];
                return ListTile(
                  leading: const Icon(Icons.tune, size: 20),
                  title: Text(variant.name),
                  subtitle: Text(
                    '${variant.options.length} options${variant.required ? ' (Required)' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _editVariant(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                        onPressed: () => _deleteVariant(index),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _VariantFormDialog extends StatefulWidget {
  final ItemVariant? variant;

  const _VariantFormDialog({this.variant});

  @override
  State<_VariantFormDialog> createState() => _VariantFormDialogState();
}

class _VariantFormDialogState extends State<_VariantFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late String _type;
  late bool _required;
  late List<VariantOption> _options;

  bool get _isEditMode => widget.variant != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.variant?.name ?? '');
    _type = widget.variant?.type ?? 'single_choice';
    _required = widget.variant?.required ?? true;
    _options = widget.variant != null
        ? List<VariantOption>.from(widget.variant!.options)
        : [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addOption() async {
    final result = await showDialog<VariantOption>(
      context: context,
      builder: (context) => const _VariantOptionFormDialog(),
    );

    if (result != null) {
      setState(() {
        _options.add(result);
      });
    }
  }

  void _editOption(int index) async {
    final result = await showDialog<VariantOption>(
      context: context,
      builder: (context) => _VariantOptionFormDialog(option: _options[index]),
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

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one option'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final variant = ItemVariant(
      id: widget.variant?.id ?? 'var_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      type: _type,
      required: _required,
      options: _options,
    );

    Navigator.pop(context, variant);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
        child: Column(
          children: [
            AppBar(
              title: Text(_isEditMode ? 'Edit Variant' : 'Add Variant'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Variant Name',
                        hintText: 'e.g., Size, Crust Type, Flavor',
                        prefixIcon: Icon(Icons.label),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Variant name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _type,
                      decoration: const InputDecoration(
                        labelText: 'Display Type',
                        prefixIcon: Icon(Icons.view_list),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'single_choice',
                          child: Text('Dropdown'),
                        ),
                        DropdownMenuItem(
                          value: 'button_group',
                          child: Text('Button Group'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _type = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Required'),
                      subtitle: const Text('Customer must select an option'),
                      value: _required,
                      onChanged: (value) {
                        setState(() {
                          _required = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Options',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addOption,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Option'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_options.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No options added yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...List.generate(_options.length, (index) {
                        final option = _options[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(option.name),
                            subtitle: Text(
                              option.priceModifier == 0
                                  ? 'No price change'
                                  : (option.priceModifier > 0 ? '+' : '') +
                                      '\$${option.priceModifier.toStringAsFixed(2)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _editOption(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      size: 18, color: Colors.red),
                                  onPressed: () => _deleteOption(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_isEditMode ? 'Update' : 'Add'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariantOptionFormDialog extends StatefulWidget {
  final VariantOption? option;

  const _VariantOptionFormDialog({this.option});

  @override
  State<_VariantOptionFormDialog> createState() =>
      _VariantOptionFormDialogState();
}

class _VariantOptionFormDialogState extends State<_VariantOptionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;

  bool get _isEditMode => widget.option != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.option?.name ?? '');
    _priceController = TextEditingController(
      text: widget.option?.priceModifier.toStringAsFixed(2) ?? '0.00',
    );
    _descriptionController =
        TextEditingController(text: widget.option?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final option = VariantOption(
      id: widget.option?.id ?? 'opt_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      priceModifier: double.parse(_priceController.text.trim()),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
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
                  labelText: 'Option Name',
                  hintText: 'e.g., Small (10"), Medium (12")',
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
                  helperText: 'Positive for extra cost, negative for discount',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Brief description',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
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

/// Customization Options Builder Widget
///
/// Composable widget for building customization options (toppings, spice levels, notes, etc.)
class CustomizationOptionsBuilder extends StatefulWidget {
  final List<CustomizationOption> options;
  final Function(List<CustomizationOption>) onChanged;

  const CustomizationOptionsBuilder({
    super.key,
    required this.options,
    required this.onChanged,
  });

  @override
  State<CustomizationOptionsBuilder> createState() =>
      _CustomizationOptionsBuilderState();
}

class _CustomizationOptionsBuilderState
    extends State<CustomizationOptionsBuilder> {
  late List<CustomizationOption> _options;

  @override
  void initState() {
    super.initState();
    _options = List<CustomizationOption>.from(widget.options);
  }

  @override
  void didUpdateWidget(CustomizationOptionsBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update internal list when widget.options changes (e.g., after import)
    // Check both reference and length to catch all updates
    if (widget.options != oldWidget.options || widget.options.length != oldWidget.options.length) {
      setState(() {
        _options = List<CustomizationOption>.from(widget.options);
      });
    }
  }

  void _addOption() async {
    final result = await showDialog<CustomizationOption>(
      context: context,
      builder: (context) => const _CustomizationOptionFormDialog(),
    );

    if (result != null) {
      setState(() {
        _options.add(result);
        widget.onChanged(_options);
      });
    }
  }

  void _editOption(int index) async {
    final result = await showDialog<CustomizationOption>(
      context: context,
      builder: (context) => _CustomizationOptionFormDialog(option: _options[index]),
    );

    if (result != null) {
      setState(() {
        _options[index] = result;
        widget.onChanged(_options);
      });
    }
  }

  void _deleteOption(int index) {
    setState(() {
      _options.removeAt(index);
      widget.onChanged(_options);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline, color: Colors.deepOrange),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customization Options',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Add-ons, toppings, special instructions, spice levels',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          if (_options.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
              child: Center(
                child: Text(
                  'No customization options added',
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
                String subtitle = option.type;
                if (option.required) subtitle += ' (Required)';
                if (option.maxSelections != null) {
                  subtitle += ' - Max ${option.maxSelections}';
                }

                return ListTile(
                  leading: Icon(_getIconForType(option.type), size: 20),
                  title: Text(option.name),
                  subtitle: Text(subtitle),
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
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'single_choice':
        return Icons.radio_button_checked;
      case 'multiple_choice':
        return Icons.check_box;
      case 'text_input':
        return Icons.text_fields;
      case 'spice_level':
        return Icons.local_fire_department;
      default:
        return Icons.settings;
    }
  }
}

class _CustomizationOptionFormDialog extends StatefulWidget {
  final CustomizationOption? option;

  const _CustomizationOptionFormDialog({this.option});

  @override
  State<_CustomizationOptionFormDialog> createState() =>
      _CustomizationOptionFormDialogState();
}

class _CustomizationOptionFormDialogState
    extends State<_CustomizationOptionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _maxSelectionsController;
  late TextEditingController _maxLengthController;
  late TextEditingController _placeholderController;
  late String _type;
  late bool _required;
  late List<CustomizationChoice> _choices;

  bool get _isEditMode => widget.option != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.option?.name ?? '');
    _type = widget.option?.type ?? 'single_choice';
    _required = widget.option?.required ?? false;
    _choices = widget.option?.choices != null
        ? List<CustomizationChoice>.from(widget.option!.choices!)
        : [];
    _maxSelectionsController = TextEditingController(
      text: widget.option?.maxSelections?.toString() ?? '',
    );
    _maxLengthController = TextEditingController(
      text: widget.option?.maxLength?.toString() ?? '200',
    );
    _placeholderController = TextEditingController(
      text: widget.option?.placeholder ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _maxSelectionsController.dispose();
    _maxLengthController.dispose();
    _placeholderController.dispose();
    super.dispose();
  }

  void _addChoice() async {
    final result = await showDialog<CustomizationChoice>(
      context: context,
      builder: (context) => const _CustomizationChoiceFormDialog(),
    );

    if (result != null) {
      setState(() {
        _choices.add(result);
      });
    }
  }

  void _editChoice(int index) async {
    final result = await showDialog<CustomizationChoice>(
      context: context,
      builder: (context) => _CustomizationChoiceFormDialog(choice: _choices[index]),
    );

    if (result != null) {
      setState(() {
        _choices[index] = result;
      });
    }
  }

  void _deleteChoice(int index) {
    setState(() {
      _choices.removeAt(index);
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate choices for choice-based types
    if (_type != 'text_input' && _choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one choice'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final option = CustomizationOption(
      id: widget.option?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      type: _type,
      required: _required,
      maxSelections: _type == 'multiple_choice' && _maxSelectionsController.text.isNotEmpty
          ? int.tryParse(_maxSelectionsController.text)
          : null,
      maxLength: _type == 'text_input' && _maxLengthController.text.isNotEmpty
          ? int.tryParse(_maxLengthController.text)
          : null,
      placeholder: _type == 'text_input' && _placeholderController.text.isNotEmpty
          ? _placeholderController.text.trim()
          : null,
      choices: _type != 'text_input' ? _choices : null,
    );

    Navigator.pop(context, option);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            AppBar(
              title: Text(_isEditMode ? 'Edit Customization' : 'Add Customization'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Option Name',
                        hintText: 'e.g., Toppings, Spice Level, Special Instructions',
                        prefixIcon: Icon(Icons.label),
                        border: OutlineInputBorder(),
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
                    DropdownButtonFormField<String>(
                      value: _type,
                      decoration: const InputDecoration(
                        labelText: 'Option Type',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'single_choice',
                          child: Text('Single Choice (Radio)'),
                        ),
                        DropdownMenuItem(
                          value: 'multiple_choice',
                          child: Text('Multiple Choice (Checkboxes)'),
                        ),
                        DropdownMenuItem(
                          value: 'spice_level',
                          child: Text('Spice Level Selector'),
                        ),
                        DropdownMenuItem(
                          value: 'text_input',
                          child: Text('Text Input (Notes)'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _type = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Required'),
                      subtitle: const Text('Customer must provide this option'),
                      value: _required,
                      onChanged: (value) {
                        setState(() {
                          _required = value;
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
                          prefixIcon: Icon(Icons.numbers),
                          border: OutlineInputBorder(),
                          helperText: 'Leave empty for unlimited',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_type == 'text_input') ...[
                      TextFormField(
                        controller: _maxLengthController,
                        decoration: const InputDecoration(
                          labelText: 'Max Length',
                          hintText: '200',
                          prefixIcon: Icon(Icons.text_fields),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _placeholderController,
                        decoration: const InputDecoration(
                          labelText: 'Placeholder Text',
                          hintText: 'e.g., Any special requests?',
                          prefixIcon: Icon(Icons.edit_note),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Choices section (not for text_input)
                    if (_type != 'text_input') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Choices',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addChoice,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Choice'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_choices.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'No choices added yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ...List.generate(_choices.length, (index) {
                          final choice = _choices[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(choice.name),
                              subtitle: Text(
                                choice.priceModifier == 0
                                    ? 'No price change'
                                    : '${choice.priceModifier > 0 ? '+' : ''}\$${choice.priceModifier.toStringAsFixed(2)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () => _editChoice(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        size: 18, color: Colors.red),
                                    onPressed: () => _deleteChoice(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_isEditMode ? 'Update' : 'Add'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomizationChoiceFormDialog extends StatefulWidget {
  final CustomizationChoice? choice;

  const _CustomizationChoiceFormDialog({this.choice});

  @override
  State<_CustomizationChoiceFormDialog> createState() =>
      _CustomizationChoiceFormDialogState();
}

class _CustomizationChoiceFormDialogState
    extends State<_CustomizationChoiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;

  bool get _isEditMode => widget.choice != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.choice?.name ?? '');
    _priceController = TextEditingController(
      text: widget.choice?.priceModifier.toStringAsFixed(2) ?? '0.00',
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

    final choice = CustomizationChoice(
      id: widget.choice?.id ?? 'choice_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      priceModifier: double.parse(_priceController.text.trim()),
    );

    Navigator.pop(context, choice);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditMode ? 'Edit Choice' : 'Add Choice'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Choice Name',
                hintText: 'e.g., Extra Cheese, No Onions',
                prefixIcon: Icon(Icons.label_outline),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Choice name is required';
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
                helperText: 'Extra cost for this choice',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
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

/// Dietary Flags Builder Widget
///
/// Composable widget for selecting dietary flags (vegetarian, vegan, etc.)
class DietaryFlagsBuilder extends StatefulWidget {
  final Map<String, bool> flags;
  final Function(Map<String, bool>) onChanged;

  const DietaryFlagsBuilder({
    super.key,
    required this.flags,
    required this.onChanged,
  });

  @override
  State<DietaryFlagsBuilder> createState() => _DietaryFlagsBuilderState();
}

class _DietaryFlagsBuilderState extends State<DietaryFlagsBuilder> {
  static const availableFlags = {
    'vegetarian': 'Vegetarian',
    'vegan': 'Vegan',
    'gluten_free': 'Gluten-Free',
    'dairy_free': 'Dairy-Free',
    'nut_free': 'Nut-Free',
    'halal': 'Halal',
    'kosher': 'Kosher',
    'organic': 'Organic',
  };

  late Map<String, bool> _flags;

  @override
  void initState() {
    super.initState();
    _flags = Map<String, bool>.from(widget.flags);
    // Initialize any missing flags
    for (final key in availableFlags.keys) {
      _flags.putIfAbsent(key, () => false);
    }
  }

  @override
  void didUpdateWidget(DietaryFlagsBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update internal map when widget.flags changes
    if (widget.flags != oldWidget.flags) {
      setState(() {
        _flags = Map<String, bool>.from(widget.flags);
        // Initialize any missing flags
        for (final key in availableFlags.keys) {
          _flags.putIfAbsent(key, () => false);
        }
      });
    }
  }

  void _toggleFlag(String key, bool value) {
    setState(() {
      _flags[key] = value;
      widget.onChanged(_flags);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.eco, color: Colors.green),
                SizedBox(width: 12),
                Text(
                  'Dietary Flags',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableFlags.entries.map((entry) {
                return FilterChip(
                  label: Text(entry.value),
                  selected: _flags[entry.key] ?? false,
                  onSelected: (value) => _toggleFlag(entry.key, value),
                  selectedColor: Colors.green[100],
                  checkmarkColor: Colors.green[900],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Allergens Builder Widget
///
/// Composable widget for managing allergen list
class AllergensBuilder extends StatefulWidget {
  final List<String> allergens;
  final Function(List<String>) onChanged;

  const AllergensBuilder({
    super.key,
    required this.allergens,
    required this.onChanged,
  });

  @override
  State<AllergensBuilder> createState() => _AllergensBuilderState();
}

class _AllergensBuilderState extends State<AllergensBuilder> {
  static const commonAllergens = [
    'dairy',
    'eggs',
    'fish',
    'shellfish',
    'tree_nuts',
    'peanuts',
    'wheat',
    'gluten',
    'soy',
    'sesame',
  ];

  late Set<String> _allergens;

  @override
  void initState() {
    super.initState();
    _allergens = Set<String>.from(widget.allergens);
  }

  @override
  void didUpdateWidget(AllergensBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update internal set when widget.allergens changes
    if (widget.allergens != oldWidget.allergens || widget.allergens.length != oldWidget.allergens.length) {
      setState(() {
        _allergens = Set<String>.from(widget.allergens);
      });
    }
  }

  void _toggleAllergen(String allergen) {
    setState(() {
      if (_allergens.contains(allergen)) {
        _allergens.remove(allergen);
      } else {
        _allergens.add(allergen);
      }
      widget.onChanged(_allergens.toList());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 12),
                Text(
                  'Allergens',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Select all allergens present in this item',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: commonAllergens.map((allergen) {
                return FilterChip(
                  label: Text(_formatAllergen(allergen)),
                  selected: _allergens.contains(allergen),
                  onSelected: (value) => _toggleAllergen(allergen),
                  selectedColor: Colors.orange[100],
                  checkmarkColor: Colors.orange[900],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAllergen(String allergen) {
    return allergen.split('_').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}

/// Image URL Field Widget
///
/// Simple text field for entering item image URL
class ImageURLField extends StatelessWidget {
  final TextEditingController controller;

  const ImageURLField({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.image, color: Colors.blue),
                SizedBox(width: 12),
                Text(
                  'Product Image',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Image URL (Optional)',
                hintText: 'https://example.com/image.jpg',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
                helperText: 'Enter a URL to an image of this item',
              ),
              keyboardType: TextInputType.url,
            ),
            if (controller.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  controller.text,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 120,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'Unable to load image',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tags Builder Widget
///
/// Composable widget for managing item tags
class TagsBuilder extends StatefulWidget {
  final List<String> tags;
  final Function(List<String>) onChanged;

  const TagsBuilder({
    super.key,
    required this.tags,
    required this.onChanged,
  });

  @override
  State<TagsBuilder> createState() => _TagsBuilderState();
}

class _TagsBuilderState extends State<TagsBuilder> {
  static const commonTags = [
    'popular',
    'chef_special',
    'new',
    'bestseller',
    'seasonal',
    'limited_time',
    'spicy',
    'healthy',
    'comfort_food',
    'kids_friendly',
  ];

  late Set<String> _tags;
  final TextEditingController _customTagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tags = Set<String>.from(widget.tags);
  }

  @override
  void didUpdateWidget(TagsBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update internal set when widget.tags changes
    if (widget.tags != oldWidget.tags || widget.tags.length != oldWidget.tags.length) {
      setState(() {
        _tags = Set<String>.from(widget.tags);
      });
    }
  }

  @override
  void dispose() {
    _customTagController.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_tags.contains(tag)) {
        _tags.remove(tag);
      } else {
        _tags.add(tag);
      }
      widget.onChanged(_tags.toList());
    });
  }

  void _addCustomTag() {
    final tag = _customTagController.text.trim().toLowerCase();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _customTagController.clear();
        widget.onChanged(_tags.toList());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final customTags = _tags.where((tag) => !commonTags.contains(tag)).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.local_offer, color: Colors.purple),
                SizedBox(width: 12),
                Text(
                  'Tags',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Add tags to help customers find this item',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: commonTags.map((tag) {
                return FilterChip(
                  label: Text(_formatTag(tag)),
                  selected: _tags.contains(tag),
                  onSelected: (value) => _toggleTag(tag),
                  selectedColor: Colors.purple[100],
                  checkmarkColor: Colors.purple[900],
                );
              }).toList(),
            ),
            if (customTags.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Custom Tags:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: customTags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _toggleTag(tag),
                    backgroundColor: Colors.purple[50],
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customTagController,
                    decoration: const InputDecoration(
                      labelText: 'Add Custom Tag',
                      hintText: 'e.g., low-carb',
                      prefixIcon: Icon(Icons.add),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addCustomTag(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addCustomTag,
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTag(String tag) {
    return tag.split('_').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}

/// Additional Info Fields Widget
///
/// Fields for calories, preparation time, and spice level
class AdditionalInfoFields extends StatelessWidget {
  final TextEditingController caloriesController;
  final TextEditingController prepTimeController;
  final int? spiceLevel;
  final Function(int?) onSpiceLevelChanged;

  const AdditionalInfoFields({
    super.key,
    required this.caloriesController,
    required this.prepTimeController,
    required this.spiceLevel,
    required this.onSpiceLevelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.teal),
                SizedBox(width: 12),
                Text(
                  'Additional Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: caloriesController,
                    decoration: const InputDecoration(
                      labelText: 'Calories (Optional)',
                      hintText: 'e.g., 350',
                      prefixIcon: Icon(Icons.local_fire_department),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: prepTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Prep Time (min)',
                      hintText: 'e.g., 15',
                      prefixIcon: Icon(Icons.timer),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: spiceLevel,
              decoration: const InputDecoration(
                labelText: 'Spice Level (Optional)',
                prefixIcon: Icon(Icons.local_fire_department),
                border: OutlineInputBorder(),
                helperText: 'General spiciness indicator for the item',
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Not Applicable')),
                DropdownMenuItem(value: 0, child: Text('🌶️ Mild')),
                DropdownMenuItem(value: 1, child: Text('🌶️🌶️ Medium')),
                DropdownMenuItem(value: 2, child: Text('🌶️🌶️🌶️ Hot')),
                DropdownMenuItem(value: 3, child: Text('🌶️🌶️🌶️🌶️ Extra Hot')),
              ],
              onChanged: onSpiceLevelChanged,
            ),
          ],
        ),
      ),
    );
  }
}
