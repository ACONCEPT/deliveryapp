import 'dart:convert';
import 'dart:developer' as developer;
import '../models/customization_template.dart';
import 'base_service.dart';

/// Service for managing customization templates via vendor and admin APIs
///
/// Provides methods for creating, fetching, updating, and deleting reusable customization templates.
/// Vendors can manage their own templates, admins can manage all templates including system-wide ones.
class CustomizationTemplateService extends BaseService {
  @override
  String get serviceName => 'CustomizationTemplateService';

  // ============================================================================
  // VENDOR ENDPOINTS
  // ============================================================================

  /// Get all customization templates accessible to the vendor
  ///
  /// [token] - Vendor JWT bearer token
  ///
  /// Returns vendor's own templates plus all system-wide templates (vendor_id IS NULL)
  Future<List<CustomizationTemplate>> getVendorTemplates(String token) async {
    try {
      developer.log('Fetching vendor customization templates', name: serviceName);

      final response = await httpClient.get(
        '/api/vendor/customization-templates',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final templatesResponse = CustomizationTemplatesResponse.fromJson(responseData);

        developer.log(
          '✅ Successfully fetched ${templatesResponse.templates.length} templates',
          name: serviceName,
        );

        return templatesResponse.templates;
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to fetch templates');
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error fetching vendor templates: $e',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get a specific customization template by ID (vendor)
  ///
  /// [token] - Vendor JWT bearer token
  /// [templateId] - Template ID
  ///
  /// Returns template if vendor owns it or if it's system-wide
  Future<CustomizationTemplate> getVendorTemplate(
    String token,
    int templateId,
  ) async {
    try {
      developer.log(
        'Fetching vendor template: $templateId',
        name: serviceName,
      );

      final response = await httpClient.get(
        '/api/vendor/customization-templates/$templateId',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final templateResponse = CustomizationTemplateResponse.fromJson(responseData);

        developer.log(
          '✅ Successfully fetched template: ${templateResponse.template?.name}',
          name: serviceName,
        );

        return templateResponse.template!;
      } else if (response.statusCode == 404) {
        throw Exception('Template not found');
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to fetch template');
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error fetching vendor template $templateId: $e',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create a new customization template (vendor-specific)
  ///
  /// [token] - Vendor JWT bearer token
  /// [request] - Template creation request
  ///
  /// Returns created template
  Future<CustomizationTemplate> createVendorTemplate(
    String token,
    CreateCustomizationTemplateRequest request,
  ) async {
    try {
      developer.log(
        'Creating vendor template: ${request.name}',
        name: serviceName,
      );

      final response = await httpClient.post(
        '/api/vendor/customization-templates',
        headers: authHeaders(token),
        body: request.toJson(),
      );

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final templateResponse = CustomizationTemplateResponse.fromJson(responseData);

        developer.log(
          '✅ Successfully created template: ${templateResponse.template?.name}',
          name: serviceName,
        );

        return templateResponse.template!;
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to create template');
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error creating vendor template: $e',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update a customization template (vendor-owned only)
  ///
  /// [token] - Vendor JWT bearer token
  /// [templateId] - Template ID
  /// [request] - Template update request (all fields optional)
  ///
  /// Returns updated template
  Future<CustomizationTemplate> updateVendorTemplate(
    String token,
    int templateId,
    UpdateCustomizationTemplateRequest request,
  ) async {
    try {
      developer.log(
        'Updating vendor template: $templateId',
        name: serviceName,
      );

      final response = await httpClient.put(
        '/api/vendor/customization-templates/$templateId',
        headers: authHeaders(token),
        body: request.toJson(),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final templateResponse = CustomizationTemplateResponse.fromJson(responseData);

        developer.log(
          '✅ Successfully updated template: ${templateResponse.template?.name}',
          name: serviceName,
        );

        return templateResponse.template!;
      } else if (response.statusCode == 404) {
        throw Exception('Template not found');
      } else if (response.statusCode == 403) {
        throw Exception('Cannot update system-wide templates');
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to update template');
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error updating vendor template $templateId: $e',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a customization template (vendor-owned only)
  ///
  /// [token] - Vendor JWT bearer token
  /// [templateId] - Template ID
  Future<void> deleteVendorTemplate(
    String token,
    int templateId,
  ) async {
    try {
      developer.log(
        'Deleting vendor template: $templateId',
        name: serviceName,
      );

      final response = await httpClient.delete(
        '/api/vendor/customization-templates/$templateId',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        developer.log(
          '✅ Successfully deleted template: $templateId',
          name: serviceName,
        );
      } else if (response.statusCode == 404) {
        throw Exception('Template not found');
      } else if (response.statusCode == 403) {
        throw Exception('Cannot delete system-wide templates');
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to delete template');
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error deleting vendor template $templateId: $e',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // ADMIN ENDPOINTS
  // ============================================================================

  /// Get all customization templates in the system (admin only)
  ///
  /// [token] - Admin JWT bearer token
  ///
  /// Returns all templates (vendor-specific and system-wide)
  Future<List<CustomizationTemplate>> getAdminTemplates(String token) async {
    try {
      developer.log('Fetching all customization templates (admin)', name: serviceName);

      final response = await httpClient.get(
        '/api/admin/customization-templates',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final templatesResponse = CustomizationTemplatesResponse.fromJson(responseData);

        developer.log(
          '✅ Successfully fetched ${templatesResponse.templates.length} templates (admin)',
          name: serviceName,
        );

        return templatesResponse.templates;
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to fetch templates');
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error fetching admin templates: $e',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create a system-wide customization template (admin only)
  ///
  /// [token] - Admin JWT bearer token
  /// [request] - Template creation request
  ///
  /// Returns created system-wide template (vendor_id = NULL)
  Future<CustomizationTemplate> createAdminTemplate(
    String token,
    CreateCustomizationTemplateRequest request,
  ) async {
    try {
      developer.log(
        'Creating system-wide template: ${request.name} (admin)',
        name: serviceName,
      );

      final response = await httpClient.post(
        '/api/admin/customization-templates',
        headers: authHeaders(token),
        body: request.toJson(),
      );

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final templateResponse = CustomizationTemplateResponse.fromJson(responseData);

        developer.log(
          '✅ Successfully created system-wide template: ${templateResponse.template?.name}',
          name: serviceName,
        );

        return templateResponse.template!;
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to create template');
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error creating admin template: $e',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update any customization template (admin only)
  ///
  /// [token] - Admin JWT bearer token
  /// [templateId] - Template ID
  /// [request] - Template update request (all fields optional)
  ///
  /// Returns updated template
  Future<CustomizationTemplate> updateAdminTemplate(
    String token,
    int templateId,
    UpdateCustomizationTemplateRequest request,
  ) async {
    try {
      developer.log(
        'Updating template: $templateId (admin)',
        name: serviceName,
      );

      final response = await httpClient.put(
        '/api/admin/customization-templates/$templateId',
        headers: authHeaders(token),
        body: request.toJson(),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final templateResponse = CustomizationTemplateResponse.fromJson(responseData);

        developer.log(
          '✅ Successfully updated template: ${templateResponse.template?.name} (admin)',
          name: serviceName,
        );

        return templateResponse.template!;
      } else if (response.statusCode == 404) {
        throw Exception('Template not found');
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to update template');
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error updating admin template $templateId: $e',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete any customization template (admin only)
  ///
  /// [token] - Admin JWT bearer token
  /// [templateId] - Template ID
  Future<void> deleteAdminTemplate(
    String token,
    int templateId,
  ) async {
    try {
      developer.log(
        'Deleting template: $templateId (admin)',
        name: serviceName,
      );

      final response = await httpClient.delete(
        '/api/admin/customization-templates/$templateId',
        headers: authHeaders(token),
      );

      if (response.statusCode == 200) {
        developer.log(
          '✅ Successfully deleted template: $templateId (admin)',
          name: serviceName,
        );
      } else if (response.statusCode == 404) {
        throw Exception('Template not found');
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'Failed to delete template');
      }
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error deleting admin template $templateId: $e',
        name: serviceName,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
