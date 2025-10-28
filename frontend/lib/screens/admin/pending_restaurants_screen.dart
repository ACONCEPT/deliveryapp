import 'package:flutter/material.dart';
import '../../models/approval.dart';
import '../../services/approval_service.dart';
import '../../config/dashboard_constants.dart';
import 'restaurant_approval_detail_screen.dart';

/// Pending Restaurants List Screen
///
/// Displays all restaurants awaiting admin approval with search/filter capabilities.
/// Each restaurant card shows key information and tapping navigates to detail view.
class PendingRestaurantsScreen extends StatefulWidget {
  final String token;

  const PendingRestaurantsScreen({
    super.key,
    required this.token,
  });

  @override
  State<PendingRestaurantsScreen> createState() =>
      _PendingRestaurantsScreenState();
}

class _PendingRestaurantsScreenState extends State<PendingRestaurantsScreen> {
  final ApprovalService _approvalService = ApprovalService();
  List<RestaurantWithApproval> _restaurants = [];
  List<RestaurantWithApproval> _filteredRestaurants = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPendingRestaurants();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Loads pending restaurants from API
  Future<void> _loadPendingRestaurants() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final restaurants =
          await _approvalService.getPendingRestaurants(widget.token);
      setState(() {
        _restaurants = restaurants;
        _filteredRestaurants = restaurants;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load pending restaurants: $e';
        _isLoading = false;
      });
    }
  }

  /// Filters restaurants based on search query
  void _filterRestaurants(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredRestaurants = _restaurants;
      } else {
        _filteredRestaurants = _restaurants.where((restaurant) {
          final name = restaurant.name.toLowerCase();
          final cuisine = restaurant.cuisine?.toLowerCase() ?? '';
          final city = restaurant.city?.toLowerCase() ?? '';
          final state = restaurant.state?.toLowerCase() ?? '';
          final searchLower = query.toLowerCase();

          return name.contains(searchLower) ||
              cuisine.contains(searchLower) ||
              city.contains(searchLower) ||
              state.contains(searchLower);
        }).toList();
      }
    });
  }

  /// Navigates to restaurant detail screen
  void _navigateToRestaurantDetail(RestaurantWithApproval restaurant) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantApprovalDetailScreen(
          token: widget.token,
          restaurant: restaurant,
        ),
      ),
    );

    // Reload list if restaurant was approved/rejected
    if (result == true) {
      _loadPendingRestaurants();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Restaurants'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),

          // Restaurant count
          if (!_isLoading && _errorMessage == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${_filteredRestaurants.length} restaurant${_filteredRestaurants.length == 1 ? '' : 's'} pending approval',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : _buildRestaurantsList(),
          ),
        ],
      ),
    );
  }

  /// Builds search bar for filtering restaurants
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _filterRestaurants,
        decoration: InputDecoration(
          hintText: 'Search by name, cuisine, or location...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterRestaurants('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
                DashboardConstants.cardBorderRadiusSmall),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  /// Builds error view with retry button
  Widget _buildErrorView() {
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
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPendingRestaurants,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds restaurants list or empty state
  Widget _buildRestaurantsList() {
    if (_filteredRestaurants.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadPendingRestaurants,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredRestaurants.length,
        itemBuilder: (context, index) {
          return _buildRestaurantCard(_filteredRestaurants[index]);
        },
      ),
    );
  }

  /// Builds empty state view
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isNotEmpty
                  ? Icons.search_off
                  : Icons.check_circle_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No restaurants found matching "${_searchController.text}"'
                  : 'No restaurants pending approval',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            if (_searchController.text.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'All restaurants have been processed!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds individual restaurant card
  Widget _buildRestaurantCard(RestaurantWithApproval restaurant) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: DashboardConstants.cardElevationSmall,
      child: InkWell(
        onTap: () => _navigateToRestaurantDetail(restaurant),
        borderRadius:
            BorderRadius.circular(DashboardConstants.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with name and pending badge
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'PENDING',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Cuisine type
              if (restaurant.cuisine != null)
                Row(
                  children: [
                    const Icon(Icons.restaurant_menu,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      restaurant.cuisine!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),

              // Location
              if (restaurant.city != null || restaurant.state != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        restaurant.location,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Phone
              if (restaurant.phone != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      restaurant.phone!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],

              // Rating and created date
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    restaurant.rating.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    'Created ${_formatDate(restaurant.createdAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),

              // Action hint
              const SizedBox(height: 8),
              const Divider(),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    'Tap to review and approve/reject',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formats DateTime for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes} min ago';
      }
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
