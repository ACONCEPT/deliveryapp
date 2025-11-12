// This file demonstrates how to use the Menu models and MenuService
// This is an example file for documentation purposes only

import 'package:delivery_app/models/menu.dart';
import 'package:delivery_app/services/menu_service.dart';

/// Example: Creating a complete menu from scratch
void exampleCreateMenu() {
  // 1. Create customization options for items
  final sizeOption = CustomizationOption(
    id: 'size',
    name: 'Size',
    type: 'single_choice',
    required: true,
    choices: [
      CustomizationChoice(
        id: 'small',
        name: 'Small',
        priceModifier: 0.0,
      ),
      CustomizationChoice(
        id: 'medium',
        name: 'Medium',
        priceModifier: 2.0,
      ),
      CustomizationChoice(
        id: 'large',
        name: 'Large',
        priceModifier: 4.0,
      ),
    ],
  );

  final toppingsOption = CustomizationOption(
    id: 'toppings',
    name: 'Extra Toppings',
    type: 'multiple_choice',
    required: false,
    maxSelections: 5,
    choices: [
      CustomizationChoice(id: 'cheese', name: 'Extra Cheese', priceModifier: 1.0),
      CustomizationChoice(id: 'pepperoni', name: 'Pepperoni', priceModifier: 1.5),
      CustomizationChoice(id: 'mushrooms', name: 'Mushrooms', priceModifier: 0.75),
      CustomizationChoice(id: 'olives', name: 'Olives', priceModifier: 0.75),
    ],
  );

  // 2. Create menu items
  final pizza = MenuItem(
    id: 'pizza_margherita',
    name: 'Margherita Pizza',
    description: 'Classic pizza with tomato sauce, mozzarella, and fresh basil',
    price: 12.99,
    displayOrder: 0,
    isActive: true,
    isAvailable: true,
    imageUrl: 'https://example.com/images/margherita.jpg',
    preparationTimeMinutes: 15,
    calories: 800,
    dietaryFlags: {
      'vegetarian': true,
      'vegan': false,
      'gluten_free': false,
      'dairy_free': false,
    },
    allergens: ['gluten', 'dairy'],
    customizationOptions: [sizeOption, toppingsOption],
    tags: ['pizza', 'italian', 'popular'],
    spiceLevel: 0,
  );

  final salad = MenuItem(
    id: 'caesar_salad',
    name: 'Caesar Salad',
    description: 'Fresh romaine lettuce with parmesan and croutons',
    price: 8.99,
    displayOrder: 1,
    isActive: true,
    isAvailable: true,
    calories: 350,
    dietaryFlags: {
      'vegetarian': true,
      'vegan': false,
      'gluten_free': false,
    },
    allergens: ['dairy', 'gluten'],
  );

  // 3. Create categories
  final mainCoursesCategory = MenuCategory(
    id: 'main_courses',
    name: 'Main Courses',
    description: 'Our signature dishes',
    displayOrder: 0,
    isActive: true,
    items: [pizza],
  );

  final saladsCategory = MenuCategory(
    id: 'salads',
    name: 'Salads',
    description: 'Fresh and healthy options',
    displayOrder: 1,
    isActive: true,
    items: [salad],
  );

  // 4. Create menu with categories
  final menu = Menu(
    name: 'Main Menu',
    description: 'Our complete menu for all occasions',
    menuConfig: {
      'version': '1.0',
      'categories': [
        mainCoursesCategory.toJson(),
        saladsCategory.toJson(),
      ],
    },
    isActive: true,
  );

  // 5. Extract categories using helper method
  final categories = menu.getCategories();
  print('Menu has ${categories.length} categories');

  // 6. Calculate price with customizations
  final selectedOptions = {
    'size': 'large',
    'toppings': ['cheese', 'pepperoni'],
  };
  final totalPrice = pizza.calculatePrice(selectedCustomizations: selectedOptions);
  print('Pizza with large size and 2 toppings: \$${totalPrice.toStringAsFixed(2)}');
}

/// Example: Using MenuService to create a menu via API
Future<void> exampleCreateMenuViaAPI(String token) async {
  final menuService = MenuService();

  // Create a simple menu
  final menu = Menu(
    name: 'Lunch Special',
    description: 'Quick lunch options',
    menuConfig: {
      'version': '1.0',
      'categories': [
        {
          'id': 'sandwiches',
          'name': 'Sandwiches',
          'display_order': 0,
          'is_active': true,
          'items': [
            {
              'id': 'club_sandwich',
              'name': 'Club Sandwich',
              'description': 'Triple-decker with turkey, bacon, and veggies',
              'price': 9.99,
              'display_order': 0,
              'is_active': true,
              'is_available': true,
            },
          ],
        },
      ],
    },
  );

  try {
    // Create menu
    final createdMenu = await menuService.createMenu(token, menu);
    print('Menu created with ID: ${createdMenu.id}');

    // Get all vendor menus
    final allMenus = await menuService.getVendorMenus(token);
    print('Total menus: ${allMenus.length}');

    // Update menu
    final updatedMenu = createdMenu.copyWith(
      description: 'Updated description',
    );
    await menuService.updateMenu(token, createdMenu.id!, updatedMenu);
    print('Menu updated successfully');

    // Assign menu to restaurant
    await menuService.assignMenuToRestaurant(
      token,
      1, // restaurantId
      createdMenu.id!,
      isActive: true,
      displayOrder: 0,
    );
    print('Menu assigned to restaurant');

    // Set as active menu
    await menuService.setActiveMenu(token, 1, createdMenu.id!);
    print('Menu set as active');

  } catch (e) {
    print('Error: $e');
  }
}

/// Example: Customer viewing restaurant menu
Future<void> exampleCustomerViewMenu(String token, int restaurantId) async {
  final menuService = MenuService();

  try {
    // Get active menu for restaurant
    final menu = await menuService.getRestaurantMenu(token, restaurantId);

    if (menu == null) {
      print('No active menu available for this restaurant');
      return;
    }

    print('Menu: ${menu.name}');

    // Get categories
    final categories = menu.getCategories();

    for (final category in categories) {
      print('\nCategory: ${category.name}');
      print('  ${category.description ?? ""}');

      for (final item in category.items) {
        print('  - ${item.name} (\$${item.price.toStringAsFixed(2)})');
        print('    ${item.description}');

        // Show dietary flags
        if (item.dietaryFlags != null) {
          final flags = item.dietaryFlags!.entries
              .where((e) => e.value == true)
              .map((e) => e.key)
              .toList();
          if (flags.isNotEmpty) {
            print('    Dietary: ${flags.join(", ")}');
          }
        }

        // Show customizations available
        if (item.customizationOptions != null &&
            item.customizationOptions!.isNotEmpty) {
          print('    Customizations available');
        }
      }
    }
  } catch (e) {
    print('Error loading menu: $e');
  }
}

/// Example: Working with menu modifications
void exampleModifyMenu() {
  // Create initial menu
  final menu = Menu(
    name: 'Original Menu',
    menuConfig: {
      'version': '1.0',
      'categories': [],
    },
  );

  // Add a category
  final newCategory = MenuCategory(
    id: 'appetizers',
    name: 'Appetizers',
    items: [],
  );

  final categories = menu.getCategories();
  categories.add(newCategory);
  menu.setCategories(categories);

  // Use copyWith to create new version
  final updatedMenu = menu.copyWith(
    name: 'Updated Menu',
    description: 'New description',
  );

  print('Original: ${menu.name}');
  print('Updated: ${updatedMenu.name}');
}

/// Example: Handling menu assignment information
void exampleMenuAssignments() {
  final assignment = RestaurantMenuAssignment(
    restaurantId: 1,
    restaurantName: 'Pizza Palace',
    isActive: true,
    displayOrder: 0,
  );

  print('Menu assigned to: ${assignment.restaurantName}');
  print('Is active: ${assignment.isActive}');

  // Create menu with assignment info (typically from API)
  final menu = Menu(
    name: 'Main Menu',
    menuConfig: {},
    assignedRestaurants: [assignment],
  );

  if (menu.assignedRestaurants != null) {
    print('This menu is assigned to ${menu.assignedRestaurants!.length} restaurants');
  }
}

/// Example: Complex customization scenario
void exampleComplexCustomization() {
  final item = MenuItem(
    id: 'build_your_own_bowl',
    name: 'Build Your Own Bowl',
    description: 'Customize your perfect bowl',
    price: 10.99,
    customizationOptions: [
      // Base selection (required)
      CustomizationOption(
        id: 'base',
        name: 'Choose Your Base',
        type: 'single_choice',
        required: true,
        choices: [
          CustomizationChoice(id: 'rice', name: 'Rice', priceModifier: 0.0),
          CustomizationChoice(id: 'quinoa', name: 'Quinoa', priceModifier: 1.0),
          CustomizationChoice(id: 'salad', name: 'Salad', priceModifier: 0.5),
        ],
      ),
      // Protein selection (required)
      CustomizationOption(
        id: 'protein',
        name: 'Choose Your Protein',
        type: 'single_choice',
        required: true,
        choices: [
          CustomizationChoice(id: 'chicken', name: 'Grilled Chicken', priceModifier: 0.0),
          CustomizationChoice(id: 'beef', name: 'Beef', priceModifier: 2.0),
          CustomizationChoice(id: 'tofu', name: 'Tofu', priceModifier: 0.0),
          CustomizationChoice(id: 'shrimp', name: 'Shrimp', priceModifier: 3.0),
        ],
      ),
      // Vegetables (multiple choice)
      CustomizationOption(
        id: 'veggies',
        name: 'Add Vegetables',
        type: 'multiple_choice',
        required: false,
        maxSelections: 5,
        choices: [
          CustomizationChoice(id: 'broccoli', name: 'Broccoli', priceModifier: 0.5),
          CustomizationChoice(id: 'carrots', name: 'Carrots', priceModifier: 0.5),
          CustomizationChoice(id: 'peppers', name: 'Bell Peppers', priceModifier: 0.5),
        ],
      ),
      // Special instructions (text input)
      CustomizationOption(
        id: 'instructions',
        name: 'Special Instructions',
        type: 'text_input',
        required: false,
        maxLength: 200,
        placeholder: 'Any special requests?',
      ),
    ],
  );

  // Customer selections
  final selections = {
    'base': 'quinoa',
    'protein': 'shrimp',
    'veggies': ['broccoli', 'peppers'],
    'instructions': 'Extra sauce please',
  };

  final totalPrice = item.calculatePrice(selectedCustomizations: selections);
  print('Build Your Own Bowl:');
  print('  Base: Quinoa (+\$1.00)');
  print('  Protein: Shrimp (+\$3.00)');
  print('  Veggies: Broccoli (+\$0.50), Bell Peppers (+\$0.50)');
  print('  Total: \$${totalPrice.toStringAsFixed(2)}');
  // Expected: $10.99 + $1.00 + $3.00 + $0.50 + $0.50 = $15.99
}

void main() {
  print('Menu Model and Service Usage Examples\n');

  print('=== Example 1: Creating a complete menu ===');
  exampleCreateMenu();

  print('\n=== Example 2: Menu modifications ===');
  exampleModifyMenu();

  print('\n=== Example 3: Menu assignments ===');
  exampleMenuAssignments();

  print('\n=== Example 4: Complex customization ===');
  exampleComplexCustomization();

  // Async examples would need to be called with await
  // exampleCreateMenuViaAPI('your-token-here');
  // exampleCustomerViewMenu('your-token-here', 1);
}
