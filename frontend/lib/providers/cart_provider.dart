import 'package:flutter/foundation.dart';
import '../models/cart.dart';
import '../models/menu.dart';

/// Provider for managing shopping cart state
/// Handles adding/removing items, quantity updates, and cart calculations
class CartProvider extends ChangeNotifier {
  Cart? _cart;

  /// Get current cart (can be null if no restaurant selected)
  Cart? get cart => _cart;

  /// Check if cart exists and is not empty
  bool get hasItems => _cart != null && _cart!.isNotEmpty;

  /// Get item count (0 if no cart)
  int get itemCount => _cart?.itemCount ?? 0;

  /// Get cart total (0 if no cart)
  double get totalAmount => _cart?.totalAmount ?? 0.0;

  /// Get restaurant ID (null if no cart)
  int? get restaurantId => _cart?.restaurantId;

  /// Get restaurant name (null if no cart)
  String? get restaurantName => _cart?.restaurantName;

  /// Initialize or switch cart to a new restaurant
  /// If switching restaurants, shows a warning and clears existing cart
  bool initializeCart(int restaurantId, String restaurantName) {
    if (_cart != null && _cart!.restaurantId != restaurantId) {
      // Switching to different restaurant, need to clear cart
      debugPrint(
          'CartProvider: Switching from restaurant ${_cart!.restaurantId} to $restaurantId');
      return false; // Return false to indicate restaurant mismatch
    }

    if (_cart == null) {
      _cart = Cart(
        restaurantId: restaurantId,
        restaurantName: restaurantName,
      );
      debugPrint('CartProvider: Initialized cart for restaurant $restaurantId');
      notifyListeners();
    }

    return true;
  }

  /// Force clear current cart and initialize new one for different restaurant
  void switchRestaurant(int restaurantId, String restaurantName) {
    _cart = Cart(
      restaurantId: restaurantId,
      restaurantName: restaurantName,
    );
    debugPrint(
        'CartProvider: Switched to new restaurant $restaurantId, cart cleared');
    notifyListeners();
  }

  /// Add item to cart
  /// Returns true if successful, false if restaurant mismatch
  bool addItem({
    required MenuItem menuItem,
    required int quantity,
    List<CustomizationChoice> selectedCustomizations = const [],
    String? specialInstructions,
  }) {
    if (_cart == null) {
      debugPrint('CartProvider: Cannot add item - cart not initialized');
      return false;
    }

    final cartItem = CartItem(
      menuItem: menuItem,
      quantity: quantity,
      selectedCustomizations: selectedCustomizations,
      specialInstructions: specialInstructions,
    );

    _cart = _cart!.addItem(cartItem);
    debugPrint(
        'CartProvider: Added ${menuItem.name} x$quantity to cart (Total items: ${_cart!.itemCount})');
    notifyListeners();
    return true;
  }

  /// Remove item from cart at specific index
  void removeItemAt(int index) {
    if (_cart == null) return;

    final itemName = _cart!.items[index].menuItem.name;
    _cart = _cart!.removeItemAt(index);
    debugPrint('CartProvider: Removed $itemName from cart');

    // If cart is now empty, set to null
    if (_cart!.isEmpty) {
      _cart = null;
      debugPrint('CartProvider: Cart is now empty, cleared cart reference');
    }

    notifyListeners();
  }

  /// Update quantity of item at specific index
  void updateQuantity(int index, int newQuantity) {
    if (_cart == null) return;

    final itemName = _cart!.items[index].menuItem.name;
    _cart = _cart!.updateQuantity(index, newQuantity);
    debugPrint('CartProvider: Updated $itemName quantity to $newQuantity');

    // If cart is now empty (quantity was set to 0), set to null
    if (_cart!.isEmpty) {
      _cart = null;
      debugPrint('CartProvider: Cart is now empty, cleared cart reference');
    }

    notifyListeners();
  }

  /// Increment quantity of item at index
  void incrementQuantity(int index) {
    if (_cart == null || index >= _cart!.items.length) return;
    final currentQuantity = _cart!.items[index].quantity;
    updateQuantity(index, currentQuantity + 1);
  }

  /// Decrement quantity of item at index
  void decrementQuantity(int index) {
    if (_cart == null || index >= _cart!.items.length) return;
    final currentQuantity = _cart!.items[index].quantity;
    if (currentQuantity > 1) {
      updateQuantity(index, currentQuantity - 1);
    } else {
      // Remove item if quantity would go to 0
      removeItemAt(index);
    }
  }

  /// Clear entire cart
  void clearCart() {
    if (_cart == null) return;

    debugPrint('CartProvider: Clearing cart for restaurant ${_cart!.restaurantId}');
    _cart = null;
    notifyListeners();
  }

  /// Get cart items as list (empty list if no cart)
  List<CartItem> get items => _cart?.items ?? [];

  /// Get subtotal
  double get subtotal => _cart?.subtotal ?? 0.0;

  /// Get tax amount
  double get taxAmount => _cart?.taxAmount ?? 0.0;

  /// Get delivery fee
  double get deliveryFee => _cart?.deliveryFee ?? 0.0;
}
