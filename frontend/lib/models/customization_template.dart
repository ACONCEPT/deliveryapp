/// Customization Template data models for vendor and admin template management
///
/// Templates allow admins and vendors to create reusable customization configurations
/// that can be applied to multiple menu items.
///
/// SIMPLIFIED STRUCTURE:
/// Each template represents a single customization (e.g., "Extra Cheese", "Spice Level")
/// with a flat list of options (e.g., ["Yes", "No"] or ["Mild", "Medium", "Hot"]).
/// No nested groups - just one title and one set of options.

import 'dart:convert';

/// Simple Customization Option
///
/// Represents a single selectable option with an optional price modifier.
/// Example: "Yes" (+$2.00), "Medium" ($0.00)
class SimpleCustomizationOption {
  final String name;
  final double priceModifier;

  SimpleCustomizationOption({
    required this.name,
    this.priceModifier = 0.0,
  });

  factory SimpleCustomizationOption.fromJson(Map<String, dynamic> json) {
    return SimpleCustomizationOption(
      name: json['name'] as String,
      priceModifier: (json['price_modifier'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price_modifier': priceModifier,
    };
  }
}

/// Customization Template Model
///
/// Represents a single customization with a title and a flat list of options.
/// Example: "Extra Cheese" with options ["Yes" (+$2), "No" ($0)]
/// Example: "Spice Level" with options ["Mild", "Medium", "Hot"]
///
/// Type can be:
/// - 'single_choice': Radio buttons (select one)
/// - 'multiple_choice': Checkboxes (select multiple)
/// - 'text_input': Free text input (notes/special instructions)
/// - 'spice_level': Special spice level selector widget
class CustomizationTemplate {
  final int? id;
  final String name; // Customization title (e.g., "Extra Cheese", "Spice Level")
  final String? description;
  final String type; // Type of customization: 'single_choice', 'multiple_choice', 'text_input', 'spice_level'
  final List<SimpleCustomizationOption> options; // Flat list of options (not needed for text_input)
  final bool required; // Whether customer must select an option
  final int? maxSelections; // For multiple_choice - limit number of selections
  final int? maxLength; // For text_input - character limit
  final String? placeholder; // For text_input - placeholder text
  final Map<String, dynamic> customizationConfig; // Legacy field for backward compatibility
  final int? vendorId; // null for system-wide (admin) templates
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CustomizationTemplate({
    this.id,
    required this.name,
    this.description,
    this.type = 'single_choice',
    List<SimpleCustomizationOption>? options,
    this.required = false,
    this.maxSelections,
    this.maxLength,
    this.placeholder,
    Map<String, dynamic>? customizationConfig,
    this.vendorId,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  })  : options = options ?? [],
        customizationConfig = customizationConfig ?? {};

  /// Whether this is a system-wide template (admin-created)
  bool get isSystemWide => vendorId == null;

  /// Whether this is a vendor-specific template
  bool get isVendorSpecific => vendorId != null;

  factory CustomizationTemplate.fromJson(Map<String, dynamic> json) {
    // Parse customization_config - backend sends it as a JSON string
    Map<String, dynamic> config = {};
    final configValue = json['customization_config'];
    if (configValue != null) {
      if (configValue is String) {
        // Backend sends JSON as string, need to decode it
        try {
          config = jsonDecode(configValue) as Map<String, dynamic>;
        } catch (e) {
          config = {};
        }
      } else if (configValue is Map<String, dynamic>) {
        // Already a map (shouldn't happen with current backend)
        config = configValue;
      }
    }

    // Parse simplified structure from config
    List<SimpleCustomizationOption> options = [];
    bool required = false;
    String type = 'single_choice';
    int? maxSelections;
    int? maxLength;
    String? placeholder;

    // Try to extract simplified structure
    if (config.containsKey('options') && config['options'] is List) {
      try {
        options = (config['options'] as List)
            .map((e) => SimpleCustomizationOption.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        // Fall back to empty list
        options = [];
      }
    }

    if (config.containsKey('required')) {
      required = config['required'] as bool? ?? false;
    }

    if (config.containsKey('type')) {
      type = config['type'] as String? ?? 'single_choice';
    }

    if (config.containsKey('max_selections')) {
      maxSelections = config['max_selections'] as int?;
    }

    if (config.containsKey('max_length')) {
      maxLength = config['max_length'] as int?;
    }

    if (config.containsKey('placeholder')) {
      placeholder = config['placeholder'] as String?;
    }

    return CustomizationTemplate(
      id: json['id'] as int?,
      name: json['name'] as String,
      description: json['description'] as String?,
      type: type,
      options: options,
      required: required,
      maxSelections: maxSelections,
      maxLength: maxLength,
      placeholder: placeholder,
      customizationConfig: config,
      vendorId: json['vendor_id'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    // Build simplified config structure
    final config = {
      'type': type,
      'required': required,
      if (type != 'text_input') 'options': options.map((o) => o.toJson()).toList(),
      if (maxSelections != null) 'max_selections': maxSelections,
      if (maxLength != null) 'max_length': maxLength,
      if (placeholder != null) 'placeholder': placeholder,
    };

    return {
      if (id != null) 'id': id,
      'name': name,
      if (description != null) 'description': description,
      // Backend expects customization_config as a JSON-encoded string
      'customization_config': jsonEncode(config),
      if (vendorId != null) 'vendor_id': vendorId,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  CustomizationTemplate copyWith({
    int? id,
    String? name,
    String? description,
    String? type,
    List<SimpleCustomizationOption>? options,
    bool? required,
    int? maxSelections,
    int? maxLength,
    String? placeholder,
    Map<String, dynamic>? customizationConfig,
    int? vendorId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomizationTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      options: options ?? this.options,
      required: required ?? this.required,
      maxSelections: maxSelections ?? this.maxSelections,
      maxLength: maxLength ?? this.maxLength,
      placeholder: placeholder ?? this.placeholder,
      customizationConfig: customizationConfig ?? this.customizationConfig,
      vendorId: vendorId ?? this.vendorId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get template type display name
  String get typeDisplayName => isSystemWide ? 'System-wide' : 'Vendor-specific';

  /// Get icon for template type
  String get typeIcon => isSystemWide ? '🌐' : '🏪';

  /// Get friendly name for customization type
  String get customizationTypeDisplayName {
    switch (type) {
      case 'single_choice':
        return 'Single Choice (Radio)';
      case 'multiple_choice':
        return 'Multiple Choice (Checkboxes)';
      case 'text_input':
        return 'Text Input (Notes)';
      case 'spice_level':
        return 'Spice Level Selector';
      default:
        return type;
    }
  }
}

/// Request to create a new customization template
class CreateCustomizationTemplateRequest {
  final String name;
  final String? description;
  final String type;
  final List<SimpleCustomizationOption> options;
  final bool required;
  final int? maxSelections;
  final int? maxLength;
  final String? placeholder;
  final bool isActive;

  CreateCustomizationTemplateRequest({
    required this.name,
    this.description,
    this.type = 'single_choice',
    required this.options,
    this.required = false,
    this.maxSelections,
    this.maxLength,
    this.placeholder,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    final config = {
      'type': type,
      'required': required,
      if (type != 'text_input') 'options': options.map((o) => o.toJson()).toList(),
      if (maxSelections != null) 'max_selections': maxSelections,
      if (maxLength != null) 'max_length': maxLength,
      if (placeholder != null) 'placeholder': placeholder,
    };

    return {
      'name': name,
      if (description != null) 'description': description,
      // Backend expects customization_config as a JSON-encoded string
      'customization_config': jsonEncode(config),
      'is_active': isActive,
    };
  }
}

/// Request to update an existing customization template
class UpdateCustomizationTemplateRequest {
  final String? name;
  final String? description;
  final String? type;
  final List<SimpleCustomizationOption>? options;
  final bool? required;
  final int? maxSelections;
  final int? maxLength;
  final String? placeholder;
  final bool? isActive;

  UpdateCustomizationTemplateRequest({
    this.name,
    this.description,
    this.type,
    this.options,
    this.required,
    this.maxSelections,
    this.maxLength,
    this.placeholder,
    this.isActive,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};
    if (name != null) json['name'] = name;
    if (description != null) json['description'] = description;

    // Build config if any of the simplified fields are provided
    if (type != null || options != null || required != null || maxSelections != null || maxLength != null || placeholder != null) {
      final config = <String, dynamic>{};
      if (type != null) config['type'] = type;
      if (required != null) config['required'] = required;
      if (options != null && type != 'text_input') {
        config['options'] = options!.map((o) => o.toJson()).toList();
      }
      if (maxSelections != null) config['max_selections'] = maxSelections;
      if (maxLength != null) config['max_length'] = maxLength;
      if (placeholder != null) config['placeholder'] = placeholder;
      json['customization_config'] = jsonEncode(config);
    }

    if (isActive != null) json['is_active'] = isActive;
    return json;
  }

  bool get isEmpty =>
    name == null &&
    description == null &&
    type == null &&
    options == null &&
    required == null &&
    maxSelections == null &&
    maxLength == null &&
    placeholder == null &&
    isActive == null;
}

/// Response from GET /api/vendor/customization-templates or /api/admin/customization-templates
class CustomizationTemplatesResponse {
  final bool success;
  final List<CustomizationTemplate> templates;

  CustomizationTemplatesResponse({
    required this.success,
    required this.templates,
  });

  factory CustomizationTemplatesResponse.fromJson(Map<String, dynamic> json) {
    return CustomizationTemplatesResponse(
      success: json['success'] as bool,
      templates: (json['data'] as List)
          .map((t) => CustomizationTemplate.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Response from POST /PUT /DELETE operations
class CustomizationTemplateResponse {
  final bool success;
  final String message;
  final CustomizationTemplate? template;

  CustomizationTemplateResponse({
    required this.success,
    required this.message,
    this.template,
  });

  factory CustomizationTemplateResponse.fromJson(Map<String, dynamic> json) {
    return CustomizationTemplateResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      template: json['data'] != null
          ? CustomizationTemplate.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}
