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
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
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
