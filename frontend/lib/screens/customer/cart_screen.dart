import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/cart/cart_item_tile.dart';
import '../../widgets/cart/cart_summary.dart';
import '../../config/dashboard_constants.dart';
import 'checkout_screen.dart';

/// Screen displaying shopping cart contents
/// Allows users to view, modify, and proceed to checkout
class CartScreen extends StatelessWidget {
  final String token;

  const CartScreen({
    super.key,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              if (!cartProvider.hasItems) return const SizedBox.shrink();

              return IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _showClearCartDialog(context),
                tooltip: 'Clear Cart',
              );
            },
          ),
        ],
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          if (!cartProvider.hasItems) {
            return _buildEmptyState(context);
          }

          return Column(
            children: [
              // Restaurant header
              _buildRestaurantHeader(cartProvider),

              // Cart items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    vertical: DashboardConstants.cardPaddingSmall,
                  ),
                  itemCount: cartProvider.items.length,
                  itemBuilder: (context, index) {
                    return CartItemTile(
                      item: cartProvider.items[index],
                      onIncrement: () =>
                          cartProvider.incrementQuantity(index),
                      onDecrement: () =>
                          cartProvider.decrementQuantity(index),
                      onRemove: () => _confirmRemoveItem(context, index),
                    );
                  },
                ),
              ),

              // Summary
              Padding(
                padding: const EdgeInsets.all(DashboardConstants.cardPadding),
                child: CartSummary(
                  subtotal: cartProvider.subtotal,
                  taxAmount: cartProvider.taxAmount,
                  deliveryFee: cartProvider.deliveryFee,
                  totalAmount: cartProvider.totalAmount,
                ),
              ),

              // Checkout button
              _buildCheckoutButton(context, cartProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRestaurantHeader(CartProvider cartProvider) {
    return Container(
      padding: const EdgeInsets.all(DashboardConstants.cardPadding),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.restaurant, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cartProvider.restaurantName ?? 'Restaurant',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${cartProvider.itemCount} ${cartProvider.itemCount == 1 ? 'item' : 'items'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add items from a restaurant to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.restaurant),
            label: const Text('Browse Restaurants'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton(BuildContext context, CartProvider cartProvider) {
    return Container(
      padding: const EdgeInsets.all(DashboardConstants.cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _navigateToCheckout(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: Text(
              'Proceed to Checkout - \$${cartProvider.totalAmount.toStringAsFixed(2)}',
            ),
          ),
        ),
      ),
    );
  }

  void _confirmRemoveItem(BuildContext context, int index) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final itemName = cartProvider.items[index].menuItem.name;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: Text('Remove $itemName from cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              cartProvider.removeItemAt(index);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$itemName removed from cart'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Remove all items from cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<CartProvider>(context, listen: false).clearCart();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cart cleared'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('CLEAR'),
          ),
        ],
      ),
    );
  }

  void _navigateToCheckout(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(token: token),
      ),
    );
  }
}
