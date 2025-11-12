import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/menu.dart';
import '../mixins/form_state_mixin.dart';

class MenuItemFormScreen extends StatefulWidget {
  final MenuItem? item;

  const MenuItemFormScreen({
    super.key,
    this.item,
  });

  @override
  State<MenuItemFormScreen> createState() => _MenuItemFormScreenState();
}

class _MenuItemFormScreenState extends State<MenuItemFormScreen> with FormStateMixin {
  late bool _isActive;
  late bool _isAvailable;

  bool get _isEditMode => widget.item != null;

  @override
  void initState() {
    super.initState();
    // Initialize text controllers using mixin
    createController('name', initialValue: widget.item?.name ?? '');
    createController('description', initialValue: widget.item?.description ?? '');
    createController('price', initialValue: widget.item != null ? widget.item!.price.toStringAsFixed(2) : '');

    _isActive = widget.item?.isActive ?? true;
    _isAvailable = widget.item?.isAvailable ?? true;
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    final item = MenuItem(
      id: widget.item?.id ?? 'item_${DateTime.now().millisecondsSinceEpoch}',
      name: getText('name'),
      description: getText('description'),
      price: double.parse(getText('price')),
      displayOrder: widget.item?.displayOrder ?? 0,
      isActive: _isActive,
      isAvailable: _isAvailable,
    );

    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Item' : 'Add Item'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Info card for Phase 5
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Basic item form. Advanced features (customizations, dietary flags, images) will be added in Phase 5.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Item name
            TextFormField(
              controller: controller('name'),
              decoration: const InputDecoration(
                labelText: 'Item Name',
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
              controller: controller('description'),
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
              validator: (value) {
                if (value != null && value.trim().length > 300) {
                  return 'Description must be less than 300 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Price
            TextFormField(
              controller: controller('price'),
              decoration: const InputDecoration(
                labelText: 'Price',
                hintText: '9.99',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
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

            // Active status
            Card(
              child: SwitchListTile(
                title: const Text('Active'),
                subtitle: Text(
                  _isActive
                      ? 'This item is active in the menu'
                      : 'This item is inactive',
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
            const SizedBox(height: 8),

            // Available status
            Card(
              child: SwitchListTile(
                title: const Text('Available'),
                subtitle: Text(
                  _isAvailable
                      ? 'This item is available for ordering'
                      : 'This item is out of stock',
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
                  color: _isAvailable ? Colors.blue : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Save button (using mixin's buildLoadingButton)
            buildLoadingButton(
              label: _isEditMode ? 'Update Item' : 'Add Item',
              onPressed: _save,
            ),
            const SizedBox(height: 8),

            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
