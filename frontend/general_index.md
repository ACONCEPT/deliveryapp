# General Index - Frontend Source Code Files
# 2-line summary of every source code file in lib/

## FILE: main.dart
Application entry point that sets up MaterialApp with theme configuration and routing.
Configures Material Design 3 theme with deep orange color scheme and custom input/button/card styling.

## FILE: models/user.dart
Data models for user authentication including User, LoginResponse, and SignupResponse classes.
Provides JSON serialization/deserialization for API communication with backend user endpoints.

## FILE: models/restaurant.dart
Restaurant data model with properties for name, cuisine, rating, delivery time, and optional icons/images.
Includes JSON serialization for API integration with backend restaurant endpoints.

## FILE: models/address.dart
Customer address data model with full address fields, geolocation, and default flag support.
Provides helper methods for formatted address strings, JSON serialization, and copyWith functionality.

## FILE: config/dashboard_constants.dart
Centralized constants for dashboard UI layout, spacing, sizing, and styling values.
Defines grid columns, padding, elevation, border radius, icon sizes, and text sizes for consistent UI.

## FILE: config/user_type_config.dart
User type configuration providing colors, icons, titles, and formatting for customer/vendor/driver/admin roles.
Static helper methods to get role-specific UI elements based on user type string.

## FILE: config/dashboard_widget_config.dart
Dashboard widget configuration defining available widgets per user type with icons, colors, and routes.
Returns different widget sets for admin, vendor, customer, and driver dashboard customization.

## FILE: services/api_service.dart
HTTP API service for authentication endpoints (login, signup) with comprehensive logging.
Handles POST requests to backend /api/login and /api/signup with error handling and response parsing.

## FILE: services/restaurant_service.dart
Restaurant data service providing mock restaurant data for development and testing.
Includes placeholder methods for future API integration to fetch featured and vendor-specific restaurants.

## FILE: services/address_service.dart
Address CRUD service for customer address management with full HTTP API integration.
Implements get, create, update, delete, and set-default operations with JWT bearer token authentication.

## FILE: screens/login_screen.dart
Login screen with username/password form, validation, loading states, and test credentials display.
Handles form submission, API authentication, and navigation to confirmation screen on success.

## FILE: screens/confirmation_screen.dart
Post-login dashboard screen displaying user info, role-specific widgets, and restaurant sections.
Features checkered background, user info popup, dashboard widget grid, and conditional customer/vendor sections.

## FILE: screens/address_list_screen.dart
Address management screen displaying list of customer addresses with CRUD operations.
Supports viewing, editing, deleting addresses, setting default, pull-to-refresh, and floating action button for adding.

## FILE: screens/address_form_screen.dart
Address creation and editing form screen with validation for all address fields.
Handles both create and update modes, form validation, API submission, and default address toggle.

## FILE: widgets/dashboard_card.dart
Reusable dashboard card widget for displaying action items with icon, title, and tap handler.
Used in dashboard grid layout with consistent styling from DashboardConstants.

## FILE: widgets/restaurant_card.dart
Restaurant display card showing restaurant image/icon, name, cuisine, rating, and delivery time.
Provides compact grid-friendly layout for restaurant lists with tap functionality.

## FILE: widgets/section_header.dart
Section header widget displaying title with icon for use in dashboard sections.
Provides consistent styling for section titles across the application.

## FILE: widgets/restaurant_section.dart
Complete restaurant section widget with header and grid of restaurant cards.
Combines SectionHeader and RestaurantCard in a Card container for featured/vendor restaurant displays.

## FILE: painters/checkered_painter.dart
Custom painter that draws alternating checkered pattern background for dashboard screen.
Implements CustomPainter with configurable square size and two-color alternating pattern.

## FILE: config/api_config.dart
Centralized API configuration with base URL, API prefix, endpoints, and timeout settings.
Provides const values for API routes including login, addresses, restaurants, menu, orders, and approvals.

## FILE: models/vendor_restaurant.dart
Junction model linking vendors to restaurants with bidirectional relationship tracking.
Includes JSON serialization for API integration with vendor_id and restaurant_id foreign keys.

## FILE: models/restaurant_request.dart
Request DTOs for restaurant creation and updates with comprehensive address and metadata fields.
CreateRestaurantRequest requires name, UpdateRestaurantRequest allows partial updates with all optional fields.

## FILE: models/menu.dart
Comprehensive menu system with hierarchical structure supporting categories, items, variants, and customizations.
Includes Menu, MenuCategory, MenuItem, ItemVariant, CustomizationOption, and CustomizationChoice classes with price calculation.

## FILE: models/approval.dart
Admin approval workflow models including ApprovalStatus enum, approval history, and dashboard statistics.
Provides VendorWithApproval and RestaurantWithApproval models with approval metadata and status tracking.

## FILE: models/cart.dart
Shopping cart models with CartItem and Cart classes supporting quantity management and price calculations.
Includes customization tracking, special instructions, and automatic cart operations (add, remove, update quantity).

## FILE: models/order.dart
Order management models with OrderStatus enum, OrderItem, and Order classes for full order lifecycle.
Supports order creation, status tracking, cancellation, and includes delivery address and special instructions.

## FILE: models/system_setting.dart
System configuration models for admin settings management with SettingDataType enum and typed value parsing.
Includes SystemSetting, SettingsResponse, UpdateSettingRequest, BatchUpdateRequest, and BatchUpdateResult classes.

## FILE: services/http_client_service.dart
Centralized HTTP client service with comprehensive logging for GET, POST, PUT, DELETE, and PATCH requests.
Singleton pattern with automatic request/response logging, timeout configuration, and Bearer token authentication support.

## FILE: services/menu_service.dart
Menu CRUD service for vendor operations and customer menu viewing with full API integration.
Vendor features: create, update, delete menus, assign to restaurants. Customer features: view active restaurant menus.

## FILE: services/approval_service.dart
Admin approval service for managing vendor and restaurant approval workflows via API.
Provides methods for fetching pending items, approving/rejecting entities, and retrieving approval history.

## FILE: services/order_service.dart
Order management service with customer, vendor, and admin operations for order lifecycle.
Handles order creation, retrieval, cancellation, status updates, and supports all user roles with comprehensive logging.

## FILE: services/system_settings_service.dart
Admin system settings service for managing configuration via API with validation and batch update support.
Provides methods for fetching settings by category, updating single/multiple settings, and client-side validation helpers.

## FILE: screens/signup_screen.dart
Multi-role signup form with dynamic fields based on user type selection (customer/vendor/driver).
Includes validation for all fields, role-specific requirements, and navigation to login after successful registration.

## FILE: screens/restaurant_form_screen.dart
Restaurant creation and editing form with comprehensive address fields and geolocation support.
Handles both create and update modes with validation, latitude/longitude input, and optional field handling.

## FILE: screens/vendor_restaurant_management_screen.dart
Vendor restaurant management dashboard with list view, CRUD operations, and active status toggle.
Features pull-to-refresh, optimistic UI updates, confirmation dialogs, and floating action button for adding restaurants.

## FILE: screens/restaurant_detail_screen.dart
Restaurant detail view displaying comprehensive information including status, address, rating, and statistics.
Read-only screen with badge display for active/inactive status and formatted stat cards.

## FILE: screens/restaurant_list_screen.dart
Customer-facing restaurant browsing screen with list view and navigation to restaurant menus.
Includes loading states, error handling, empty state, and pull-to-refresh functionality.

## FILE: screens/vendor_menu_list_screen.dart
Vendor menu management screen listing all menus with stats, actions, and creation workflow.
Displays menu metadata (categories, items, assignments) with edit, delete, and assign buttons.

## FILE: screens/menu_item_form_screen.dart
Basic menu item form for creating/editing items with name, description, price, and status toggles.
Simplified version for Phase 4, with note about advanced features coming in Phase 5.

## FILE: screens/menu_form_screen.dart
Menu creation and editing form with name, description, and active status management.
Provides navigation to MenuBuilderScreen for adding categories and items in edit mode.

## FILE: screens/menu_item_form_screen_enhanced.dart
Comprehensive menu item builder with all Phase 5 features including variants, customizations, and dietary info.
Supports image upload, dietary flags, allergens, tags, calories, prep time, and spice level configuration.

## FILE: screens/menu_builder_screen.dart
Interactive menu builder for managing categories and items with drag-to-reorder functionality.
Features nested CRUD operations, unsaved changes detection, and real-time menu structure editing.

## FILE: screens/admin/approvals_dashboard_screen.dart
Admin dashboard displaying approval statistics and navigation to pending vendor/restaurant lists.
Shows counts for pending, approved, and rejected entities with card-based navigation interface.

## FILE: screens/admin/pending_vendors_screen.dart
Admin screen listing all pending vendor approvals with quick approve/reject actions.
Displays vendor details including business name, location, rating, and approval buttons.

## FILE: screens/admin/vendor_approval_detail_screen.dart
Detailed vendor approval screen with comprehensive vendor information and approval workflow.
Includes approval history, rejection reason input dialog, and navigation back to pending list after action.

## FILE: screens/admin/pending_restaurants_screen.dart
Admin screen listing all pending restaurant approvals with filtering and action buttons.
Shows restaurant details with cuisine type, location, and quick approve/reject functionality.

## FILE: screens/admin/restaurant_approval_detail_screen.dart
Detailed restaurant approval screen with full restaurant information and approval actions.
Displays address, phone, status, and provides approve/reject buttons with reason collection.

## FILE: screens/admin/system_settings_screen.dart
Admin system settings management screen with category tabs, search, and batch update functionality.
Features type-specific input fields, unsaved changes tracking, validation, and error handling for configuration management.

## FILE: screens/customer/cart_screen.dart
Shopping cart screen with item list, quantity controls, price breakdown, and checkout navigation.
Integrates with CartProvider for state management and supports item removal and quantity adjustment.

## FILE: screens/customer/restaurant_menu_screen.dart
Customer restaurant menu browsing with category sections, item cards, and add-to-cart functionality.
Features floating cart button, menu item customization dialog, and restaurant switching confirmation.

## FILE: screens/customer/customer_active_orders_screen.dart
Customer screen displaying active orders with real-time status tracking and navigation to order details.
Shows order cards with status badges, restaurant info, and item count with pull-to-refresh.

## FILE: screens/customer/customer_order_history_screen.dart
Customer order history screen with completed and cancelled orders display.
Includes filtering, search, reorder functionality, and navigation to order details for review.

## FILE: screens/customer/customer_order_detail_screen.dart
Detailed order view showing order status, items, pricing, delivery info, and action buttons.
Supports order cancellation for eligible orders and displays order timeline with status history.

## FILE: screens/customer/checkout_screen.dart
Multi-step checkout flow with address selection, order review, and payment confirmation.
Validates address selection, displays order summary with itemized costs, and creates order via API.

## FILE: screens/customer/order_confirmation_screen.dart
Post-order confirmation screen showing order number, estimated delivery time, and success message.
Provides navigation to order tracking and includes helpful next steps for the customer.

## FILE: widgets/image_upload_field.dart
Reusable image upload widget supporting both URL input and file upload with preview.
Includes image validation, upload progress indicator, and error handling for file size/type limits.

## FILE: widgets/menu_item_builders.dart
Collection of composable form builders for menu item configuration including variants, customizations, and metadata.
Includes VariantBuilder, CustomizationOptionsBuilder, DietaryFlagsBuilder, AllergensBuilder, TagsBuilder, and AdditionalInfoFields.

## FILE: widgets/cart/cart_summary.dart
Cart summary widget displaying subtotal, tax, delivery fee, and total with line-item breakdown.
Provides formatted currency display and optional styling for checkout vs cart screens.

## FILE: widgets/cart/floating_cart_button.dart
Floating action button for cart with item count badge and total price display.
Animated appearance when items are added, provides quick access to cart screen.

## FILE: widgets/cart/cart_item_tile.dart
Cart item list tile with image, name, customizations, quantity controls, and price display.
Supports increment/decrement buttons, item removal, and displays customization summary.

## FILE: widgets/menu/item_customization_dialog.dart
Modal dialog for menu item customization with variant selection and add-on choices.
Displays dynamic price calculation, validates required selections, and returns configured CartItem.

## FILE: widgets/menu/menu_item_card.dart
Menu item display card showing image, name, description, price, and dietary badges.
Features tap handler for customization dialog and displays availability status.

## FILE: widgets/order/order_status_badge.dart
Status badge widget with color-coded display for order status (pending, confirmed, delivered, etc).
Provides consistent status visualization across order screens with icon and text.

## FILE: widgets/order/order_timeline.dart
Visual timeline component showing order status progression with timestamps.
Displays completed, current, and upcoming status steps with connecting lines.

## FILE: widgets/order/order_card.dart
Order summary card for list views with restaurant name, status, items, and total price.
Includes tap handler for navigation to order details and displays order date.

## FILE: widgets/order/reorder_confirmation_dialog.dart
Confirmation dialog for reordering with item list preview and cart clearing warning.
Handles cart conflicts when reordering from different restaurant.

## FILE: widgets/settings/setting_input_field.dart
Smart input widget that adapts to SettingDataType with appropriate controls and validation.
Provides TextFormField for string/number/JSON, Switch for boolean, with type-specific formatting and validation.

## FILE: widgets/settings/setting_card.dart
Display card for individual system setting with inline editing, validation, and undo functionality.
Shows setting key, description, current value, data type badge, and provides save/cancel actions for editable settings.

## FILE: providers/cart_provider.dart
ChangeNotifier-based cart state management with add/remove/update operations.
Provides cart initialization, restaurant switching logic, and computed properties for totals.

## FILE: utils/json_helpers.dart
JSON parsing utilities with error handling for lists and objects to reduce service code duplication.
Includes parseList, parseObject, requireField, and getFieldOrDefault helper methods.

## FILE: utils/api_helpers.dart
API call wrappers with standardized error handling, logging, and retry logic.
Provides handleApiCall, handleOperation, and handleApiCallWithRetry with exponential backoff.

## FILE: examples/menu_usage_example.dart
Comprehensive examples demonstrating menu model usage, MenuService API integration, and customization scenarios.
Includes complete workflows for creating menus, managing categories, and calculating prices with customizations.
