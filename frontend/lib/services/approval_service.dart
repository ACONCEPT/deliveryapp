import 'dart:convert';
import 'dart:developer' as developer;
import '../models/approval.dart';
import 'base_service.dart';

/// Service for admin approval operations
///
/// Handles API communication for vendor and restaurant approval workflows,
/// including fetching pending items, approving/rejecting entities, and
/// retrieving approval history and dashboard statistics.
class ApprovalService extends BaseService {
  @override
  String get serviceName => 'ApprovalService';

  /// Get approval dashboard statistics
  ///
  /// Returns summary counts of pending, approved, and rejected vendors/restaurants.
  /// Requires admin authentication token.
  Future<ApprovalDashboardStats> getDashboardStats(String token) async {
    try {
      final response = await httpClient.get(
        '/api/admin/approvals/dashboard',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        // Extract 'data' field from wrapped response
        final data = responseData['data'] as Map<String, dynamic>;
        return ApprovalDashboardStats.fromJson(data);
      } else {
        throw Exception('Failed to load dashboard stats: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in getDashboardStats',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all pending vendors awaiting approval
  ///
  /// Returns list of vendors with pending approval status.
  /// Requires admin authentication token.
  Future<List<VendorWithApproval>> getPendingVendors(String token) async {
    try {
      final response = await httpClient.get(
        '/api/admin/approvals/vendors',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle both array and object with data field
        List<dynamic> vendorsJson;
        if (data is List) {
          vendorsJson = data;
        } else if (data is Map && data['vendors'] != null) {
          vendorsJson = data['vendors'] as List;
        } else if (data is Map && data['data'] != null) {
          vendorsJson = data['data'] as List;
        } else {
          vendorsJson = [];
        }

        return vendorsJson
            .map((json) => VendorWithApproval.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load pending vendors: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in getPendingVendors',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all pending restaurants awaiting approval
  ///
  /// Returns list of restaurants with pending approval status.
  /// Requires admin authentication token.
  Future<List<RestaurantWithApproval>> getPendingRestaurants(String token) async {
    try {
      final response = await httpClient.get(
        '/api/admin/approvals/restaurants',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle both array and object with data field
        List<dynamic> restaurantsJson;
        if (data is List) {
          restaurantsJson = data;
        } else if (data is Map && data['restaurants'] != null) {
          restaurantsJson = data['restaurants'] as List;
        } else if (data is Map && data['data'] != null) {
          restaurantsJson = data['data'] as List;
        } else {
          restaurantsJson = [];
        }

        return restaurantsJson
            .map((json) => RestaurantWithApproval.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load pending restaurants: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in getPendingRestaurants',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Approve a vendor
  ///
  /// Approves the vendor with the given [vendorId].
  /// Optional [reason] can be provided for approval notes.
  /// Requires admin authentication token.
  Future<void> approveVendor(String token, int vendorId, {String? reason}) {
    return executeVoidOperation(
      () => httpClient.put(
        '/api/admin/vendors/$vendorId/approve',
        headers: authHeaders(token),
        body: ApprovalActionRequest(reason: reason).toJson(),
      ),
      'approve vendor',
    );
  }

  /// Reject a vendor with a reason
  ///
  /// Rejects the vendor with the given [vendorId].
  /// [reason] is required for rejection to explain the decision.
  /// Requires admin authentication token.
  Future<void> rejectVendor(String token, int vendorId, {required String reason}) {
    return executeVoidOperation(
      () => httpClient.put(
        '/api/admin/vendors/$vendorId/reject',
        headers: authHeaders(token),
        body: ApprovalActionRequest(reason: reason).toJson(),
      ),
      'reject vendor',
    );
  }

  /// Approve a restaurant
  ///
  /// Approves the restaurant with the given [restaurantId].
  /// Optional [reason] can be provided for approval notes.
  /// Requires admin authentication token.
  Future<void> approveRestaurant(String token, int restaurantId, {String? reason}) {
    return executeVoidOperation(
      () => httpClient.put(
        '/api/admin/restaurants/$restaurantId/approve',
        headers: authHeaders(token),
        body: ApprovalActionRequest(reason: reason).toJson(),
      ),
      'approve restaurant',
    );
  }

  /// Reject a restaurant with a reason
  ///
  /// Rejects the restaurant with the given [restaurantId].
  /// [reason] is required for rejection to explain the decision.
  /// Requires admin authentication token.
  Future<void> rejectRestaurant(String token, int restaurantId, {required String reason}) {
    return executeVoidOperation(
      () => httpClient.put(
        '/api/admin/restaurants/$restaurantId/reject',
        headers: authHeaders(token),
        body: ApprovalActionRequest(reason: reason).toJson(),
      ),
      'reject restaurant',
    );
  }

  /// Get approval history for a specific entity
  ///
  /// Returns list of approval actions for the given entity.
  /// [entityType] should be "vendor" or "restaurant".
  /// Requires admin authentication token.
  Future<List<ApprovalHistory>> getApprovalHistory(
      String token, String entityType, int entityId) async {
    try {
      final response = await httpClient.get(
        '/api/admin/approvals/history?entity_type=$entityType&entity_id=$entityId',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle both array and object with data field
        List<dynamic> historyJson;
        if (data is List) {
          historyJson = data;
        } else if (data is Map && data['history'] != null) {
          historyJson = data['history'] as List;
        } else if (data is Map && data['data'] != null) {
          historyJson = data['data'] as List;
        } else {
          historyJson = [];
        }

        return historyJson
            .map((json) => ApprovalHistory.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load approval history: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in getApprovalHistory',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
