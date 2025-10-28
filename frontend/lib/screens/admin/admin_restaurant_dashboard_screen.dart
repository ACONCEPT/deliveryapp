import 'package:flutter/material.dart';
import '../../models/restaurant.dart';
import '../../models/restaurant_request.dart';
import '../../models/user.dart';
import '../../services/restaurant_service.dart';
import '../../config/dashboard_constants.dart';
import 'admin_restaurant_menus_screen.dart';
import '../restaurant_form_screen.dart';

/// Admin Restaurant Dashboard Screen
///
/// Displays overview statistics and complete list of all restaurants in the system.
/// Features:
/// - Statistics cards (total, active, inactive, with menus)
/// - Restaurant list with filtering and search
/// - Quick actions: View Menus, Edit, Activate/Deactivate
/// - Navigation to restaurant details and menu management
class AdminRestaurantDashboardScreen extends StatefulWidget {
  final String token;
  final User user;

  const AdminRestaurantDashboardScreen({
    super.key,
    required this.token,
    required this.user,
  });

  @override
  State<AdminRestaurantDashboardScreen> createState() =>
      _AdminRestaurantDashboardScreenState();
}

class _AdminRestaurantDashboardScreenState
    extends State<AdminRestaurantDashboardScreen> {
  final RestaurantService _restaurantService = RestaurantService();

  List<Restaurant> _allRestaurants = [];
  List<Restaurant> _filteredRestaurants = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'active', 'inactive'
  String _sortBy = 'name'; // 'name', 'created', 'rating'

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
      final restaurants = await _restaurantService.getRestaurants(widget.token);
      setState(() {
        _allRestaurants = restaurants;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<Restaurant> filtered = List.from(_allRestaurants);

    // Apply status filter
    if (_statusFilter == 'active') {
      filtered = filtered.where((r) => r.isActive).toList();
    } else if (_statusFilter == 'inactive') {
      filtered = filtered.where((r) => !r.isActive).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((r) {
        return r.name.toLowerCase().contains(query) ||
            (r.city != null && r.city!.toLowerCase().contains(query)) ||
            (r.state != null && r.state!.toLowerCase().contains(query));
      }).toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          return a.name.compareTo(b.name);
        case 'created':
          final aDate = a.createdAt ?? DateTime.now();
          final bDate = b.createdAt ?? DateTime.now();
          return bDate.compareTo(aDate); // Newest first
        case 'rating':
          return b.rating.compareTo(a.rating); // Highest first
        default:
          return 0;
      }
    });

    setState(() {
      _filteredRestaurants = filtered;
    });
  }

  Future<void> _toggleRestaurantStatus(Restaurant restaurant) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restaurant.isActive
                ? 'Deactivating ${restaurant.name}...'
                : 'Activating ${restaurant.name}...',
          ),
          duration: const Duration(seconds: 1),
        ),
      );

      // Create updated restaurant with toggled status
      final updatedRestaurant = restaurant.copyWith(
        isActive: !restaurant.isActive,
      );

      // Call update API (using UpdateRestaurantRequest)
      await _restaurantService.updateRestaurant(
        widget.token,
        restaurant.id!,
        UpdateRestaurantRequest(isActive: !restaurant.isActive),
      );

      // Reload restaurants to get fresh data
      await _loadRestaurants();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Restaurant ${updatedRestaurant.isActive ? 'activated' : 'deactivated'} successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update restaurant: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _navigateToRestaurantMenus(Restaurant restaurant) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminRestaurantMenusScreen(
          token: widget.token,
          user: widget.user,
          restaurant: restaurant,
        ),
      ),
    );
  }

  Future<void> _navigateToEditRestaurant(Restaurant restaurant) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantFormScreen(
          token: widget.token,
          restaurant: restaurant,
        ),
      ),
    );

    if (result == true) {
      _loadRestaurants();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Administration'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadRestaurants,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.all(DashboardConstants.screenPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatisticsCards(),
                          SizedBox(height: DashboardConstants.sectionSpacing),
                          _buildFiltersSection(),
                          SizedBox(height: DashboardConstants.sectionSpacing),
                          _buildRestaurantList(),
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
            'Error loading restaurants',
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
            onPressed: _loadRestaurants,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards() {
    final totalRestaurants = _allRestaurants.length;
    final activeRestaurants =
        _allRestaurants.where((r) => r.isActive).length;
    final inactiveRestaurants = totalRestaurants - activeRestaurants;

    // Note: We don't have menu count data yet - would need additional API call
    // For now, showing 0 as placeholder
    const totalMenus = 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Restaurants',
            totalRestaurants.toString(),
            Icons.restaurant,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Active',
            activeRestaurants.toString(),
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Inactive',
            inactiveRestaurants.toString(),
            Icons.cancel,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Total Menus',
            totalMenus.toString(),
            Icons.restaurant_menu,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      elevation: DashboardConstants.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Card(
      elevation: DashboardConstants.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters & Search',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or location...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                      DashboardConstants.cardBorderRadius),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilters();
                });
              },
            ),
            const SizedBox(height: 16),
            // Status filter chips
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _statusFilter == 'all',
                  onSelected: (selected) {
                    setState(() {
                      _statusFilter = 'all';
                      _applyFilters();
                    });
                  },
                ),
                FilterChip(
                  label: const Text('Active Only'),
                  selected: _statusFilter == 'active',
                  onSelected: (selected) {
                    setState(() {
                      _statusFilter = 'active';
                      _applyFilters();
                    });
                  },
                ),
                FilterChip(
                  label: const Text('Inactive Only'),
                  selected: _statusFilter == 'inactive',
                  onSelected: (selected) {
                    setState(() {
                      _statusFilter = 'inactive';
                      _applyFilters();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Sort dropdown
            Row(
              children: [
                const Text('Sort by: '),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _sortBy,
                  items: const [
                    DropdownMenuItem(value: 'name', child: Text('Name')),
                    DropdownMenuItem(
                        value: 'created', child: Text('Created Date')),
                    DropdownMenuItem(value: 'rating', child: Text('Rating')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _sortBy = value;
                        _applyFilters();
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantList() {
    if (_filteredRestaurants.isEmpty) {
      return Card(
        elevation: DashboardConstants.cardElevation,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.restaurant_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No restaurants found',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isNotEmpty || _statusFilter != 'all'
                      ? 'Try adjusting your filters'
                      : 'No restaurants in the system',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[500],
                      ),
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
          'Restaurants (${_filteredRestaurants.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredRestaurants.length,
          itemBuilder: (context, index) {
            return _buildRestaurantCard(_filteredRestaurants[index]);
          },
        ),
      ],
    );
  }

  Widget _buildRestaurantCard(Restaurant restaurant) {
    return Card(
      elevation: DashboardConstants.cardElevation,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Restaurant icon/placeholder
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.restaurant, size: 32),
                ),
                const SizedBox(width: 16),
                // Restaurant info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              restaurant.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          _buildStatusBadge(restaurant.isActive),
                        ],
                      ),
                      if (restaurant.shortAddress.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              restaurant.shortAddress,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                      if (restaurant.phone != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              restaurant.phone!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Stats row
                      Row(
                        children: [
                          _buildStatChip(
                            Icons.star,
                            restaurant.rating.toStringAsFixed(1),
                            Colors.amber,
                          ),
                          const SizedBox(width: 8),
                          _buildStatChip(
                            Icons.shopping_bag,
                            '${restaurant.totalOrders} orders',
                            Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          _buildStatChip(
                            Icons.restaurant_menu,
                            '0 menus', // Placeholder - need API enhancement
                            Colors.purple,
                          ),
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
                  onPressed: () => _navigateToRestaurantMenus(restaurant),
                  icon: const Icon(Icons.restaurant_menu, size: 18),
                  label: const Text('View Menus'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _navigateToEditRestaurant(restaurant),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _toggleRestaurantStatus(restaurant),
                  icon: Icon(
                    restaurant.isActive ? Icons.cancel : Icons.check_circle,
                    size: 18,
                  ),
                  label: Text(restaurant.isActive ? 'Deactivate' : 'Activate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        restaurant.isActive ? Colors.orange : Colors.green,
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

  Widget _buildStatusBadge(bool isActive) {
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

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
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
