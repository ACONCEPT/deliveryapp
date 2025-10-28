import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../config/dashboard_constants.dart';
import 'order_status_badge.dart';

/// Reusable order card widget for list views
/// Displays order summary with restaurant, items, status, and total
class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onTap;
  final VoidCallback? onReorder;
  final bool showReorderButton;

  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.onReorder,
    this.showReorderButton = false,
  });

  /// Format DateTime to readable date string
  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';

    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays == 0) {
      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return 'Today at $hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  /// Get items summary text
  String _getItemsSummary() {
    final itemCount = order.totalItemCount;
    if (order.items.isEmpty) return 'No items';
    if (order.items.length == 1) {
      return '${order.items[0].menuItemName} x${order.items[0].quantity}';
    }
    return '${order.items[0].menuItemName} + ${itemCount - order.items[0].quantity} more';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
        child: Padding(
          padding: const EdgeInsets.all(DashboardConstants.cardPaddingSmall),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Order ID and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  OrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),

              // Restaurant name
              Row(
                children: [
                  const Icon(Icons.restaurant, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.restaurantName ?? 'Unknown Restaurant',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Items summary
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined,
                      size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getItemsSummary(),
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Date
              Row(
                children: [
                  const Icon(Icons.access_time, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(order.createdAt),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Footer: Total and Action Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Total amount
                  Text(
                    '\$${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),

                  // Reorder button (conditional)
                  if (showReorderButton && onReorder != null)
                    OutlinedButton.icon(
                      onPressed: onReorder,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reorder'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepOrange,
                        side: const BorderSide(color: Colors.deepOrange),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
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
}
