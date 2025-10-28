import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../config/dashboard_constants.dart';
import '../../widgets/order/order_card.dart';
import '../../widgets/order/reorder_confirmation_dialog.dart';
import 'customer_order_detail_screen.dart';

/// Customer order history screen showing completed and cancelled orders
/// Includes filter/search functionality and reorder option
class CustomerOrderHistoryScreen extends StatefulWidget {
  final String token;

  const CustomerOrderHistoryScreen({
    super.key,
    required this.token,
  });

  @override
  State<CustomerOrderHistoryScreen> createState() =>
      _CustomerOrderHistoryScreenState();
}

class _CustomerOrderHistoryScreenState
    extends State<CustomerOrderHistoryScreen> {
  final OrderService _orderService = OrderService();
  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  OrderHistoryFilter _currentFilter = OrderHistoryFilter.all;

  @override
  void initState() {
    super.initState();
    _loadOrderHistory();
  }

  /// Load order history from API
  Future<void> _loadOrderHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allOrders = await _orderService.getCustomerOrders();

      // Filter for completed/cancelled orders only
      final historyOrders = allOrders
          .where((order) =>
              order.status == OrderStatus.delivered ||
              order.status == OrderStatus.cancelled)
          .toList();

      // Sort by created date (newest first)
      historyOrders.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      setState(() {
        _allOrders = historyOrders;
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

  /// Apply current filters and search to orders list
  void _applyFilters() {
    var filtered = _allOrders;

    // Apply status filter
    if (_currentFilter == OrderHistoryFilter.delivered) {
      filtered =
          filtered.where((o) => o.status == OrderStatus.delivered).toList();
    } else if (_currentFilter == OrderHistoryFilter.cancelled) {
      filtered =
          filtered.where((o) => o.status == OrderStatus.cancelled).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((order) {
        final query = _searchQuery.toLowerCase();
        final restaurantMatch =
            order.restaurantName?.toLowerCase().contains(query) ?? false;
        final orderIdMatch = order.id?.toString().contains(query) ?? false;
        final itemsMatch = order.items.any(
            (item) => item.menuItemName.toLowerCase().contains(query));

        return restaurantMatch || orderIdMatch || itemsMatch;
      }).toList();
    }

    setState(() {
      _filteredOrders = filtered;
    });
  }

  /// Handle search query change
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  /// Handle filter change
  void _onFilterChanged(OrderHistoryFilter? filter) {
    if (filter == null) return;
    setState(() {
      _currentFilter = filter;
      _applyFilters();
    });
  }

  /// Navigate to order detail screen
  void _navigateToOrderDetail(Order order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CustomerOrderDetailScreen(
          orderId: order.id!,
          token: widget.token,
        ),
      ),
    );
  }

  /// Handle reorder action
  Future<void> _handleReorder(Order order) async {
    final confirmed =
        await ReorderConfirmationDialog.show(context, order) ?? false;

    if (!confirmed) return;

    // TODO: Implement cart service to add items
    // For now, show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${order.items.length} items added to cart'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'View Cart',
            textColor: Colors.white,
            onPressed: () {
              // Navigate to cart screen
              Navigator.of(context).pushNamed('/customer/cart');
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrderHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter bar
          _buildSearchAndFilterBar(),

          // Orders list
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(DashboardConstants.cardPaddingSmall),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search field
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by restaurant, order #, or item...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: 12),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  'Filter: ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('All'),
                  selected: _currentFilter == OrderHistoryFilter.all,
                  onSelected: (_) => _onFilterChanged(OrderHistoryFilter.all),
                  selectedColor: Colors.deepOrange,
                  labelStyle: TextStyle(
                    color: _currentFilter == OrderHistoryFilter.all
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Delivered'),
                  selected: _currentFilter == OrderHistoryFilter.delivered,
                  onSelected: (_) =>
                      _onFilterChanged(OrderHistoryFilter.delivered),
                  selectedColor: Colors.deepOrange,
                  labelStyle: TextStyle(
                    color: _currentFilter == OrderHistoryFilter.delivered
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Cancelled'),
                  selected: _currentFilter == OrderHistoryFilter.cancelled,
                  onSelected: (_) =>
                      _onFilterChanged(OrderHistoryFilter.cancelled),
                  selectedColor: Colors.deepOrange,
                  labelStyle: TextStyle(
                    color: _currentFilter == OrderHistoryFilter.cancelled
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
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
      return _buildErrorState();
    }

    if (_filteredOrders.isEmpty) {
      return _buildEmptyState();
    }

    return _buildOrdersList();
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to Load Order History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadOrderHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    if (_searchQuery.isNotEmpty) {
      message = 'No orders found matching "$_searchQuery"';
      icon = Icons.search_off;
    } else if (_currentFilter == OrderHistoryFilter.delivered) {
      message = 'No delivered orders yet';
      icon = Icons.delivery_dining;
    } else if (_currentFilter == OrderHistoryFilter.cancelled) {
      message = 'No cancelled orders';
      icon = Icons.cancel_outlined;
    } else if (_allOrders.isEmpty) {
      message = 'No order history yet.\nPlace your first order to get started!';
      icon = Icons.history;
    } else {
      message = 'No orders found';
      icon = Icons.shopping_bag_outlined;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 100,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            if (_allOrders.isEmpty) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.restaurant),
                label: const Text('Browse Restaurants'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
            if (_searchQuery.isNotEmpty || _currentFilter != OrderHistoryFilter.all) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _currentFilter = OrderHistoryFilter.all;
                    _applyFilters();
                  });
                },
                child: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList() {
    return RefreshIndicator(
      onRefresh: _loadOrderHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(DashboardConstants.cardPaddingSmall),
        itemCount: _filteredOrders.length,
        itemBuilder: (context, index) {
          final order = _filteredOrders[index];
          return Padding(
            padding: const EdgeInsets.only(
                bottom: DashboardConstants.cardPaddingSmall),
            child: OrderCard(
              order: order,
              onTap: () => _navigateToOrderDetail(order),
              onReorder: order.status == OrderStatus.delivered
                  ? () => _handleReorder(order)
                  : null,
              showReorderButton: order.status == OrderStatus.delivered,
            ),
          );
        },
      ),
    );
  }
}

/// Enum for order history filter options
enum OrderHistoryFilter {
  all,
  delivered,
  cancelled,
}
