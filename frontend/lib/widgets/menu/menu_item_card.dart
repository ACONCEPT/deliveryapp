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
              padding: const EdgeInsets.all(8.0),
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
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!menuItem.isAvailable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'N/A',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Description
                  if (menuItem.description != null &&
                      menuItem.description!.isNotEmpty)
                    Text(
                      menuItem.description!,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),

                  // Price and add button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Price
                      Text(
                        '\$${menuItem.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),

                      // Customization indicator and Add button
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (menuItem.customizationOptions != null &&
                              menuItem.customizationOptions!.isNotEmpty)
                            Icon(
                              Icons.tune,
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                          if (menuItem.customizationOptions != null &&
                              menuItem.customizationOptions!.isNotEmpty)
                            const SizedBox(width: 4),
                          if (menuItem.isAvailable)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.add,
                                  color: Colors.orange,
                                ),
                                onPressed: onTap,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                iconSize: 16,
                                tooltip: 'Add to cart',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
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
      height: 80,
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
        size: 32,
        color: Colors.grey,
      ),
    );
  }
}
