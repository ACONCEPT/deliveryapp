import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/models/menu.dart';

void main() {
  group('Menu Model Tests', () {
    test('Menu toJson and fromJson round trip', () {
      final menu = Menu(
        name: 'Test Menu',
        description: 'A test menu for testing',
        menuConfig: {
          'version': '1.0',
          'categories': [],
        },
      );

      final json = menu.toJson();
      final decoded = Menu.fromJson(json);

      expect(decoded.name, menu.name);
      expect(decoded.description, menu.description);
      expect(decoded.isActive, menu.isActive);
    });

    test('Menu handles menuConfig as String from API', () {
      final jsonFromApi = {
        'id': 1,
        'name': 'API Menu',
        'menu_config': '{"version":"1.0","categories":[]}',
        'is_active': true,
      };

      final menu = Menu.fromJson(jsonFromApi);

      expect(menu.id, 1);
      expect(menu.name, 'API Menu');
      expect(menu.menuConfig['version'], '1.0');
      expect(menu.menuConfig['categories'], []);
    });

    test('Menu getCategories returns parsed categories', () {
      final menu = Menu(
        name: 'Test',
        menuConfig: {
          'categories': [
            {
              'id': 'cat1',
              'name': 'Category 1',
              'display_order': 0,
              'is_active': true,
              'items': [],
            },
          ],
        },
      );

      final categories = menu.getCategories();
      expect(categories.length, 1);
      expect(categories[0].name, 'Category 1');
      expect(categories[0].id, 'cat1');
    });

    test('Menu setCategories updates menuConfig', () {
      final menu = Menu(
        name: 'Test',
        menuConfig: {},
      );

      final category = MenuCategory(
        id: 'cat1',
        name: 'New Category',
      );

      menu.setCategories([category]);

      expect(menu.menuConfig['categories'], isNotNull);
      expect(menu.menuConfig['categories'], isList);
      expect((menu.menuConfig['categories'] as List).length, 1);
    });

    test('Menu copyWith creates new instance with updated values', () {
      final menu = Menu(
        name: 'Original',
        menuConfig: {},
      );

      final updated = menu.copyWith(name: 'Updated');

      expect(updated.name, 'Updated');
      expect(menu.name, 'Original'); // Original unchanged
    });
  });

  group('MenuCategory Model Tests', () {
    test('MenuCategory toJson and fromJson round trip', () {
      final category = MenuCategory(
        id: 'cat1',
        name: 'Appetizers',
        description: 'Start your meal',
        displayOrder: 0,
        items: [],
      );

      final json = category.toJson();
      final decoded = MenuCategory.fromJson(json);

      expect(decoded.id, category.id);
      expect(decoded.name, category.name);
      expect(decoded.description, category.description);
      expect(decoded.displayOrder, category.displayOrder);
    });

    test('MenuCategory handles items list correctly', () {
      final item = MenuItem(
        id: 'item1',
        name: 'Test Item',
        description: 'A test item',
        price: 9.99,
      );

      final category = MenuCategory(
        id: 'cat1',
        name: 'Category',
        items: [item],
      );

      expect(category.items.length, 1);
      expect(category.items[0].name, 'Test Item');

      final json = category.toJson();
      final decoded = MenuCategory.fromJson(json);

      expect(decoded.items.length, 1);
      expect(decoded.items[0].name, 'Test Item');
    });
  });

  group('MenuItem Model Tests', () {
    test('MenuItem toJson and fromJson round trip', () {
      final item = MenuItem(
        id: 'item1',
        name: 'Burger',
        description: 'Delicious burger',
        price: 12.99,
        displayOrder: 0,
        isActive: true,
        isAvailable: true,
        calories: 500,
      );

      final json = item.toJson();
      final decoded = MenuItem.fromJson(json);

      expect(decoded.id, item.id);
      expect(decoded.name, item.name);
      expect(decoded.price, item.price);
      expect(decoded.calories, item.calories);
    });

    test('MenuItem handles dietary flags correctly', () {
      final item = MenuItem(
        id: 'item1',
        name: 'Salad',
        description: 'Healthy salad',
        price: 8.99,
        dietaryFlags: {
          'vegetarian': true,
          'vegan': true,
          'gluten_free': false,
        },
      );

      final json = item.toJson();
      final decoded = MenuItem.fromJson(json);

      expect(decoded.dietaryFlags, isNotNull);
      expect(decoded.dietaryFlags!['vegetarian'], true);
      expect(decoded.dietaryFlags!['vegan'], true);
      expect(decoded.dietaryFlags!['gluten_free'], false);
    });

    test('MenuItem calculatePrice with single choice customization', () {
      final item = MenuItem(
        id: 'item1',
        name: 'Pizza',
        description: 'Delicious pizza',
        price: 10.0,
        customizationOptions: [
          CustomizationOption(
            id: 'size',
            name: 'Size',
            type: 'single_choice',
            choices: [
              CustomizationChoice(id: 'small', name: 'Small', priceModifier: 0.0),
              CustomizationChoice(id: 'large', name: 'Large', priceModifier: 2.0),
            ],
          ),
        ],
      );

      final selectedOptions = {'size': 'large'};
      final finalPrice = item.calculatePrice(selectedCustomizations: selectedOptions);
      expect(finalPrice, 12.0);
    });

    test('MenuItem calculatePrice with multiple choice customization', () {
      final item = MenuItem(
        id: 'item1',
        name: 'Pizza',
        description: 'Delicious pizza',
        price: 10.0,
        customizationOptions: [
          CustomizationOption(
            id: 'toppings',
            name: 'Toppings',
            type: 'multiple_choice',
            choices: [
              CustomizationChoice(id: 'cheese', name: 'Extra Cheese', priceModifier: 1.0),
              CustomizationChoice(id: 'pepperoni', name: 'Pepperoni', priceModifier: 1.5),
            ],
          ),
        ],
      );

      final selectedOptions = {
        'toppings': ['cheese', 'pepperoni']
      };
      final finalPrice = item.calculatePrice(selectedCustomizations: selectedOptions);
      expect(finalPrice, 12.5);
    });

    test('MenuItem calculatePrice with no customizations', () {
      final item = MenuItem(
        id: 'item1',
        name: 'Burger',
        description: 'Plain burger',
        price: 8.0,
      );

      final selectedOptions = <String, dynamic>{};
      final finalPrice = item.calculatePrice(selectedCustomizations: selectedOptions);
      expect(finalPrice, 8.0);
    });
  });

  group('CustomizationOption Model Tests', () {
    test('CustomizationOption toJson and fromJson round trip', () {
      final option = CustomizationOption(
        id: 'size',
        name: 'Size',
        type: 'single_choice',
        required: true,
        choices: [
          CustomizationChoice(id: 'small', name: 'Small', priceModifier: 0.0),
          CustomizationChoice(id: 'large', name: 'Large', priceModifier: 2.0),
        ],
      );

      final json = option.toJson();
      final decoded = CustomizationOption.fromJson(json);

      expect(decoded.id, option.id);
      expect(decoded.name, option.name);
      expect(decoded.type, option.type);
      expect(decoded.required, option.required);
      expect(decoded.choices!.length, 2);
    });

    test('CustomizationOption handles text input type', () {
      final option = CustomizationOption(
        id: 'instructions',
        name: 'Special Instructions',
        type: 'text_input',
        maxLength: 200,
        placeholder: 'Any special requests?',
      );

      final json = option.toJson();
      final decoded = CustomizationOption.fromJson(json);

      expect(decoded.type, 'text_input');
      expect(decoded.maxLength, 200);
      expect(decoded.placeholder, 'Any special requests?');
      expect(decoded.choices, isNull);
    });
  });

  group('CustomizationChoice Model Tests', () {
    test('CustomizationChoice toJson and fromJson round trip', () {
      final choice = CustomizationChoice(
        id: 'large',
        name: 'Large Size',
        priceModifier: 2.5,
      );

      final json = choice.toJson();
      final decoded = CustomizationChoice.fromJson(json);

      expect(decoded.id, choice.id);
      expect(decoded.name, choice.name);
      expect(decoded.priceModifier, choice.priceModifier);
    });

    test('CustomizationChoice defaults priceModifier to 0.0', () {
      final choice = CustomizationChoice(
        id: 'regular',
        name: 'Regular',
      );

      expect(choice.priceModifier, 0.0);

      final json = choice.toJson();
      final decoded = CustomizationChoice.fromJson(json);

      expect(decoded.priceModifier, 0.0);
    });
  });

  group('RestaurantMenuAssignment Model Tests', () {
    test('RestaurantMenuAssignment toJson and fromJson round trip', () {
      final assignment = RestaurantMenuAssignment(
        restaurantId: 1,
        restaurantName: 'Pizza Palace',
        isActive: true,
        displayOrder: 0,
      );

      final json = assignment.toJson();
      final decoded = RestaurantMenuAssignment.fromJson(json);

      expect(decoded.restaurantId, assignment.restaurantId);
      expect(decoded.restaurantName, assignment.restaurantName);
      expect(decoded.isActive, assignment.isActive);
      expect(decoded.displayOrder, assignment.displayOrder);
    });
  });

  group('Integration Tests', () {
    test('Complete menu with categories and items serialization', () {
      // Create a complete menu structure
      final menu = Menu(
        name: 'Main Menu',
        description: 'Our complete menu',
        menuConfig: {
          'version': '1.0',
          'categories': [
            {
              'id': 'appetizers',
              'name': 'Appetizers',
              'description': 'Start your meal',
              'display_order': 0,
              'is_active': true,
              'items': [
                {
                  'id': 'garlic_bread',
                  'name': 'Garlic Bread',
                  'description': 'Fresh baked',
                  'price': 5.99,
                  'display_order': 0,
                  'is_active': true,
                  'is_available': true,
                  'dietary_flags': {
                    'vegetarian': true,
                    'vegan': false,
                  },
                  'customization_options': [
                    {
                      'id': 'cheese',
                      'name': 'Add Cheese',
                      'type': 'single_choice',
                      'required': false,
                      'choices': [
                        {
                          'id': 'yes',
                          'name': 'Yes',
                          'price_modifier': 1.0,
                        },
                        {
                          'id': 'no',
                          'name': 'No',
                          'price_modifier': 0.0,
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },
      );

      // Test categories extraction
      final categories = menu.getCategories();
      expect(categories.length, 1);
      expect(categories[0].name, 'Appetizers');
      expect(categories[0].items.length, 1);

      // Test item details
      final item = categories[0].items[0];
      expect(item.name, 'Garlic Bread');
      expect(item.price, 5.99);
      expect(item.dietaryFlags!['vegetarian'], true);
      expect(item.customizationOptions!.length, 1);

      // Test customization
      final customization = item.customizationOptions![0];
      expect(customization.name, 'Add Cheese');
      expect(customization.choices!.length, 2);

      // Test price calculation
      final priceWithCheese = item.calculatePrice(selectedCustomizations: {'cheese': 'yes'});
      expect(priceWithCheese, 6.99);

      // Test JSON round trip
      final json = menu.toJson();
      final decoded = Menu.fromJson(json);
      final decodedCategories = decoded.getCategories();
      expect(decodedCategories.length, 1);
      expect(decodedCategories[0].items[0].name, 'Garlic Bread');
    });
  });
}
