import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../config/dashboard_constants.dart';
import '../../widgets/order/order_status_badge.dart';
import 'vendor_order_detail_screen.dart';

/// Screen displaying all orders for vendor's restaurants with status filtering
class VendorOrdersListScreen extends StatefulWidget {
  final String token;

  const VendorOrdersListScreen({
    super.key,
    required this.token,
  });

  @override
  State<VendorOrdersListScreen> createState() => _VendorOrdersListScreenState();
}

class _VendorOrdersListScreenState extends State<VendorOrdersListScreen> {
  final OrderService _orderService = OrderService();
  List<Order> _filteredOrders = [];
  bool _isLoading = false;
  String? _errorMessage;
  OrderStatus? _selectedStatusFilter;

  // Status filter options relevant to vendors
  final List<OrderStatus?> _statusFilters = [
    null, // All orders
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.pickedUp,
    OrderStatus.enRoute,
    OrderStatus.delivered,
    OrderStatus.cancelled,
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orders = await _orderService.getVendorOrders(
        statusFilter: _selectedStatusFilter,
      );

      // Sort orders by created_at descending (most recent first)
      orders.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.now();
        final bTime = b.createdAt ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

      setState(() {
        _filteredOrders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load orders: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _applyStatusFilter(OrderStatus? status) {
    setState(() {
      _selectedStatusFilter = status;
    });
    _loadOrders();
  }

  void _navigateToOrderDetail(Order order) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VendorOrderDetailScreen(
          token: widget.token,
          orderId: order.id!,
        ),
      ),
    );

    // Reload orders if status was updated
    if (result == true) {
      _loadOrders();
    }
  }

  String _getFilterLabel(OrderStatus? status) {
    if (status == null) return 'All Orders';
    return status.displayName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Orders'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<OrderStatus?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by Status',
            onSelected: _applyStatusFilter,
            itemBuilder: (context) {
              return _statusFilters.map((status) {
                return PopupMenuItem<OrderStatus?>(
                  value: status,
                  child: Row(
                    children: [
                      if (_selectedStatusFilter == status)
                        const Icon(Icons.check, size: 18),
                      if (_selectedStatusFilter == status)
                        const SizedBox(width: 8),
                      Text(_getFilterLabel(status)),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
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
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedStatusFilter == null
                  ? 'No orders yet'
                  : 'No ${_getFilterLabel(_selectedStatusFilter)} orders',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Orders from your restaurants will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: Column(
        children: [
          // Filter status indicator
          if (_selectedStatusFilter != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.deepOrange.shade50,
              child: Row(
                children: [
                  const Icon(Icons.filter_list, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Showing: ${_getFilterLabel(_selectedStatusFilter)}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _applyStatusFilter(null),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredOrders.length,
              itemBuilder: (context, index) {
                final order = _filteredOrders[index];
                return _buildOrderCard(order);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final orderDate = order.createdAt ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: DashboardConstants.cardElevationSmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
      ),
      child: InkWell(
        onTap: () => _navigateToOrderDetail(order),
        borderRadius: BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with order ID and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  OrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 12),

              // Restaurant name
              if (order.restaurantName != null)
                Row(
                  children: [
                    const Icon(Icons.restaurant, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.restaurantName!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),

              // Order date
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(orderDate),
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Items count and total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_bag, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        '${order.totalItemCount} item${order.totalItemCount != 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
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

              // Action indicator for actionable statuses
              if (order.status == OrderStatus.pending ||
                  order.status == OrderStatus.confirmed ||
                  order.status == OrderStatus.preparing)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_active,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Action Required',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
