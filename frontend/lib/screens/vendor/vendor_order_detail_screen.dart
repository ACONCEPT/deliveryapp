import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../config/dashboard_constants.dart';
import '../../widgets/order/order_status_badge.dart';

/// Screen displaying detailed information about a vendor order with status update functionality
class VendorOrderDetailScreen extends StatefulWidget {
  final String token;
  final int orderId;

  const VendorOrderDetailScreen({
    super.key,
    required this.token,
    required this.orderId,
  });

  @override
  State<VendorOrderDetailScreen> createState() => _VendorOrderDetailScreenState();
}

class _VendorOrderDetailScreenState extends State<VendorOrderDetailScreen> {
  final OrderService _orderService = OrderService();
  Order? _order;
  bool _isLoading = false;
  bool _isUpdatingStatus = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final order = await _orderService.getVendorOrderById(widget.orderId);
      setState(() {
        _order = order;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load order details: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOrderStatus(OrderStatus newStatus) async {
    if (_order == null) return;

    // Show confirmation dialog
    final confirmed = await _showStatusUpdateConfirmDialog(newStatus);
    if (!confirmed) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      await _orderService.updateVendorOrderStatus(
        widget.orderId,
        newStatus,
      );

      // Reload order to get updated data
      await _loadOrderDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to ${newStatus.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  Future<bool> _showStatusUpdateConfirmDialog(OrderStatus newStatus) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Order Status'),
        content: Text(
          'Update order status to ${newStatus.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    ) ?? false;
  }

  List<OrderStatus> _getAvailableNextStatuses() {
    if (_order == null) return [];

    switch (_order!.status) {
      case OrderStatus.pending:
        return [OrderStatus.confirmed, OrderStatus.cancelled];
      case OrderStatus.confirmed:
        return [OrderStatus.preparing, OrderStatus.cancelled];
      case OrderStatus.preparing:
        return [OrderStatus.ready, OrderStatus.cancelled];
      case OrderStatus.ready:
        return []; // Driver will update to picked_up
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_order == null ? 'Order Details' : 'Order #${_order!.id}'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading && _order != null)
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
            const SizedBox(height: 16),
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

    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            _buildStatusCard(),
            const SizedBox(height: 16),

            // Restaurant info
            _buildInfoCard(
              title: 'Restaurant',
              icon: Icons.restaurant,
              children: [
                _buildInfoRow('Name', _order!.restaurantName ?? 'N/A'),
              ],
            ),
            const SizedBox(height: 16),

            // Order info
            _buildInfoCard(
              title: 'Order Information',
              icon: Icons.receipt,
              children: [
                _buildInfoRow(
                  'Placed',
                  dateFormat.format(_order!.createdAt ?? DateTime.now()),
                ),
                if (_order!.specialInstructions != null)
                  _buildInfoRow('Instructions', _order!.specialInstructions!),
              ],
            ),
            const SizedBox(height: 16),

            // Items
            _buildItemsCard(),
            const SizedBox(height: 16),

            // Price breakdown
            _buildPriceCard(),
            const SizedBox(height: 16),

            // Status update actions
            if (_getAvailableNextStatuses().isNotEmpty)
              _buildStatusUpdateActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: DashboardConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DashboardConstants.cardBorderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Current Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            OrderStatusBadge(
              status: _order!.status,
              fontSize: 16,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Colors.deepOrange),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_bag, size: 20, color: Colors.deepOrange),
                const SizedBox(width: 8),
                const Text(
                  'Order Items',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._order!.items.map((item) => _buildItemRow(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(OrderItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item.quantity}x',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
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
                if (item.menuItemDescription != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.menuItemDescription!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                if (item.specialInstructions != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Note: ${item.specialInstructions}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.orange,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '\$${item.totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard() {
    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments, size: 20, color: Colors.deepOrange),
                const SizedBox(width: 8),
                const Text(
                  'Price Breakdown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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
              fontSize: isTotal ? 18 : 15,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusUpdateActions() {
    final availableStatuses = _getAvailableNextStatuses();

    return Card(
      elevation: DashboardConstants.cardElevation,
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DashboardConstants.cardBorderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.update, size: 20, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'Update Order Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Select the next status for this order:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ...availableStatuses.map((status) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton(
                onPressed: _isUpdatingStatus
                    ? null
                    : () => _updateOrderStatus(status),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getStatusColor(status),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isUpdatingStatus
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Mark as ${status.displayName}',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.orange;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
