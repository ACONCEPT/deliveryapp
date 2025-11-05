import 'package:flutter/material.dart';
import 'user_type_config.dart';

class DashboardWidgetConfig {
  final String title;
  final IconData icon;
  final Color color;
  final String? route;
  final VoidCallback? onTap;

  const DashboardWidgetConfig({
    required this.title,
    required this.icon,
    required this.color,
    this.route,
    this.onTap,
  });

  static List<DashboardWidgetConfig> getWidgetsForUserType(String userType) {
    switch (userType) {
      case UserTypeConfig.admin:
        return [
          const DashboardWidgetConfig(
            title: 'User Admin',
            icon: Icons.people,
            color: Colors.red,
            route: '/admin/users',
          ),
          const DashboardWidgetConfig(
            title: 'System Settings',
            icon: Icons.settings,
            color: Colors.deepPurple,
            route: '/admin/settings',
          ),
          const DashboardWidgetConfig(
            title: 'Approvals',
            icon: Icons.approval,
            color: Colors.green,
            route: '/admin/approvals',
          ),
          const DashboardWidgetConfig(
            title: 'Customization Templates',
            icon: Icons.layers,
            color: Colors.teal,
            route: '/admin/customization-templates',
          ),
          const DashboardWidgetConfig(
            title: 'Restaurant Admin',
            icon: Icons.restaurant_menu,
            color: Colors.red,
            route: '/admin/restaurants',
          ),
          const DashboardWidgetConfig(
            title: 'Vendor Admin',
            icon: Icons.store,
            color: Colors.orange,
          ),
          const DashboardWidgetConfig(
            title: 'Order Dashboard',
            icon: Icons.dashboard,
            color: Colors.blue,
            route: '/admin/orders',
          ),
        ];

      case UserTypeConfig.vendor:
        return [
          const DashboardWidgetConfig(
            title: 'Manage Orders',
            icon: Icons.receipt_long,
            color: Colors.green,
            route: '/vendor/orders',
          ),
          const DashboardWidgetConfig(
            title: 'My Restaurants',
            icon: Icons.add_business,
            color: Colors.orange,
            route: '/vendor/restaurants',
          ),
          const DashboardWidgetConfig(
            title: 'Manage Menus',
            icon: Icons.restaurant_menu,
            color: Colors.blue,
            route: '/vendor/restaurant-selector',
          ),
          const DashboardWidgetConfig(
            title: 'Customization Templates',
            icon: Icons.layers,
            color: Colors.teal,
            route: '/vendor/customization-templates',
          ),
        ];

      case UserTypeConfig.customer:
        return [
          const DashboardWidgetConfig(
            title: 'Browse Restaurants',
            icon: Icons.restaurant,
            color: Colors.green,
            route: '/restaurants',
          ),
          const DashboardWidgetConfig(
            title: 'Order Now',
            icon: Icons.shopping_cart,
            color: Colors.green,
          ),
          const DashboardWidgetConfig(
            title: 'My Active Orders',
            icon: Icons.local_shipping,
            color: Colors.orange,
            route: '/customer/active-orders',
          ),
          const DashboardWidgetConfig(
            title: 'Order History',
            icon: Icons.history,
            color: Colors.blue,
            route: '/customer/order-history',
          ),
          const DashboardWidgetConfig(
            title: 'Manage Addresses',
            icon: Icons.location_on,
            color: Colors.red,
            route: '/addresses',
          ),
        ];

      case UserTypeConfig.driver:
        return [
          const DashboardWidgetConfig(
            title: 'Available Orders',
            icon: Icons.local_shipping_outlined,
            color: Colors.orange,
            route: '/driver/available-orders',
          ),
          const DashboardWidgetConfig(
            title: 'My Deliveries',
            icon: Icons.local_shipping,
            color: Colors.purple,
            route: '/driver/orders',
          ),
          const DashboardWidgetConfig(
            title: 'Browse Restaurants',
            icon: Icons.restaurant,
            color: Colors.green,
            route: '/restaurants',
          ),
        ];

      default:
        return [];
    }
  }
}
