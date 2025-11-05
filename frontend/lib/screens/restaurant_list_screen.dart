import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../services/restaurant_service.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/common/paginated_list_screen.dart';
import 'customer/restaurant_menu_screen.dart';

class RestaurantListScreen extends StatelessWidget {
  final String token;

  const RestaurantListScreen({
    super.key,
    required this.token,
  });

  void _navigateToMenu(BuildContext context, Restaurant restaurant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantMenuScreen(
          restaurant: restaurant,
          token: token,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final restaurantService = RestaurantService();

    return PaginatedListScreen<Restaurant>(
      title: 'Restaurants',
      token: token,
      appBarColor: Colors.blue,
      loadItems: (token) => restaurantService.getRestaurants(token!),
      itemBuilder: (restaurant, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: RestaurantCard(
          restaurant: restaurant,
          onTap: () => _navigateToMenu(context, restaurant),
        ),
      ),
      emptyIcon: Icons.restaurant_menu,
      emptyTitle: 'No restaurants available',
      emptyMessage: 'Check back later for new restaurants',
      enableSearch: false,
    );
  }
}
