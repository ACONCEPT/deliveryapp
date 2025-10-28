import 'package:flutter/material.dart';
import '../../models/cart.dart';
import '../../config/dashboard_constants.dart';

/// Widget displaying a single cart item with quantity controls
class CartItemTile extends StatelessWidget {
  final CartItem item;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback? onRemove;
  final bool showControls;

  const CartItemTile({
    super.key,
    required this.item,
    this.onIncrement,
    this.onDecrement,
    this.onRemove,
    this.showControls = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: DashboardConstants.cardPaddingSmall,
        vertical: 6,
      ),
      elevation: DashboardConstants.cardElevationSmall,
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPaddingSmall),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item image or icon
            _buildItemImage(),
            const SizedBox(width: DashboardConstants.cardPaddingSmall),

            // Item details
            Expanded(
              child: _buildItemDetails(context),
            ),

            // Quantity controls or price display
            if (showControls)
              _buildQuantityControls()
            else
              _buildPriceDisplay(context),
          ],
        ),
      ),
    );
  }

  Widget _buildItemImage() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(
          DashboardConstants.cardBorderRadiusExtraSmall,
        ),
      ),
      child: item.menuItem.imageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(
                DashboardConstants.cardBorderRadiusExtraSmall,
              ),
              child: Image.network(
                item.menuItem.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.restaurant_menu,
                  color: Colors.orange,
                  size: 32,
                ),
              ),
            )
          : const Icon(
              Icons.restaurant_menu,
              color: Colors.orange,
              size: 32,
            ),
    );
  }

  Widget _buildItemDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Item name
        Text(
          item.menuItem.name,
          style: const TextStyle(
            fontSize: DashboardConstants.restaurantNameTextSize,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),

        // Base price
        Text(
          '\$${item.menuItem.price.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: DashboardConstants.restaurantInfoTextSize,
            color: Colors.grey.shade600,
          ),
        ),

        // Customizations if any
        if (item.selectedCustomizations.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            item.customizationsSummary,
            style: TextStyle(
              fontSize: DashboardConstants.restaurantInfoSmallTextSize,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.customizationsCost > 0)
            Text(
              '+\$${item.customizationsCost.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: DashboardConstants.restaurantInfoSmallTextSize,
                color: Colors.green.shade700,
              ),
            ),
        ],

        // Special instructions if any
        if (item.specialInstructions != null &&
            item.specialInstructions!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.note,
                size: 14,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.specialInstructions!,
                  style: TextStyle(
                    fontSize: DashboardConstants.restaurantInfoSmallTextSize,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildQuantityControls() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Remove button
        IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: onRemove,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          color: Colors.red.shade400,
        ),

        const SizedBox(height: 8),

        // Quantity controls
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Decrement
            InkWell(
              onTap: onDecrement,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.remove, size: 16),
              ),
            ),

            // Quantity
            Container(
              width: 36,
              alignment: Alignment.center,
              child: Text(
                '${item.quantity}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Increment
            InkWell(
              onTap: onIncrement,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.add,
                  size: 16,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Total price for this item
        Text(
          '\$${item.totalPrice.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: DashboardConstants.restaurantNameTextSize,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceDisplay(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'x${item.quantity}',
          style: TextStyle(
            fontSize: DashboardConstants.restaurantInfoTextSize,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '\$${item.totalPrice.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: DashboardConstants.restaurantNameTextSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
