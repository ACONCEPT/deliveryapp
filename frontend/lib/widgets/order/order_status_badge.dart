import 'package:flutter/material.dart';
import '../../models/order.dart';

/// Badge widget displaying order status with color coding
/// Used in order cards and detail views
class OrderStatusBadge extends StatelessWidget {
  final OrderStatus status;
  final double fontSize;
  final EdgeInsets padding;

  const OrderStatusBadge({
    super.key,
    required this.status,
    this.fontSize = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  /// Get color for order status
  Color _getStatusColor() {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.ready:
        return Colors.teal;
      case OrderStatus.pickedUp:
        return Colors.indigo;
      case OrderStatus.enRoute:
        return Colors.deepPurple;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  /// Get icon for order status
  IconData _getStatusIcon() {
    switch (status) {
      case OrderStatus.pending:
        return Icons.pending_outlined;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.ready:
        return Icons.shopping_bag_outlined;
      case OrderStatus.pickedUp:
        return Icons.local_shipping_outlined;
      case OrderStatus.enRoute:
        return Icons.delivery_dining;
      case OrderStatus.delivered:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(),
            size: fontSize + 2,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            status.displayName,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
