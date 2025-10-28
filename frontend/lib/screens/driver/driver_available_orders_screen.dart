import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../widgets/order/order_status_badge.dart';
import 'driver_order_detail_screen.dart';

/// Screen for drivers to view and assign available orders
/// Displays orders that are ready for pickup (status=ready, no driver assigned)
class DriverAvailableOrdersScreen extends StatefulWidget {
  final String token;

  const DriverAvailableOrdersScreen({
    super.key,
    required this.token,
  });

  @override
  State<DriverAvailableOrdersScreen> createState() =>
      _DriverAvailableOrdersScreenState();
}

class _DriverAvailableOrdersScreenState
    extends State<DriverAvailableOrdersScreen> {
  final OrderService _orderService = OrderService();
  List<Order> _availableOrders = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAvailableOrders();
  }

  /// Load available orders from API
  Future<void> _loadAvailableOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orders = await _orderService.getAvailableOrders();
      setState(() {
        _availableOrders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load available orders: $e';
        _isLoading = false;
      });
    }
  }

  /// Assign order to driver
  Future<void> _assignOrder(Order order) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Pickup'),
        content: Text(
          'Do you want to pick up this order from ${order.restaurantName ?? 'Unknown Restaurant'}?\n\n'
          'Order Total: \$${order.totalAmount.toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm Pickup'),
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
      await _orderService.assignOrderToDriver(order.id!);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order assigned successfully! Check "My Deliveries" to view.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Reload available orders
      _loadAvailableOrders();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Check if error is due to order already being assigned (409 Conflict)
      final errorMessage = e.toString();
      final isConflict = errorMessage.contains('Status: 409') ||
                         errorMessage.contains('409') ||
                         errorMessage.toLowerCase().contains('conflict') ||
                         errorMessage.toLowerCase().contains('already assigned');

      if (isConflict) {
        // Order was assigned by another driver - show specific message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ This order has already been assigned to another driver.\n'
              'Refreshing the list...',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );

        // Refresh the list to remove the now-assigned order
        _loadAvailableOrders();
      } else {
        // Generic error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign order: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Navigate to order details
  void _viewOrderDetails(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverOrderDetailScreen(
          token: widget.token,
          orderId: order.id!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Orders'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAvailableOrders,
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
              onPressed: _loadAvailableOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_availableOrders.isEmpty) {
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
              'No available orders',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new delivery opportunities',
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
      onRefresh: _loadAvailableOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _availableOrders.length,
        itemBuilder: (context, index) {
          final order = _availableOrders[index];
          return _AvailableOrderCard(
            order: order,
            onViewDetails: () => _viewOrderDetails(order),
            onAssign: () => _assignOrder(order),
          );
        },
      ),
    );
  }
}

/// Card widget for displaying an available order
class _AvailableOrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onViewDetails;
  final VoidCallback onAssign;

  const _AvailableOrderCard({
    required this.order,
    required this.onViewDetails,
    required this.onAssign,
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

              // Order time
              if (order.createdAt != null) ...[
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Ordered ${_formatDateTime(order.createdAt!)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
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
                      label: const Text('Details'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: onAssign,
                      icon: const Icon(Icons.local_shipping, size: 18),
                      label: const Text('Pick Up Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
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

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }
}
