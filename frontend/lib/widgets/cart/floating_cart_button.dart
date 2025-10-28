import 'package:flutter/material.dart';

/// Floating action button that displays cart item count and total
class FloatingCartButton extends StatelessWidget {
  final int itemCount;
  final double totalAmount;
  final VoidCallback onPressed;

  const FloatingCartButton({
    super.key,
    required this.itemCount,
    required this.totalAmount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cart icon with badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart, size: 24),
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      '$itemCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),

            // Text
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'View Cart',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '\$${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 20),
          ],
        ),
      ),
    );
  }
}
