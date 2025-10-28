import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

/// Represents an address suggestion from Nominatim API
class AddressSuggestion {
  final String placeId;
  final String displayName;
  final double lat;
  final double lon;
  final String? houseNumber;
  final String? road;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final String? countryCode;
  final String type;

  AddressSuggestion({
    required this.placeId,
    required this.displayName,
    required this.lat,
    required this.lon,
    this.houseNumber,
    this.road,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.countryCode,
    required this.type,
  });

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>? ?? {};

    // Debug logging to see what we're getting from Nominatim
    developer.log(
      '📍 Parsing address suggestion',
      name: 'AddressSuggestion',
      error: 'Display: ${json['display_name']}\n'
          'House#: ${address['house_number']}\n'
          'Road: ${address['road']}\n'
          'City: ${address['city'] ?? address['town'] ?? address['village']}\n'
          'State: ${address['state']}\n'
          'Postal: ${address['postcode']}',
    );

    return AddressSuggestion(
      placeId: json['place_id']?.toString() ?? '',
      displayName: json['display_name'] as String? ?? '',
      lat: double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      lon: double.tryParse(json['lon']?.toString() ?? '0') ?? 0.0,
      houseNumber: address['house_number'] as String?,
      road: address['road'] as String?,
      city: address['city'] as String? ??
          address['town'] as String? ??
          address['village'] as String?,
      state: address['state'] as String?,
      postalCode: address['postcode'] as String?,
      country: address['country'] as String?,
      countryCode: address['country_code'] as String?,
      type: json['type'] as String? ?? 'unknown',
    );
  }

  /// Get the street address (combination of house number and road)
  String get street {
    // Try to build a complete street address from available components
    final List<String> parts = [];

    if (houseNumber != null && houseNumber!.isNotEmpty) {
      parts.add(houseNumber!);
    }

    if (road != null && road!.isNotEmpty) {
      parts.add(road!);
    }

    // If we have parts, join them
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }

    // Fallback: try to extract street from display_name
    // Format is often: "house_number road, city, state postal_code, country"
    final displayParts = displayName.split(',');
    if (displayParts.isNotEmpty) {
      return displayParts[0].trim();
    }

    return '';
  }

  /// Get a short description of the address type
  String get typeDescription {
    switch (type) {
      case 'restaurant':
      case 'cafe':
      case 'fast_food':
        return 'Restaurant';
      case 'building':
        return 'Building';
      case 'house':
        return 'House';
      case 'road':
      case 'highway':
        return 'Road';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }
}

/// Service for interacting with OpenStreetMap Nominatim API
class NominatimService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'DeliveryApp/1.0';

  /// Search for address suggestions based on user input
  ///
  /// [query] - The search query string
  /// [limit] - Maximum number of results to return (default: 5)
  /// [countryCode] - Optional country code to restrict results (e.g., 'us', 'ca')
  ///
  /// Returns a list of address suggestions
  Future<List<AddressSuggestion>> searchAddress(
    String query, {
    int limit = 5,
    String? countryCode,
  }) async {
    try {
      // Nominatim requires at least 3 characters
      if (query.trim().length < 3) {
        return [];
      }

      // Build query parameters
      final params = {
        'q': query.trim(),
        'format': 'json',
        'addressdetails': '1',
        'limit': limit.toString(),
      };

      if (countryCode != null && countryCode.isNotEmpty) {
        params['countrycodes'] = countryCode.toLowerCase();
      }

      final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: params);

      developer.log(
        '🌍 Nominatim Search Request',
        name: 'NominatimService',
        error: 'Query: "$query", Limit: $limit, Country: ${countryCode ?? 'any'}',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      developer.log(
        '🌍 Nominatim Response: ${response.statusCode}',
        name: 'NominatimService',
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);

        developer.log(
          '✅ Found ${results.length} address suggestions',
          name: 'NominatimService',
        );

        final suggestions = results
            .map((json) => AddressSuggestion.fromJson(json as Map<String, dynamic>))
            .toList();

        // Sort suggestions to prioritize those with house numbers
        suggestions.sort((a, b) {
          // If both have house numbers, keep original order (relevance)
          if (a.houseNumber != null && b.houseNumber != null) return 0;
          // Prioritize results with house numbers
          if (a.houseNumber != null && b.houseNumber == null) return -1;
          if (a.houseNumber == null && b.houseNumber != null) return 1;
          return 0;
        });

        return suggestions;
      } else {
        developer.log(
          '❌ Nominatim API error: ${response.statusCode}',
          name: 'NominatimService',
          error: response.body,
        );
        return [];
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error searching address',
        name: 'NominatimService',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Reverse geocode coordinates to an address
  ///
  /// [lat] - Latitude
  /// [lon] - Longitude
  ///
  /// Returns an address suggestion or null if not found
  Future<AddressSuggestion?> reverseGeocode(double lat, double lon) async {
    try {
      final params = {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'format': 'json',
        'addressdetails': '1',
      };

      final uri = Uri.parse('$_baseUrl/reverse').replace(queryParameters: params);

      developer.log(
        '🌍 Nominatim Reverse Geocode',
        name: 'NominatimService',
        error: 'Lat: $lat, Lon: $lon',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;

        developer.log(
          '✅ Reverse geocode successful',
          name: 'NominatimService',
        );

        return AddressSuggestion.fromJson(json);
      } else {
        developer.log(
          '❌ Reverse geocode failed: ${response.statusCode}',
          name: 'NominatimService',
        );
        return null;
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error reverse geocoding',
        name: 'NominatimService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
