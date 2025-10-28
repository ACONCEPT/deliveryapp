import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../config/dashboard_constants.dart';
import '../../config/user_type_config.dart';
import '../../widgets/order/order_status_badge.dart';
import 'admin_order_detail_screen.dart';

/// Admin Orders List Screen
///
/// Displays all orders with filtering by status and search functionality.
/// Provides navigation to order detail view for management actions.
class AdminOrdersListScreen extends StatefulWidget {
  final String token;
  final OrderStatus? initialStatusFilter;

  const AdminOrdersListScreen({
    super.key,
    required this.token,
    this.initialStatusFilter,
  });

  @override
  State<AdminOrdersListScreen> createState() => _AdminOrdersListScreenState();
}

class _AdminOrdersListScreenState extends State<AdminOrdersListScreen> {
  final OrderService _orderService = OrderService();
  final TextEditingController _searchController = TextEditingController();

  List<Order> _orders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = true;
  String? _errorMessage;
  OrderStatus? _selectedStatusFilter;

  @override
  void initState() {
    super.initState();
    _selectedStatusFilter = widget.initialStatusFilter;
    _loadOrders();
    _searchController.addListener(_filterOrders);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Load all orders from API with optional status filter
  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orders = await _orderService.getAdminOrders(
        token: widget.token,
        statusFilter: _selectedStatusFilter,
        page: 1,
        perPage: 100, // Load more for filtering
      );

      setState(() {
        _orders = orders;
        _filteredOrders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load orders: $e';
        _isLoading = false;
      });
    }
  }

  /// Filter orders based on search query
  void _filterOrders() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredOrders = _orders;
      } else {
        _filteredOrders = _orders.where((order) {
          final orderId = order.id.toString();
          final restaurantName = order.restaurantName?.toLowerCase() ?? '';
          final status = order.status.displayName.toLowerCase();
          final total = order.totalAmount.toStringAsFixed(2);

          return orderId.contains(query) ||
              restaurantName.contains(query) ||
              status.contains(query) ||
              total.contains(query);
        }).toList();
      }
    });
  }

  /// Show status filter dialog
  void _showStatusFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption(null, 'All Orders'),
            ...OrderStatus.values.map(
              (status) => _buildFilterOption(status, status.displayName),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOption(OrderStatus? status, String label) {
    final isSelected = _selectedStatusFilter == status;
    return RadioListTile<OrderStatus?>(
      title: Text(label),
      value: status,
      groupValue: _selectedStatusFilter,
      onChanged: (value) {
        setState(() {
          _selectedStatusFilter = value;
        });
        Navigator.pop(context);
        _loadOrders();
      },
      selected: isSelected,
    );
  }

  /// Navigate to order detail screen
  void _navigateToOrderDetail(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminOrderDetailScreen(
          token: widget.token,
          orderId: order.id!,
        ),
      ),
    ).then((_) {
      // Reload orders when returning from detail screen
      _loadOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedStatusFilter == null
            ? 'All Orders'
            : '${_selectedStatusFilter!.displayName} Orders'),
        backgroundColor: UserTypeConfig.getColor('admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showStatusFilterDialog,
            tooltip: 'Filter by Status',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(DashboardConstants.cardPaddingSmall),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by order ID, restaurant, status...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                      DashboardConstants.cardBorderRadiusSmall),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),

          // Orders List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : _filteredOrders.isEmpty
                        ? _buildEmptyView()
                        : RefreshIndicator(
                            onRefresh: _loadOrders,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(
                                  DashboardConstants.cardPaddingSmall),
                              itemCount: _filteredOrders.length,
                              itemBuilder: (context, index) {
                                final order = _filteredOrders[index];
                                return _buildOrderCard(order);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadOrders,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? 'No orders match your search'
                : _selectedStatusFilter != null
                    ? 'No ${_selectedStatusFilter!.displayName.toLowerCase()} orders'
                    : 'No orders yet',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final createdDate = order.createdAt != null
        ? '${order.createdAt!.month}/${order.createdAt!.day} ${order.createdAt!.hour}:${order.createdAt!.minute.toString().padLeft(2, '0')}'
        : '';

    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _navigateToOrderDetail(order),
        borderRadius: BorderRadius.circular(
            DashboardConstants.cardBorderRadiusSmall),
        child: Padding(
          padding: const EdgeInsets.all(DashboardConstants.cardPaddingSmall),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Order ID and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Order #${order.id}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  OrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 8),

              // Restaurant Name
              Row(
                children: [
                  const Icon(Icons.restaurant, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.restaurantName ?? 'Unknown Restaurant',
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Order Details
              Row(
                children: [
                  const Icon(Icons.shopping_bag, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '${order.totalItemCount} items',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    createdDate,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Total Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.attach_money,
                          size: 20, color: Colors.green),
                      Text(
                        '\$${order.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.grey[400]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
