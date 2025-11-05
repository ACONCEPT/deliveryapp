import 'base/json_parsers.dart';

class VendorRestaurant {
  final int? id;
  final int vendorId;
  final int restaurantId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  VendorRestaurant({
    this.id,
    required this.vendorId,
    required this.restaurantId,
    this.createdAt,
    this.updatedAt,
  });

  factory VendorRestaurant.fromJson(Map<String, dynamic> json) {
    return VendorRestaurant(
      id: json['id'] as int?,
      vendorId: json['vendor_id'] as int,
      restaurantId: json['restaurant_id'] as int,
      createdAt: JsonParsers.parseDateTime(json['created_at']),
      updatedAt: JsonParsers.parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'vendor_id': vendorId,
      'restaurant_id': restaurantId,
    };
  }
}
