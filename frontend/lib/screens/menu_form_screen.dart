import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../models/menu.dart';
import '../models/restaurant.dart';
import '../services/menu_service.dart';
import '../services/restaurant_service.dart';
import 'menu_builder_screen.dart';

class MenuFormScreen extends StatefulWidget {
  final String token;
  final Menu? menu; // null for new menu, provided for editing
  final Restaurant? restaurant; // Optional: pre-selected restaurant for new menus

  const MenuFormScreen({
    super.key,
    required this.token,
    this.menu,
    this.restaurant,
  });

  @override
  State<MenuFormScreen> createState() => _MenuFormScreenState();
}

class _MenuFormScreenState extends State<MenuFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final MenuService _menuService = MenuService();
  final RestaurantService _restaurantService = RestaurantService();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isLoadingRestaurants = false;

  List<Restaurant> _restaurants = [];
  Restaurant? _selectedRestaurant;
  String? _restaurantErrorMessage;

  bool get _isEditMode => widget.menu != null;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing data if editing
    _nameController = TextEditingController(
      text: widget.menu?.name ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.menu?.description ?? '',
    );
    _isActive = widget.menu?.isActive ?? true;

    // If restaurant is pre-selected, use it
    if (widget.restaurant != null) {
      _selectedRestaurant = widget.restaurant;
      _restaurants = [widget.restaurant!];
      developer.log('Using pre-selected restaurant: ${widget.restaurant!.name}', name: 'MenuFormScreen');
    }

    // Load restaurants for vendor (only for create mode and if not pre-selected)
    if (!_isEditMode && widget.restaurant == null) {
      _loadRestaurants();
    }
  }

  Future<void> _loadRestaurants() async {
    setState(() {
      _isLoadingRestaurants = true;
      _restaurantErrorMessage = null;
    });

    try {
      developer.log('Loading vendor restaurants', name: 'MenuFormScreen');
      final restaurants = await _restaurantService.getRestaurants(widget.token);

      setState(() {
        _restaurants = restaurants;
        _isLoadingRestaurants = false;

        // Auto-select if only one restaurant
        if (_restaurants.length == 1) {
          _selectedRestaurant = _restaurants[0];
          developer.log('Auto-selected single restaurant: ${_selectedRestaurant!.name}', name: 'MenuFormScreen');
        }
      });

      developer.log('Loaded ${restaurants.length} restaurants', name: 'MenuFormScreen');
    } catch (e) {
      developer.log('Error loading restaurants: $e', name: 'MenuFormScreen', error: e);

      setState(() {
        _restaurantErrorMessage = 'Failed to load restaurants: ${e.toString()}';
        _isLoadingRestaurants = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveMenu() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate restaurant selection for create mode
    if (!_isEditMode && _selectedRestaurant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a restaurant'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();

      if (_isEditMode) {
        // Update existing menu
        developer.log('Updating menu ${widget.menu!.id}', name: 'MenuFormScreen');

        final updatedMenu = widget.menu!.copyWith(
          name: name,
          description: description.isEmpty ? null : description,
          isActive: _isActive,
        );

        await _menuService.updateMenu(
          widget.token,
          updatedMenu.id!,
          updatedMenu,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Menu updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        // Create new menu with restaurant assignment
        developer.log('Creating new menu for restaurant ${_selectedRestaurant!.id}', name: 'MenuFormScreen');

        // Create menu with empty menuConfig
        final newMenu = Menu(
          name: name,
          description: description.isEmpty ? null : description,
          menuConfig: {
            'version': '1.0',
            'categories': [],
          },
          isActive: _isActive,
        );

        // Create menu first
        final createdMenu = await _menuService.createMenu(widget.token, newMenu);
        developer.log('Menu created with ID: ${createdMenu.id}', name: 'MenuFormScreen');

        // Assign menu to restaurant
        await _menuService.assignMenuToRestaurant(
          widget.token,
          _selectedRestaurant!.id!,
          createdMenu.id!,
          isActive: _isActive,
        );
        developer.log('Menu assigned to restaurant ${_selectedRestaurant!.name}', name: 'MenuFormScreen');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Menu created and assigned to ${_selectedRestaurant!.name}'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate success
        }
      }
    } catch (e) {
      developer.log('Error saving menu: $e', name: 'MenuFormScreen', error: e);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Menu' : 'Create Menu'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Info card
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
                        _isEditMode
                            ? 'Update menu name and description. Menu items will be managed in the menu builder (Phase 4).'
                            : 'Create a menu and assign it to one of your restaurants. You\'ll be able to add categories and items in the menu builder (Phase 4).',
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

            // Restaurant selection (only for create mode)
            if (!_isEditMode) ...[
              // If restaurant is pre-selected, show read-only info card
              if (widget.restaurant != null)
                _buildRestaurantInfoCard()
              else
                _buildRestaurantSelector(),
              const SizedBox(height: 16),
            ],

            // Menu name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Menu Name',
                hintText: 'e.g., Main Menu, Breakfast, Lunch Special',
                prefixIcon: Icon(Icons.restaurant_menu),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Menu name is required';
                }
                if (value.trim().length < 3) {
                  return 'Menu name must be at least 3 characters';
                }
                if (value.trim().length > 100) {
                  return 'Menu name must be less than 100 characters';
                }
                return null;
              },
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            // Description field
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Brief description of this menu',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value != null && value.trim().length > 500) {
                  return 'Description must be less than 500 characters';
                }
                return null;
              },
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            // Active status toggle
            Card(
              child: SwitchListTile(
                title: const Text('Active'),
                subtitle: Text(
                  _isActive
                      ? 'This menu is active and can be assigned to restaurants'
                      : 'This menu is inactive and cannot be assigned to restaurants',
                ),
                value: _isActive,
                onChanged: _isLoading
                    ? null
                    : (value) {
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
            const SizedBox(height: 24),

            // Additional info for edit mode
            if (_isEditMode && widget.menu != null) ...[
              Card(
                color: Colors.grey[100],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Menu Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.category,
                        'Categories',
                        '${widget.menu!.getCategories().length}',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.fastfood,
                        'Total Items',
                        '${widget.menu!.getCategories().fold<int>(0, (sum, cat) => sum + cat.items.length)}',
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.link,
                        'Assigned Restaurants',
                        '${widget.menu!.assignedRestaurants?.length ?? 0}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Build Menu button for edit mode
              OutlinedButton.icon(
                onPressed: _isLoading ? null : () async {
                  final navigator = Navigator.of(context);
                  final result = await navigator.push<bool>(
                    MaterialPageRoute(
                      builder: (context) => MenuBuilderScreen(
                        token: widget.token,
                        menu: widget.menu!,
                      ),
                    ),
                  );
                  // Builder returns true if menu was saved
                  if (result == true && mounted) {
                    navigator.pop(true);
                  }
                },
                icon: const Icon(Icons.construction),
                label: const Text('Build Menu (Add Categories & Items)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.deepOrange, width: 2),
                  foregroundColor: Colors.deepOrange,
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Save button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveMenu,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _isEditMode ? 'Update Menu' : 'Create Menu',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 8),

            // Cancel button
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRestaurantInfoCard() {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant, color: Colors.green[700], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Restaurant',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.restaurant!.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.restaurant!.shortAddress.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              widget.restaurant!.shortAddress,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This menu will be created and assigned to this restaurant',
              style: TextStyle(
                fontSize: 13,
                color: Colors.green[900],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantSelector() {
    // Loading state
    if (_isLoadingRestaurants) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Loading restaurants...',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // Error state
    if (_restaurantErrorMessage != null) {
      return Card(
        color: Colors.red[50],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _restaurantErrorMessage!,
                      style: TextStyle(color: Colors.red[900]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadRestaurants,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // No restaurants state
    if (_restaurants.isEmpty) {
      return Card(
        color: Colors.orange[50],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You need to create a restaurant first before creating menus',
                      style: TextStyle(
                        color: Colors.orange[900],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Menus must be associated with a restaurant. Please create at least one restaurant first.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange[800],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Go back to menu list
                  // User should navigate to restaurant creation from dashboard
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Restaurant dropdown (single or multiple restaurants)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Restaurant',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Restaurant>(
          value: _selectedRestaurant,
          decoration: InputDecoration(
            hintText: 'Select a restaurant',
            prefixIcon: const Icon(Icons.restaurant),
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: _restaurants.length == 1 ? Colors.grey[100] : null,
          ),
          items: _restaurants.map((restaurant) {
            return DropdownMenuItem<Restaurant>(
              value: restaurant,
              child: Text(
                restaurant.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _isLoading || _restaurants.length == 1
              ? null // Disable if loading or only one option
              : (Restaurant? value) {
                  setState(() {
                    _selectedRestaurant = value;
                  });
                },
          validator: (value) {
            if (value == null) {
              return 'Please select a restaurant';
            }
            return null;
          },
          isExpanded: true,
        ),
        if (_restaurants.length == 1) ...[
          const SizedBox(height: 8),
          Text(
            'Automatically selected (you have only one restaurant)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (_selectedRestaurant != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Colors.green[50],
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This menu will be assigned to "${_selectedRestaurant!.name}"',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
