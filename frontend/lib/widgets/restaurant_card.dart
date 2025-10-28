import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../config/dashboard_constants.dart';

class RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback? onTap;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: DashboardConstants.cardElevationRestaurant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
      ),
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
        child: Padding(
          padding: const EdgeInsets.all(DashboardConstants.cardPaddingSmall),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRestaurantImage(),
              const SizedBox(height: 8),
              _buildRestaurantName(),
              const SizedBox(height: 4),
              _buildLocationAndStatus(),
              const SizedBox(height: 4),
              _buildRestaurantInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantImage() {
    return Container(
      height: DashboardConstants.restaurantImageHeight,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(DashboardConstants.cardBorderRadiusExtraSmall),
      ),
      child: const Center(
        child: Icon(
          Icons.restaurant,
          size: DashboardConstants.restaurantIconSize,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildRestaurantName() {
    return Text(
      restaurant.name,
      style: const TextStyle(
        fontSize: DashboardConstants.restaurantNameTextSize,
        fontWeight: FontWeight.bold,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildLocationAndStatus() {
    return Row(
      children: [
        Expanded(
          child: Text(
            restaurant.shortAddress.isNotEmpty ? restaurant.shortAddress : 'No location',
            style: TextStyle(
              fontSize: DashboardConstants.restaurantCuisineTextSize,
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: restaurant.isActive ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        restaurant.isActive ? 'Active' : 'Inactive',
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRestaurantInfo() {
    return Row(
      children: [
        const Icon(Icons.star, size: 14, color: Colors.amber),
        const SizedBox(width: 4),
        Text(
          restaurant.rating.toStringAsFixed(1),
          style: const TextStyle(fontSize: DashboardConstants.restaurantInfoTextSize),
        ),
        const SizedBox(width: 12),
        Icon(Icons.shopping_bag, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          '${restaurant.totalOrders} orders',
          style: TextStyle(
            fontSize: DashboardConstants.restaurantInfoSmallTextSize,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
