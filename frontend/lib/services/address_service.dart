import '../models/address.dart';
import 'base_service.dart';

/// Service for customer address management with full CRUD operations.
/// All methods require Bearer token authentication.
///
/// Example usage:
/// ```dart
/// final service = AddressService();
/// final addresses = await service.getAddresses(token);
/// final newAddress = await service.createAddress(token, address);
/// ```
class AddressService extends BaseService {
  @override
  String get serviceName => 'AddressService';

  /// Get all addresses for the authenticated customer
  Future<List<Address>> getAddresses(String token) async {
    return getList<Address>(
      '/api/addresses',
      'addresses',
      (json) => Address.fromJson(json),
      token: token,
    );
  }

  /// Get a specific address by ID
  Future<Address> getAddress(String token, int addressId) async {
    return getObject<Address>(
      '/api/addresses/$addressId',
      'address',
      (json) => Address.fromJson(json),
      token: token,
    );
  }

  /// Create a new address
  Future<Address> createAddress(String token, Address address) async {
    return postObject<Address>(
      '/api/customer/addresses',
      'address',
      address.toJson(),
      (json) => Address.fromJson(json),
      token: token,
    );
  }

  /// Update an existing address
  Future<Address> updateAddress(
      String token, int addressId, Address address) async {
    return putObject<Address>(
      '/api/customer/addresses/$addressId',
      'address',
      address.toJson(),
      (json) => Address.fromJson(json),
      token: token,
    );
  }

  /// Delete an address
  Future<void> deleteAddress(String token, int addressId) async {
    await deleteResource(
      '/api/customer/addresses/$addressId',
      token: token,
    );
  }

  /// Set an address as default
  Future<void> setDefaultAddress(String token, int addressId) async {
    await executeVoidOperation(
      () async {
        final headers = authHeaders(token);
        return await httpClient.put(
          '/api/customer/addresses/$addressId/set-default',
          headers: headers,
        );
      },
      'set default address',
    );
  }
}
