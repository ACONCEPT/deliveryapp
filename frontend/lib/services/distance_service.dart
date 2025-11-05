import 'dart:convert';
import 'dart:developer' as developer;
import '../models/distance.dart';
import 'base_service.dart';

/// Service for calculating distance and duration between addresses and restaurants
/// Uses backend distance API which integrates with Mapbox Directions API
class DistanceService extends BaseService {
  @override
  String get serviceName => 'DistanceService';

  /// Calculate distance and duration between customer address and restaurant
  /// POST /api/distance/estimate
  ///
  /// [token] Bearer authentication token
  /// [addressId] Customer address ID (must have valid coordinates)
  /// [restaurantId] Restaurant ID (must have valid coordinates)
  ///
  /// Returns [DistanceEstimate] with distance and duration information
  /// Throws exception on error (missing coordinates, rate limit, network error)
  Future<DistanceEstimate> calculateDistance({
    required String token,
    required int addressId,
    required int restaurantId,
  }) async {
    try {
      developer.log(
        'Calculating distance: address_id=$addressId, restaurant_id=$restaurantId',
        name: serviceName,
      );

      final response = await httpClient.post(
        '/api/distance/estimate',
        headers: authHeaders(token),
        body: {
          'address_id': addressId,
          'restaurant_id': restaurantId,
        },
      );

      developer.log(
        'Distance API response status: ${response.statusCode}',
        name: serviceName,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

        // Backend returns: {success: true, message: "...", data: {...}}
        if (jsonResponse['success'] == true && jsonResponse.containsKey('data')) {
          final data = jsonResponse['data'] as Map<String, dynamic>;
          final estimate = DistanceEstimate.fromJson(data);

          developer.log(
            'Distance calculated successfully: ${estimate.distance.miles} miles, ${estimate.duration.text}',
            name: serviceName,
          );

          return estimate;
        } else {
          final message = jsonResponse['message'] ?? 'Unknown error';
          throw Exception('Distance calculation failed: $message');
        }
      } else if (response.statusCode == 429) {
        // Rate limit exceeded
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Rate limit exceeded. Please try again later.');
      } else if (response.statusCode == 400) {
        // Bad request (missing coordinates, invalid IDs)
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Invalid request');
      } else if (response.statusCode == 404) {
        // Address or restaurant not found
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Address or restaurant not found');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to calculate distance');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error calculating distance',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Calculate distance with automatic retry on transient errors
  /// Useful for improving reliability in production
  Future<DistanceEstimate?> calculateDistanceWithRetry({
    required String token,
    required int addressId,
    required int restaurantId,
    int maxRetries = 2,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await calculateDistance(
          token: token,
          addressId: addressId,
          restaurantId: restaurantId,
        );
      } catch (e) {
        developer.log(
          'Distance calculation attempt $attempt/$maxRetries failed: $e',
          name: serviceName,
        );

        if (attempt >= maxRetries) {
          // Last attempt failed, return null instead of throwing
          developer.log(
            'All distance calculation attempts exhausted',
            name: serviceName,
          );
          return null;
        }

        // Wait before retrying (exponential backoff)
        await Future.delayed(Duration(seconds: attempt));
      }
    }

    return null;
  }

  /// Safely calculate distance, returning null on any error
  /// Use this when distance is optional/nice-to-have
  Future<DistanceEstimate?> calculateDistanceSafe({
    required String token,
    required int addressId,
    required int restaurantId,
  }) async {
    try {
      return await calculateDistance(
        token: token,
        addressId: addressId,
        restaurantId: restaurantId,
      );
    } catch (e) {
      developer.log(
        'Distance calculation failed (safe mode, returning null): $e',
        name: serviceName,
      );
      return null;
    }
  }
}
