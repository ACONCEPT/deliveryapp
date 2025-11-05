import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../models/menu.dart';
import '../models/restaurant.dart';
import '../services/menu_service.dart';
import '../config/dashboard_constants.dart';
import 'menu_form_screen.dart';

class VendorMenuListScreen extends StatefulWidget {
  final String token;
  final Restaurant? restaurant; // Optional: if provided, filter menus for this restaurant
  final String? userType; // User type for template import (typically 'vendor')

  const VendorMenuListScreen({
    super.key,
    required this.token,
    this.restaurant,
    this.userType,
  });

  @override
  State<VendorMenuListScreen> createState() => _VendorMenuListScreenState();
}

class _VendorMenuListScreenState extends State<VendorMenuListScreen> {
  final MenuService _menuService = MenuService();
  List<Menu> _menus = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMenus();
  }

  Future<void> _loadMenus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      developer.log('Loading vendor menus', name: 'VendorMenuListScreen');

      // Load menus, optionally filtered by restaurant
      final menus = await _menuService.getVendorMenus(
        widget.token,
        restaurantId: widget.restaurant?.id,
      );

      // If restaurant is specified, filter menus assigned to this restaurant
      List<Menu> filteredMenus = menus;
      if (widget.restaurant != null) {
        filteredMenus = menus.where((menu) {
          return menu.assignedRestaurants != null &&
                 menu.assignedRestaurants!.any((assignment) => assignment.restaurantId == widget.restaurant!.id);
        }).toList();
        developer.log('Filtered to ${filteredMenus.length} menus for restaurant ${widget.restaurant!.name}',
                     name: 'VendorMenuListScreen');
      }

      setState(() {
        _menus = filteredMenus;
        _isLoading = false;
      });

      developer.log('Loaded ${filteredMenus.length} menus', name: 'VendorMenuListScreen');
    } catch (e) {
      developer.log('Error loading menus: $e', name: 'VendorMenuListScreen', error: e);

      setState(() {
        _errorMessage = 'Failed to load menus: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteMenu(Menu menu) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Menu'),
        content: Text(
          'Are you sure you want to delete "${menu.name}"?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _menuService.deleteMenu(widget.token, menu.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Menu "${menu.name}" deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadMenus(); // Reload the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete menu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _navigateToCreateMenu() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => MenuFormScreen(
          token: widget.token,
          restaurant: widget.restaurant, // Pass restaurant to auto-assign
          userType: widget.userType,
        ),
      ),
    );

    // Reload menus if a menu was created
    if (result == true && mounted) {
      _loadMenus();
    }
  }

  Future<void> _navigateToEditMenu(Menu menu) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => MenuFormScreen(
          token: widget.token,
          menu: menu,
          userType: widget.userType,
        ),
      ),
    );

    // Reload menus if a menu was updated
    if (result == true && mounted) {
      _loadMenus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Menus'),
            if (widget.restaurant != null)
              Text(
                widget.restaurant!.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateMenu,
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        tooltip: 'Create New Menu',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMenus,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_menus.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              widget.restaurant != null
                  ? 'No menus for ${widget.restaurant!.name}'
                  : 'No menus yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.restaurant != null
                  ? 'Tap the + button to create a menu for this restaurant'
                  : 'Tap the + button to create your first menu',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMenus,
      child: ListView.builder(
        padding: const EdgeInsets.all(DashboardConstants.screenPadding / 2),
        itemCount: _menus.length,
        itemBuilder: (context, index) {
          final menu = _menus[index];
          return _MenuCard(
            menu: menu,
            onEdit: () => _navigateToEditMenu(menu),
            onDelete: () => _deleteMenu(menu),
          );
        },
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final Menu menu;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MenuCard({
    required this.menu,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final categories = menu.getCategories();
    final totalItems = categories.fold<int>(
      0,
      (sum, cat) => sum + cat.items.length,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: DashboardConstants.cardPaddingSmall),
      elevation: DashboardConstants.cardElevationSmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with menu name and status
          Container(
            padding: const EdgeInsets.all(DashboardConstants.cardPadding / 2),
            decoration: BoxDecoration(
              color: menu.isActive ? Colors.green[50] : Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(DashboardConstants.cardBorderRadiusSmall),
                topRight: Radius.circular(DashboardConstants.cardBorderRadiusSmall),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        menu.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (menu.description != null && menu.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            menu.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: menu.isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    menu.isActive ? 'ACTIVE' : 'INACTIVE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content: Menu stats
          Padding(
            padding: const EdgeInsets.all(DashboardConstants.cardPadding / 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow(
                  Icons.category,
                  'Categories',
                  '${categories.length}',
                  Colors.orange,
                ),
                const SizedBox(height: 8),
                _buildStatRow(
                  Icons.fastfood,
                  'Total Items',
                  '$totalItems',
                  Colors.purple,
                ),
                if (menu.createdAt != null) ...[
                  const SizedBox(height: 8),
                  _buildStatRow(
                    Icons.calendar_today,
                    'Created',
                    _formatDate(menu.createdAt!),
                    Colors.grey,
                  ),
                ],
              ],
            ),
          ),

          // Actions
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DashboardConstants.cardPadding / 4,
              vertical: DashboardConstants.cardPadding / 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange,
                  ),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }
}
