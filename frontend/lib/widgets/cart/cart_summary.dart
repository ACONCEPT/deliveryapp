import 'package:flutter/material.dart';
import '../../config/dashboard_constants.dart';

/// Widget displaying cart summary with subtotal, tax, delivery fee, and total
class CartSummary extends StatelessWidget {
  final double subtotal;
  final double taxAmount;
  final double deliveryFee;
  final double totalAmount;
  final bool showDividers;

  const CartSummary({
    super.key,
    required this.subtotal,
    required this.taxAmount,
    required this.deliveryFee,
    required this.totalAmount,
    this.showDividers = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Text(
              'Order Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DashboardConstants.cardPaddingSmall),

            if (showDividers) const Divider(),
            if (showDividers)
              const SizedBox(height: DashboardConstants.cardPaddingSmall),

            // Subtotal
            _buildSummaryRow(
              'Subtotal',
              subtotal,
              isTotal: false,
            ),
            const SizedBox(height: 8),

            // Tax
            _buildSummaryRow(
              'Tax (8%)',
              taxAmount,
              isTotal: false,
            ),
            const SizedBox(height: 8),

            // Delivery fee
            _buildSummaryRow(
              'Delivery Fee',
              deliveryFee,
              isTotal: false,
            ),

            if (showDividers)
              const SizedBox(height: DashboardConstants.cardPaddingSmall),
            if (showDividers) const Divider(thickness: 2),
            if (showDividers)
              const SizedBox(height: DashboardConstants.cardPaddingSmall),

            // Total
            _buildSummaryRow(
              'Total',
              totalAmount,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {required bool isTotal}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : DashboardConstants.restaurantNameTextSize,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Colors.black : Colors.grey.shade700,
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 18 : DashboardConstants.restaurantNameTextSize,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Colors.orange : Colors.black,
          ),
        ),
      ],
    );
  }
}
