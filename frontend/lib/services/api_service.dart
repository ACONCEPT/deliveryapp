import 'dart:convert';
import 'dart:developer' as developer;
import '../models/user.dart';
import 'http_client_service.dart';

class ApiService {
  final HttpClientService _httpClient = HttpClientService();

  Future<LoginResponse> login(String username, String password) async {
    try {
      final response = await _httpClient.post(
        '/api/login',
        body: {
          'username': username,
          'password': password,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return LoginResponse.fromJson(data);
      } else {
        return LoginResponse(
          success: false,
          message: data['message'] ?? 'Login failed',
        );
      }
    } catch (e) {
      developer.log('Error in login', name: 'ApiService', error: e);
      return LoginResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  Future<SignupResponse> signup({
    required String username,
    required String email,
    required String password,
    required String userType,
    required String fullName,
    String? phone,
    String? businessName,
    String? description,
    String? vehicleType,
    String? vehiclePlate,
    String? licenseNumber,
  }) async {
    try {
      final response = await _httpClient.post(
        '/api/signup',
        body: {
          'username': username,
          'email': email,
          'password': password,
          'user_type': userType,
          'full_name': fullName,
          if (phone != null) 'phone': phone,
          if (businessName != null) 'business_name': businessName,
          if (description != null) 'description': description,
          if (vehicleType != null) 'vehicle_type': vehicleType,
          if (vehiclePlate != null) 'vehicle_plate': vehiclePlate,
          if (licenseNumber != null) 'license_number': licenseNumber,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return SignupResponse.fromJson(data);
      } else {
        return SignupResponse(
          success: false,
          message: data['message'] ?? 'Signup failed',
        );
      }
    } catch (e) {
      developer.log('Error in signup', name: 'ApiService', error: e);
      return SignupResponse(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }
}
