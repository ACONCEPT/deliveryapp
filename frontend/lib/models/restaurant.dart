class Restaurant {
  final int? id;
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
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      isActive: json['is_active'] as bool? ?? true,
      rating: json['rating'] != null
          ? (json['rating'] as num).toDouble()
          : 0.0,
      totalOrders: json['total_orders'] as int? ?? 0,
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

  // Helper method to get formatted full address string
  String get fullAddress {
    final parts = <String>[
      if (addressLine1 != null && addressLine1!.isNotEmpty) addressLine1!,
      if (addressLine2 != null && addressLine2!.isNotEmpty) addressLine2!,
      if (city != null && city!.isNotEmpty) city!,
      if (state != null && state!.isNotEmpty) state!,
      if (postalCode != null && postalCode!.isNotEmpty) postalCode!,
      if (country != null && country!.isNotEmpty) country!,
    ];
    return parts.join(', ');
  }

  // Helper method to get short address string (city, state only)
  String get shortAddress {
    final parts = <String>[
      if (city != null && city!.isNotEmpty) city!,
      if (state != null && state!.isNotEmpty) state!,
    ];
    return parts.join(', ');
  }

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
