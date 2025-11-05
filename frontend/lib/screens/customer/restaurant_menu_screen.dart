import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/restaurant.dart';
import '../../models/menu.dart';
import '../../services/menu_service.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/menu/menu_item_card.dart';
import '../../widgets/menu/item_customization_dialog.dart';
import '../../widgets/cart/floating_cart_button.dart';
import '../../config/dashboard_constants.dart';
import 'cart_screen.dart';

/// Screen displaying restaurant menu with categories and items
/// Allows customers to browse menu and add items to cart
class RestaurantMenuScreen extends StatefulWidget {
  final Restaurant restaurant;
  final String token;

  const RestaurantMenuScreen({
    super.key,
    required this.restaurant,
    required this.token,
  });

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  final MenuService _menuService = MenuService();
  List<Menu> _menus = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMenus();
  }

  Future<void> _loadMenus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final menu = await _menuService.getRestaurantMenu(
        widget.token,
        widget.restaurant.id!,
      );

      setState(() {
        if (menu != null) {
          _menus = [menu];
        } else {
          _menus = [];
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.restaurant.name),
            if (widget.restaurant.description != null)
              Text(
                widget.restaurant.description!,
                style: const TextStyle(fontSize: 14),
              ),
          ],
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
      floatingActionButton: _buildFloatingCartButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_menus.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadMenus,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: DashboardConstants.cardPadding,
          left: DashboardConstants.cardPadding,
          right: DashboardConstants.cardPadding,
          bottom: 100, // Space for floating cart button
        ),
        itemCount: _menus.length,
        itemBuilder: (context, index) {
          return _buildMenuSection(_menus[index]);
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load menu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadMenus,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Menu Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This restaurant hasn\'t created a menu yet.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadMenus,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(Menu menu) {
    // Get categories from menu config
    final categories = menu.getCategories();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Menu name
        Card(
          color: Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(DashboardConstants.cardPadding),
            child: Row(
              children: [
                Icon(Icons.restaurant, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        menu.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (menu.description != null)
                        Text(
                          menu.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Categories
        ...categories.where((cat) => cat.isActive).map((category) {
          return _buildCategorySection(category.name, category.items);
        }),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCategorySection(String category, List<MenuItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: DashboardConstants.cardPaddingSmall,
          ),
          child: Text(
            category,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Items grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.95,
            crossAxisSpacing: DashboardConstants.gridSpacing,
            mainAxisSpacing: DashboardConstants.gridSpacing,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return MenuItemCard(
              menuItem: items[index],
              onTap: () => _handleMenuItemTap(items[index]),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFloatingCartButton() {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        if (!cartProvider.hasItems) {
          return const SizedBox.shrink();
        }

        return FloatingCartButton(
          itemCount: cartProvider.itemCount,
          totalAmount: cartProvider.totalAmount,
          onPressed: () => _navigateToCart(context),
        );
      },
    );
  }

  void _handleMenuItemTap(MenuItem menuItem) async {
    if (!menuItem.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This item is currently unavailable'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // Initialize cart if needed, or check for restaurant mismatch
    final canAddToCart = cartProvider.initializeCart(
      widget.restaurant.id!,
      widget.restaurant.name,
    );

    if (!canAddToCart) {
      // Show dialog for restaurant mismatch
      final shouldSwitch = await _showRestaurantMismatchDialog();
      if (shouldSwitch != true) return;

      // User wants to switch, clear and initialize new cart
      cartProvider.switchRestaurant(
        widget.restaurant.id!,
        widget.restaurant.name,
      );
    }

    // Show customization dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ItemCustomizationDialog(menuItem: menuItem),
    );

    if (result != null) {
      // Add to cart
      final success = cartProvider.addItem(
        menuItem: menuItem,
        quantity: result['quantity'] as int,
        selectedCustomizations: result['customizations'] as List<CustomizationChoice>,
        specialInstructions: result['instructions'] as String?,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${menuItem.name} added to cart'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'VIEW CART',
              textColor: Colors.white,
              onPressed: () => _navigateToCart(context),
            ),
          ),
        );
      }
    }
  }

  Future<bool?> _showRestaurantMismatchDialog() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Different Restaurant'),
        content: Text(
          'Your cart contains items from ${cartProvider.restaurantName}. '
          'Would you like to clear your cart and start a new order from ${widget.restaurant.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('CLEAR CART'),
          ),
        ],
      ),
    );
  }

  void _navigateToCart(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(token: widget.token),
      ),
    );
  }
}
