class CreateRestaurantRequest {
  final String name;
  final String? description;
  final String? phone;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final double? latitude;
  final double? longitude;
  final bool? isActive;
  final double? rating;
  final int? totalOrders;

  CreateRestaurantRequest({
    required this.name,
    this.description,
    this.phone,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.latitude,
    this.longitude,
    this.isActive,
    this.rating,
    this.totalOrders,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null) 'description': description,
      if (phone != null) 'phone': phone,
      if (addressLine1 != null) 'address_line1': addressLine1,
      if (addressLine2 != null) 'address_line2': addressLine2,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (postalCode != null) 'postal_code': postalCode,
      if (country != null) 'country': country,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (isActive != null) 'is_active': isActive,
      if (rating != null) 'rating': rating,
      if (totalOrders != null) 'total_orders': totalOrders,
    };
  }
}

class UpdateRestaurantRequest {
  final String? name;
  final String? description;
  final String? phone;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final double? latitude;
  final double? longitude;
  final bool? isActive;
  final double? rating;
  final int? totalOrders;

  UpdateRestaurantRequest({
    this.name,
    this.description,
    this.phone,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.latitude,
    this.longitude,
    this.isActive,
    this.rating,
    this.totalOrders,
  });

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (phone != null) 'phone': phone,
      if (addressLine1 != null) 'address_line1': addressLine1,
      if (addressLine2 != null) 'address_line2': addressLine2,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (postalCode != null) 'postal_code': postalCode,
      if (country != null) 'country': country,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (isActive != null) 'is_active': isActive,
      if (rating != null) 'rating': rating,
      if (totalOrders != null) 'total_orders': totalOrders,
    };
  }
}
