import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import '../models/restaurant.dart';
import '../config/dashboard_constants.dart';
import '../config/user_type_config.dart';
import '../config/dashboard_widget_config.dart';
import '../services/restaurant_service.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/restaurant_section.dart';
import '../painters/checkered_painter.dart';
import '../providers/auth_provider.dart';
import 'address_list_screen.dart';
import 'restaurant_list_screen.dart';
import 'vendor_restaurant_management_screen.dart';
import 'vendor_menu_list_screen.dart';
import 'vendor/vendor_restaurant_selector_screen.dart';
import 'vendor/vendor_orders_list_screen.dart';
import 'admin/approvals_dashboard_screen.dart';
import 'admin/system_settings_screen.dart';
import 'admin/admin_order_dashboard_screen.dart';
import 'admin/admin_restaurant_dashboard_screen.dart';
import 'admin/user_admin_list_screen.dart';
import 'customer/restaurant_menu_screen.dart';
import 'customer/customer_active_orders_screen.dart';
import 'customer/customer_order_history_screen.dart';
import 'driver/driver_available_orders_screen.dart';
import 'driver/driver_orders_screen.dart';
import 'customization_template_list_screen.dart';

class ConfirmationScreen extends StatefulWidget {
  final User user;
  final Map<String, dynamic>? profile;
  final String token;

  const ConfirmationScreen({
    super.key,
    required this.user,
    this.profile,
    required this.token,
  });

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  final RestaurantService _restaurantService = RestaurantService();
  List<Restaurant> _restaurants = [];
  bool _isLoadingRestaurants = true;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    setState(() {
      _isLoadingRestaurants = true;
    });

    try {
      final restaurants = await _restaurantService.getRestaurants(widget.token);
      setState(() {
        _restaurants = restaurants;
        _isLoadingRestaurants = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingRestaurants = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          _buildCheckeredBackground(),
          _buildDashboardContent(),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.clearAuth();
    // Navigation handled automatically by Consumer in main.dart
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(UserTypeConfig.getTitle(widget.user.userType)),
      automaticallyImplyLeading: false,
      backgroundColor: UserTypeConfig.getColor(widget.user.userType),
      foregroundColor: Colors.white,
      elevation: 4,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.account_circle),
          tooltip: 'User Information',
          offset: const Offset(0, 50),
          itemBuilder: (BuildContext context) {
            return [
              PopupMenuItem<String>(
                value: 'info',
                enabled: false,
                child: _buildUserInfoContent(),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ];
          },
          onSelected: (value) async {
            if (value == 'logout') {
              await _handleLogout();
            }
          },
        ),
      ],
    );
  }

  Widget _buildCheckeredBackground() {
    return CustomPaint(
      painter: CheckeredPainter(),
      child: Container(),
    );
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(DashboardConstants.screenPadding),
          child: Column(
            children: [
              _buildDashboardWidgetsCard(),
              if (widget.user.userType == UserTypeConfig.customer)
                ..._buildCustomerSections(),
              if (widget.user.userType == UserTypeConfig.vendor)
                ..._buildVendorSections(),
            ],
          ),
        ),
      ),
    );
  }

  void _handleWidgetTap(BuildContext context, DashboardWidgetConfig config) {
    if (config.route != null) {
      switch (config.route) {
        case '/addresses':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddressListScreen(token: widget.token),
            ),
          );
          break;
        case '/restaurants':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RestaurantListScreen(token: widget.token),
            ),
          );
          break;
        case '/vendor/orders':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VendorOrdersListScreen(token: widget.token),
            ),
          );
          break;
        case '/vendor/restaurants':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VendorRestaurantManagementScreen(token: widget.token),
            ),
          );
          break;
        case '/vendor/menus':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VendorMenuListScreen(
                token: widget.token,
                userType: widget.user.userType,
              ),
            ),
          );
          break;
        case '/vendor/restaurant-selector':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VendorRestaurantSelectorScreen(
                token: widget.token,
                userType: widget.user.userType,
              ),
            ),
          );
          break;
        case '/admin/users':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserAdminListScreen(token: widget.token),
            ),
          );
          break;
        case '/admin/settings':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SystemSettingsScreen(token: widget.token),
            ),
          );
          break;
        case '/admin/approvals':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ApprovalsDashboardScreen(token: widget.token),
            ),
          );
          break;
        case '/admin/orders':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminOrderDashboardScreen(token: widget.token),
            ),
          );
          break;
        case '/admin/restaurants':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminRestaurantDashboardScreen(
                token: widget.token,
                user: widget.user,
              ),
            ),
          );
          break;
        case '/customer/active-orders':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerActiveOrdersScreen(token: widget.token),
            ),
          );
          break;
        case '/customer/order-history':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerOrderHistoryScreen(token: widget.token),
            ),
          );
          break;
        case '/driver/available-orders':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DriverAvailableOrdersScreen(token: widget.token),
            ),
          );
          break;
        case '/driver/orders':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DriverOrdersScreen(token: widget.token),
            ),
          );
          break;
        case '/admin/customization-templates':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomizationTemplateListScreen(
                token: widget.token,
                userType: 'admin',
              ),
            ),
          );
          break;
        case '/vendor/customization-templates':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomizationTemplateListScreen(
                token: widget.token,
                userType: 'vendor',
              ),
            ),
          );
          break;
        default:
          // Handle other routes as needed
          break;
      }
    }
  }

  Widget _buildDashboardWidgetsCard() {
    final widgets = DashboardWidgetConfig.getWidgetsForUserType(widget.user.userType);

    return Card(
      elevation: DashboardConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DashboardConstants.cardBorderRadius),
      ),
      child: Container(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: DashboardConstants.dashboardGridColumns,
            crossAxisSpacing: DashboardConstants.gridSpacing,
            mainAxisSpacing: DashboardConstants.gridSpacing,
            childAspectRatio: DashboardConstants.dashboardCardAspectRatio,
          ),
          itemCount: widgets.length,
          itemBuilder: (context, index) {
            final config = widgets[index];
            return DashboardCard(
              title: config.title,
              icon: config.icon,
              color: config.color,
              onTap: config.onTap ?? () => _handleWidgetTap(context, config),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildCustomerSections() {
    if (_isLoadingRestaurants) {
      return [
        const SizedBox(height: DashboardConstants.sectionSpacing),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ];
    }

    if (_restaurants.isEmpty) {
      return []; // Don't show section if no restaurants
    }

    return [
      const SizedBox(height: DashboardConstants.sectionSpacing),
      RestaurantSection(
        title: 'Featured Restaurants',
        headerIcon: Icons.restaurant,
        headerIconColor: Colors.blue,
        restaurants: _restaurants,
        onRestaurantTap: (restaurant) => _navigateToRestaurantMenu(restaurant),
      ),
    ];
  }

  List<Widget> _buildVendorSections() {
    if (_isLoadingRestaurants) {
      return [
        const SizedBox(height: DashboardConstants.sectionSpacing),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ];
    }

    if (_restaurants.isEmpty) {
      return []; // Don't show section if no restaurants
    }

    return [
      const SizedBox(height: DashboardConstants.sectionSpacing),
      RestaurantSection(
        title: 'My Restaurants',
        headerIcon: Icons.store,
        headerIconColor: Colors.orange,
        restaurants: _restaurants,
      ),
    ];
  }

  Widget _buildUserInfoContent() {
    return Container(
      width: DashboardConstants.userInfoPopupWidth * 1.2, // Wider for more content
      constraints: const BoxConstraints(
        maxHeight: DashboardConstants.userInfoPopupMaxHeight * 1.5,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section: User Details
            _buildSectionHeader('User Details'),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.numbers,
              label: 'User ID',
              value: widget.user.id.toString(),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.person,
              label: 'Username',
              value: widget.user.username,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.email,
              label: 'Email',
              value: widget.user.email,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.badge,
              label: 'User Type',
              value: UserTypeConfig.formatUserType(widget.user.userType),
              valueColor: UserTypeConfig.getColor(widget.user.userType),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.shield,
              label: 'User Role',
              value: UserTypeConfig.formatUserType(widget.user.userRole),
              valueColor: UserTypeConfig.getColor(widget.user.userRole),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.verified_user,
              label: 'Status',
              value: widget.user.status.toUpperCase(),
              valueColor: widget.user.status == 'active' ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.calendar_today,
              label: 'Created At',
              value: _formatDateTime(widget.user.createdAt),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.update,
              label: 'Updated At',
              value: _formatDateTime(widget.user.updatedAt),
            ),

            // Section: JWT Token Details
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            _buildSectionHeader('JWT Token Details'),
            const SizedBox(height: 12),
            ..._buildJWTInfo(),

            // Section: Profile Information
            if (widget.profile != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              _buildSectionHeader('Profile Information'),
              const SizedBox(height: 12),
              ..._buildProfileInfo(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy HH:mm:ss').format(dateTime);
  }

  List<Widget> _buildJWTInfo() {
    try {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(widget.token);

      List<Widget> widgets = [];

      // Token Expiration
      if (decodedToken.containsKey('exp')) {
        int exp = decodedToken['exp'];
        DateTime expirationDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        Duration timeUntilExpiry = expirationDate.difference(DateTime.now());
        bool isExpired = timeUntilExpiry.isNegative;

        widgets.add(_buildInfoRow(
          icon: Icons.access_time,
          label: 'Token Expiration',
          value: _formatDateTime(expirationDate),
          valueColor: isExpired ? Colors.red : Colors.green,
        ));
        widgets.add(const SizedBox(height: 12));

        // Time until expiry
        String expiryText = isExpired
            ? 'EXPIRED'
            : '${timeUntilExpiry.inHours}h ${timeUntilExpiry.inMinutes % 60}m remaining';
        widgets.add(_buildInfoRow(
          icon: isExpired ? Icons.error : Icons.timer,
          label: 'Status',
          value: expiryText,
          valueColor: isExpired ? Colors.red : Colors.green,
        ));
        widgets.add(const SizedBox(height: 12));
      }

      // Token Issued At
      if (decodedToken.containsKey('iat')) {
        int iat = decodedToken['iat'];
        DateTime issuedDate = DateTime.fromMillisecondsSinceEpoch(iat * 1000);
        widgets.add(_buildInfoRow(
          icon: Icons.schedule,
          label: 'Issued At',
          value: _formatDateTime(issuedDate),
        ));
        widgets.add(const SizedBox(height: 12));
      }

      // User ID from token
      if (decodedToken.containsKey('user_id')) {
        widgets.add(_buildInfoRow(
          icon: Icons.fingerprint,
          label: 'Token User ID',
          value: decodedToken['user_id'].toString(),
        ));
        widgets.add(const SizedBox(height: 12));
      }

      // Username from token
      if (decodedToken.containsKey('username')) {
        widgets.add(_buildInfoRow(
          icon: Icons.account_circle,
          label: 'Token Username',
          value: decodedToken['username'],
        ));
        widgets.add(const SizedBox(height: 12));
      }

      // User Type from token
      if (decodedToken.containsKey('user_type')) {
        String userType = decodedToken['user_type'];
        widgets.add(_buildInfoRow(
          icon: Icons.category,
          label: 'Token User Type',
          value: UserTypeConfig.formatUserType(userType),
          valueColor: UserTypeConfig.getColor(userType),
        ));
        widgets.add(const SizedBox(height: 12));
      }

      // Issuer
      if (decodedToken.containsKey('iss')) {
        widgets.add(_buildInfoRow(
          icon: Icons.business,
          label: 'Issuer',
          value: decodedToken['iss'],
        ));
      }

      return widgets;
    } catch (e) {
      return [
        Text(
          'Unable to decode JWT token',
          style: TextStyle(
            fontSize: 14,
            color: Colors.red[700],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Error: $e',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ];
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildProfileInfo() {
    if (widget.profile == null) return [];

    List<Widget> widgets = [];

    switch (widget.user.userType) {
      case UserTypeConfig.customer:
        if (widget.profile!['full_name'] != null) {
          widgets.add(_buildInfoRow(
            icon: Icons.person_outline,
            label: 'Full Name',
            value: widget.profile!['full_name'],
          ));
          widgets.add(const SizedBox(height: 12));
        }
        if (widget.profile!['phone'] != null) {
          widgets.add(_buildInfoRow(
            icon: Icons.phone,
            label: 'Phone',
            value: widget.profile!['phone'],
          ));
        }
        break;

      case UserTypeConfig.vendor:
        if (widget.profile!['business_name'] != null) {
          widgets.add(_buildInfoRow(
            icon: Icons.store,
            label: 'Business Name',
            value: widget.profile!['business_name'],
          ));
          widgets.add(const SizedBox(height: 12));
        }
        if (widget.profile!['phone'] != null) {
          widgets.add(_buildInfoRow(
            icon: Icons.phone,
            label: 'Phone',
            value: widget.profile!['phone'],
          ));
          widgets.add(const SizedBox(height: 12));
        }
        if (widget.profile!['city'] != null) {
          widgets.add(_buildInfoRow(
            icon: Icons.location_city,
            label: 'City',
            value: widget.profile!['city'],
          ));
          widgets.add(const SizedBox(height: 12));
        }
        widgets.add(_buildInfoRow(
          icon: Icons.star,
          label: 'Rating',
          value: '${widget.profile!['rating'] ?? 0.0}',
        ));
        break;

      case UserTypeConfig.driver:
        if (widget.profile!['full_name'] != null) {
          widgets.add(_buildInfoRow(
            icon: Icons.person_outline,
            label: 'Full Name',
            value: widget.profile!['full_name'],
          ));
          widgets.add(const SizedBox(height: 12));
        }
        if (widget.profile!['phone'] != null) {
          widgets.add(_buildInfoRow(
            icon: Icons.phone,
            label: 'Phone',
            value: widget.profile!['phone'],
          ));
          widgets.add(const SizedBox(height: 12));
        }
        if (widget.profile!['vehicle_type'] != null) {
          widgets.add(_buildInfoRow(
            icon: Icons.local_shipping,
            label: 'Vehicle Type',
            value: widget.profile!['vehicle_type'],
          ));
          widgets.add(const SizedBox(height: 12));
        }
        widgets.add(_buildInfoRow(
          icon: widget.profile!['is_available'] == true
              ? Icons.check_circle
              : Icons.cancel,
          label: 'Availability',
          value: widget.profile!['is_available'] == true ? 'Available' : 'Not Available',
          valueColor: widget.profile!['is_available'] == true ? Colors.green : Colors.red,
        ));
        break;

      case UserTypeConfig.admin:
        if (widget.profile!['full_name'] != null) {
          widgets.add(_buildInfoRow(
            icon: Icons.person_outline,
            label: 'Full Name',
            value: widget.profile!['full_name'],
          ));
          widgets.add(const SizedBox(height: 12));
        }
        if (widget.profile!['role'] != null) {
          widgets.add(_buildInfoRow(
            icon: Icons.admin_panel_settings,
            label: 'Role',
            value: widget.profile!['role'],
          ));
        }
        break;
    }

    return widgets;
  }

  void _navigateToRestaurantMenu(Restaurant restaurant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantMenuScreen(
          restaurant: restaurant,
          token: widget.token,
        ),
      ),
    );
  }
}
