import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../config/dashboard_constants.dart';
import 'restaurant_card.dart';
import 'section_header.dart';

class RestaurantSection extends StatelessWidget {
  final String title;
  final IconData headerIcon;
  final Color headerIconColor;
  final List<Restaurant> restaurants;
  final Function(Restaurant)? onRestaurantTap;

  const RestaurantSection({
    super.key,
    required this.title,
    required this.headerIcon,
    required this.headerIconColor,
    required this.restaurants,
    this.onRestaurantTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: DashboardConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DashboardConstants.cardBorderRadius),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: title,
              icon: headerIcon,
              iconColor: headerIconColor,
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: DashboardConstants.dashboardGridColumns,
                crossAxisSpacing: DashboardConstants.gridSpacing,
                mainAxisSpacing: DashboardConstants.gridSpacing,
                childAspectRatio: DashboardConstants.restaurantCardAspectRatio,
              ),
              itemCount: restaurants.length,
              itemBuilder: (context, index) {
                return RestaurantCard(
                  restaurant: restaurants[index],
                  onTap: onRestaurantTap != null
                      ? () => onRestaurantTap!(restaurants[index])
                      : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
