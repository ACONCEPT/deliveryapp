import 'package:flutter/material.dart';
import '../../models/menu.dart';
import '../../config/dashboard_constants.dart';

/// Widget displaying a menu item in list format with horizontal layout
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
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: menuItem.isAvailable ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildItemImage(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNameRow(),
                    if (menuItem.description != null &&
                        menuItem.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _buildDescription(),
                    ],
                    const SizedBox(height: 8),
                    _buildPriceAndActions(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 100,
        height: 100,
        child: menuItem.imageUrl != null
            ? Image.network(
                menuItem.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(
        Icons.restaurant_menu,
        size: 40,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildNameRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            menuItem.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
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
                fontSize: 11,
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDescription() {
    return Text(
      menuItem.description!,
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey.shade600,
        height: 1.3,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildPriceAndActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '\$${menuItem.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            if (menuItem.customizationOptions != null &&
                menuItem.customizationOptions!.isNotEmpty)
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
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (menuItem.isAvailable)
          ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
          ),
      ],
    );
  }
}
