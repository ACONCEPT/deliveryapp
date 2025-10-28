import 'package:flutter/material.dart';

class UserTypeConfig {
  static const String customer = 'customer';
  static const String vendor = 'vendor';
  static const String driver = 'driver';
  static const String admin = 'admin';

  static Color getColor(String userType) {
    switch (userType) {
      case customer:
        return Colors.blue;
      case vendor:
        return Colors.orange;
      case driver:
        return Colors.purple;
      case admin:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static String getTitle(String userType) {
    switch (userType) {
      case customer:
        return 'Customer Dashboard';
      case vendor:
        return 'Vendor Dashboard';
      case driver:
        return 'Driver Dashboard';
      case admin:
        return 'Admin Dashboard';
      default:
        return 'Dashboard';
    }
  }

  static String formatUserType(String userType) {
    if (userType.isEmpty) return '';
    return userType[0].toUpperCase() + userType.substring(1);
  }

  static IconData getIcon(String userType) {
    switch (userType) {
      case customer:
        return Icons.person;
      case vendor:
        return Icons.store;
      case driver:
        return Icons.local_shipping;
      case admin:
        return Icons.admin_panel_settings;
      default:
        return Icons.dashboard;
    }
  }
}
