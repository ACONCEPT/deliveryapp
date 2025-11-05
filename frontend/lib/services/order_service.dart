import 'dart:convert';
import 'dart:developer' as developer;
import '../models/order.dart';
import 'base_service.dart';

/// Service for managing orders via backend API
/// Handles order creation, retrieval, cancellation, and status updates
class OrderService extends BaseService {
  @override
  String get serviceName => 'OrderService';

  /// Helper method to convert OrderStatus enum to backend string format
  String _statusToString(OrderStatus status) {
    if (status == OrderStatus.pickedUp) {
      return 'picked_up';
    } else if (status == OrderStatus.enRoute) {
      return 'in_transit';
    }
    return status.toString().split('.').last;
  }

  /// Helper method to parse complex order response with items merging
  Order _parseOrderResponse(Map<String, dynamic> jsonResponse) {
    try {
      // Backend returns: {success, message, data: {order, items, status_history}}
      // We need to merge order and items before passing to Order.fromJson
      if (jsonResponse.containsKey('data')) {
        final data = jsonResponse['data'] as Map<String, dynamic>;

        // Extract order object and items array
        if (data.containsKey('order') && data.containsKey('items')) {
          final orderData = Map<String, dynamic>.from(
              data['order'] as Map<String, dynamic>);
          orderData['items'] = data['items']; // Merge items into order
          return Order.fromJson(orderData);
        }

        // If data already has the right structure, use it directly
        return Order.fromJson(data);
      }

      // Fallback: try to parse directly (for backwards compatibility)
      return Order.fromJson(jsonResponse);
    } catch (e, stackTrace) {
      developer.log('❌ PARSING ERROR:',
          name: serviceName, error: e, stackTrace: stackTrace, level: 1000);
      developer.log('Full Response:', name: serviceName, level: 1000);
      developer.log(JsonEncoder.withIndent('  ').convert(jsonResponse),
          name: serviceName, level: 1000);
      rethrow;
    }
  }

  /// Helper method to parse order list responses with multiple wrapper formats
  List<Order> _parseOrderListResponse(dynamic jsonResponse) {
    List<dynamic> ordersJson;
    if (jsonResponse is List) {
      ordersJson = jsonResponse;
    } else if (jsonResponse is Map && jsonResponse.containsKey('orders')) {
      ordersJson = jsonResponse['orders'] as List;
    } else if (jsonResponse is Map && jsonResponse.containsKey('data')) {
      final data = jsonResponse['data'];
      if (data is Map && data.containsKey('orders')) {
        ordersJson = data['orders'] as List;
      } else if (data is List) {
        ordersJson = data;
      } else {
        ordersJson = [];
      }
    } else {
      ordersJson = [];
    }

    developer.log('Found ${ordersJson.length} orders', name: serviceName);
    return ordersJson
        .map((json) => Order.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // ==================== CUSTOMER ORDER METHODS ====================

  /// Create a new order
  /// POST /api/customer/orders
  Future<Order> createOrder(Order order) async {
    try {
      developer.log('Creating order with data: ${order.toJson()}',
          name: serviceName);

      final response = await httpClient.post(
        '/api/customer/orders',
        body: order.toJson(),
      );

      developer.log('Order creation response status: ${response.statusCode}',
          name: serviceName);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

        // Backend returns: {success, message, data: {order_id, total_amount, status}}
        // We need to construct a partial Order object from the limited response
        final data = jsonResponse['data'] as Map<String, dynamic>;

        final createdOrder = Order(
          id: data['order_id'] as int,
          customerId: order.customerId,
          restaurantId: order.restaurantId,
          restaurantName: order.restaurantName,
          deliveryAddressId: order.deliveryAddressId,
          status: OrderStatus.fromString(data['status'] as String),
          subtotal: order.subtotal,
          taxAmount: order.taxAmount,
          deliveryFee: order.deliveryFee,
          totalAmount: (data['total_amount'] as num).toDouble(),
          items: order.items,
          specialInstructions: order.specialInstructions,
          createdAt: DateTime.now(),
        );

        developer.log('Successfully created Order object with ID: ${createdOrder.id}',
            name: serviceName);
        return createdOrder;
      } else {
        final errorMsg =
            'Failed to create order. Status: ${response.statusCode}, Body: ${response.body}';
        developer.log(errorMsg, name: serviceName, level: 1000);
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error creating order: $e',
          name: serviceName, error: e, stackTrace: stackTrace, level: 1000);
      rethrow;
    }
  }

  /// Get list of customer's orders
  /// GET /api/customer/orders
  Future<List<Order>> getCustomerOrders() async {
    try {
      developer.log('Getting customer orders...', name: serviceName);
      final response = await httpClient.get('/api/customer/orders');

      developer.log('Response status: ${response.statusCode}',
          name: serviceName);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return _parseOrderListResponse(jsonResponse);
      } else {
        throw Exception(
            'Failed to get orders. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error getting orders: $e',
          name: serviceName, error: e, stackTrace: stackTrace, level: 1000);
      rethrow;
    }
  }

  /// Get order details by ID
  /// GET /api/customer/orders/{id}
  Future<Order> getOrderById(int orderId) async {
    try {
      developer.log('🔍 Fetching order by ID: $orderId', name: serviceName);

      final response = await httpClient.get('/api/customer/orders/$orderId');

      developer.log('📡 Response status: ${response.statusCode}',
          name: serviceName);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        developer.log('📦 Raw JSON Response:', name: serviceName);
        developer.log(JsonEncoder.withIndent('  ').convert(jsonResponse),
            name: serviceName);

        return _parseOrderResponse(jsonResponse);
      } else {
        throw Exception(
            'Failed to get order. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error getting order: $e',
          name: serviceName, error: e, stackTrace: stackTrace, level: 1000);
      rethrow;
    }
  }

  /// Cancel an order
  /// PUT /api/customer/orders/{id}/cancel
  /// Returns the updated order after cancellation
  /// Note: reason is REQUIRED by the API (minLength: 1, maxLength: 500)
  Future<Order> cancelOrder(int orderId, {required String reason}) async {
    try {
      final response = await httpClient.put(
        '/api/customer/orders/$orderId/cancel',
        body: {'reason': reason},
      );

      if (response.statusCode == 200) {
        // Backend returns success but no order data
        // Refetch the order to get updated status
        return await getOrderById(orderId);
      } else {
        throw Exception(
            'Failed to cancel order. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e, stackTrace) {
      developer.log('Error cancelling order: $e',
          name: serviceName, error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ==================== VENDOR ORDER METHODS ====================

  /// Get vendor's orders with optional status filtering
  /// GET /api/vendor/orders?status={status}
  Future<List<Order>> getVendorOrders({
    OrderStatus? statusFilter,
    int page = 1,
    int perPage = 100,
  }) async {
    try {
      developer.log('Getting vendor orders...', name: serviceName);

      // Build query parameters
      String queryParams = '?page=$page&per_page=$perPage';
      if (statusFilter != null) {
        String statusString = _statusToString(statusFilter);
        queryParams += '&status=$statusString';
        developer.log('Filtering by status: $statusString', name: serviceName);
      }

      final response = await httpClient.get('/api/vendor/orders$queryParams');

      developer.log('Response status: ${response.statusCode}',
          name: serviceName);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return _parseOrderListResponse(jsonResponse);
      } else {
        throw Exception(
            'Failed to get vendor orders. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error getting vendor orders: $e',
          name: serviceName, error: e, stackTrace: stackTrace, level: 1000);
      rethrow;
    }
  }

  /// Get vendor order details by ID
  /// GET /api/vendor/orders/{id}
  Future<Order> getVendorOrderById(int orderId) async {
    try {
      developer.log('🍽️ Fetching vendor order by ID: $orderId',
          name: serviceName);

      final response = await httpClient.get('/api/vendor/orders/$orderId');

      developer.log('📡 Response status: ${response.statusCode}',
          name: serviceName);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        developer.log('📦 Vendor order response:', name: serviceName);
        developer.log(JsonEncoder.withIndent('  ').convert(jsonResponse),
            name: serviceName);

        return _parseOrderResponse(jsonResponse);
      } else {
        throw Exception(
            'Failed to get vendor order. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error getting vendor order: $e',
          name: serviceName, error: e, stackTrace: stackTrace, level: 1000);
      rethrow;
    }
  }

  /// Update vendor order status
  /// PUT /api/vendor/orders/{id}
  /// Valid transitions: pending -> confirmed/cancelled, confirmed -> preparing/cancelled, preparing -> ready/cancelled
  ///
  /// Optional [estimatedPrepTimeMinutes] can be provided when confirming an order (pending -> confirmed)
  /// to specify the estimated preparation time in minutes. This helps set customer expectations.
  Future<void> updateVendorOrderStatus(
    int orderId,
    OrderStatus newStatus, {
    int? estimatedPrepTimeMinutes,
    String? notes,
  }) async {
    try {
      developer.log('🍽️ Updating vendor order $orderId status to $newStatus',
          name: serviceName);

      String statusString = _statusToString(newStatus);

      // Build request body
      final Map<String, dynamic> requestBody = {
        'status': statusString,
      };

      // Add optional fields if provided
      if (estimatedPrepTimeMinutes != null) {
        requestBody['estimated_preparation_time'] = estimatedPrepTimeMinutes;
        developer.log('📦 Including estimated prep time: $estimatedPrepTimeMinutes minutes',
            name: serviceName);
      }

      if (notes != null && notes.isNotEmpty) {
        requestBody['notes'] = notes;
      }

      final response = await httpClient.put(
        '/api/vendor/orders/$orderId',
        body: requestBody,
      );

      developer.log('📡 Update status response: ${response.statusCode}',
          name: serviceName);

      if (response.statusCode == 200) {
        developer.log('✅ Order status updated successfully',
            name: serviceName);
      } else {
        final errorMsg =
            'Failed to update order status. Status: ${response.statusCode}, Body: ${response.body}';
        developer.log(errorMsg, name: serviceName, level: 1000);
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error updating vendor order status: $e',
          name: serviceName, error: e, stackTrace: stackTrace, level: 1000);
      rethrow;
    }
  }

  // ==================== ADMIN ORDER METHODS ====================

  /// Get all orders (admin only)
  /// GET /api/admin/orders?status={status}&page={page}&per_page={perPage}
  Future<List<Order>> getAdminOrders({
    required String token,
    OrderStatus? statusFilter,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      developer.log('👑 Getting admin orders...', name: serviceName);

      // Build query parameters
      String queryParams = '?page=$page&per_page=$perPage';
      if (statusFilter != null) {
        String statusString = _statusToString(statusFilter);
        queryParams += '&status=$statusString';
        developer.log('Filtering by status: $statusString', name: serviceName);
      }

      final response = await httpClient.get(
        '/api/admin/orders$queryParams',
        headers: authHeaders(token),
      );

      developer.log('📡 Response status: ${response.statusCode}',
          name: serviceName);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        developer.log('✅ Found admin orders', name: serviceName);
        return _parseOrderListResponse(jsonResponse);
      } else {
        throw Exception(
            'Failed to get admin orders. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error getting admin orders: $e',
          name: serviceName, error: e, stackTrace: stackTrace, level: 1000);
      rethrow;
    }
  }

  /// Get admin order details by ID
  /// GET /api/admin/orders/{id}
  Future<Order> getAdminOrderById(int orderId, String token) async {
    try {
      developer.log('👑 Fetching admin order by ID: $orderId',
          name: serviceName);

      final response = await httpClient.get(
        '/api/admin/orders/$orderId',
        headers: authHeaders(token),
      );

      developer.log('📡 Response status: ${response.statusCode}',
          name: serviceName);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        developer.log('📦 Admin order response:', name: serviceName);
        developer.log(const JsonEncoder.withIndent('  ').convert(jsonResponse),
            name: serviceName);

        return _parseOrderResponse(jsonResponse);
      } else {
        throw Exception(
            'Failed to get admin order. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error getting admin order: $e',
          name: serviceName, error: e, stackTrace: stackTrace, level: 1000);
      rethrow;
    }
  }

  /// Get admin order statistics
  /// GET /api/admin/orders/stats
  Future<Map<String, dynamic>> getAdminOrderStats(String token) async {
    try {
      developer.log('👑 Getting admin order statistics...', name: serviceName);

      final response = await httpClient.get(
        '/api/admin/orders/stats',
        headers: authHeaders(token),
      );

      developer.log('📡 Stats response status: ${response.statusCode}',
          name: serviceName);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        // Handle wrapper format: {success, message, data: {stats}}
        if (jsonResponse is Map && jsonResponse.containsKey('data')) {
          return jsonResponse['data'] as Map<String, dynamic>;
        }

        return jsonResponse as Map<String, dynamic>;
      } else {
        throw Exception(
            'Failed to get order stats. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error getting admin order stats: $e',
          name: serviceName, error: e, stackTrace: stackTrace, level: 1000);
      rethrow;
    }
  }

  /// Update order status (admin override)
  /// PUT /api/admin/orders/{id}/status
  /// Allows admins to manually set any order status
  Future<void> updateAdminOrderStatus(
    int orderId,
    OrderStatus newStatus,
    String token,
  ) async {
    try {
      developer.log('👑 Admin updating order $orderId status to $newStatus',
          name: serviceName);

      String statusString = _statusToString(newStatus);

      final response = await httpClient.put(
        '/api/admin/orders/$orderId/status',
        headers: authHeaders(token),
        body: {'status': statusString},
      );

      developer.log('📡 Update status response: ${response.statusCode}',
          name: serviceName);

      if (response.statusCode == 200) {
        developer.log('✅ Order status updated successfully by admin',
            name: serviceName);
      } else {
        final errorMsg =
            'Failed to update order status. Status: ${response.statusCode}, Body: ${response.body}';
        developer.log(errorMsg, name: serviceName, level: 1000);
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error updating admin order status: $e',
          name: serviceName, error: e, stackTrace: stackTrace, level: 1000);
      rethrow;
    }
  }

  /// Assign driver to order (admin action)
  /// POST /api/admin/orders/{id}/assign-driver
  Future<void> adminAssignDriver(
    int orderId,
    int driverId,
    String token,
  ) async {
    try {
      developer.log('👑 Admin assigning driver $driverId to order $orderId',
          name: serviceName);

      final response = await httpClient.post(
        '/api/admin/orders/$orderId/assign-driver',
        headers: authHeaders(token),
        body: {'driver_id': driverId},
      );

      developer.log('📡 Assign driver response: ${response.statusCode}',
          name: serviceName);

      if (response.statusCode == 200) {
        developer.log('✅ Driver assigned successfully by admin',
            name: serviceName);
      } else {
        final errorMsg =
            'Failed to assign driver. Status: ${response.statusCode}, Body: ${response.body}';
        developer.log(errorMsg, name: serviceName, level: 1000);
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error assigning driver: $e',
          name: serviceName, error: e, stackTrace: stackTrace, level: 1000);
      rethrow;
    }
  }

  // ==================== DRIVER ORDER METHODS ====================

  /// Get available orders for driver assignment
  /// GET /api/driver/orders/available
  /// Returns orders that are ready for pickup (status=ready, no driver assigned)
  Future<List<Order>> getAvailableOrders({int page = 1, int perPage = 20}) async {
    try {
      developer.log('🚚 Getting available orders for driver assignment...',
          name: serviceName);

      final response = await httpClient.get(
          '/api/driver/orders/available?page=$page&per_page=$perPage');

      developer.log('📡 Available orders response status: ${response.statusCode}',
          name: serviceName);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        developer.log('📦 Available orders response: $jsonResponse',
            name: serviceName);

        return _parseOrderListResponse(jsonResponse);
      } else {
        throw Exception(
            'Failed to get available orders. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error getting available orders: $e',
          name: serviceName, error: e, stackTrace: stackTrace, level: 1000);
      rethrow;
    }
  }

  /// Get driver's assigned orders
  /// GET /api/driver/orders
  /// Returns all orders assigned to the authenticated driver
  Future<List<Order>> getDriverOrders({int page = 1, int perPage = 20}) async {
    try {
      developer.log('🚚 Getting driver assigned orders...', name: serviceName);

      final response = await httpClient.get(
          '/api/driver/orders?page=$page&per_page=$perPage');

      developer.log('📡 Driver orders response status: ${response.statusCode}',
          name: serviceName);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        developer.log('📦 Driver orders response: $jsonResponse',
            name: serviceName);

        return _parseOrderListResponse(jsonResponse);
      } else {
        throw Exception(
            'Failed to get driver orders. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error getting driver orders: $e',
          name: serviceName, error: e, stackTrace: stackTrace, level: 1000);
      rethrow;
    }
  }

  /// Get driver order details by ID
  /// GET /api/driver/orders/{id}
  /// Returns detailed information about a specific order (must be assigned to driver or available)
  Future<Order> getDriverOrderById(int orderId) async {
    try {
      developer.log('🚚 Fetching driver order by ID: $orderId',
          name: serviceName);

      final response = await httpClient.get('/api/driver/orders/$orderId');

      developer.log('📡 Response status: ${response.statusCode}',
          name: serviceName);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        developer.log('📦 Driver order response:', name: serviceName);
        developer.log(const JsonEncoder.withIndent('  ').convert(jsonResponse),
            name: serviceName);

        return _parseOrderResponse(jsonResponse);
      } else {
        throw Exception(
            'Failed to get driver order. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error getting driver order: $e',
          name: serviceName, error: e, stackTrace: stackTrace, level: 1000);
      rethrow;
    }
  }

  /// Assign order to driver (driver self-assignment)
  /// POST /api/driver/orders/{id}/assign
  /// Order must be in 'ready' status and not already assigned
  /// Automatically updates order status to 'driver_assigned'
  Future<Map<String, dynamic>> assignOrderToDriver(int orderId) async {
    try {
      developer.log('🚚 Assigning order $orderId to driver...',
          name: serviceName);

      final response = await httpClient.post(
        '/api/driver/orders/$orderId/assign',
        body: {}, // Empty body as per API spec
      );

      developer.log('📡 Assign order response status: ${response.statusCode}',
          name: serviceName);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        developer.log('✅ Order assigned successfully', name: serviceName);
        developer.log('📦 Response: $jsonResponse', name: serviceName);

        // Backend returns: {success, message, data: {order_id, driver_id, status}}
        return jsonResponse['data'] as Map<String, dynamic>;
      } else {
        final errorMsg =
            'Failed to assign order. Status: ${response.statusCode}, Body: ${response.body}';
        developer.log(errorMsg, name: serviceName, level: 1000);
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error assigning order: $e',
          name: serviceName, error: e, stackTrace: stackTrace, level: 1000);
      rethrow;
    }
  }

  /// Update driver order status
  /// PUT /api/driver/orders/{id}/status
  /// Valid transitions: driver_assigned -> picked_up -> in_transit -> delivered
  Future<Order> updateDriverOrderStatus(
      int orderId, OrderStatus newStatus) async {
    try {
      developer.log('🚚 Updating driver order $orderId status to $newStatus',
          name: serviceName);

      String statusString = _statusToString(newStatus);

      final response = await httpClient.put(
        '/api/driver/orders/$orderId/status',
        body: {'status': statusString},
      );

      developer.log('📡 Update status response: ${response.statusCode}',
          name: serviceName);

      if (response.statusCode == 200) {
        developer.log('✅ Order status updated successfully',
            name: serviceName);

        // Refetch the order to get complete updated data
        return await getDriverOrderById(orderId);
      } else {
        final errorMsg =
            'Failed to update order status. Status: ${response.statusCode}, Body: ${response.body}';
        developer.log(errorMsg, name: serviceName, level: 1000);
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      developer.log('❌ Error updating driver order status: $e',
          name: serviceName, error: e, stackTrace: stackTrace, level: 1000);
      rethrow;
    }
  }
}
