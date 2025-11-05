import 'package:flutter/material.dart';
import '../../models/approval.dart';
import '../../services/approval_service.dart';
import '../../config/dashboard_constants.dart';
import 'driver_approval_detail_screen.dart';

/// Pending Drivers List Screen
///
/// Displays all drivers awaiting admin approval with search/filter capabilities.
/// Each driver card shows key information and tapping navigates to detail view.
class PendingDriversScreen extends StatefulWidget {
  final String token;

  const PendingDriversScreen({
    super.key,
    required this.token,
  });

  @override
  State<PendingDriversScreen> createState() => _PendingDriversScreenState();
}

class _PendingDriversScreenState extends State<PendingDriversScreen> {
  final ApprovalService _approvalService = ApprovalService();
  List<DriverWithApproval> _drivers = [];
  List<DriverWithApproval> _filteredDrivers = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPendingDrivers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Loads pending drivers from API
  Future<void> _loadPendingDrivers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final drivers = await _approvalService.getPendingDrivers(widget.token);
      setState(() {
        _drivers = drivers;
        _filteredDrivers = drivers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load pending drivers: $e';
        _isLoading = false;
      });
    }
  }

  /// Filters drivers based on search query
  void _filterDrivers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredDrivers = _drivers;
      } else {
        _filteredDrivers = _drivers.where((driver) {
          final fullName = driver.fullName.toLowerCase();
          final vehicleType = driver.vehicleType?.toLowerCase() ?? '';
          final vehiclePlate = driver.vehiclePlate?.toLowerCase() ?? '';
          final city = driver.city?.toLowerCase() ?? '';
          final state = driver.state?.toLowerCase() ?? '';
          final searchLower = query.toLowerCase();

          return fullName.contains(searchLower) ||
              vehicleType.contains(searchLower) ||
              vehiclePlate.contains(searchLower) ||
              city.contains(searchLower) ||
              state.contains(searchLower);
        }).toList();
      }
    });
  }

  /// Navigates to driver detail screen
  void _navigateToDriverDetail(DriverWithApproval driver) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => DriverApprovalDetailScreen(
          token: widget.token,
          driver: driver,
        ),
      ),
    );

    // Reload list if driver was approved/rejected
    if (result == true) {
      _loadPendingDrivers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Drivers'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),

          // Driver count
          if (!_isLoading && _errorMessage == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${_filteredDrivers.length} driver${_filteredDrivers.length == 1 ? '' : 's'} pending approval',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : _buildDriversList(),
          ),
        ],
      ),
    );
  }

  /// Builds search bar for filtering drivers
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _filterDrivers,
        decoration: InputDecoration(
          hintText: 'Search by name, vehicle, or location...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterDrivers('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
                DashboardConstants.cardBorderRadiusSmall),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  /// Builds error view with retry button
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPendingDrivers,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds drivers list or empty state
  Widget _buildDriversList() {
    if (_filteredDrivers.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadPendingDrivers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredDrivers.length,
        itemBuilder: (context, index) {
          return _buildDriverCard(_filteredDrivers[index]);
        },
      ),
    );
  }

  /// Builds empty state view
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isNotEmpty
                  ? Icons.search_off
                  : Icons.check_circle_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No drivers found matching "${_searchController.text}"'
                  : 'No drivers pending approval',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            if (_searchController.text.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'All drivers have been processed!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds individual driver card
  Widget _buildDriverCard(DriverWithApproval driver) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: DashboardConstants.cardElevationSmall,
      child: InkWell(
        onTap: () => _navigateToDriverDetail(driver),
        borderRadius:
            BorderRadius.circular(DashboardConstants.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with driver name and pending badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      driver.fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'PENDING',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Vehicle info
              if (driver.vehicleType != null || driver.vehiclePlate != null)
                Row(
                  children: [
                    const Icon(Icons.directions_car, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        driver.vehicleInfo,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),

              // License number
              if (driver.licenseNumber != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.badge, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'License: ${driver.licenseNumber}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],

              // Location
              if (driver.city != null || driver.state != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        driver.location,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Phone
              if (driver.phone != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      driver.phone!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],

              // Rating and created date
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    driver.rating.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 16),
                  // Availability indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: driver.isAvailable ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      border: Border.all(
                        color: driver.isAvailable ? Colors.green : Colors.grey,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      driver.availabilityStatus,
                      style: TextStyle(
                        fontSize: 10,
                        color: driver.isAvailable ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Applied ${_formatDate(driver.createdAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),

              // Action hint
              const SizedBox(height: 8),
              const Divider(),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    'Tap to review and approve/reject',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formats DateTime for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes} min ago';
      }
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
