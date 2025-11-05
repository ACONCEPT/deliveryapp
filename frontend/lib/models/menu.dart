import 'base/json_parsers.dart';

/// Main Menu Model
///
/// Represents a menu with categories and items stored in menuConfig JSON field.
/// The menuConfig can be a String (from API) or Map (in-memory working format).
class Menu {
  final int? id;
  final String name;
  final String? description;
  final Map<String, dynamic> menuConfig;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<RestaurantMenuAssignment>? assignedRestaurants;

  Menu({
    this.id,
    required this.name,
    this.description,
    required this.menuConfig,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.assignedRestaurants,
  });

  factory Menu.fromJson(Map<String, dynamic> json) {
    return Menu(
      id: json['id'] as int?,
      name: json['name'] as String,
      description: json['description'] as String?,
      menuConfig: JsonParsers.parseJsonField(json['menu_config']),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: JsonParsers.parseDateTime(json['created_at']),
      updatedAt: JsonParsers.parseDateTime(json['updated_at']),
      assignedRestaurants: (json['assigned_restaurants'] as List?)
          ?.map((e) => RestaurantMenuAssignment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (description != null) 'description': description,
      'menu_config': JsonParsers.encodeJsonField(menuConfig),
      'is_active': isActive,
    };
  }

  /// Helper to get categories from menuConfig
  List<MenuCategory> getCategories() {
    final categoriesList = menuConfig['categories'] as List? ?? [];
    return categoriesList
        .map((cat) => MenuCategory.fromJson(cat as Map<String, dynamic>))
        .toList();
  }

  /// Helper to set categories in menuConfig
  void setCategories(List<MenuCategory> categories) {
    menuConfig['categories'] = categories.map((c) => c.toJson()).toList();
  }

  Menu copyWith({
    int? id,
    String? name,
    String? description,
    Map<String, dynamic>? menuConfig,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<RestaurantMenuAssignment>? assignedRestaurants,
  }) {
    return Menu(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      menuConfig: menuConfig ?? this.menuConfig,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      assignedRestaurants: assignedRestaurants ?? this.assignedRestaurants,
    );
  }
}

/// Restaurant Menu Assignment Info
///
/// Represents the assignment of a menu to a restaurant with metadata.
class RestaurantMenuAssignment {
  final int restaurantId;
  final String restaurantName;
  final bool isActive;
  final int displayOrder;

  RestaurantMenuAssignment({
    required this.restaurantId,
    required this.restaurantName,
    required this.isActive,
    this.displayOrder = 0,
  });

  factory RestaurantMenuAssignment.fromJson(Map<String, dynamic> json) {
    return RestaurantMenuAssignment(
      restaurantId: (json['restaurant_id'] is int)
          ? json['restaurant_id'] as int
          : int.parse(json['restaurant_id'].toString()),
      restaurantName: json['restaurant_name'] as String,
      isActive: json['is_active'] as bool,
      displayOrder: json['display_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'restaurant_id': restaurantId,
      'restaurant_name': restaurantName,
      'is_active': isActive,
      'display_order': displayOrder,
    };
  }

  RestaurantMenuAssignment copyWith({
    int? restaurantId,
    String? restaurantName,
    bool? isActive,
    int? displayOrder,
  }) {
    return RestaurantMenuAssignment(
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }
}

/// Menu Category Model
///
/// Represents a category within a menu containing multiple items.
class MenuCategory {
  final String id;
  final String name;
  final String? description;
  final int displayOrder;
  final bool isActive;
  final String? imageUrl;
  final List<MenuItem> items;

  MenuCategory({
    required this.id,
    required this.name,
    this.description,
    this.displayOrder = 0,
    this.isActive = true,
    this.imageUrl,
    List<MenuItem>? items,
  }) : items = items ?? [];

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: json['id'].toString(),
      name: json['name'] as String,
      description: json['description'] as String?,
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      imageUrl: json['image_url'] as String?,
      items: (json['items'] as List?)
              ?.map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      'display_order': displayOrder,
      'is_active': isActive,
      if (imageUrl != null) 'image_url': imageUrl,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }

  MenuCategory copyWith({
    String? id,
    String? name,
    String? description,
    int? displayOrder,
    bool? isActive,
    String? imageUrl,
    List<MenuItem>? items,
  }) {
    return MenuCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      imageUrl: imageUrl ?? this.imageUrl,
      items: items ?? this.items,
    );
  }
}

/// Menu Item Model
///
/// Represents an individual item on the menu with all details including
/// price, dietary information, customization options, and variants.
///
/// Variants are pre-configured options like size/crust type that affect the base item.
/// Customizations are add-ons/modifications that customers can choose.
class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final int displayOrder;
  final bool isActive;
  final bool isAvailable;
  final String? imageUrl;
  final int? preparationTimeMinutes;
  final int? calories;
  final Map<String, bool>? dietaryFlags;
  final List<String>? allergens;
  final List<ItemVariant>? variants;
  final List<CustomizationOption>? customizationOptions;
  final List<String>? tags;
  final int? spiceLevel;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.displayOrder = 0,
    this.isActive = true,
    this.isAvailable = true,
    this.imageUrl,
    this.preparationTimeMinutes,
    this.calories,
    this.dietaryFlags,
    this.allergens,
    this.variants,
    this.customizationOptions,
    this.tags,
    this.spiceLevel,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'].toString(),
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: JsonParsers.parseDoubleWithDefault(json['price'], 0.0),
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      isAvailable: json['is_available'] as bool? ?? true,
      imageUrl: json['image_url'] as String?,
      preparationTimeMinutes: json['preparation_time_minutes'] as int?,
      calories: json['calories'] as int?,
      dietaryFlags: json['dietary_flags'] != null
          ? Map<String, bool>.from(json['dietary_flags'] as Map)
          : null,
      allergens: json['allergens'] != null
          ? List<String>.from(json['allergens'] as List)
          : null,
      variants: (json['variants'] as List?)
          ?.map((e) => ItemVariant.fromJson(e as Map<String, dynamic>))
          .toList(),
      customizationOptions: (json['customization_options'] as List?)
          ?.map((e) => CustomizationOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      tags: json['tags'] != null ? List<String>.from(json['tags'] as List) : null,
      spiceLevel: json['spice_level'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'display_order': displayOrder,
      'is_active': isActive,
      'is_available': isAvailable,
      if (imageUrl != null) 'image_url': imageUrl,
      if (preparationTimeMinutes != null)
        'preparation_time_minutes': preparationTimeMinutes,
      if (calories != null) 'calories': calories,
      if (dietaryFlags != null) 'dietary_flags': dietaryFlags,
      if (allergens != null) 'allergens': allergens,
      if (variants != null) 'variants': variants!.map((e) => e.toJson()).toList(),
      if (customizationOptions != null)
        'customization_options':
            customizationOptions!.map((e) => e.toJson()).toList(),
      if (tags != null) 'tags': tags,
      if (spiceLevel != null) 'spice_level': spiceLevel,
    };
  }

  /// Helper to calculate final price with variants and customizations
  ///
  /// Takes maps of selected variants and customization options.
  /// - selectedVariants: Map where keys are variant IDs and values are selected option IDs
  /// - selectedCustomizations: Map where keys are customization option IDs and values are selected choice IDs
  double calculatePrice({
    Map<String, String>? selectedVariants,
    Map<String, dynamic>? selectedCustomizations,
  }) {
    double total = price;

    // Add variant price modifiers
    if (variants != null && selectedVariants != null) {
      for (final variant in variants!) {
        final selectedOptionId = selectedVariants[variant.id];
        if (selectedOptionId != null) {
          final option = variant.options.firstWhere(
            (o) => o.id == selectedOptionId,
            orElse: () => VariantOption(id: '', name: '', priceModifier: 0.0),
          );
          total += option.priceModifier;
        }
      }
    }

    // Add customization price modifiers
    if (customizationOptions != null && selectedCustomizations != null) {
      for (final option in customizationOptions!) {
        final selectedValue = selectedCustomizations[option.id];
        if (selectedValue == null || option.choices == null) {
          continue;
        }

        // Handle single choice and spice_level
        if ((option.type == 'single_choice' || option.type == 'spice_level') &&
            selectedValue is String) {
          final choice = option.choices!.firstWhere(
            (c) => c.id == selectedValue,
            orElse: () => CustomizationChoice(id: '', name: '', priceModifier: 0.0),
          );
          total += choice.priceModifier;
        }

        // Handle multiple choice
        if (option.type == 'multiple_choice' && selectedValue is List) {
          for (final choiceId in selectedValue) {
            final choice = option.choices!.firstWhere(
              (c) => c.id == choiceId,
              orElse: () => CustomizationChoice(id: '', name: '', priceModifier: 0.0),
            );
            total += choice.priceModifier;
          }
        }
      }
    }

    return total;
  }

  MenuItem copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    int? displayOrder,
    bool? isActive,
    bool? isAvailable,
    String? imageUrl,
    int? preparationTimeMinutes,
    int? calories,
    Map<String, bool>? dietaryFlags,
    List<String>? allergens,
    List<ItemVariant>? variants,
    List<CustomizationOption>? customizationOptions,
    List<String>? tags,
    int? spiceLevel,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      isAvailable: isAvailable ?? this.isAvailable,
      imageUrl: imageUrl ?? this.imageUrl,
      preparationTimeMinutes: preparationTimeMinutes ?? this.preparationTimeMinutes,
      calories: calories ?? this.calories,
      dietaryFlags: dietaryFlags ?? this.dietaryFlags,
      allergens: allergens ?? this.allergens,
      variants: variants ?? this.variants,
      customizationOptions: customizationOptions ?? this.customizationOptions,
      tags: tags ?? this.tags,
      spiceLevel: spiceLevel ?? this.spiceLevel,
    );
  }
}

/// Item Variant Model
///
/// Represents a variant group for menu items (e.g., Size, Crust Type).
/// Variants are pre-configured options that typically affect the base price.
/// Example: Size (Small/Medium/Large), Crust (Thin/Thick/Stuffed)
class ItemVariant {
  final String id;
  final String name;
  final String type; // 'single_choice' (dropdown), 'button_group' (radio buttons)
  final bool required;
  final List<VariantOption> options;

  ItemVariant({
    required this.id,
    required this.name,
    this.type = 'single_choice',
    this.required = false,
    List<VariantOption>? options,
  }) : options = options ?? [];

  factory ItemVariant.fromJson(Map<String, dynamic> json) {
    return ItemVariant(
      id: json['id'].toString(),
      name: json['name'] as String,
      type: json['type'] as String? ?? 'single_choice',
      required: json['required'] as bool? ?? false,
      options: (json['options'] as List?)
          ?.map((e) => VariantOption.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'required': required,
      'options': options.map((e) => e.toJson()).toList(),
    };
  }

  ItemVariant copyWith({
    String? id,
    String? name,
    String? type,
    bool? required,
    List<VariantOption>? options,
  }) {
    return ItemVariant(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      required: required ?? this.required,
      options: options ?? this.options,
    );
  }
}

/// Variant Option Model
///
/// Represents a single option within a variant group.
/// Example: "Small (10\")" with price modifier -2.00
class VariantOption {
  final String id;
  final String name;
  final double priceModifier;
  final String? description;

  VariantOption({
    required this.id,
    required this.name,
    this.priceModifier = 0.0,
    this.description,
  });

  factory VariantOption.fromJson(Map<String, dynamic> json) {
    return VariantOption(
      id: json['id'].toString(),
      name: json['name'] as String,
      priceModifier: JsonParsers.parseDoubleWithDefault(json['price_modifier'], 0.0),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price_modifier': priceModifier,
      if (description != null) 'description': description,
    };
  }

  VariantOption copyWith({
    String? id,
    String? name,
    double? priceModifier,
    String? description,
  }) {
    return VariantOption(
      id: id ?? this.id,
      name: name ?? this.name,
      priceModifier: priceModifier ?? this.priceModifier,
      description: description ?? this.description,
    );
  }
}

/// Customization Option Model
///
/// Represents a customization option for a menu item.
/// Supports types: single_choice, multiple_choice, text_input, spice_level.
class CustomizationOption {
  final String id;
  final String name;
  final String type; // 'single_choice', 'multiple_choice', 'text_input', 'spice_level'
  final bool required;
  final int? maxSelections; // For multiple_choice
  final int? maxLength; // For text_input
  final String? placeholder; // For text_input
  final List<CustomizationChoice>? choices; // For single/multiple choice

  CustomizationOption({
    required this.id,
    required this.name,
    required this.type,
    this.required = false,
    this.maxSelections,
    this.maxLength,
    this.placeholder,
    this.choices,
  });

  factory CustomizationOption.fromJson(Map<String, dynamic> json) {
    return CustomizationOption(
      id: json['id'].toString(),
      name: json['name'] as String,
      type: json['type'] as String,
      required: json['required'] as bool? ?? false,
      maxSelections: json['max_selections'] as int?,
      maxLength: json['max_length'] as int?,
      placeholder: json['placeholder'] as String?,
      choices: (json['choices'] as List?)
          ?.map((e) => CustomizationChoice.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'required': required,
      if (maxSelections != null) 'max_selections': maxSelections,
      if (maxLength != null) 'max_length': maxLength,
      if (placeholder != null) 'placeholder': placeholder,
      if (choices != null) 'choices': choices!.map((e) => e.toJson()).toList(),
    };
  }

  CustomizationOption copyWith({
    String? id,
    String? name,
    String? type,
    bool? required,
    int? maxSelections,
    int? maxLength,
    String? placeholder,
    List<CustomizationChoice>? choices,
  }) {
    return CustomizationOption(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      required: required ?? this.required,
      maxSelections: maxSelections ?? this.maxSelections,
      maxLength: maxLength ?? this.maxLength,
      placeholder: placeholder ?? this.placeholder,
      choices: choices ?? this.choices,
    );
  }
}

/// Customization Choice Model
///
/// Represents an individual choice within a customization option.
class CustomizationChoice {
  final String id;
  final String name;
  final double priceModifier;

  CustomizationChoice({
    required this.id,
    required this.name,
    this.priceModifier = 0.0,
  });

  factory CustomizationChoice.fromJson(Map<String, dynamic> json) {
    return CustomizationChoice(
      id: json['id'].toString(),
      name: json['name'] as String,
      priceModifier: JsonParsers.parseDoubleWithDefault(json['price_modifier'], 0.0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price_modifier': priceModifier,
    };
  }

  CustomizationChoice copyWith({
    String? id,
    String? name,
    double? priceModifier,
  }) {
    return CustomizationChoice(
      id: id ?? this.id,
      name: name ?? this.name,
      priceModifier: priceModifier ?? this.priceModifier,
    );
  }
}

/// Update Menu Request
///
/// DTO for updating menu properties (all fields optional for partial updates)
class UpdateMenuRequest {
  final String? name;
  final String? description;
  final Map<String, dynamic>? menuConfig;
  final bool? isActive;

  UpdateMenuRequest({
    this.name,
    this.description,
    this.menuConfig,
    this.isActive,
  });

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (menuConfig != null) 'menu_config': JsonParsers.encodeJsonField(menuConfig!),
      if (isActive != null) 'is_active': isActive,
    };
  }
}
