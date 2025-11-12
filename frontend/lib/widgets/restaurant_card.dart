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
          padding: EdgeInsets.all(DashboardConstants.responsiveCardPaddingSmall(context)),
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
    return Builder(
      builder: (context) => Container(
        height: DashboardConstants.responsiveRestaurantImageHeight(context),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(DashboardConstants.cardBorderRadiusExtraSmall),
        ),
        child: Center(
          child: Icon(
            Icons.restaurant,
            size: DashboardConstants.responsiveRestaurantIconSize(context),
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantName() {
    return Builder(
      builder: (context) => Text(
        restaurant.name,
        style: TextStyle(
          fontSize: DashboardConstants.responsiveRestaurantNameTextSize(context),
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildLocationAndStatus() {
    return Builder(
      builder: (context) => Row(
        children: [
          Expanded(
            child: Text(
              restaurant.shortAddress.isNotEmpty ? restaurant.shortAddress : 'No location',
              style: TextStyle(
                fontSize: DashboardConstants.responsiveRestaurantCuisineTextSize(context),
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          _buildStatusBadge(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: restaurant.isActive ? Colors.green : Colors.red,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          restaurant.isActive ? 'Active' : 'Inactive',
          style: TextStyle(
            fontSize: DashboardConstants.isMobile(context) ? 10.0 : 9.0,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantInfo() {
    return Builder(
      builder: (context) => Row(
        children: [
          const Icon(Icons.star, size: 14, color: Colors.amber),
          const SizedBox(width: 4),
          Text(
            restaurant.rating.toStringAsFixed(1),
            style: TextStyle(fontSize: DashboardConstants.responsiveRestaurantInfoTextSize(context)),
          ),
          const SizedBox(width: 12),
          Icon(Icons.shopping_bag, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            '${restaurant.totalOrders} orders',
            style: TextStyle(
              fontSize: DashboardConstants.responsiveRestaurantInfoSmallTextSize(context),
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
