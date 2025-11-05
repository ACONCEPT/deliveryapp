import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../widgets/order/order_card.dart';
import '../../widgets/common/paginated_list_screen.dart';
import 'customer_order_detail_screen.dart';

/// Customer active orders screen showing ongoing orders
/// Displays orders with status != delivered/cancelled
class CustomerActiveOrdersScreen extends StatelessWidget {
  final String token;

  const CustomerActiveOrdersScreen({
    super.key,
    required this.token,
  });

  /// Load active orders from API and filter/sort
  Future<List<Order>> _loadActiveOrders(String? token) async {
    final orderService = OrderService();
    final allOrders = await orderService.getCustomerOrders();

    // Filter for active orders only
    final activeOrders = allOrders.where((order) => order.isActive).toList();

    // Sort by created date (newest first)
    activeOrders.sort((a, b) {
      if (a.createdAt == null && b.createdAt == null) return 0;
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!);
    });

    return activeOrders;
  }

  /// Navigate to order detail screen
  void _navigateToOrderDetail(BuildContext context, Order order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CustomerOrderDetailScreen(
          orderId: order.id!,
          token: token,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PaginatedListScreen<Order>(
      title: 'Active Orders',
      token: token,
      appBarColor: Colors.deepOrange,
      loadItems: _loadActiveOrders,
      itemBuilder: (order, index) => OrderCard(
        order: order,
        onTap: () => _navigateToOrderDetail(context, order),
        showReorderButton: false,
      ),
      emptyIcon: Icons.shopping_bag_outlined,
      emptyTitle: 'No Active Orders',
      emptyMessage: 'You don\'t have any active orders at the moment.\nPlace an order to get started!',
      enableSearch: false,
    );
  }
}
