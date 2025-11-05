import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../models/distance.dart';
import '../../config/dashboard_constants.dart';
import '../../widgets/order/order_status_badge.dart';
import '../../services/distance_service.dart';
import 'customer_order_detail_screen.dart';

/// Order confirmation screen displayed after successful order placement
/// Shows order summary, confirmation number, and next action options
class OrderConfirmationScreen extends StatefulWidget {
  final Order order;
  final String token;

  const OrderConfirmationScreen({
    super.key,
    required this.order,
    required this.token,
  });

  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  final DistanceService _distanceService = DistanceService();
  DistanceEstimate? _distanceEstimate;
  bool _isLoadingDistance = false;
  String? _distanceError;

  @override
  void initState() {
    super.initState();
    _loadDistanceEstimate();
  }

  /// Load distance estimate if order has delivery address and restaurant
  Future<void> _loadDistanceEstimate() async {
    if (widget.order.deliveryAddressId == null) {
      print('⚠️ No delivery address for order, skipping distance calculation');
      return;
    }

    setState(() {
      _isLoadingDistance = true;
      _distanceError = null;
    });

    try {
      print(
          '📍 Fetching distance estimate: address=${widget.order.deliveryAddressId}, restaurant=${widget.order.restaurantId}');

      final estimate = await _distanceService.calculateDistanceSafe(
        token: widget.token,
        addressId: widget.order.deliveryAddressId!,
        restaurantId: widget.order.restaurantId,
      );

      if (mounted) {
        setState(() {
          _distanceEstimate = estimate;
          _isLoadingDistance = false;
        });

        if (estimate != null) {
          print(
              '✅ Distance estimate loaded: ${estimate.distance.miles} miles, ${estimate.duration.text}');
        } else {
          print('⚠️ Distance estimate unavailable (coordinates missing?)');
        }
      }
    } catch (e) {
      print('❌ Failed to load distance estimate: $e');
      if (mounted) {
        setState(() {
          _distanceError = e.toString();
          _isLoadingDistance = false;
        });
      }
    }
  }

  /// Get estimated delivery time text based on distance estimate or order field
  String _getEstimatedDeliveryText() {
    // Priority 1: Use distance-based estimate if available
    if (_distanceEstimate != null) {
      return _distanceEstimate!.formattedDeliveryTimeRange();
    }

    // Priority 2: Use order's estimated delivery time
    if (widget.order.estimatedDeliveryTime != null) {
      final now = DateTime.now();
      final diff = widget.order.estimatedDeliveryTime!.difference(now);

      if (diff.inMinutes < 60) {
        return '${diff.inMinutes} minutes';
      } else {
        final hours = diff.inHours;
        final minutes = diff.inMinutes % 60;
        return '$hours hr${hours > 1 ? 's' : ''} ${minutes > 0 ? '$minutes min' : ''}';
      }
    }

    // Priority 3: Default fallback
    return '30-45 minutes';
  }

  @override
  Widget build(BuildContext context) {
    print('🎉 OrderConfirmationScreen building...');
    print('Order ID: ${widget.order.id}');
    print('Order Status: ${widget.order.status}');
    print('Order Total: ${widget.order.totalAmount}');
    print('Number of items: ${widget.order.items.length}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Confirmed'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Remove back button
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DashboardConstants.screenPadding),
        child: Column(
          children: [
            // Success animation/icon
            _buildSuccessSection(),
            const SizedBox(height: 32),

            // Order number card
            _buildOrderNumberCard(),
            const SizedBox(height: 24),

            // Estimated delivery time
            _buildEstimatedTimeCard(),
            const SizedBox(height: 24),

            // Order summary
            _buildOrderSummaryCard(),
            const SizedBox(height: 32),

            // Action buttons
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessSection() {
    return Column(
      children: [
        // Success icon with animation
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.shade50,
            border: Border.all(color: Colors.green, width: 3),
          ),
          child: const Icon(
            Icons.check_circle,
            size: 80,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Order Placed Successfully!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Your order has been received and is being prepared',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOrderNumberCard() {
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
            const Text(
              'Order Number',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '#${widget.order.id ?? 'N/A'}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 12),
            OrderStatusBadge(status: widget.order.status, fontSize: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildEstimatedTimeCard() {
    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
      ),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: _isLoadingDistance
                      ? SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.blue.shade700,
                          ),
                        )
                      : Icon(
                          Icons.access_time,
                          size: 32,
                          color: Colors.blue.shade700,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated Delivery Time',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getEstimatedDeliveryText(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Show distance information if available
            if (_distanceEstimate != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDistanceInfo(
                    icon: Icons.straighten,
                    label: 'Distance',
                    value: '${_distanceEstimate!.distance.miles.toStringAsFixed(1)} mi',
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.blue.shade200,
                  ),
                  _buildDistanceInfo(
                    icon: Icons.directions_car,
                    label: 'Drive Time',
                    value: _distanceEstimate!.duration.text,
                  ),
                ],
              ),
            ],
            // Show error message if distance fetch failed
            if (_distanceError != null && _distanceEstimate == null && !_isLoadingDistance) ...[
              const SizedBox(height: 8),
              Text(
                'Distance unavailable',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceInfo({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.blue.shade700),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade900,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummaryCard() {
    print('📦 Building order summary...');
    print('Restaurant: ${widget.order.restaurantName}');
    print('Items count: ${widget.order.items.length}');
    for (var i = 0; i < widget.order.items.length; i++) {
      final item = widget.order.items[i];
      print('Item $i: ${item.menuItemName} x${item.quantity} = \$${item.totalPrice}');
    }

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

            // Restaurant name
            Row(
              children: [
                const Icon(Icons.restaurant, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.order.restaurantName ?? 'Unknown Restaurant',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Items list
            ...widget.order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${item.quantity}',
                            style: TextStyle(
                              fontSize: 12,
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
                                fontWeight: FontWeight.w500,
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

            const Divider(),
            const SizedBox(height: 12),

            // Price breakdown
            _buildPriceRow('Subtotal', widget.order.subtotal),
            const SizedBox(height: 8),
            _buildPriceRow('Tax', widget.order.taxAmount),
            const SizedBox(height: 8),
            _buildPriceRow('Delivery Fee', widget.order.deliveryFee),
            const SizedBox(height: 12),
            const Divider(thickness: 2),
            const SizedBox(height: 12),
            _buildPriceRow('Total', widget.order.totalAmount, isTotal: true),
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

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // Track Order button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {
              // Navigate to order detail screen
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => CustomerOrderDetailScreen(
                    orderId: widget.order.id!,
                    token: widget.token,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.location_on),
            label: const Text(
              'Track Order',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Back to Restaurant button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () {
              // Navigate back to restaurant menu
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.restaurant_menu),
            label: const Text(
              'Back to Restaurant',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.deepOrange,
              side: const BorderSide(color: Colors.deepOrange, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Go Home button
        TextButton(
          onPressed: () {
            // Navigate to dashboard/home
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          child: const Text(
            'Go to Dashboard',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}
