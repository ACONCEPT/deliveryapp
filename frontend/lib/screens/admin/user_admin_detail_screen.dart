import 'package:flutter/material.dart';
import 'package:delivery_app/models/user.dart';
import 'package:delivery_app/models/order.dart';
import 'package:delivery_app/services/http_client_service.dart';
import 'package:delivery_app/config/api_config.dart';
import 'package:delivery_app/widgets/order/order_card.dart';
import 'dart:convert';

/// Admin screen for viewing user details, orders, and performing actions
/// Features: view orders, send message, delete user
class UserAdminDetailScreen extends StatefulWidget {
  final String token;
  final User user;

  const UserAdminDetailScreen({
    super.key,
    required this.token,
    required this.user,
  });

  @override
  State<UserAdminDetailScreen> createState() => _UserAdminDetailScreenState();
}

class _UserAdminDetailScreenState extends State<UserAdminDetailScreen>
    with SingleTickerProviderStateMixin {
  final HttpClientService _httpClient = HttpClientService();
  late TabController _tabController;

  List<Order> _orders = [];
  bool _isLoadingOrders = true;
  String? _ordersError;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserOrders() async {
    setState(() {
      _isLoadingOrders = true;
      _ordersError = null;
    });

    try {
      // Load orders for this user (customer orders only)
      if (widget.user.userType == 'customer') {
        // Use admin orders endpoint with customer_id filter
        final response = await _httpClient.get(
          '${ApiConfig.apiPrefix}/admin/orders?customer_id=${widget.user.id}',
          headers: {
            'Authorization': 'Bearer ${widget.token}',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true && data['data'] != null) {
            final List<dynamic> ordersJson = data['data'] as List;
            setState(() {
              _orders = ordersJson.map((json) => Order.fromJson(json)).toList();
              _isLoadingOrders = false;
            });
          } else {
            setState(() {
              _ordersError = data['message'] ?? 'Failed to load orders';
              _isLoadingOrders = false;
            });
          }
        } else {
          setState(() {
            _ordersError = 'Server error: ${response.statusCode}';
            _isLoadingOrders = false;
          });
        }
      } else {
        // For non-customers, no orders to show
        setState(() {
          _orders = [];
          _isLoadingOrders = false;
        });
      }
    } catch (e) {
      setState(() {
        _ordersError = e.toString();
        _isLoadingOrders = false;
      });
    }
  }

  Color _getUserTypeColor() {
    switch (widget.user.userType) {
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

  IconData _getUserTypeIcon() {
    switch (widget.user.userType) {
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

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete User'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this user?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Username: ${widget.user.username}'),
            Text('Email: ${widget.user.email}'),
            Text('Type: ${widget.user.userType}'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ This action cannot be undone!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'All user data including profile, orders, and history will be permanently deleted.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete User'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteUser();
    }
  }

  Future<void> _deleteUser() async {
    setState(() {
      _isDeleting = true;
    });

    try {
      final response = await _httpClient.delete(
        '${ApiConfig.apiPrefix}/admin/users/${widget.user.id}',
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${widget.user.username} deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Return true to indicate user was deleted
        Navigator.pop(context, true);
      } else {
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Failed to delete user');
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() {
        _isDeleting = false;
      });
    }
  }

  Future<void> _showMessageDialog() async {
    final messageController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To: ${widget.user.username}'),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Enter your message...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement actual message sending
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Message functionality coming soon! This will integrate with the messaging system.',
                  ),
                  duration: Duration(seconds: 3),
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );

    messageController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getUserTypeColor();
    final typeIcon = _getUserTypeIcon();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user.username),
        backgroundColor: typeColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: _showMessageDialog,
            tooltip: 'Send Message',
          ),
          if (!_isDeleting)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteConfirmation,
              tooltip: 'Delete User',
            ),
          if (_isDeleting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'User Info', icon: Icon(Icons.person)),
            Tab(text: 'Order History', icon: Icon(Icons.receipt_long)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserInfoTab(typeColor, typeIcon),
          _buildOrderHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildUserInfoTab(Color typeColor, IconData typeIcon) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User type banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: typeColor, width: 2),
            ),
            child: Row(
              children: [
                Icon(typeIcon, size: 48, color: typeColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.userType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                      Text(
                        widget.user.status.toUpperCase(),
                        style: TextStyle(
                          color: widget.user.status == 'active'
                              ? Colors.green
                              : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Basic info section
          _buildInfoSection(
            'Basic Information',
            [
              _buildInfoRow(Icons.person, 'Username', widget.user.username),
              _buildInfoRow(Icons.email, 'Email', widget.user.email),
              _buildInfoRow(Icons.badge, 'User ID', '#${widget.user.id}'),
              _buildInfoRow(
                Icons.calendar_today,
                'Created',
                _formatDate(widget.user.createdAt),
              ),
              _buildInfoRow(
                Icons.update,
                'Last Updated',
                _formatDate(widget.user.updatedAt),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Statistics section (for customers)
          if (widget.user.userType == 'customer') ...[
            _buildInfoSection(
              'Statistics',
              [
                _buildInfoRow(
                  Icons.shopping_cart,
                  'Total Orders',
                  '${_orders.length}',
                ),
                _buildInfoRow(
                  Icons.check_circle,
                  'Completed Orders',
                  '${_orders.where((o) => o.status == OrderStatus.delivered).length}',
                ),
                _buildInfoRow(
                  Icons.local_shipping,
                  'Active Orders',
                  '${_orders.where((o) => o.isActive).length}',
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Action buttons
          _buildInfoSection(
            'Actions',
            [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showMessageDialog,
                      icon: const Icon(Icons.message),
                      label: const Text('Send Message'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showDeleteConfirmation,
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete User'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderHistoryTab() {
    if (widget.user.userType != 'customer') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Order history is only available for customers',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_isLoadingOrders) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_ordersError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Error: $_ordersError'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserOrders,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No orders found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This user has not placed any orders yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUserOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          return OrderCard(
            order: order,
            onTap: () {
              // TODO: Navigate to order detail screen
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Order #${order.id} details coming soon'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
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
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}