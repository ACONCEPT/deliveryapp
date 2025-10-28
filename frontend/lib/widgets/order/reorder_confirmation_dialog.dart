import 'package:flutter/material.dart';
import '../../models/order.dart';

/// Confirmation dialog for reordering items from a previous order
/// Shows order details and asks user to confirm reorder action
class ReorderConfirmationDialog extends StatelessWidget {
  final Order order;

  const ReorderConfirmationDialog({
    super.key,
    required this.order,
  });

  /// Show the dialog and return true if user confirmed
  static Future<bool?> show(BuildContext context, Order order) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ReorderConfirmationDialog(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.refresh, color: Colors.deepOrange),
          SizedBox(width: 8),
          Text('Reorder Items?'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add the following items to your cart?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),

            // Restaurant name
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.restaurant, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.restaurantName ?? 'Unknown Restaurant',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Items list
            const Text(
              'Items:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.menuItemName,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        '\$${item.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 24),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${order.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Note
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Items will be added to your cart. You can modify them before checkout.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.shopping_cart),
          label: const Text('Add to Cart'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
