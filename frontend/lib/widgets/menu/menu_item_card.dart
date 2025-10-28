import 'package:flutter/material.dart';
import '../../models/menu.dart';
import '../../config/dashboard_constants.dart';

/// Widget displaying a menu item with image, name, price, and description
class MenuItemCard extends StatelessWidget {
  final MenuItem menuItem;
  final VoidCallback? onTap;

  const MenuItemCard({
    super.key,
    required this.menuItem,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item image
            _buildItemImage(),

            // Item details
            Padding(
              padding: const EdgeInsets.all(DashboardConstants.cardPaddingSmall),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and availability
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          menuItem.name,
                          style: const TextStyle(
                            fontSize: DashboardConstants.restaurantNameTextSize,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!menuItem.isAvailable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Unavailable',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Description
                  if (menuItem.description != null &&
                      menuItem.description!.isNotEmpty)
                    Text(
                      menuItem.description!,
                      style: TextStyle(
                        fontSize: DashboardConstants.restaurantInfoSmallTextSize,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),

                  // Price and add button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Price
                      Text(
                        '\$${menuItem.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),

                      // Add button
                      if (menuItem.isAvailable)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.add,
                              color: Colors.orange,
                            ),
                            onPressed: onTap,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            iconSize: 20,
                          ),
                        ),
                    ],
                  ),

                  // Customization indicator
                  if (menuItem.customizationOptions != null &&
                      menuItem.customizationOptions!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.tune,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Customizable',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemImage() {
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: menuItem.imageUrl != null
          ? Image.network(
              menuItem.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
            )
          : _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(
        Icons.restaurant_menu,
        size: 48,
        color: Colors.grey,
      ),
    );
  }
}
