import 'dart:convert';
import 'dart:developer' as developer;
import '../models/restaurant.dart';
import '../models/restaurant_request.dart';
import 'base_service.dart';

class RestaurantService extends BaseService {
  @override
  String get serviceName => 'RestaurantService';

  // Get all restaurants
  Future<List<Restaurant>> getRestaurants(String token) {
    return getList(
      '/api/restaurants',
      'restaurants',
      Restaurant.fromJson,
      token: token,
    );
  }

  // Get a specific restaurant by ID
  Future<Restaurant> getRestaurant(String token, int id) {
    return getObject(
      '/api/restaurants/$id',
      'restaurant',
      Restaurant.fromJson,
      token: token,
    );
  }

  // Get restaurant owner information
  Future<Map<String, dynamic>> getRestaurantOwner(String token, int restaurantId) async {
    try {
      final response = await httpClient.get(
        '/api/restaurants/$restaurantId/owner',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        developer.log('Parsed JSON: $data', name: serviceName);
        return data as Map<String, dynamic>;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load restaurant owner');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in getRestaurantOwner',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Create a new restaurant (vendor endpoint)
  Future<Restaurant> createRestaurant(String token, CreateRestaurantRequest request) {
    return postObject(
      '/api/vendor/restaurants',
      'restaurant',
      request.toJson(),
      Restaurant.fromJson,
      token: token,
    );
  }

  // Update an existing restaurant (vendor endpoint)
  Future<Restaurant> updateRestaurant(String token, int id, UpdateRestaurantRequest request) {
    return putObject(
      '/api/vendor/restaurants/$id',
      'restaurant',
      request.toJson(),
      Restaurant.fromJson,
      token: token,
    );
  }

  // Delete a restaurant (vendor endpoint)
  Future<void> deleteRestaurant(String token, int id) {
    return deleteResource('/api/vendor/restaurants/$id', token: token);
  }

  // ============================================================================
  // Admin-specific methods
  // ============================================================================

  // Get all vendor-restaurant associations (admin endpoint)
  Future<List<Map<String, dynamic>>> getVendorRestaurants(String token) async {
    try {
      final response = await httpClient.get(
        '/api/admin/vendor-restaurants',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        developer.log('Parsed JSON: $data', name: serviceName);

        final vendorRestaurantsData = data['vendor_restaurants'];
        if (vendorRestaurantsData == null) {
          developer.log('Vendor restaurants field is null, returning empty list', name: serviceName);
          return [];
        }

        if (vendorRestaurantsData is! List) {
          developer.log('Vendor restaurants field is not a List: $vendorRestaurantsData', name: serviceName);
          return [];
        }

        developer.log('Found ${vendorRestaurantsData.length} vendor-restaurant associations', name: serviceName);

        return vendorRestaurantsData.map((json) => json as Map<String, dynamic>).toList();
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load vendor restaurants');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in getVendorRestaurants',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Get a specific vendor-restaurant association by ID (admin endpoint)
  Future<Map<String, dynamic>> getVendorRestaurant(String token, int id) async {
    try {
      final response = await httpClient.get(
        '/api/admin/vendor-restaurants/$id',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        developer.log('Parsed JSON: $data', name: serviceName);
        return data as Map<String, dynamic>;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load vendor restaurant');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in getVendorRestaurant',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Delete a vendor-restaurant association (admin endpoint)
  Future<void> deleteVendorRestaurant(String token, int id) {
    return deleteResource('/api/admin/vendor-restaurants/$id', token: token);
  }

  // Transfer restaurant ownership to a new vendor (admin endpoint)
  Future<void> transferRestaurantOwnership(String token, int restaurantId, int newVendorId) {
    return executeVoidOperation(
      () => httpClient.put(
        '/api/admin/restaurants/$restaurantId/transfer',
        headers: authHeaders(token),
        body: {'new_vendor_id': newVendorId},
      ),
      'transfer restaurant ownership',
    );
  }
}
