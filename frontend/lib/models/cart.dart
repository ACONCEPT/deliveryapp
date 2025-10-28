import 'menu.dart';

/// Represents a single item in the shopping cart
class CartItem {
  final MenuItem menuItem;
  final int quantity;
  final List<CustomizationChoice> selectedCustomizations;
  final String? specialInstructions;

  CartItem({
    required this.menuItem,
    required this.quantity,
    this.selectedCustomizations = const [],
    this.specialInstructions,
  });

  /// Calculate total price including customizations
  double get totalPrice {
    double customizationsTotal = selectedCustomizations.fold(
      0.0,
      (sum, choice) => sum + choice.priceModifier,
    );
    return (menuItem.price + customizationsTotal) * quantity;
  }

  /// Calculate base price without customizations
  double get basePrice {
    return menuItem.price * quantity;
  }

  /// Calculate total customization cost
  double get customizationsCost {
    return selectedCustomizations.fold(
          0.0,
          (sum, choice) => sum + choice.priceModifier,
        ) *
        quantity;
  }

  /// Get comma-separated list of customization names
  String get customizationsSummary {
    if (selectedCustomizations.isEmpty) return '';
    return selectedCustomizations.map((c) => c.name).join(', ');
  }

  /// Create a copy with updated fields
  CartItem copyWith({
    MenuItem? menuItem,
    int? quantity,
    List<CustomizationChoice>? selectedCustomizations,
    String? specialInstructions,
  }) {
    return CartItem(
      menuItem: menuItem ?? this.menuItem,
      quantity: quantity ?? this.quantity,
      selectedCustomizations: selectedCustomizations ?? this.selectedCustomizations,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }

  /// Check if two cart items are the same (same item + customizations)
  bool isSameAs(CartItem other) {
    if (menuItem.id != other.menuItem.id) return false;
    if (selectedCustomizations.length != other.selectedCustomizations.length) {
      return false;
    }

    // Check if all customizations match
    final thisCustomizationIds =
        selectedCustomizations.map((c) => c.id).toSet();
    final otherCustomizationIds =
        other.selectedCustomizations.map((c) => c.id).toSet();

    return thisCustomizationIds.containsAll(otherCustomizationIds) &&
        otherCustomizationIds.containsAll(thisCustomizationIds);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CartItem) return false;
    return isSameAs(other) && specialInstructions == other.specialInstructions;
  }

  @override
  int get hashCode {
    return Object.hash(
      menuItem.id,
      selectedCustomizations.map((c) => c.id).toList(),
      specialInstructions,
    );
  }
}

/// Represents the shopping cart for a restaurant
class Cart {
  final int restaurantId;
  final String restaurantName;
  final List<CartItem> items;

  Cart({
    required this.restaurantId,
    required this.restaurantName,
    this.items = const [],
  });

  /// Calculate subtotal (sum of all item prices)
  double get subtotal {
    return items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  /// Calculate tax amount (8% for now, can be made configurable)
  double get taxAmount {
    const taxRate = 0.08;
    return subtotal * taxRate;
  }

  /// Calculate delivery fee (fixed for now, can be made dynamic based on distance)
  double get deliveryFee {
    return 5.99;
  }

  /// Calculate total amount (subtotal + tax + delivery fee)
  double get totalAmount {
    return subtotal + taxAmount + deliveryFee;
  }

  /// Get total number of items in cart
  int get itemCount {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  /// Check if cart is empty
  bool get isEmpty {
    return items.isEmpty;
  }

  /// Check if cart is not empty
  bool get isNotEmpty {
    return items.isNotEmpty;
  }

  /// Create a copy with updated fields
  Cart copyWith({
    int? restaurantId,
    String? restaurantName,
    List<CartItem>? items,
  }) {
    return Cart(
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      items: items ?? this.items,
    );
  }

  /// Add item to cart or update quantity if same item exists
  Cart addItem(CartItem newItem) {
    final existingIndex = items.indexWhere((item) => item == newItem);

    if (existingIndex != -1) {
      // Item already exists, update quantity
      final updatedItems = List<CartItem>.from(items);
      updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
        quantity: updatedItems[existingIndex].quantity + newItem.quantity,
      );
      return copyWith(items: updatedItems);
    } else {
      // New item, add to cart
      return copyWith(items: [...items, newItem]);
    }
  }

  /// Remove item from cart at index
  Cart removeItemAt(int index) {
    if (index < 0 || index >= items.length) return this;
    final updatedItems = List<CartItem>.from(items)..removeAt(index);
    return copyWith(items: updatedItems);
  }

  /// Update item quantity at index
  Cart updateQuantity(int index, int newQuantity) {
    if (index < 0 || index >= items.length) return this;
    if (newQuantity <= 0) return removeItemAt(index);

    final updatedItems = List<CartItem>.from(items);
    updatedItems[index] = updatedItems[index].copyWith(quantity: newQuantity);
    return copyWith(items: updatedItems);
  }

  /// Clear all items from cart
  Cart clear() {
    return copyWith(items: []);
  }
}
