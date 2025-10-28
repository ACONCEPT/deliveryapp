import 'dart:convert';
import 'dart:developer' as developer;
import '../models/menu.dart';
import 'base_service.dart';

/// Menu Service
///
/// Handles all menu-related API operations for both vendor and customer users.
/// Vendor operations: Create, update, delete menus and manage restaurant assignments.
/// Customer operations: View active menus for restaurants.
class MenuService extends BaseService {
  @override
  String get serviceName => 'MenuService';

  // ============================================================================
  // Vendor Operations
  // ============================================================================

  /// Create a new menu
  ///
  /// POST /api/vendor/menus
  /// Returns the created menu with assigned ID
  Future<Menu> createMenu(String token, Menu menu) {
    return postObject(
      '/api/vendor/menus',
      'menu',
      menu.toJson(),
      Menu.fromJson,
      token: token,
    );
  }

  /// Get all menus for the authenticated vendor
  ///
  /// GET /api/vendor/menus
  /// Optional restaurantId filter to get menus assigned to a specific restaurant
  Future<List<Menu>> getVendorMenus(String token, {int? restaurantId}) {
    var path = '/api/vendor/menus';
    if (restaurantId != null) {
      path += '?restaurant_id=$restaurantId';
    }

    return getList(
      path,
      'menus',
      Menu.fromJson,
      token: token,
    );
  }

  /// Get a single menu by ID
  ///
  /// GET /api/vendor/menus/{id}
  /// Returns the menu with full details including categories and items
  Future<Menu> getMenu(String token, int menuId) {
    return getObject(
      '/api/vendor/menus/$menuId',
      'menu',
      Menu.fromJson,
      token: token,
    );
  }

  /// Update an existing menu
  ///
  /// PUT /api/vendor/menus/{id}
  /// Returns the updated menu
  /// Accepts either a full Menu object or an UpdateMenuRequest for partial updates
  Future<Menu> updateMenu(String token, int menuId, dynamic menuData) async {
    // Support both Menu and UpdateMenuRequest
    final body = menuData is Menu ? menuData.toJson() : (menuData as UpdateMenuRequest).toJson();

    return putObject(
      '/api/vendor/menus/$menuId',
      'menu',
      body,
      Menu.fromJson,
      token: token,
    );
  }

  /// Delete a menu
  ///
  /// DELETE /api/vendor/menus/{id}
  /// No return value on success
  Future<void> deleteMenu(String token, int menuId) {
    return deleteResource('/api/vendor/menus/$menuId', token: token);
  }

  /// Assign a menu to a restaurant
  ///
  /// POST /api/vendor/restaurants/{restaurantId}/menus/{menuId}
  /// Optional parameters for isActive and displayOrder
  Future<void> assignMenuToRestaurant(
    String token,
    int restaurantId,
    int menuId, {
    bool isActive = false,
    int displayOrder = 0,
  }) {
    return executeVoidOperation(
      () => httpClient.post(
        '/api/vendor/restaurants/$restaurantId/menus/$menuId',
        headers: authHeaders(token),
        body: {
          'is_active': isActive,
          'display_order': displayOrder,
        },
      ),
      'assign menu to restaurant',
    );
  }

  /// Unassign a menu from a restaurant
  ///
  /// DELETE /api/vendor/restaurants/{restaurantId}/menus/{menuId}
  /// No return value on success
  Future<void> unassignMenuFromRestaurant(
    String token,
    int restaurantId,
    int menuId,
  ) {
    return deleteResource(
      '/api/vendor/restaurants/$restaurantId/menus/$menuId',
      token: token,
    );
  }

  /// Set a menu as the active menu for a restaurant
  ///
  /// PUT /api/vendor/restaurants/{restaurantId}/active-menu
  /// This will set the specified menu as active and deactivate all other menus
  Future<void> setActiveMenu(
    String token,
    int restaurantId,
    int menuId,
  ) {
    return executeVoidOperation(
      () => httpClient.put(
        '/api/vendor/restaurants/$restaurantId/active-menu',
        headers: authHeaders(token),
        body: {'menu_id': menuId},
      ),
      'set active menu',
    );
  }

  // ============================================================================
  // Admin Operations
  // ============================================================================

  /// Get all menus in the system (admin only)
  ///
  /// GET /api/admin/menus
  /// Optional filters for vendorId and restaurantId
  Future<List<Menu>> getAdminMenus(
    String token, {
    int? vendorId,
    int? restaurantId,
  }) {
    var path = '/api/admin/menus';
    final queryParams = <String>[];
    if (vendorId != null) {
      queryParams.add('vendor_id=$vendorId');
    }
    if (restaurantId != null) {
      queryParams.add('restaurant_id=$restaurantId');
    }
    if (queryParams.isNotEmpty) {
      path += '?${queryParams.join('&')}';
    }

    return getList(
      path,
      'menus',
      Menu.fromJson,
      token: token,
    );
  }

  // ============================================================================
  // Customer Operations
  // ============================================================================

  /// Get the active menu for a restaurant (customer view)
  ///
  /// GET /api/restaurants/{restaurantId}/menu
  /// Returns null if no active menu is assigned (404 response)
  /// Throws exception for other errors
  Future<Menu?> getRestaurantMenu(String token, int restaurantId) async {
    try {
      final response = await httpClient.get(
        '/api/restaurants/$restaurantId/menu',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        developer.log('Parsed JSON: $data', name: serviceName);
        return Menu.fromJson(data['menu'] as Map<String, dynamic>);
      } else if (response.statusCode == 404) {
        // No active menu for this restaurant - this is expected, return null
        developer.log('No active menu found for restaurant $restaurantId', name: serviceName);
        return null;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load restaurant menu');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in getRestaurantMenu',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
