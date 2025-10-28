import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../widgets/order/order_status_badge.dart';
import 'driver_order_detail_screen.dart';

/// Screen for drivers to view and manage their assigned orders
/// Displays all orders assigned to the driver with status tracking
class DriverOrdersScreen extends StatefulWidget {
  final String token;

  const DriverOrdersScreen({
    super.key,
    required this.token,
  });

  @override
  State<DriverOrdersScreen> createState() => _DriverOrdersScreenState();
}

class _DriverOrdersScreenState extends State<DriverOrdersScreen> {
  final OrderService _orderService = OrderService();
  List<Order> _driverOrders = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDriverOrders();
  }

  /// Load driver's assigned orders from API
  Future<void> _loadDriverOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orders = await _orderService.getDriverOrders();
      setState(() {
        _driverOrders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load your orders: $e';
        _isLoading = false;
      });
    }
  }

  /// Navigate to order details
  void _viewOrderDetails(Order order) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverOrderDetailScreen(
          token: widget.token,
          orderId: order.id!,
        ),
      ),
    );

    // Reload orders if detail screen indicates a change
    if (result == true) {
      _loadDriverOrders();
    }
  }

  /// Quick update order status
  Future<void> _quickUpdateStatus(Order order, OrderStatus newStatus) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update to ${newStatus.displayName}?'),
        content: Text(
          'Update order #${order.id} status to ${newStatus.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await _orderService.updateDriverOrderStatus(order.id!, newStatus);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order updated to ${newStatus.displayName}'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload orders
      _loadDriverOrders();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update order: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Get next valid status for an order
  OrderStatus? _getNextStatus(OrderStatus currentStatus) {
    // Valid transitions for drivers:
    // driver_assigned -> picked_up -> in_transit -> delivered
    switch (currentStatus) {
      case OrderStatus.ready:
        return OrderStatus.pickedUp; // Should not happen but handle it
      case OrderStatus.pickedUp:
        return OrderStatus.enRoute;
      case OrderStatus.enRoute:
        return OrderStatus.delivered;
      default:
        return null; // No valid next status
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Deliveries'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDriverOrders,
            tooltip: 'Refresh',
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
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDriverOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_driverOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No active deliveries',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick up an order from Available Orders',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDriverOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _driverOrders.length,
        itemBuilder: (context, index) {
          final order = _driverOrders[index];
          return _DriverOrderCard(
            order: order,
            onViewDetails: () => _viewOrderDetails(order),
            onQuickUpdate: _getNextStatus(order.status) != null
                ? () => _quickUpdateStatus(order, _getNextStatus(order.status)!)
                : null,
            nextStatus: _getNextStatus(order.status),
          );
        },
      ),
    );
  }
}

/// Card widget for displaying a driver order with quick actions
class _DriverOrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onViewDetails;
  final VoidCallback? onQuickUpdate;
  final OrderStatus? nextStatus;

  const _DriverOrderCard({
    required this.order,
    required this.onViewDetails,
    this.onQuickUpdate,
    this.nextStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onViewDetails,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Restaurant name and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.restaurantName ?? 'Unknown Restaurant',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 12),

              // Order info
              Row(
                children: [
                  const Icon(Icons.receipt_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Order #${order.id}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    '${order.totalItemCount} items',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Delivery time estimate
              if (order.estimatedDeliveryTime != null) ...[
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text(
                      'ETA: ${_formatTime(order.estimatedDeliveryTime!)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Total amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '\$${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onViewDetails,
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (onQuickUpdate != null && nextStatus != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: onQuickUpdate,
                        icon: _getStatusIcon(nextStatus!),
                        label: Text(_getStatusActionText(nextStatus!)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getStatusColor(nextStatus!),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  Icon _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pickedUp:
        return const Icon(Icons.check_circle_outline, size: 18);
      case OrderStatus.enRoute:
        return const Icon(Icons.local_shipping, size: 18);
      case OrderStatus.delivered:
        return const Icon(Icons.check_circle, size: 18);
      default:
        return const Icon(Icons.arrow_forward, size: 18);
    }
  }

  String _getStatusActionText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pickedUp:
        return 'Mark Picked Up';
      case OrderStatus.enRoute:
        return 'Start Delivery';
      case OrderStatus.delivered:
        return 'Mark Delivered';
      default:
        return 'Update Status';
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pickedUp:
        return Colors.orange;
      case OrderStatus.enRoute:
        return Colors.blue;
      case OrderStatus.delivered:
        return Colors.green;
      default:
        return Colors.purple;
    }
  }
}
