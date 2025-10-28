# Detailed Index - Frontend Source Code Files
# Detailed summaries with class names, method signatures, and line numbers

================================================================================
FILE: main.dart
================================================================================
PURPOSE: Application entry point with MaterialApp configuration and theming.
LANGUAGE: Dart (Flutter)
DEPENDENCIES: flutter/material, screens/login_screen

FUNCTION: main() [line 4]
  - Application entry point
  - Calls runApp() with DeliveryApp widget

CLASS: DeliveryApp [lines 8-59]
  - StatelessWidget for root application widget
  - Configures MaterialApp with theme and routing

  Constructor: const DeliveryApp({super.key}) [line 9]

  Method: build(BuildContext context) -> Widget [line 12]
    - Returns MaterialApp with comprehensive theme configuration
    - Sets up Material Design 3 with ColorScheme from deep orange seed
    - Configures InputDecorationTheme with rounded borders and grey fills
    - Sets up ElevatedButtonTheme with deep orange styling
    - Configures CardTheme with rounded corners
    - Sets home to LoginScreen

THEME CONFIGURATION:
  - Color scheme: Deep orange seed with light brightness [lines 17-20]
  - Input decoration: Rounded borders, grey fill, orange focus [lines 22-37]
  - Elevated buttons: Deep orange background, white foreground [lines 38-48]
  - Cards: Rounded 16px corners, elevation 2 [lines 49-54]


================================================================================
FILE: models/user.dart
================================================================================
PURPOSE: User authentication data models with JSON serialization.
LANGUAGE: Dart
DEPENDENCIES: None (core Dart only)

CLASS: User [lines 1-43]
  Fields:
    - int id
    - String username
    - String email
    - String userType
    - String status
    - DateTime createdAt
    - DateTime updatedAt

  Constructor: User({required this.id, ...}) [lines 10-18]
    - All fields required

  Factory: User.fromJson(Map<String, dynamic> json) -> User [line 20]
    - Parses JSON from API response
    - Converts created_at and updated_at strings to DateTime

  Method: toJson() -> Map<String, dynamic> [line 32]
    - Serializes user to JSON for API requests
    - Converts DateTime to ISO8601 strings

CLASS: LoginResponse [lines 45-69]
  Fields:
    - bool success
    - String message
    - String? token (nullable)
    - User? user (nullable)
    - Map<String, dynamic>? profile (nullable)

  Constructor: LoginResponse({required this.success, ...}) [lines 52-58]
    - success and message required, others optional

  Factory: LoginResponse.fromJson(Map<String, dynamic> json) -> LoginResponse [line 60]
    - Parses JSON login response from backend
    - Conditionally creates User from nested JSON

CLASS: SignupResponse [lines 71-89]
  Fields:
    - bool success
    - String message
    - int? userId (nullable)

  Constructor: SignupResponse({required this.success, ...}) [lines 76-80]

  Factory: SignupResponse.fromJson(Map<String, dynamic> json) -> SignupResponse [line 82]
    - Parses JSON signup response from backend


================================================================================
FILE: models/restaurant.dart
================================================================================
PURPOSE: Restaurant data model with UI display properties.
LANGUAGE: Dart (Flutter)
DEPENDENCIES: flutter/material

CLASS: Restaurant [lines 3-45]
  Fields:
    - int? id (nullable)
    - String name
    - String cuisine
    - double rating
    - String deliveryTime
    - IconData? iconData (nullable)
    - Color? iconColor (nullable)
    - String? imageUrl (nullable)

  Constructor: const Restaurant({this.id, required this.name, ...}) [lines 13-22]
    - name, cuisine, rating, deliveryTime required
    - id, iconData, iconColor, imageUrl optional

  Factory: Restaurant.fromJson(Map<String, dynamic> json) -> Restaurant [line 24]
    - Parses JSON from backend API
    - Casts numeric rating to double

  Method: toJson() -> Map<String, dynamic> [line 35]
    - Serializes restaurant to JSON


================================================================================
FILE: models/address.dart
================================================================================
PURPOSE: Customer address data model with comprehensive address fields and helpers.
LANGUAGE: Dart
DEPENDENCIES: None (core Dart only)

CLASS: Address [lines 1-127]
  Fields:
    - int? id (nullable)
    - int? customerId (nullable)
    - String addressLine1
    - String? addressLine2 (nullable)
    - String city
    - String? state (nullable)
    - String? postalCode (nullable)
    - String country
    - double? latitude (nullable)
    - double? longitude (nullable)
    - bool isDefault (default: false)
    - DateTime? createdAt (nullable)
    - DateTime? updatedAt (nullable)

  Constructor: Address({this.id, required this.addressLine1, ...}) [lines 16-30]
    - addressLine1, city, country required
    - isDefault defaults to false

  Factory: Address.fromJson(Map<String, dynamic> json) -> Address [line 32]
    - Parses JSON from backend API
    - Handles nullable fields and type conversions
    - Converts numeric lat/long to double
    - Parses ISO8601 datetime strings

  Method: toJson() -> Map<String, dynamic> [line 58]
    - Serializes address to JSON for API
    - Uses conditional inclusion for nullable fields

  Getter: formattedAddress -> String [line 75]
    - Returns comma-separated full address string
    - Includes all non-empty address components

  Getter: shortAddress -> String [line 88]
    - Returns brief address with line1 and city only

  Method: copyWith({...}) -> Address [line 96]
    - Creates new Address with selectively updated fields
    - All parameters optional, uses existing values as defaults


================================================================================
FILE: config/dashboard_constants.dart
================================================================================
PURPOSE: Centralized UI constants for dashboard layout and styling.
LANGUAGE: Dart
DEPENDENCIES: None (core Dart only)

CLASS: DashboardConstants [lines 1-39]
  - Static constants class (no instances created)

  Grid Layout Constants:
    - dashboardGridColumns: 5 [line 3]
    - gridSpacing: 12.0 [line 4]
    - dashboardCardAspectRatio: 1.0 [line 5]
    - restaurantCardAspectRatio: 0.85 [line 6]

  Padding & Spacing Constants:
    - cardPadding: 24.0 [line 9]
    - cardPaddingSmall: 12.0 [line 10]
    - sectionSpacing: 24.0 [line 11]
    - screenPadding: 32.0 [line 12]

  Card Styling Constants:
    - cardElevation: 8.0 [line 15]
    - cardElevationSmall: 3.0 [line 16]
    - cardElevationRestaurant: 2.0 [line 17]
    - cardBorderRadius: 16.0 [line 18]
    - cardBorderRadiusSmall: 12.0 [line 19]
    - cardBorderRadiusExtraSmall: 8.0 [line 20]

  Icon Size Constants:
    - dashboardIconSize: 32.0 [line 23]
    - restaurantIconSize: 40.0 [line 24]
    - sectionHeaderIconSize: 24.0 [line 25]

  Text Size Constants:
    - dashboardCardTextSize: 12.0 [line 28]
    - restaurantNameTextSize: 14.0 [line 29]
    - restaurantCuisineTextSize: 12.0 [line 30]
    - restaurantInfoTextSize: 12.0 [line 31]
    - restaurantInfoSmallTextSize: 11.0 [line 32]

  Other Constants:
    - restaurantCardMaxLines: 2 [line 35]
    - restaurantImageHeight: 80.0 [line 36]
    - userInfoPopupWidth: 280.0 [line 37]
    - userInfoPopupMaxHeight: 400.0 [line 38]


================================================================================
FILE: config/user_type_config.dart
================================================================================
PURPOSE: User type configuration with role-specific UI helpers.
LANGUAGE: Dart (Flutter)
DEPENDENCIES: flutter/material

CLASS: UserTypeConfig [lines 3-58]
  Constants:
    - customer: 'customer' [line 4]
    - vendor: 'vendor' [line 5]
    - driver: 'driver' [line 6]
    - admin: 'admin' [line 7]

  Static Method: getColor(String userType) -> Color [line 9]
    - Returns role-specific color
    - customer: blue, vendor: orange, driver: purple, admin: red

  Static Method: getTitle(String userType) -> String [line 24]
    - Returns dashboard title for user type
    - Example: "Customer Dashboard", "Vendor Dashboard"

  Static Method: formatUserType(String userType) -> String [line 39]
    - Capitalizes first letter of user type
    - Returns empty string for empty input

  Static Method: getIcon(String userType) -> IconData [line 44]
    - Returns role-specific icon
    - customer: person, vendor: store, driver: local_shipping, admin: admin_panel_settings


================================================================================
FILE: config/dashboard_widget_config.dart
================================================================================
PURPOSE: Dashboard widget configuration providing role-specific widget definitions.
LANGUAGE: Dart (Flutter)
DEPENDENCIES: flutter/material, user_type_config

CLASS: DashboardWidgetConfig [lines 4-97]
  Fields:
    - String title
    - IconData icon
    - Color color
    - String? route (nullable)
    - VoidCallback? onTap (nullable)

  Constructor: const DashboardWidgetConfig({required this.title, ...}) [lines 11-17]
    - title, icon, color required
    - route and onTap optional

  Static Method: getWidgetsForUserType(String userType) -> List<DashboardWidgetConfig> [line 19]
    - Returns list of widgets for specific user type
    - Admin widgets [lines 21-43]: Restaurant Admin, Vendor Admin, Order Dashboard, Approvals
    - Vendor widgets [lines 45-57]: Create Restaurant, Order Dashboard
    - Customer widgets [lines 59-77]: Order Now, Recent Orders, Manage Addresses (with /addresses route)
    - Driver widgets [lines 79-91]: Delivery, Open Orders
    - Returns empty list for unknown types


================================================================================
FILE: services/api_service.dart
================================================================================
PURPOSE: HTTP API service for user authentication endpoints.
LANGUAGE: Dart
DEPENDENCIES: dart:convert, dart:developer, http, models/user

CLASS: ApiService [lines 6-129]
  Constants:
    - baseUrl: 'http://localhost:8080' [line 8]

  Method: _logRequest(String method, String url, Map<String, String> headers, {String? body}) [line 14]
    - Private logging helper for API requests
    - Logs method, URL, headers, and optional body

  Method: _logResponse(String method, String url, int statusCode, String body) [line 22]
    - Private logging helper for API responses
    - Logs status code and response body

  Method: login(String username, String password) -> Future<LoginResponse> [line 30]
    - Sends POST request to /api/login
    - Encodes username and password as JSON
    - Returns LoginResponse on success
    - Handles network errors and returns error LoginResponse

  Method: signup({required String username, ...}) -> Future<SignupResponse> [line 69]
    - Sends POST request to /api/signup
    - Parameters: username, email, password, userType, fullName required
    - Optional parameters: phone, businessName, description, vehicleType, vehiclePlate, licenseNumber
    - Returns SignupResponse on success (status 200 or 201)
    - Handles network errors and returns error SignupResponse


================================================================================
FILE: services/restaurant_service.dart
================================================================================
PURPOSE: Restaurant data service with mock data for development.
LANGUAGE: Dart (Flutter)
DEPENDENCIES: flutter/material, models/restaurant

CLASS: RestaurantService [lines 4-72]
  Static Method: getMockRestaurants() -> List<Restaurant> [line 6]
    - Returns hardcoded list of 5 mock restaurants
    - Pizza Palace, Burger Haven, Sushi Spot, Taco Town, Curry House
    - Each with icon, color, rating, and delivery time

  Static Method: getFeaturedRestaurants() -> Future<List<Restaurant>> [line 52]
    - Placeholder for API integration (TODO comment)
    - Currently returns mock data
    - Future: Will fetch from /restaurants/featured endpoint

  Static Method: getVendorRestaurants(int vendorId) -> Future<List<Restaurant>> [line 63]
    - Placeholder for API integration (TODO comment)
    - Currently returns mock data
    - Future: Will fetch from /vendors/{vendorId}/restaurants endpoint


================================================================================
FILE: services/address_service.dart
================================================================================
PURPOSE: Address CRUD service with full HTTP API integration.
LANGUAGE: Dart
DEPENDENCIES: dart:convert, dart:developer, http, models/address

CLASS: AddressService [lines 6-240]
  Constants:
    - baseUrl: 'http://localhost:8080' [line 7]

  Method: _logRequest(String method, String url, Map<String, String> headers, {String? body}) [line 9]
    - Private logging helper for API requests

  Method: _logResponse(String method, String url, int statusCode, String body) [line 17]
    - Private logging helper for API responses

  Method: getAddresses(String token) -> Future<List<Address>> [line 26]
    - GET /api/addresses with Bearer token
    - Returns list of addresses for authenticated customer
    - Handles null/empty addresses array gracefully
    - Throws exception on API errors

  Method: getAddress(String token, int addressId) -> Future<Address> [line 80]
    - GET /api/addresses/{addressId} with Bearer token
    - Returns single address by ID
    - Throws exception on errors

  Method: createAddress(String token, Address address) -> Future<Address> [line 112]
    - POST /api/customer/addresses with Bearer token
    - Sends address as JSON body
    - Returns created address from API (status 200 or 201)
    - Throws exception on errors

  Method: updateAddress(String token, int addressId, Address address) -> Future<Address> [line 147]
    - PUT /api/customer/addresses/{addressId} with Bearer token
    - Sends updated address as JSON body
    - Returns updated address from API
    - Throws exception on errors

  Method: deleteAddress(String token, int addressId) -> Future<void> [line 182]
    - DELETE /api/customer/addresses/{addressId} with Bearer token
    - No return value on success
    - Throws exception on errors

  Method: setDefaultAddress(String token, int addressId) -> Future<void> [line 212]
    - PUT /api/customer/addresses/{addressId}/set-default with Bearer token
    - No request body
    - No return value on success
    - Throws exception on errors


================================================================================
FILE: screens/login_screen.dart
================================================================================
PURPOSE: Login screen with authentication form and credential validation.
LANGUAGE: Dart (Flutter)
DEPENDENCIES: flutter/material, services/api_service, models/user, screens/confirmation_screen

CLASS: LoginScreen [lines 6-249]
  - StatefulWidget for login UI

  Constructor: const LoginScreen({super.key}) [line 7]

  Method: createState() -> State<LoginScreen> [line 10]
    - Creates _LoginScreenState

CLASS: _LoginScreenState [lines 13-249]
  - State class managing login form and authentication

  Fields:
    - GlobalKey<FormState> _formKey [line 14]
    - TextEditingController _usernameController [line 15]
    - TextEditingController _passwordController [line 16]
    - ApiService _apiService [line 17]
    - bool _isLoading [line 18]
    - bool _obscurePassword [line 19]

  Method: dispose() [line 22]
    - Disposes text controllers to prevent memory leaks

  Method: _handleLogin() -> Future<void> [line 28]
    - Validates form fields
    - Calls API service login method
    - Navigates to ConfirmationScreen on success
    - Shows error SnackBar on failure
    - Manages loading state

  Method: build(BuildContext context) -> Widget [line 76]
    - Builds login UI with Scaffold and Form
    - Contains app logo, title, username/password fields
    - Login button with loading indicator
    - Test credentials info box

  Method: _buildCredentialRow(String role, String username) -> Widget [line 237]
    - Helper to build test credential display rows


================================================================================
FILE: screens/confirmation_screen.dart
================================================================================
PURPOSE: Post-login dashboard with user info and role-specific content.
LANGUAGE: Dart (Flutter)
DEPENDENCIES: flutter/material, models/user, config/*, services/restaurant_service, widgets/*, painters/checkered_painter, screens/address_list_screen

CLASS: ConfirmationScreen [lines 12-365]
  - StatelessWidget for main dashboard

  Fields:
    - User user
    - Map<String, dynamic>? profile (nullable)
    - String token

  Constructor: const ConfirmationScreen({super.key, required this.user, ...}) [lines 17-22]

  Method: build(BuildContext context) -> Widget [line 25]
    - Returns Scaffold with AppBar and Stack layout
    - Stack contains checkered background and scrollable content

  Method: _buildAppBar(BuildContext context) -> AppBar [line 37]
    - Creates role-colored AppBar with user type title
    - Includes PopupMenuButton for user info display

  Method: _buildCheckeredBackground() -> Widget [line 62]
    - Returns CustomPaint with CheckeredPainter

  Method: _buildDashboardContent() -> Widget [line 69]
    - SingleChildScrollView with dashboard widgets card
    - Conditionally shows customer or vendor sections

  Method: _handleWidgetTap(BuildContext context, DashboardWidgetConfig config) [line 88]
    - Handles widget tap events
    - Routes to appropriate screen (e.g., /addresses -> AddressListScreen)

  Method: _buildDashboardWidgetsCard() -> Widget [line 106]
    - Creates Card with GridView of DashboardCard widgets
    - Gets widgets from DashboardWidgetConfig for user type

  Method: _buildCustomerSections() -> List<Widget> [line 140]
    - Returns RestaurantSection with featured restaurants
    - Used when userType is customer

  Method: _buildVendorSections() -> List<Widget> [line 154]
    - Returns RestaurantSection with vendor's restaurants
    - Used when userType is vendor

  Method: _buildUserInfoContent() -> Widget [line 168]
    - Builds popup content showing user details
    - Displays username, email, user type, status
    - Conditionally shows profile info based on user type

  Method: _buildInfoRow({required IconData icon, ...}) -> Widget [line 216]
    - Helper to build info rows with icon, label, and value
    - Optional valueColor parameter

  Method: _buildProfileInfo() -> List<Widget> [line 253]
    - Builds profile-specific info based on user type
    - Customer: full_name, phone
    - Vendor: business_name, phone, city, rating
    - Driver: full_name, phone, vehicle_type, availability
    - Admin: full_name, role


================================================================================
FILE: screens/address_list_screen.dart
================================================================================
PURPOSE: Address list management screen with CRUD operations.
LANGUAGE: Dart (Flutter)
DEPENDENCIES: flutter/material, models/address, services/address_service, screens/address_form_screen

CLASS: AddressListScreen [lines 6-218]
  - StatefulWidget for address list view

  Fields:
    - String token

  Constructor: const AddressListScreen({super.key, required this.token}) [lines 9-12]

  Method: createState() -> State<AddressListScreen> [line 15]

CLASS: _AddressListScreenState [lines 18-218]
  - State class managing address list and operations

  Fields:
    - AddressService _addressService [line 19]
    - List<Address> _addresses [line 20]
    - bool _isLoading [line 21]
    - String? _errorMessage [line 22]

  Method: initState() [line 25]
    - Calls _loadAddresses on screen initialization

  Method: _loadAddresses() -> Future<void> [line 30]
    - Fetches addresses from API
    - Updates state with addresses or error message
    - Includes print statements for debugging

  Method: _deleteAddress(int addressId) -> Future<void> [line 55]
    - Shows confirmation dialog
    - Calls API to delete address
    - Reloads list on success
    - Shows SnackBar for feedback

  Method: _setDefaultAddress(int addressId) -> Future<void> [line 91]
    - Calls API to set default address
    - Reloads list on success
    - Shows SnackBar for feedback

  Method: _navigateToAddAddress() -> Future<void> [line 105]
    - Navigates to AddressFormScreen for creating new address
    - Reloads list if result is true

  Method: _navigateToEditAddress(Address address) -> Future<void> [line 120]
    - Navigates to AddressFormScreen with existing address
    - Reloads list if result is true

  Method: build(BuildContext context) -> Widget [line 137]
    - Builds Scaffold with AppBar
    - Shows loading indicator, error message, or address list
    - Includes RefreshIndicator for pull-to-refresh
    - FloatingActionButton for adding addresses

CLASS: _AddressCard [lines 220-342]
  - StatelessWidget for individual address display

  Fields:
    - Address address
    - VoidCallback onEdit
    - VoidCallback onDelete
    - VoidCallback? onSetDefault (nullable)

  Constructor: const _AddressCard({required this.address, ...}) [lines 226-231]

  Method: build(BuildContext context) -> Widget [line 234]
    - Builds Card with address details
    - Shows DEFAULT badge if isDefault is true
    - Action buttons: Set Default (if not default), Edit, Delete


================================================================================
FILE: screens/address_form_screen.dart
================================================================================
PURPOSE: Address creation and editing form with validation.
LANGUAGE: Dart (Flutter)
DEPENDENCIES: flutter/material, models/address, services/address_service

CLASS: AddressFormScreen [lines 5-272]
  - StatefulWidget for address form

  Fields:
    - String token
    - Address? address (nullable - null for create, provided for edit)

  Constructor: const AddressFormScreen({super.key, required this.token, this.address}) [lines 9-13]

  Method: createState() -> State<AddressFormScreen> [line 16]

CLASS: _AddressFormScreenState [lines 19-272]
  - State class managing form input and submission

  Fields:
    - GlobalKey<FormState> _formKey [line 20]
    - AddressService _addressService [line 21]
    - TextEditingController for each field [lines 23-28]
    - bool _isDefault [line 29]
    - bool _isLoading [line 30]

  Getter: _isEditMode -> bool [line 32]
    - Returns true if widget.address is not null

  Method: initState() [line 35]
    - Initializes text controllers with existing address data if editing
    - Sets default values for new addresses

  Method: dispose() [line 61]
    - Disposes all text controllers

  Method: _saveAddress() -> Future<void> [line 71]
    - Validates form
    - Creates Address object from form inputs
    - Calls updateAddress or createAddress based on mode
    - Shows SnackBar on success
    - Pops screen with true result
    - Handles errors with SnackBar

  Method: build(BuildContext context) -> Widget [line 135]
    - Builds Scaffold with Form
    - Address line 1 and 2 fields
    - City, state, postal code, country fields
    - SwitchListTile for default address toggle
    - Save button with loading indicator


================================================================================
FILE: widgets/dashboard_card.dart
================================================================================
PURPOSE: Reusable dashboard action card widget.
LANGUAGE: Dart (Flutter)
DEPENDENCIES: flutter/material, config/dashboard_constants

CLASS: DashboardCard [lines 4-55]
  - StatelessWidget for dashboard grid items

  Fields:
    - String title
    - IconData icon
    - Color color
    - VoidCallback onTap

  Constructor: const DashboardCard({super.key, required this.title, ...}) [lines 10-16]
    - All fields required

  Method: build(BuildContext context) -> Widget [line 19]
    - Returns Card with InkWell for tap handling
    - Column layout with icon and title
    - Uses DashboardConstants for consistent sizing
    - Text ellipsis for long titles (max 2 lines)


================================================================================
FILE: widgets/restaurant_card.dart
================================================================================
PURPOSE: Restaurant display card for grid layout.
LANGUAGE: Dart (Flutter)
DEPENDENCIES: flutter/material, models/restaurant, config/dashboard_constants

CLASS: RestaurantCard [lines 5-113]
  - StatelessWidget for restaurant display

  Fields:
    - Restaurant restaurant
    - VoidCallback? onTap (nullable)

  Constructor: const RestaurantCard({super.key, required this.restaurant, this.onTap}) [lines 9-13]

  Method: build(BuildContext context) -> Widget [line 16]
    - Returns Card with InkWell
    - Column layout with image, name, cuisine, and info row

  Method: _buildRestaurantImage() -> Widget [line 44]
    - Colored container with icon or network image
    - Falls back to default restaurant icon on error
    - Fixed height from DashboardConstants

  Method: _buildRestaurantName() -> Widget [line 69]
    - Bold text with ellipsis for overflow
    - Single line truncation

  Method: _buildCuisineType() -> Widget [line 81]
    - Grey text showing cuisine type

  Method: _buildRestaurantInfo() -> Widget [line 91]
    - Row with star rating and delivery time
    - Uses icons with text


================================================================================
FILE: widgets/section_header.dart
================================================================================
PURPOSE: Section header widget with icon and title.
LANGUAGE: Dart (Flutter)
DEPENDENCIES: flutter/material, config/dashboard_constants

CLASS: SectionHeader [lines 4-35]
  - StatelessWidget for section titles

  Fields:
    - String title
    - IconData icon
    - Color iconColor

  Constructor: const SectionHeader({super.key, required this.title, ...}) [lines 9-14]
    - All fields required

  Method: build(BuildContext context) -> Widget [line 17]
    - Returns Row with icon and bold title text
    - Icon size from DashboardConstants


================================================================================
FILE: widgets/restaurant_section.dart
================================================================================
PURPOSE: Complete restaurant section with header and grid.
LANGUAGE: Dart (Flutter)
DEPENDENCIES: flutter/material, models/restaurant, config/dashboard_constants, widgets/restaurant_card, widgets/section_header

CLASS: RestaurantSection [lines 7-59]
  - StatelessWidget combining header and restaurant grid

  Fields:
    - String title
    - IconData headerIcon
    - Color headerIconColor
    - List<Restaurant> restaurants

  Constructor: const RestaurantSection({super.key, required this.title, ...}) [lines 13-19]
    - All fields required

  Method: build(BuildContext context) -> Widget [line 22]
    - Returns Card container
    - SectionHeader at top
    - GridView.builder with restaurant cards
    - Uses DashboardConstants for grid configuration
    - Non-scrollable grid (shrinkWrap: true)


================================================================================
FILE: painters/checkered_painter.dart
================================================================================
PURPOSE: Custom painter for checkered background pattern.
LANGUAGE: Dart (Flutter)
DEPENDENCIES: flutter/material

CLASS: CheckeredPainter [lines 3-42]
  - Extends CustomPainter for canvas drawing

  Fields:
    - double squareSize
    - Color color1
    - Color color2

  Constructor: CheckeredPainter({this.squareSize = 40.0, Color? color1, Color? color2}) [lines 8-13]
    - squareSize defaults to 40.0
    - color1 defaults to Colors.grey[200]
    - color2 defaults to Colors.grey[100]

  Method: paint(Canvas canvas, Size size) [line 16]
    - Draws alternating checkered pattern
    - Nested loops iterate over grid positions
    - Alternates colors based on (i + j) % 2
    - Draws rectangles with calculated positions

  Method: shouldRepaint(CheckeredPainter oldDelegate) -> bool [line 37]
    - Returns true if any configuration changed
    - Compares squareSize, color1, color2 with old values


================================================================================
FILE: config/api_config.dart
================================================================================
PURPOSE: Centralized API configuration for base URLs, endpoints, and timeout settings.
LANGUAGE: Dart
DEPENDENCIES: None (core Dart only)

CLASS: ApiConfig [lines 3-34]
  Static Constants:
    - baseUrl: String (default: 'http://localhost:8080') [line 6]
    - apiPrefix: String = '/api' [line 12]
    - login: String = '/auth/login' [line 18]
    - addresses: String = '/addresses' [line 19]
    - restaurants: String = '/restaurants' [line 20]
    - menu: String = '/menu' [line 21]
    - menuItems: String = '/menu-items' [line 22]
    - orders: String = '/orders' [line 23]
    - approvals: String = '/approvals' [line 24]
    - requestTimeout: Duration = Duration(seconds: 30) [line 27]
    - maxRetries: int = 3 [line 30]
    - retryBaseDelay: Duration = Duration(seconds: 1) [line 33]

  Static Getter: fullBaseUrl -> String [line 15]
    - Returns baseUrl combined with apiPrefix

NOTABLE FEATURES:
  - Environment variable support for API_BASE_URL via String.fromEnvironment
  - Centralized endpoint definitions for consistency
  - Configurable timeout and retry settings


================================================================================
FILE: models/cart.dart
================================================================================
PURPOSE: Shopping cart data models with item management and price calculations.
LANGUAGE: Dart
DEPENDENCIES: models/menu.dart

CLASS: CartItem [lines 4-93]
  Fields:
    - MenuItem menuItem
    - int quantity
    - List<CustomizationChoice> selectedCustomizations
    - String? specialInstructions

  Constructor: CartItem({required this.menuItem, required this.quantity, ...}) [line 10]

  Getter: totalPrice -> double [line 18]
    - Calculates total price including customizations * quantity

  Getter: basePrice -> double [line 27]
    - Returns menuItem.price * quantity without customizations

  Getter: customizationsCost -> double [line 32]
    - Calculates total customization cost * quantity

  Getter: customizationsSummary -> String [line 41]
    - Returns comma-separated list of customization names

  Method: copyWith({...}) -> CartItem [line 47]
    - Creates copy with selectively updated fields

  Method: isSameAs(CartItem other) -> bool [line 62]
    - Checks if two cart items are same item + customizations

  Method: operator ==(Object other) -> bool [line 79]
    - Equality comparison including special instructions

  Method: hashCode -> int [line 86]
    - Hash code based on menuItem.id, customizations, and instructions

CLASS: Cart [lines 96-194]
  Fields:
    - int restaurantId
    - String restaurantName
    - List<CartItem> items

  Constructor: Cart({required this.restaurantId, required this.restaurantName, ...}) [line 101]

  Getter: subtotal -> double [line 108]
    - Sum of all item prices

  Getter: taxAmount -> double [line 113]
    - Calculates 8% tax on subtotal

  Getter: deliveryFee -> double [line 119]
    - Returns fixed $5.99 delivery fee

  Getter: totalAmount -> double [line 124]
    - Returns subtotal + tax + delivery fee

  Getter: itemCount -> int [line 129]
    - Total quantity of all items

  Getter: isEmpty -> bool [line 134]

  Getter: isNotEmpty -> bool [line 139]

  Method: copyWith({...}) -> Cart [line 144]

  Method: addItem(CartItem newItem) -> Cart [line 157]
    - Adds item or updates quantity if same item exists

  Method: removeItemAt(int index) -> Cart [line 174]

  Method: updateQuantity(int index, int newQuantity) -> Cart [line 181]
    - Updates quantity or removes if newQuantity <= 0

  Method: clear() -> Cart [line 191]
    - Returns cart with empty items list

NOTABLE FEATURES:
  - Immutable data structures with copyWith patterns
  - Automatic quantity merging for identical items
  - Tax and delivery fee calculations
  - CustomizationChoice equality checking


================================================================================
FILE: models/order.dart
================================================================================
PURPOSE: Order and OrderItem models for complete order lifecycle management.
LANGUAGE: Dart
DEPENDENCIES: None (core Dart only)

ENUM: OrderStatus [lines 5-44]
  Values: pending, confirmed, preparing, ready, pickedUp, enRoute, delivered, cancelled

  Getter: displayName -> String [line 16]
    - Returns formatted display string for status

  Static Method: fromString(String status) -> OrderStatus [line 38]
    - Converts string to enum value

CLASS: OrderItem [lines 47-132]
  Fields:
    - int? id
    - int? orderId
    - String menuItemName
    - String? menuItemDescription
    - int quantity
    - double basePrice
    - double totalPrice
    - Map<String, dynamic>? customizations
    - String? specialInstructions
    - DateTime? createdAt

  Constructor: OrderItem({this.id, this.orderId, required this.menuItemName, ...}) [line 59]

  Factory: OrderItem.fromJson(Map<String, dynamic> json) -> OrderItem [line 73]
    - Parses JSON with price_at_time and line_total fields

  Method: toJson() -> Map<String, dynamic> [line 94]
    - Serializes for CreateOrderItemRequest structure

  Method: copyWith({...}) -> OrderItem [line 107]

CLASS: Order [lines 135-273]
  Fields:
    - int? id
    - int customerId
    - int restaurantId
    - String? restaurantName
    - int? deliveryAddressId
    - OrderStatus status
    - double subtotal
    - double taxAmount
    - double deliveryFee
    - double totalAmount
    - List<OrderItem> items
    - String? specialInstructions
    - String? cancellationReason
    - DateTime? createdAt
    - DateTime? updatedAt
    - DateTime? estimatedDeliveryTime

  Constructor: Order({this.id, required this.customerId, ...}) [line 153]

  Factory: Order.fromJson(Map<String, dynamic> json) -> Order [line 173]

  Method: toJson() -> Map<String, dynamic> [line 206]
    - Serializes for CreateOrderRequest structure

  Method: copyWith({...}) -> Order [line 217]

  Getter: canBeCancelled -> bool [line 257]
    - Returns true if status allows cancellation

  Getter: isActive -> bool [line 264]
    - Returns true if not delivered or cancelled

  Getter: totalItemCount -> int [line 270]
    - Sum of all item quantities

NOTABLE FEATURES:
  - Comprehensive order lifecycle support
  - Status-based business logic (canBeCancelled, isActive)
  - Separate OrderItem model for line items
  - Support for customizations JSON field


================================================================================
FILE: services/http_client_service.dart
================================================================================
PURPOSE: Centralized HTTP client with comprehensive request/response logging.
LANGUAGE: Dart
DEPENDENCIES: dart:convert, dart:developer, http, config/api_config

CLASS: HttpClientService [lines 8-234]
  - Singleton pattern (factory constructor returns _instance)

  Static Field: baseUrl -> String [line 9]
    - Initialized from ApiConfig.baseUrl

  Constructor (private): HttpClientService._internal() [line 14]

  Factory: HttpClientService() -> HttpClientService [line 13]
    - Returns singleton instance

  Method (private): _logRequest(String method, String url, Map<String, String> headers, {String? body}) [line 17]
    - Logs HTTP request with method, URL, headers (masks Authorization), and formatted JSON body

  Method (private): _logResponse(String method, String url, int statusCode, String body) [line 50]
    - Logs HTTP response with status code and formatted JSON body

  Method: get(String path, {Map<String, String>? headers, Duration? timeout}) -> Future<http.Response> [line 72]
    - Performs GET request with logging and timeout
    - Auto-adds Content-Type: application/json header
    - Uses ApiConfig.requestTimeout as default

  Method: post(String path, {Map<String, String>? headers, Object? body, Duration? timeout}) -> Future<http.Response> [line 103]
    - Performs POST request with JSON encoding

  Method: put(String path, {Map<String, String>? headers, Object? body, Duration? timeout}) -> Future<http.Response> [line 137]
    - Performs PUT request with JSON encoding

  Method: delete(String path, {Map<String, String>? headers, Duration? timeout}) -> Future<http.Response> [line 171]
    - Performs DELETE request

  Method: patch(String path, {Map<String, String>? headers, Object? body, Duration? timeout}) -> Future<http.Response> [line 202]
    - Performs PATCH request with JSON encoding

NOTABLE FEATURES:
  - Singleton pattern for consistent logging
  - Automatic JSON encoding/decoding
  - Authorization header masking in logs
  - Configurable timeouts per request
  - Pretty-printed JSON in logs
  - Success/error icons in log output


================================================================================
FILE: providers/cart_provider.dart
================================================================================
PURPOSE: State management for shopping cart using ChangeNotifier pattern.
LANGUAGE: Dart (Flutter)
DEPENDENCIES: flutter/foundation, models/cart, models/menu

CLASS: CartProvider extends ChangeNotifier [lines 7-161]
  Fields:
    - Cart? _cart (private)

  Getter: cart -> Cart? [line 11]

  Getter: hasItems -> bool [line 14]
    - Returns true if cart exists and has items

  Getter: itemCount -> int [line 17]

  Getter: totalAmount -> double [line 20]

  Getter: restaurantId -> int? [line 23]

  Getter: restaurantName -> String? [line 26]

  Method: initializeCart(int restaurantId, String restaurantName) -> bool [line 30]
    - Returns false if switching restaurants (mismatch)
    - Returns true if initialized or already matches

  Method: switchRestaurant(int restaurantId, String restaurantName) [line 51]
    - Forces cart clear and initializes new restaurant

  Method: addItem({required MenuItem menuItem, required int quantity, ...}) -> bool [line 63]
    - Adds item with customizations and special instructions
    - Merges with existing identical item if found

  Method: removeItemAt(int index) [line 89]
    - Removes item at index, sets cart to null if empty

  Method: updateQuantity(int index, int newQuantity) [line 106]
    - Updates quantity, removes if newQuantity <= 0

  Method: incrementQuantity(int index) [line 123]

  Method: decrementQuantity(int index) [line 130]
    - Decrements or removes if quantity would be 0

  Method: clearCart() [line 142]

  Getter: items -> List<CartItem> [line 151]

  Getter: subtotal -> double [line 154]

  Getter: taxAmount -> double [line 157]

  Getter: deliveryFee -> double [line 160]

NOTABLE FEATURES:
  - ChangeNotifier for reactive UI updates
  - Restaurant switching protection
  - Automatic cart clearing when empty
  - Comprehensive debug logging
  - Convenience methods for quantity operations


================================================================================
FILE: utils/json_helpers.dart
================================================================================
PURPOSE: JSON parsing utilities to reduce code duplication across services.
LANGUAGE: Dart
DEPENDENCIES: dart:developer

CLASS: JsonHelpers [lines 4-143]
  Static Method: parseList<T>(Map<String, dynamic> json, String key, T Function(Map<String, dynamic>) fromJson, {String loggerName}) -> List<T> [line 17]
    - Safely parses array from JSON with error handling
    - Returns empty list if key missing, null, or wrong type
    - Logs errors and continues parsing remaining items

  Static Method: parseObject<T>(Map<String, dynamic> json, String key, T Function(Map<String, dynamic>) fromJson, {String loggerName}) -> T? [line 79]
    - Safely parses single object from JSON
    - Returns null if key missing, null, or wrong type
    - Logs parsing errors

  Static Method: requireField<T>(Map<String, dynamic> json, String key) -> T [line 119]
    - Validates required field exists with correct type
    - Throws FormatException if missing or wrong type

  Static Method: getFieldOrDefault<T>(Map<String, dynamic> json, String key, T defaultValue) -> T [line 135]
    - Returns field value or default if missing/null/wrong type

NOTABLE FEATURES:
  - Generic type support for any model class
  - Comprehensive error logging with stack traces
  - Continues parsing on individual item failures
  - Consistent logger name parameter for service identification


================================================================================
FILE: utils/api_helpers.dart
================================================================================
PURPOSE: API call wrappers with standardized error handling and retry logic.
LANGUAGE: Dart
DEPENDENCIES: dart:developer

CLASS: ApiHelpers [lines 4-99]
  Static Method: handleApiCall<T>(String methodName, Future<T> Function() apiCall, {String loggerName}) -> Future<T> [line 13]
    - Wraps async API call with error logging
    - Rethrows exceptions after logging

  Static Method: handleOperation<T>(String methodName, T Function() operation, {String loggerName}) -> T [line 36]
    - Wraps synchronous operation with error logging

  Static Method: handleApiCallWithRetry<T>(String methodName, Future<T> Function() apiCall, {int maxRetries, Duration retryDelay, String loggerName}) -> Future<T> [line 63]
    - Executes API call with retry logic
    - Uses exponential backoff (1s, 2s, 4s, etc.)
    - Logs each retry attempt with remaining attempts
    - Rethrows after max retries exceeded

NOTABLE FEATURES:
  - Generic type support
  - Exponential backoff calculation: retryDelay * (1 << (attempt - 1))
  - Configurable max retries (default 3)
  - Configurable base delay (default 1 second)
  - Consistent error logging format
