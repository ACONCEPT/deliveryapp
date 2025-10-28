import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../models/menu.dart';
import '../services/menu_service.dart';
import '../config/dashboard_constants.dart';
import 'menu_item_form_screen_enhanced.dart';

class MenuBuilderScreen extends StatefulWidget {
  final String token;
  final Menu menu;

  const MenuBuilderScreen({
    super.key,
    required this.token,
    required this.menu,
  });

  @override
  State<MenuBuilderScreen> createState() => _MenuBuilderScreenState();
}

class _MenuBuilderScreenState extends State<MenuBuilderScreen> {
  final MenuService _menuService = MenuService();
  late List<MenuCategory> _categories;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _categories = widget.menu.getCategories();
    developer.log('Loaded ${_categories.length} categories', name: 'MenuBuilderScreen');
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _saveMenu() async {
    setState(() {
      _isLoading = true;
    });

    try {
      developer.log('Saving menu with ${_categories.length} categories', name: 'MenuBuilderScreen');

      // Update menu with current categories
      final updatedMenu = widget.menu.copyWith(
        menuConfig: {
          'version': '1.0',
          'categories': _categories.map((c) => c.toJson()).toList(),
        },
      );

      await _menuService.updateMenu(
        widget.token,
        updatedMenu.id!,
        updatedMenu,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menu saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      developer.log('Error saving menu: $e', name: 'MenuBuilderScreen', error: e);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save menu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addCategory() async {
    final result = await showDialog<MenuCategory>(
      context: context,
      builder: (context) => const _CategoryFormDialog(),
    );

    if (result != null) {
      setState(() {
        _categories.add(result);
        _updateDisplayOrders();
        _markChanged();
      });
    }
  }

  Future<void> _editCategory(int index) async {
    final result = await showDialog<MenuCategory>(
      context: context,
      builder: (context) => _CategoryFormDialog(category: _categories[index]),
    );

    if (result != null) {
      setState(() {
        _categories[index] = result;
        _markChanged();
      });
    }
  }

  Future<void> _deleteCategory(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Are you sure you want to delete "${_categories[index].name}"?\n\n'
          'This will also delete all ${_categories[index].items.length} items in this category.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _categories.removeAt(index);
        _updateDisplayOrders();
        _markChanged();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category deleted')),
        );
      }
    }
  }

  void _reorderCategories(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final category = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, category);
      _updateDisplayOrders();
      _markChanged();
    });
  }

  void _updateDisplayOrders() {
    for (int i = 0; i < _categories.length; i++) {
      _categories[i] = _categories[i].copyWith(displayOrder: i);
    }
  }

  Future<void> _addItem(int categoryIndex) async {
    final result = await Navigator.push<MenuItem>(
      context,
      MaterialPageRoute(
        builder: (context) => MenuItemFormScreenEnhanced(token: widget.token),
      ),
    );

    if (result != null) {
      setState(() {
        final updatedItems = List<MenuItem>.from(_categories[categoryIndex].items)
          ..add(result);
        _categories[categoryIndex] = _categories[categoryIndex].copyWith(items: updatedItems);
        _markChanged();
      });
    }
  }

  Future<void> _editItem(int categoryIndex, int itemIndex) async {
    final result = await Navigator.push<MenuItem>(
      context,
      MaterialPageRoute(
        builder: (context) => MenuItemFormScreenEnhanced(
          item: _categories[categoryIndex].items[itemIndex],
          token: widget.token,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        final updatedItems = List<MenuItem>.from(_categories[categoryIndex].items);
        updatedItems[itemIndex] = result;
        _categories[categoryIndex] = _categories[categoryIndex].copyWith(items: updatedItems);
        _markChanged();
      });
    }
  }

  Future<void> _deleteItem(int categoryIndex, int itemIndex) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text(
          'Are you sure you want to delete "${_categories[categoryIndex].items[itemIndex].name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        final updatedItems = List<MenuItem>.from(_categories[categoryIndex].items);
        updatedItems.removeAt(itemIndex);
        _categories[categoryIndex] = _categories[categoryIndex].copyWith(items: updatedItems);
        _markChanged();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges || _isLoading,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          return;
        }

        if (_hasChanges && !_isLoading) {
          final shouldDiscard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Unsaved Changes'),
              content: const Text('You have unsaved changes. Do you want to discard them?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );

          if (shouldDiscard == true && context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Build Menu: ${widget.menu.name}'),
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          actions: [
            if (_hasChanges)
              TextButton.icon(
                onPressed: _isLoading ? null : _saveMenu,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save, color: Colors.white),
                label: const Text(
                  'Save',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
        body: _buildBody(),
        floatingActionButton: _isLoading
            ? null
            : FloatingActionButton(
                onPressed: _addCategory,
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                tooltip: 'Add Category',
                child: const Icon(Icons.add),
              ),
      ),
    );
  }

  Widget _buildBody() {
    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No categories yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add your first category',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(DashboardConstants.screenPadding / 2),
      onReorder: _reorderCategories,
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return _CategoryCard(
          key: ValueKey(category.id),
          category: category,
          categoryIndex: index,
          onEdit: () => _editCategory(index),
          onDelete: () => _deleteCategory(index),
          onAddItem: () => _addItem(index),
          onEditItem: (itemIndex) => _editItem(index, itemIndex),
          onDeleteItem: (itemIndex) => _deleteItem(index, itemIndex),
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final MenuCategory category;
  final int categoryIndex;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddItem;
  final Function(int) onEditItem;
  final Function(int) onDeleteItem;

  const _CategoryCard({
    super.key,
    required this.category,
    required this.categoryIndex,
    required this.onEdit,
    required this.onDelete,
    required this.onAddItem,
    required this.onEditItem,
    required this.onDeleteItem,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: DashboardConstants.cardPaddingSmall),
      elevation: DashboardConstants.cardElevationSmall,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepOrange[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(DashboardConstants.cardBorderRadiusSmall),
                topRight: Radius.circular(DashboardConstants.cardBorderRadiusSmall),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.drag_handle, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (category.description != null && category.description!.isNotEmpty)
                        Text(
                          category.description!,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: onEdit,
                  tooltip: 'Edit Category',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: onDelete,
                  tooltip: 'Delete Category',
                ),
              ],
            ),
          ),

          // Items list
          if (category.items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No items yet',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: category.items.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, itemIndex) {
                final item = category.items[itemIndex];
                return ListTile(
                  leading: const Icon(Icons.fastfood, size: 20),
                  title: Text(item.name),
                  subtitle: Text(
                    '\$${item.price.toStringAsFixed(2)}${item.description.isNotEmpty ? ' - ${item.description}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => onEditItem(itemIndex),
                        tooltip: 'Edit Item',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                        onPressed: () => onDeleteItem(itemIndex),
                        tooltip: 'Delete Item',
                      ),
                    ],
                  ),
                );
              },
            ),

          // Add item button
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton.icon(
              onPressed: onAddItem,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryFormDialog extends StatefulWidget {
  final MenuCategory? category;

  const _CategoryFormDialog({this.category});

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late bool _isActive;

  bool get _isEditMode => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _descriptionController = TextEditingController(text: widget.category?.description ?? '');
    _isActive = widget.category?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final category = MenuCategory(
      id: widget.category?.id ?? 'cat_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      displayOrder: widget.category?.displayOrder ?? 0,
      isActive: _isActive,
      items: widget.category?.items ?? [],
    );

    Navigator.pop(context, category);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditMode ? 'Edit Category' : 'Add Category'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g., Appetizers, Main Course',
                  prefixIcon: Icon(Icons.category),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Category name is required';
                  }
                  if (value.trim().length < 2) {
                    return 'Name must be at least 2 characters';
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
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active'),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
                activeTrackColor: Colors.green[200],
                activeThumbColor: Colors.green,
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
