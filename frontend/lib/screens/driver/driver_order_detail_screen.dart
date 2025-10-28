import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../widgets/order/order_status_badge.dart';

/// Detailed order view for drivers
/// Shows complete order information with status update controls
class DriverOrderDetailScreen extends StatefulWidget {
  final String token;
  final int orderId;

  const DriverOrderDetailScreen({
    super.key,
    required this.token,
    required this.orderId,
  });

  @override
  State<DriverOrderDetailScreen> createState() =>
      _DriverOrderDetailScreenState();
}

class _DriverOrderDetailScreenState extends State<DriverOrderDetailScreen> {
  final OrderService _orderService = OrderService();
  Order? _order;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  /// Load order details from API
  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final order = await _orderService.getDriverOrderById(widget.orderId);
      setState(() {
        _order = order;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load order details: $e';
        _isLoading = false;
      });
    }
  }

  /// Update order status
  Future<void> _updateStatus(OrderStatus newStatus) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update to ${newStatus.displayName}?'),
        content: Text(
          'Update this order status to ${newStatus.displayName}?',
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
      await _orderService.updateDriverOrderStatus(widget.orderId, newStatus);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order updated to ${newStatus.displayName}'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload order details
      _loadOrderDetails();
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

  /// Get available status transitions for current order
  List<OrderStatus> _getAvailableTransitions() {
    if (_order == null) return [];

    switch (_order!.status) {
      case OrderStatus.ready:
        return [OrderStatus.pickedUp];
      case OrderStatus.pickedUp:
        return [OrderStatus.enRoute];
      case OrderStatus.enRoute:
        return [OrderStatus.delivered];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.orderId}'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrderDetails,
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
              onPressed: _loadOrderDetails,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_order == null) {
      return const Center(
        child: Text('Order not found'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusSection(),
          const SizedBox(height: 24),
          _buildRestaurantSection(),
          const SizedBox(height: 24),
          _buildItemsSection(),
          const SizedBox(height: 24),
          _buildPricingSection(),
          const SizedBox(height: 24),
          _buildActionsSection(),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OrderStatusBadge(status: _order!.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _order!.status.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (_order!.estimatedDeliveryTime != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 18, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'ETA: ${_formatDateTime(_order!.estimatedDeliveryTime!)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pickup Location',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.restaurant, color: Colors.deepOrange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _order!.restaurantName ?? 'Unknown Restaurant',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Items (${_order!.items.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._order!.items.map((item) => _buildOrderItem(item)),
            if (_order!.specialInstructions != null &&
                _order!.specialInstructions!.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'Special Instructions:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _order!.specialInstructions!,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${item.quantity}x',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.menuItemName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.menuItemDescription != null &&
                    item.menuItemDescription!.isNotEmpty)
                  Text(
                    item.menuItemDescription!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                if (item.specialInstructions != null &&
                    item.specialInstructions!.isNotEmpty)
                  Text(
                    'Note: ${item.specialInstructions}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Colors.orange,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '\$${item.totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Price Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildPriceRow('Subtotal', _order!.subtotal),
            _buildPriceRow('Tax', _order!.taxAmount),
            _buildPriceRow('Delivery Fee', _order!.deliveryFee),
            const Divider(height: 24),
            _buildPriceRow(
              'Total',
              _order!.totalAmount,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 15,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 20 : 15,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    final availableTransitions = _getAvailableTransitions();

    if (availableTransitions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                _order!.status == OrderStatus.delivered
                    ? Icons.check_circle
                    : Icons.info_outline,
                size: 48,
                color: _order!.status == OrderStatus.delivered
                    ? Colors.green
                    : Colors.grey,
              ),
              const SizedBox(height: 12),
              Text(
                _order!.status == OrderStatus.delivered
                    ? 'Order Completed'
                    : 'No actions available',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Update Order Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...availableTransitions.map((status) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus(status),
                    icon: _getStatusIcon(status),
                    label: Text(_getStatusActionText(status)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getStatusColor(status),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Icon _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pickedUp:
        return const Icon(Icons.check_circle_outline);
      case OrderStatus.enRoute:
        return const Icon(Icons.local_shipping);
      case OrderStatus.delivered:
        return const Icon(Icons.check_circle);
      default:
        return const Icon(Icons.arrow_forward);
    }
  }

  String _getStatusActionText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pickedUp:
        return 'Mark as Picked Up';
      case OrderStatus.enRoute:
        return 'Start Delivery (En Route)';
      case OrderStatus.delivered:
        return 'Mark as Delivered';
      default:
        return 'Update to ${status.displayName}';
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

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.month}/${dateTime.day} at $hour:$minute $period';
  }
}
