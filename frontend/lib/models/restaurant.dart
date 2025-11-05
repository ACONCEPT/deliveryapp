import 'base/json_parsers.dart';
import 'base/location_mixin.dart';

class Restaurant with LocationFormatterMixin {
  final int? id;
  final String name;
  final String? description;
  final String? phone;
  @override
  final String? addressLine1;
  @override
  final String? addressLine2;
  @override
  final String? city;
  @override
  final String? state;
  final String? postalCode;
  final String? country;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  final double rating;
  final int totalOrders;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Restaurant({
    this.id,
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
    this.isActive = true,
    this.rating = 0.0,
    this.totalOrders = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as int?,
      name: json['name'] as String,
      description: json['description'] as String?,
      phone: json['phone'] as String?,
      addressLine1: json['address_line1'] as String?,
      addressLine2: json['address_line2'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String?,
      latitude: JsonParsers.parseDouble(json['latitude']),
      longitude: JsonParsers.parseDouble(json['longitude']),
      isActive: json['is_active'] as bool? ?? true,
      rating: JsonParsers.parseDoubleWithDefault(json['rating'], 0.0),
      totalOrders: json['total_orders'] as int? ?? 0,
      createdAt: JsonParsers.parseDateTime(json['created_at']),
      updatedAt: JsonParsers.parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'phone': phone,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'is_active': isActive,
      'rating': rating,
      'total_orders': totalOrders,
    };
  }

  // Implement LocationFormatterMixin getters
  @override
  String? get zipCode => postalCode;

  // Helper method to get formatted full address string using mixin
  String get fullAddress => formatFullAddress();

  // Helper method to get short address string (city, state only) using mixin
  String get shortAddress => formatLocation();

  Restaurant copyWith({
    int? id,
    String? name,
    String? description,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    double? latitude,
    double? longitude,
    bool? isActive,
    double? rating,
    int? totalOrders,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Restaurant(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isActive: isActive ?? this.isActive,
      rating: rating ?? this.rating,
      totalOrders: totalOrders ?? this.totalOrders,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
