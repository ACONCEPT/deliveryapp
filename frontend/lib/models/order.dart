import 'base/enum_helpers.dart';
import 'base/json_parsers.dart';

/// Order and OrderItem models for order management
/// Supports order creation, status tracking, and full order lifecycle

/// Order status enumeration
enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready,
  pickedUp,
  enRoute,
  delivered,
  cancelled;

  /// Convert status to displayable string
  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready for Pickup';
      case OrderStatus.pickedUp:
        return 'Picked Up';
      case OrderStatus.enRoute:
        return 'En Route';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Convert string to OrderStatus enum
  static OrderStatus fromString(String status) {
    return EnumHelpers.enumFromString(
      OrderStatus.values,
      status,
      defaultValue: OrderStatus.pending,
    );
  }
}

/// Represents a single item in an order with customizations
class OrderItem {
  final int? id;
  final int? orderId;
  final String menuItemName;
  final String? menuItemDescription;
  final int quantity;
  final double basePrice;
  final double totalPrice;
  final Map<String, dynamic>? customizations;
  final String? specialInstructions;
  final DateTime? createdAt;

  OrderItem({
    this.id,
    this.orderId,
    required this.menuItemName,
    this.menuItemDescription,
    required this.quantity,
    required this.basePrice,
    required this.totalPrice,
    this.customizations,
    this.specialInstructions,
    this.createdAt,
  });

  /// Create OrderItem from JSON (response from backend)
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as int?,
      orderId: JsonParsers.extractId(json['order_id']),
      // Handle menu_item_name which might be String or nested menuItem object with 'name' field
      menuItemName: JsonParsers.extractString(json['menu_item_name'], 'name') ??
                    JsonParsers.extractString(json['menuItem'], 'name') ??
                    JsonParsers.extractString(json['menu_item'], 'name') ?? '',
      // Handle menu_item_description which might be String or nested menuItem object with 'description' field
      menuItemDescription: JsonParsers.extractString(json['menu_item_description'], 'description') ??
                          JsonParsers.extractString(json['menuItem'], 'description') ??
                          JsonParsers.extractString(json['menu_item'], 'description'),
      quantity: json['quantity'] as int? ?? 1,
      basePrice: JsonParsers.parseDouble(json['price_at_time']) ?? 0.0,
      totalPrice: JsonParsers.parseDouble(json['line_total']) ?? 0.0,
      customizations: json['customizations'] != null
          ? (json['customizations'] is Map
              ? Map<String, dynamic>.from(json['customizations'] as Map)
              : null)
          : null,
      specialInstructions: null, // Backend doesn't store per-item special instructions
      createdAt: JsonParsers.parseDateTime(json['created_at']),
    );
  }

  /// Convert OrderItem to JSON (for sending to backend)
  /// Matches backend's CreateOrderItemRequest structure
  Map<String, dynamic> toJson() {
    return {
      'menu_item_name': menuItemName,
      if (menuItemDescription != null && menuItemDescription!.isNotEmpty)
        'menu_item_description': menuItemDescription,
      'price': basePrice,
      'quantity': quantity,
      if (customizations != null && customizations!.isNotEmpty)
        'customizations': customizations,
    };
  }

  /// Create a copy with updated fields
  OrderItem copyWith({
    int? id,
    int? orderId,
    String? menuItemName,
    String? menuItemDescription,
    int? quantity,
    double? basePrice,
    double? totalPrice,
    Map<String, dynamic>? customizations,
    String? specialInstructions,
    DateTime? createdAt,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      menuItemName: menuItemName ?? this.menuItemName,
      menuItemDescription: menuItemDescription ?? this.menuItemDescription,
      quantity: quantity ?? this.quantity,
      basePrice: basePrice ?? this.basePrice,
      totalPrice: totalPrice ?? this.totalPrice,
      customizations: customizations ?? this.customizations,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Represents a complete order
class Order {
  final int? id;
  final int customerId;
  final int restaurantId;
  final String? restaurantName;
  final int? deliveryAddressId;
  final OrderStatus status;
  final double subtotal;
  final double taxAmount;
  final double deliveryFee;
  final double totalAmount;
  final List<OrderItem> items;
  final String? specialInstructions;
  final String? cancellationReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? estimatedDeliveryTime;

  Order({
    this.id,
    required this.customerId,
    required this.restaurantId,
    this.restaurantName,
    this.deliveryAddressId,
    required this.status,
    required this.subtotal,
    required this.taxAmount,
    required this.deliveryFee,
    required this.totalAmount,
    required this.items,
    this.specialInstructions,
    this.cancellationReason,
    this.createdAt,
    this.updatedAt,
    this.estimatedDeliveryTime,
  });

  /// Create Order from JSON
  factory Order.fromJson(Map<String, dynamic> json) {
    // Helper to safely extract status as String
    String? extractStatus(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      if (value is Map<String, dynamic> && value.containsKey('status')) {
        return value['status'] as String?;
      }
      return null;
    }

    return Order(
      id: json['id'] as int?,
      // Handle customer_id which might be int or nested customer object
      customerId: JsonParsers.extractId(json['customer_id']) ?? 0,
      // Handle restaurant_id which might be int or nested restaurant object
      restaurantId: JsonParsers.extractId(json['restaurant_id']) ?? 0,
      // Handle restaurant_name which might be String or nested restaurant object with 'name' field
      restaurantName: JsonParsers.extractString(json['restaurant_name'], 'name') ??
                      JsonParsers.extractString(json['restaurant'], 'name'),
      // Handle delivery_address_id which might be int or nested address object
      deliveryAddressId: JsonParsers.extractId(json['delivery_address_id']),
      // Handle status which might be String or nested object
      status: OrderStatus.fromString(extractStatus(json['status']) ?? 'pending'),
      // Add null safety for numeric fields with fallbacks
      subtotal: JsonParsers.parseDouble(json['subtotal_amount']) ??
                JsonParsers.parseDouble(json['subtotal']) ?? 0.0,
      taxAmount: JsonParsers.parseDouble(json['tax_amount']) ?? 0.0,
      deliveryFee: JsonParsers.parseDouble(json['delivery_fee']) ?? 0.0,
      totalAmount: JsonParsers.parseDouble(json['total_amount']) ?? 0.0,
      items: JsonParsers.parseList(
        json,
        'items',
        (item) => OrderItem.fromJson(item),
      ),
      specialInstructions: JsonParsers.extractString(json['special_instructions'], 'text'),
      cancellationReason: JsonParsers.extractString(json['cancellation_reason'], 'text'),
      createdAt: JsonParsers.parseDateTimeWithNullable(json['created_at']),
      updatedAt: JsonParsers.parseDateTimeWithNullable(json['updated_at']),
      estimatedDeliveryTime: JsonParsers.parseDateTimeWithNullable(json['estimated_delivery_time']),
    );
  }

  /// Convert Order to JSON (for sending to backend)
  /// Matches backend's CreateOrderRequest structure
  Map<String, dynamic> toJson() {
    return {
      'restaurant_id': restaurantId,
      'delivery_address_id': deliveryAddressId,
      if (specialInstructions != null && specialInstructions!.isNotEmpty)
        'special_instructions': specialInstructions,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  /// Create a copy with updated fields
  Order copyWith({
    int? id,
    int? customerId,
    int? restaurantId,
    String? restaurantName,
    int? deliveryAddressId,
    OrderStatus? status,
    double? subtotal,
    double? taxAmount,
    double? deliveryFee,
    double? totalAmount,
    List<OrderItem>? items,
    String? specialInstructions,
    String? cancellationReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? estimatedDeliveryTime,
  }) {
    return Order(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      deliveryAddressId: deliveryAddressId ?? this.deliveryAddressId,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      totalAmount: totalAmount ?? this.totalAmount,
      items: items ?? this.items,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
    );
  }

  /// Check if order can be cancelled
  bool get canBeCancelled {
    return status == OrderStatus.pending ||
        status == OrderStatus.confirmed ||
        status == OrderStatus.preparing;
  }

  /// Check if order is active (not completed or cancelled)
  bool get isActive {
    return status != OrderStatus.delivered &&
        status != OrderStatus.cancelled;
  }

  /// Get total item count
  int get totalItemCount {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }
}
