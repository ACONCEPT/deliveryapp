import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../config/dashboard_constants.dart';
import '../../config/user_type_config.dart';
import 'admin_orders_list_screen.dart';

/// Admin Order Dashboard Screen
///
/// Main entry point for admin order management. Displays overview statistics
/// including total orders, orders by status, and provides navigation to
/// detailed order management views.
class AdminOrderDashboardScreen extends StatefulWidget {
  final String token;

  const AdminOrderDashboardScreen({
    super.key,
    required this.token,
  });

  @override
  State<AdminOrderDashboardScreen> createState() =>
      _AdminOrderDashboardScreenState();
}

class _AdminOrderDashboardScreenState
    extends State<AdminOrderDashboardScreen> {
  final OrderService _orderService = OrderService();
  Map<String, dynamic>? _stats;
  List<Order> _recentOrders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  /// Loads order statistics and recent orders from API
  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load stats and recent orders in parallel
      final results = await Future.wait([
        _orderService.getAdminOrderStats(widget.token),
        _orderService.getAdminOrders(
          token: widget.token,
          page: 1,
          perPage: 5,
        ),
      ]);

      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _recentOrders = results[1] as List<Order>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load order dashboard: $e';
        _isLoading = false;
      });
    }
  }

  /// Navigate to orders list filtered by status
  void _navigateToOrdersList({OrderStatus? statusFilter}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminOrdersListScreen(
          token: widget.token,
          initialStatusFilter: statusFilter,
        ),
      ),
    ).then((_) {
      // Reload dashboard data when returning
      _loadDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Dashboard'),
        backgroundColor: UserTypeConfig.getColor('admin'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(
                        DashboardConstants.screenPadding),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Overview Statistics Cards
                        _buildOverviewSection(),
                        const SizedBox(
                            height: DashboardConstants.sectionSpacing),

                        // Orders by Status
                        _buildStatusSection(),
                        const SizedBox(
                            height: DashboardConstants.sectionSpacing),

                        // Recent Orders
                        _buildRecentOrdersSection(),
                      ],
                    ),
                  ),
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
            onPressed: _loadDashboardData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection() {
    final totalOrders = _stats?['total_orders'] ?? 0;
    final activeOrders = _stats?['active_orders'] ?? 0;
    final totalRevenue = _stats?['total_revenue'] ?? 0.0;
    final averageOrderValue = _stats?['average_order_value'] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Orders',
                totalOrders.toString(),
                Icons.receipt_long,
                Colors.blue,
                onTap: () => _navigateToOrdersList(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Active Orders',
                activeOrders.toString(),
                Icons.pending_actions,
                Colors.orange,
                onTap: () => _navigateToOrdersList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Revenue',
                '\$${totalRevenue.toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Avg Order Value',
                '\$${averageOrderValue.toStringAsFixed(2)}',
                Icons.trending_up,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: DashboardConstants.cardElevation,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
            DashboardConstants.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(DashboardConstants.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 32),
                  if (onTap != null) const Spacer(),
                  if (onTap != null)
                    Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.grey[600]),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    final pendingCount = _stats?['pending_orders'] ?? 0;
    final confirmedCount = _stats?['confirmed_orders'] ?? 0;
    final preparingCount = _stats?['preparing_orders'] ?? 0;
    final readyCount = _stats?['ready_orders'] ?? 0;
    final assignedCount = _stats?['driver_assigned_orders'] ?? 0;
    final enRouteCount = _stats?['in_transit_orders'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Orders by Status',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: DashboardConstants.cardElevation,
          child: Column(
            children: [
              _buildStatusTile(
                'Pending',
                pendingCount,
                Icons.schedule,
                Colors.orange,
                OrderStatus.pending,
              ),
              const Divider(height: 1),
              _buildStatusTile(
                'Confirmed',
                confirmedCount,
                Icons.check_circle_outline,
                Colors.blue,
                OrderStatus.confirmed,
              ),
              const Divider(height: 1),
              _buildStatusTile(
                'Preparing',
                preparingCount,
                Icons.restaurant,
                Colors.purple,
                OrderStatus.preparing,
              ),
              const Divider(height: 1),
              _buildStatusTile(
                'Ready',
                readyCount,
                Icons.done_all,
                Colors.green,
                OrderStatus.ready,
              ),
              const Divider(height: 1),
              _buildStatusTile(
                'Driver Assigned',
                assignedCount,
                Icons.local_shipping,
                Colors.indigo,
                OrderStatus.pickedUp,
              ),
              const Divider(height: 1),
              _buildStatusTile(
                'En Route',
                enRouteCount,
                Icons.delivery_dining,
                Colors.teal,
                OrderStatus.enRoute,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTile(
    String title,
    int count,
    IconData icon,
    Color color,
    OrderStatus status,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
        ],
      ),
      onTap: () => _navigateToOrdersList(statusFilter: status),
    );
  }

  Widget _buildRecentOrdersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Orders',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => _navigateToOrdersList(),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _recentOrders.isEmpty
            ? Card(
                elevation: DashboardConstants.cardElevation,
                child: Padding(
                  padding: const EdgeInsets.all(DashboardConstants.cardPadding),
                  child: const Center(
                    child: Text('No recent orders'),
                  ),
                ),
              )
            : Column(
                children: _recentOrders
                    .map((order) => _buildRecentOrderCard(order))
                    .toList(),
              ),
      ],
    );
  }

  Widget _buildRecentOrderCard(Order order) {
    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text('#${order.id}'),
        ),
        title: Text(order.restaurantName ?? 'Unknown Restaurant'),
        subtitle: Text(
          'Items: ${order.totalItemCount} • \$${order.totalAmount.toStringAsFixed(2)}',
        ),
        trailing: _buildStatusBadge(order.status),
        onTap: () {
          // Navigate to order detail
          _navigateToOrdersList();
        },
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color color;
    switch (status) {
      case OrderStatus.pending:
        color = Colors.orange;
        break;
      case OrderStatus.confirmed:
        color = Colors.blue;
        break;
      case OrderStatus.preparing:
        color = Colors.purple;
        break;
      case OrderStatus.ready:
        color = Colors.green;
        break;
      case OrderStatus.pickedUp:
        color = Colors.indigo;
        break;
      case OrderStatus.enRoute:
        color = Colors.teal;
        break;
      case OrderStatus.delivered:
        color = Colors.green[700]!;
        break;
      case OrderStatus.cancelled:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
