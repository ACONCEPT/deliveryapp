import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../config/dashboard_constants.dart';
import '../../config/user_type_config.dart';
import '../../widgets/order/order_status_badge.dart';
import '../../widgets/order/order_timeline.dart';

/// Admin Order Detail Screen
///
/// Displays complete order information including customer details, items,
/// pricing, delivery info, and order timeline. Provides admin actions:
/// - Assign/reassign driver
/// - Update order status (admin override)
/// - View status change history
class AdminOrderDetailScreen extends StatefulWidget {
  final String token;
  final int orderId;

  const AdminOrderDetailScreen({
    super.key,
    required this.token,
    required this.orderId,
  });

  @override
  State<AdminOrderDetailScreen> createState() =>
      _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  final OrderService _orderService = OrderService();

  Order? _order;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  /// Load full order details from API
  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final order =
          await _orderService.getAdminOrderById(widget.orderId, widget.token);

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

  /// Show driver assignment dialog
  void _showDriverAssignmentDialog() {
    // For now, just show a placeholder dialog
    // In a full implementation, this would fetch available drivers
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Driver'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Driver assignment feature coming soon.'),
            SizedBox(height: 16),
            Text(
              'This will allow admins to manually assign or reassign drivers to orders.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Show status update dialog
  void _showStatusUpdateDialog() {
    if (_order == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Order Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current status: ${_order!.status.displayName}'),
            const SizedBox(height: 16),
            const Text('Select new status:'),
            const SizedBox(height: 8),
            ...OrderStatus.values
                .where((s) =>
                    s != _order!.status &&
                    s != OrderStatus.cancelled) // Can't manually set cancelled
                .map((status) => RadioListTile<OrderStatus>(
                      title: Text(status.displayName),
                      value: status,
                      groupValue: null,
                      dense: true,
                      onChanged: (value) {
                        if (value != null) {
                          Navigator.pop(context);
                          _updateOrderStatus(value);
                        }
                      },
                    )),
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

  /// Update order status (admin override)
  Future<void> _updateOrderStatus(OrderStatus newStatus) async {
    try {
      await _orderService.updateAdminOrderStatus(
        widget.orderId,
        newStatus,
        widget.token,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to ${newStatus.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
        _loadOrderDetails(); // Reload to get updated data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.orderId}'),
        backgroundColor: UserTypeConfig.getColor('admin'),
        actions: [
          if (_order != null && _order!.isActive)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showStatusUpdateDialog,
              tooltip: 'Update Status',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : RefreshIndicator(
                  onRefresh: _loadOrderDetails,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(
                        DashboardConstants.cardPaddingSmall),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order Status and Basic Info
                        _buildOrderHeader(),
                        const SizedBox(
                            height: DashboardConstants.sectionSpacing),

                        // Order Timeline
                        _buildTimelineCard(),
                        const SizedBox(
                            height: DashboardConstants.sectionSpacing),

                        // Restaurant and Customer Info
                        _buildParticipantsCard(),
                        const SizedBox(
                            height: DashboardConstants.sectionSpacing),

                        // Order Items
                        _buildOrderItemsCard(),
                        const SizedBox(
                            height: DashboardConstants.sectionSpacing),

                        // Pricing Breakdown
                        _buildPricingCard(),
                        const SizedBox(
                            height: DashboardConstants.sectionSpacing),

                        // Admin Actions
                        if (_order!.isActive) _buildAdminActionsCard(),
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
            onPressed: _loadOrderDetails,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderHeader() {
    return Card(
      elevation: DashboardConstants.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${_order!.id}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                OrderStatusBadge(status: _order!.status),
              ],
            ),
            const SizedBox(height: 12),
            if (_order!.createdAt != null)
              _buildInfoRow(
                Icons.access_time,
                'Placed',
                _formatDateTime(_order!.createdAt!),
              ),
            if (_order!.estimatedDeliveryTime != null)
              _buildInfoRow(
                Icons.schedule,
                'Est. Delivery',
                _formatDateTime(_order!.estimatedDeliveryTime!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard() {
    return Card(
      elevation: DashboardConstants.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timeline, size: 20),
                SizedBox(width: 8),
                Text(
                  'Order Timeline',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OrderTimeline(
              currentStatus: _order!.status,
              createdAt: _order!.createdAt,
              estimatedDeliveryTime: _order!.estimatedDeliveryTime,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsCard() {
    return Card(
      elevation: DashboardConstants.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Participants',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.restaurant,
              'Restaurant',
              _order!.restaurantName ?? 'Unknown',
            ),
            const Divider(),
            _buildInfoRow(
              Icons.person,
              'Customer',
              'Customer #${_order!.customerId}',
            ),
            if (_order!.deliveryAddressId != null) ...[
              const Divider(),
              _buildInfoRow(
                Icons.location_on,
                'Delivery Address',
                'Address #${_order!.deliveryAddressId}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemsCard() {
    return Card(
      elevation: DashboardConstants.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Order Items',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_order!.items.length} items',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._order!.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${item.quantity}x',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            if (item.menuItemDescription != null &&
                                item.menuItemDescription!.isNotEmpty)
                              Text(
                                item.menuItemDescription!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '\$${item.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )),
            if (_order!.specialInstructions != null &&
                _order!.specialInstructions!.isNotEmpty) ...[
              const Divider(),
              _buildInfoRow(
                Icons.note,
                'Special Instructions',
                _order!.specialInstructions!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCard() {
    return Card(
      elevation: DashboardConstants.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pricing',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildPriceRow('Subtotal', _order!.subtotal),
            _buildPriceRow('Tax', _order!.taxAmount),
            _buildPriceRow('Delivery Fee', _order!.deliveryFee),
            const Divider(),
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

  Widget _buildAdminActionsCard() {
    return Card(
      elevation: DashboardConstants.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showDriverAssignmentDialog,
                    icon: const Icon(Icons.local_shipping),
                    label: const Text('Assign Driver'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showStatusUpdateDialog,
                    icon: const Icon(Icons.edit),
                    label: const Text('Update Status'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} '
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
