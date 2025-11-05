import 'package:flutter/material.dart';
import 'package:delivery_app/models/user.dart';
import 'package:delivery_app/services/http_client_service.dart';
import 'package:delivery_app/config/api_config.dart';
import 'package:delivery_app/screens/admin/user_admin_detail_screen.dart';
import 'dart:convert';
import 'dart:async';

/// Admin screen for managing all users
/// Features: search, filter by type, view details, delete users
class UserAdminListScreen extends StatefulWidget {
  final String token;

  const UserAdminListScreen({
    super.key,
    required this.token,
  });

  @override
  State<UserAdminListScreen> createState() => _UserAdminListScreenState();
}

class _UserAdminListScreenState extends State<UserAdminListScreen> {
  final HttpClientService _httpClient = HttpClientService();
  final TextEditingController _searchController = TextEditingController();

  List<User> _allUsers = [];
  List<User> _filteredUsers = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'all';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Cancel previous timer
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Start new timer (500ms delay)
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadUsers();
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Backend endpoint: GET /api/admin/users
      // Supports filtering by user_type, status, search, and pagination
      // Build query parameters
      final queryParams = <String, String>{};

      // Add user_type filter if not 'all'
      if (_selectedFilter != 'all') {
        queryParams['user_type'] = _selectedFilter;
      }

      // Add search query if provided
      if (_searchController.text.isNotEmpty) {
        queryParams['search'] = _searchController.text;
      }

      // Build URL with query parameters
      String endpoint = '${ApiConfig.apiPrefix}/admin/users';
      if (queryParams.isNotEmpty) {
        final queryString = queryParams.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&');
        endpoint = '$endpoint?$queryString';
      }

      final response = await _httpClient.get(
        endpoint,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          // Backend returns: { success, message, data: { users: [], total_count, page, per_page, total_pages } }
          final responseData = data['data'] as Map<String, dynamic>;
          final List<dynamic> usersJson = responseData['users'] as List;
          setState(() {
            // With server-side filtering, filtered and all users are the same
            _allUsers = usersJson.map((json) => User.fromJson(json)).toList();
            _filteredUsers = _allUsers;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Failed to load users';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  void _filterUsers() {
    // Trigger server-side filtering by reloading users
    _loadUsers();
  }

  void _setFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    // Reload users with new filter
    _loadUsers();
  }

  Color _getUserTypeColor(String userType) {
    switch (userType) {
      case 'customer':
        return Colors.blue;
      case 'vendor':
        return Colors.orange;
      case 'driver':
        return Colors.purple;
      case 'admin':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getUserTypeIcon(String userType) {
    switch (userType) {
      case 'customer':
        return Icons.person;
      case 'vendor':
        return Icons.store;
      case 'driver':
        return Icons.local_shipping;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.help;
    }
  }

  Future<void> _navigateToUserDetail(User user) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserAdminDetailScreen(
          token: widget.token,
          user: user,
        ),
      ),
    );

    // Reload if user was modified or deleted
    if (result == true) {
      _loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by username or email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Customers', 'customer'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Vendors', 'vendor'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Drivers', 'driver'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Admins', 'admin'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // User count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            width: double.infinity,
            color: Colors.grey[200],
            child: Text(
              '${_filteredUsers.length} user(s) found',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // User list
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _setFilter(value),
      selectedColor: Colors.red[100],
      checkmarkColor: Colors.red,
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadUsers,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty || _selectedFilter != 'all'
                  ? 'Try adjusting your filters'
                  : 'No users available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        itemCount: _filteredUsers.length,
        itemBuilder: (context, index) {
          final user = _filteredUsers[index];
          return _UserCard(
            user: user,
            onTap: () => _navigateToUserDetail(user),
            getUserTypeColor: _getUserTypeColor,
            getUserTypeIcon: _getUserTypeIcon,
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final User user;
  final VoidCallback onTap;
  final Color Function(String) getUserTypeColor;
  final IconData Function(String) getUserTypeIcon;

  const _UserCard({
    required this.user,
    required this.onTap,
    required this.getUserTypeColor,
    required this.getUserTypeIcon,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = getUserTypeColor(user.userType);
    final typeIcon = getUserTypeIcon(user.userType);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // User type icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  typeIcon,
                  color: typeColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),

              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // User type badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: typeColor, width: 1),
                          ),
                          child: Text(
                            user.userType.toUpperCase(),
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: user.status == 'active'
                                ? Colors.green.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            user.status.toUpperCase(),
                            style: TextStyle(
                              color: user.status == 'active'
                                  ? Colors.green
                                  : Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
