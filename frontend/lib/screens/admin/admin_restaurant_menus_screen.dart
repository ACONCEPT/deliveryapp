import 'package:flutter/material.dart';
import '../../models/restaurant.dart';
import '../../models/user.dart';
import '../../models/menu.dart';
import '../../services/menu_service.dart';
import '../../config/dashboard_constants.dart';
import '../menu_builder_screen.dart';

/// Admin Restaurant Menus Screen
///
/// Displays all menus for a specific restaurant with admin management capabilities.
/// Features:
/// - Restaurant context header
/// - List of all menus assigned to the restaurant
/// - Menu details (categories count, items count, active status)
/// - Actions: View/Edit menu, Activate/Deactivate, Delete menu
/// - Empty state for restaurants with no menus
class AdminRestaurantMenusScreen extends StatefulWidget {
  final String token;
  final User user;
  final Restaurant restaurant;

  const AdminRestaurantMenusScreen({
    super.key,
    required this.token,
    required this.user,
    required this.restaurant,
  });

  @override
  State<AdminRestaurantMenusScreen> createState() =>
      _AdminRestaurantMenusScreenState();
}

class _AdminRestaurantMenusScreenState
    extends State<AdminRestaurantMenusScreen> {
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
      // Use admin endpoint to get all menus filtered by this restaurant
      final allMenus =
          await _menuService.getAdminMenus(widget.token, restaurantId: widget.restaurant.id);

      setState(() {
        _menus = allMenus;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleMenuStatus(Menu menu) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            menu.isActive
                ? 'Deactivating ${menu.name}...'
                : 'Activating ${menu.name}...',
          ),
          duration: const Duration(seconds: 1),
        ),
      );

      // Update menu status via vendor endpoint (admin has vendor permissions)
      await _menuService.updateMenu(
        widget.token,
        menu.id!,
        UpdateMenuRequest(isActive: !menu.isActive),
      );

      // Reload menus
      await _loadMenus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Menu ${!menu.isActive ? 'activated' : 'deactivated'} successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update menu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteMenu(Menu menu) async {
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleting ${menu.name}...'),
          duration: const Duration(seconds: 1),
        ),
      );

      await _menuService.deleteMenu(widget.token, menu.id!);

      // Reload menus
      await _loadMenus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menu deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
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

  Future<void> _navigateToEditMenu(Menu menu) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MenuBuilderScreen(
          token: widget.token,
          menu: menu,
          userType: widget.user.userType,
        ),
      ),
    );

    if (result == true) {
      _loadMenus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.restaurant.name} - Menus'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadMenus,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(DashboardConstants.screenPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRestaurantHeader(),
                          const SizedBox(height: DashboardConstants.sectionSpacing),
                          _buildMenuList(),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading menus',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadMenus,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantHeader() {
    return Card(
      elevation: DashboardConstants.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius:
                    BorderRadius.circular(DashboardConstants.cardBorderRadius),
              ),
              child: const Icon(Icons.restaurant, size: 40),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.restaurant.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (widget.restaurant.shortAddress.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          widget.restaurant.shortAddress,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.restaurant.isActive
                              ? Colors.green
                              : Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.restaurant.isActive ? 'ACTIVE' : 'INACTIVE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildRestaurantStatChip(
                        Icons.star,
                        widget.restaurant.rating.toStringAsFixed(1),
                        Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      _buildRestaurantStatChip(
                        Icons.shopping_bag,
                        '${widget.restaurant.totalOrders}',
                        Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuList() {
    if (_menus.isEmpty) {
      return Card(
        elevation: DashboardConstants.cardElevation,
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.restaurant_menu_outlined,
                    size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No Menus Found',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This restaurant has no menus assigned yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[500],
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Menus (${_menus.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _menus.length,
          itemBuilder: (context, index) {
            return _buildMenuCard(_menus[index]);
          },
        ),
      ],
    );
  }

  Widget _buildMenuCard(Menu menu) {
    // Calculate stats from menu config
    final categories = menu.getCategories();
    final totalItems = categories.fold<int>(
      0,
      (sum, category) => sum + category.items.length,
    );

    return Card(
      elevation: DashboardConstants.cardElevation,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              menu.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          _buildMenuStatusBadge(menu.isActive),
                        ],
                      ),
                      if (menu.description != null &&
                          menu.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          menu.description!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildMenuStatChip(
                            Icons.category,
                            '$categories categories',
                            Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          _buildMenuStatChip(
                            Icons.fastfood,
                            '$totalItems items',
                            Colors.orange,
                          ),
                          if (menu.assignedRestaurants != null) ...[
                            const SizedBox(width: 8),
                            _buildMenuStatChip(
                              Icons.restaurant,
                              '${menu.assignedRestaurants!.length} restaurants',
                              Colors.purple,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _navigateToEditMenu(menu),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('View Details'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _navigateToEditMenu(menu),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _deleteMenu(menu),
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  label: const Text('Delete',
                      style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _toggleMenuStatus(menu),
                  icon: Icon(
                    menu.isActive ? Icons.cancel : Icons.check_circle,
                    size: 18,
                  ),
                  label: Text(menu.isActive ? 'Deactivate' : 'Activate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        menu.isActive ? Colors.orange : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green : Colors.grey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'INACTIVE',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMenuStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
