import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../models/restaurant_request.dart';
import '../services/restaurant_service.dart';
import 'restaurant_form_screen.dart';
import 'vendor/restaurant_settings_screen.dart';

class VendorRestaurantManagementScreen extends StatefulWidget {
  final String token;

  const VendorRestaurantManagementScreen({
    super.key,
    required this.token,
  });

  @override
  State<VendorRestaurantManagementScreen> createState() =>
      _VendorRestaurantManagementScreenState();
}

class _VendorRestaurantManagementScreenState
    extends State<VendorRestaurantManagementScreen> {
  final RestaurantService _restaurantService = RestaurantService();
  List<Restaurant> _restaurants = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final restaurants =
          await _restaurantService.getRestaurants(widget.token);
      if (mounted) {
        setState(() {
          _restaurants = restaurants;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteRestaurant(int restaurantId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Restaurant'),
        content: const Text(
          'Are you sure you want to delete this restaurant? This action cannot be undone.',
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

    if (confirmed != true) return;

    try {
      await _restaurantService.deleteRestaurant(widget.token, restaurantId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restaurant deleted successfully')),
        );
        _loadRestaurants(); // Reload list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting restaurant: $e')),
        );
      }
    }
  }

  Future<void> _toggleActiveStatus(Restaurant restaurant) async {
    // Optimistic UI update
    final originalRestaurants = List<Restaurant>.from(_restaurants);
    final index = _restaurants.indexWhere((r) => r.id == restaurant.id);
    if (index == -1) return;

    setState(() {
      _restaurants[index] = restaurant.copyWith(isActive: !restaurant.isActive);
    });

    try {
      final request = UpdateRestaurantRequest(
        isActive: !restaurant.isActive,
      );

      await _restaurantService.updateRestaurant(
        widget.token,
        restaurant.id!,
        request,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              restaurant.isActive
                  ? 'Restaurant deactivated'
                  : 'Restaurant activated',
            ),
          ),
        );
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _restaurants = originalRestaurants;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating restaurant: $e')),
        );
      }
    }
  }

  Future<void> _navigateToAddRestaurant() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantFormScreen(
          token: widget.token,
        ),
      ),
    );

    if (result == true) {
      _loadRestaurants(); // Reload list if restaurant was created
    }
  }

  Future<void> _navigateToEditRestaurant(Restaurant restaurant) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantFormScreen(
          token: widget.token,
          restaurant: restaurant,
        ),
      ),
    );

    if (result == true) {
      _loadRestaurants(); // Reload list if restaurant was updated
    }
  }

  Future<void> _navigateToRestaurantSettings(Restaurant restaurant) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantSettingsScreen(
          token: widget.token,
          restaurantId: restaurant.id!,
          restaurantName: restaurant.name,
        ),
      ),
    );

    if (result == true) {
      _loadRestaurants(); // Reload list if settings were updated
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Restaurants'),
        backgroundColor: Colors.orange,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : _restaurants.isEmpty
                  ? _buildEmptyState()
                  : _buildRestaurantList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddRestaurant,
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add),
        label: const Text('Add Restaurant'),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
              'Error loading restaurants',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadRestaurants,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.restaurant,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No Restaurants Yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              "You haven't created any restaurants yet. Tap + to get started.",
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantList() {
    return RefreshIndicator(
      onRefresh: _loadRestaurants,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _restaurants.length,
        itemBuilder: (context, index) {
          final restaurant = _restaurants[index];
          return _RestaurantCard(
            restaurant: restaurant,
            onEdit: () => _navigateToEditRestaurant(restaurant),
            onDelete: () => _deleteRestaurant(restaurant.id!),
            onToggleActive: () => _toggleActiveStatus(restaurant),
            onSettings: () => _navigateToRestaurantSettings(restaurant),
          );
        },
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  final VoidCallback onSettings;

  const _RestaurantCard({
    required this.restaurant,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Restaurant name and status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    restaurant.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: restaurant.isActive ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    restaurant.isActive ? 'Active' : 'Inactive',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Location
            if (restaurant.shortAddress.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      restaurant.shortAddress,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),

            // Rating and orders
            Row(
              children: [
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  restaurant.rating.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.shopping_bag, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${restaurant.totalOrders} orders',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action buttons and toggle
            Row(
              children: [
                // Toggle active switch
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        'Active',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: restaurant.isActive,
                        onChanged: (_) => onToggleActive(),
                        activeTrackColor: Colors.green,
                      ),
                    ],
                  ),
                ),

                // Settings button
                IconButton(
                  onPressed: onSettings,
                  icon: const Icon(Icons.settings),
                  color: Colors.deepOrange,
                  tooltip: 'Settings',
                ),

                // Edit button
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  color: Colors.blue,
                  tooltip: 'Edit',
                ),

                // Delete button
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
