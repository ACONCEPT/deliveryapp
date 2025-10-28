import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../models/address.dart';
import '../../services/order_service.dart';
import '../../services/address_service.dart';
import '../../config/dashboard_constants.dart';
import '../../widgets/order/order_status_badge.dart';
import '../../widgets/order/order_timeline.dart';

/// Customer order detail screen showing full order information
/// Includes status timeline, items, totals, and action buttons
class CustomerOrderDetailScreen extends StatefulWidget {
  final int orderId;
  final String token;

  const CustomerOrderDetailScreen({
    super.key,
    required this.orderId,
    required this.token,
  });

  @override
  State<CustomerOrderDetailScreen> createState() =>
      _CustomerOrderDetailScreenState();
}

class _CustomerOrderDetailScreenState
    extends State<CustomerOrderDetailScreen> {
  final OrderService _orderService = OrderService();
  final AddressService _addressService = AddressService();

  Order? _order;
  Address? _deliveryAddress;
  bool _isLoading = false;
  bool _isCancelling = false;
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
      final order =
          await _orderService.getOrderById(widget.orderId);

      // Load delivery address if available
      Address? address;
      if (order.deliveryAddressId != null) {
        try {
          address = await _addressService.getAddress(
            widget.token,
            order.deliveryAddressId!,
          );
        } catch (e) {
          // Address loading failed, continue without it
          print('Failed to load delivery address: $e');
        }
      }

      setState(() {
        _order = order;
        _deliveryAddress = address;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      setState(() {
        // Capture full error details including stack trace
        _errorMessage = '''
ERROR: $e

STACK TRACE:
$stackTrace

ORDER ID: ${widget.orderId}

If this is a parsing error, please check the backend response format in the browser DevTools Network tab.
''';
        _isLoading = false;
      });
      // Also log to console for debugging
      print('❌ Error loading order ${widget.orderId}: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Cancel order with confirmation and mandatory reason
  Future<void> _cancelOrder() async {
    final reasonController = TextEditingController();

    // Show confirmation dialog with reason input
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => _CancelOrderDialog(reasonController: reasonController),
    );

    // Clean up controller
    reasonController.dispose();

    // If user cancelled or didn't provide reason, return
    if (result == null || result.isEmpty) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      final cancelledOrder = await _orderService.cancelOrder(
        widget.orderId,
        reason: result,
      );

      setState(() {
        _order = cancelledOrder;
        _isCancelling = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isCancelling = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Contact support (placeholder)
  void _contactSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.support_agent, color: Colors.blue),
            SizedBox(width: 8),
            Text('Contact Support'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Need help with your order?'),
            const SizedBox(height: 16),
            _buildContactOption(Icons.phone, 'Call Us', '1-800-DELIVERY'),
            const SizedBox(height: 12),
            _buildContactOption(Icons.email, 'Email', 'support@delivery.com'),
            const SizedBox(height: 12),
            _buildContactOption(Icons.chat, 'Live Chat', 'Available 24/7'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactOption(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.orderId}'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrderDetails,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.support_agent),
            onPressed: _contactSupport,
            tooltip: 'Contact Support',
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
      return _buildErrorState();
    }

    if (_order == null) {
      return const Center(
        child: Text('Order not found'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DashboardConstants.cardPaddingSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order status card
          _buildOrderStatusCard(),
          const SizedBox(height: 16),

          // Status timeline
          _buildTimelineCard(),
          const SizedBox(height: 16),

          // Restaurant details
          _buildRestaurantCard(),
          const SizedBox(height: 16),

          // Delivery address
          if (_deliveryAddress != null) ...[
            _buildDeliveryAddressCard(),
            const SizedBox(height: 16),
          ],

          // Order items
          _buildOrderItemsCard(),
          const SizedBox(height: 16),

          // Order summary
          _buildOrderSummaryCard(),
          const SizedBox(height: 16),

          // Action buttons
          _buildActionButtons(),
          const SizedBox(height: 24),
        ],
      ),
    );
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
              'Failed to Load Order',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Error details (selectable for copy-paste):',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            // UPDATED: Selectable error text with scrollable container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(maxHeight: 300),
              child: SingleChildScrollView(
                child: SelectableText(
                  _errorMessage ?? 'An unknown error occurred',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade900,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadOrderDetails,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusCard() {
    return Card(
      elevation: DashboardConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(DashboardConstants.cardBorderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                OrderStatusBadge(status: _order!.status, fontSize: 14),
              ],
            ),
            if (_order!.estimatedDeliveryTime != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Estimated Delivery: ${_formatEstimatedTime(_order!.estimatedDeliveryTime!)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
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

  Widget _buildTimelineCard() {
    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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

  Widget _buildRestaurantCard() {
    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.deepOrange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.restaurant,
                size: 32,
                color: Colors.deepOrange.shade700,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Restaurant',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _order!.restaurantName ?? 'Unknown Restaurant',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.phone),
              onPressed: () {
                // Call restaurant
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Restaurant contact feature coming soon'),
                  ),
                );
              },
              tooltip: 'Call Restaurant',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryAddressCard() {
    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.location_on, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Text(
                  'Delivery Address',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _deliveryAddress!.formattedAddress,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemsCard() {
    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._order!.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${item.quantity}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange.shade700,
                            ),
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
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (item.customizations != null &&
                                item.customizations!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _formatCustomizations(item.customizations!),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            if (item.specialInstructions != null &&
                                item.specialInstructions!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  item.specialInstructions!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
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
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildPriceRow('Subtotal', _order!.subtotal),
            const SizedBox(height: 8),
            _buildPriceRow('Tax', _order!.taxAmount),
            const SizedBox(height: 8),
            _buildPriceRow('Delivery Fee', _order!.deliveryFee),
            const SizedBox(height: 12),
            const Divider(thickness: 2),
            const SizedBox(height: 12),
            _buildPriceRow('Total', _order!.totalAmount, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isTotal = false}) {
    return Row(
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
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: isTotal ? Colors.deepOrange : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Track Delivery button (if order is in transit)
        if (_order!.status == OrderStatus.enRoute ||
            _order!.status == OrderStatus.pickedUp)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Live tracking feature coming soon'),
                  ),
                );
              },
              icon: const Icon(Icons.location_on),
              label: const Text('Track Delivery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

        // Cancel Order button (if order can be cancelled)
        if (_order!.canBeCancelled) ...[
          if (_order!.status == OrderStatus.enRoute ||
              _order!.status == OrderStatus.pickedUp)
            const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isCancelling ? null : _cancelOrder,
              icon: _isCancelling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cancel),
              label: Text(_isCancelling ? 'Cancelling...' : 'Cancel Order'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatEstimatedTime(DateTime estimatedTime) {
    final now = DateTime.now();
    final diff = estimatedTime.difference(now);

    if (diff.isNegative) {
      return 'Any moment now';
    }

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min';
    } else {
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      return '$hours hr${hours > 1 ? 's' : ''} ${minutes > 0 ? '$minutes min' : ''}';
    }
  }

  String _formatCustomizations(Map<String, dynamic> customizations) {
    if (customizations.isEmpty) return '';
    return customizations.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(', ');
  }
}

/// Dialog for canceling order with mandatory reason input
class _CancelOrderDialog extends StatefulWidget {
  final TextEditingController reasonController;

  const _CancelOrderDialog({
    required this.reasonController,
  });

  @override
  State<_CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<_CancelOrderDialog> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    // Listen to text changes to enable/disable button
    widget.reasonController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.reasonController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.reasonController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel Order?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Are you sure you want to cancel this order? This action cannot be undone.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Please provide a reason for cancellation:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: widget.reasonController,
            decoration: InputDecoration(
              hintText: 'e.g., Changed my mind, ordered by mistake...',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              helperText: widget.reasonController.text.isEmpty
                  ? 'Required (max 500 characters)'
                  : '${widget.reasonController.text.length}/500 characters',
              helperStyle: TextStyle(
                color: widget.reasonController.text.length > 500
                    ? Colors.red
                    : Colors.grey.shade600,
              ),
            ),
            maxLength: 500,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('No, Keep Order'),
        ),
        ElevatedButton(
          onPressed: _hasText
              ? () {
                  final reason = widget.reasonController.text.trim();
                  Navigator.of(context).pop(reason);
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade500,
          ),
          child: const Text('Yes, Cancel'),
        ),
      ],
    );
  }
}
