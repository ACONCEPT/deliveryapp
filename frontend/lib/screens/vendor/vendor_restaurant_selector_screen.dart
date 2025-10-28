import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../../models/restaurant.dart';
import '../../services/restaurant_service.dart';
import '../../services/menu_service.dart';
import '../../config/dashboard_constants.dart';
import '../vendor_menu_list_screen.dart';
import '../vendor_restaurant_management_screen.dart';

/// Restaurant Selector Screen for Menu Management
///
/// This screen displays a list of vendor's restaurants and allows
/// them to select which restaurant's menus they want to manage.
/// This provides a restaurant-first approach to menu management.
class VendorRestaurantSelectorScreen extends StatefulWidget {
  final String token;

  const VendorRestaurantSelectorScreen({
    super.key,
    required this.token,
  });

  @override
  State<VendorRestaurantSelectorScreen> createState() =>
      _VendorRestaurantSelectorScreenState();
}

class _VendorRestaurantSelectorScreenState
    extends State<VendorRestaurantSelectorScreen> {
  final RestaurantService _restaurantService = RestaurantService();
  final MenuService _menuService = MenuService();

  List<Restaurant> _restaurants = [];
  Map<int, int> _menuCounts = {}; // restaurantId -> menu count
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRestaurantsAndMenuCounts();
  }

  Future<void> _loadRestaurantsAndMenuCounts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      developer.log('Loading vendor restaurants', name: 'VendorRestaurantSelectorScreen');

      // Load restaurants
      final restaurants = await _restaurantService.getRestaurants(widget.token);
      developer.log('Loaded ${restaurants.length} restaurants', name: 'VendorRestaurantSelectorScreen');

      // Load all menus to calculate counts per restaurant
      final allMenus = await _menuService.getVendorMenus(widget.token);
      developer.log('Loaded ${allMenus.length} total menus', name: 'VendorRestaurantSelectorScreen');

      // Calculate menu counts per restaurant
      final Map<int, int> menuCounts = {};
      for (final menu in allMenus) {
        if (menu.assignedRestaurants != null) {
          for (final assignment in menu.assignedRestaurants!) {
            menuCounts[assignment.restaurantId] = (menuCounts[assignment.restaurantId] ?? 0) + 1;
          }
        }
      }

      setState(() {
        _restaurants = restaurants;
        _menuCounts = menuCounts;
        _isLoading = false;
      });

      developer.log('Menu counts calculated: $menuCounts', name: 'VendorRestaurantSelectorScreen');
    } catch (e) {
      developer.log('Error loading restaurants: $e', name: 'VendorRestaurantSelectorScreen', error: e);

      setState(() {
        _errorMessage = 'Failed to load restaurants: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _navigateToMenuList(Restaurant restaurant) {
    developer.log('Navigating to menu list for restaurant: ${restaurant.name}', name: 'VendorRestaurantSelectorScreen');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VendorMenuListScreen(
          token: widget.token,
          restaurant: restaurant,
        ),
      ),
    ).then((_) {
      // Reload menu counts when returning from menu list
      _loadRestaurantsAndMenuCounts();
    });
  }

  void _navigateToCreateRestaurant() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VendorRestaurantManagementScreen(
          token: widget.token,
        ),
      ),
    ).then((_) {
      // Reload restaurants when returning
      _loadRestaurantsAndMenuCounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Restaurant'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_restaurants.isEmpty) {
      return _buildEmptyState();
    }

    return _buildRestaurantGrid();
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.screenPadding),
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
            ElevatedButton.icon(
              onPressed: _loadRestaurantsAndMenuCounts,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
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
        padding: const EdgeInsets.all(DashboardConstants.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Restaurants Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You need to create a restaurant first\nbefore managing menus',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToCreateRestaurant,
              icon: const Icon(Icons.add_business),
              label: const Text('Create Restaurant'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantGrid() {
    return RefreshIndicator(
      onRefresh: _loadRestaurantsAndMenuCounts,
      child: CustomScrollView(
        slivers: [
          // Info header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(DashboardConstants.cardPadding / 2),
              child: Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(DashboardConstants.cardPadding / 2),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Select a restaurant to manage its menus',
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
            ),
          ),

          // Restaurant grid
          SliverPadding(
            padding: const EdgeInsets.all(DashboardConstants.cardPadding / 2),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: DashboardConstants.gridSpacing,
                mainAxisSpacing: DashboardConstants.gridSpacing,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final restaurant = _restaurants[index];
                  final menuCount = _menuCounts[restaurant.id] ?? 0;
                  return _RestaurantCard(
                    restaurant: restaurant,
                    menuCount: menuCount,
                    onTap: () => _navigateToMenuList(restaurant),
                  );
                },
                childCount: _restaurants.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final int menuCount;
  final VoidCallback onTap;

  const _RestaurantCard({
    required this.restaurant,
    required this.menuCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Restaurant icon/image header
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.deepOrange[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(DashboardConstants.cardBorderRadiusSmall),
                  topRight: Radius.circular(DashboardConstants.cardBorderRadiusSmall),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.restaurant,
                  size: 48,
                  color: Colors.deepOrange[700],
                ),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(DashboardConstants.cardPaddingSmall),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Restaurant name
                    Text(
                      restaurant.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Address
                    if (restaurant.shortAddress.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              restaurant.shortAddress,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    const Spacer(),

                    // Menu count badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: menuCount > 0 ? Colors.green[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: 14,
                            color: menuCount > 0 ? Colors.green[700] : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$menuCount ${menuCount == 1 ? 'menu' : 'menus'}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: menuCount > 0 ? Colors.green[700] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Chevron indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          Icons.arrow_forward,
                          size: 20,
                          color: Colors.deepOrange[700],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
