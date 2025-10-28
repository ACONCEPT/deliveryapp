import 'package:flutter/material.dart';
import '../../models/approval.dart';
import '../../services/approval_service.dart';
import '../../config/dashboard_constants.dart';
import 'vendor_approval_detail_screen.dart';

/// Pending Vendors List Screen
///
/// Displays all vendors awaiting admin approval with search/filter capabilities.
/// Each vendor card shows key information and tapping navigates to detail view.
class PendingVendorsScreen extends StatefulWidget {
  final String token;

  const PendingVendorsScreen({
    super.key,
    required this.token,
  });

  @override
  State<PendingVendorsScreen> createState() => _PendingVendorsScreenState();
}

class _PendingVendorsScreenState extends State<PendingVendorsScreen> {
  final ApprovalService _approvalService = ApprovalService();
  List<VendorWithApproval> _vendors = [];
  List<VendorWithApproval> _filteredVendors = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPendingVendors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Loads pending vendors from API
  Future<void> _loadPendingVendors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final vendors = await _approvalService.getPendingVendors(widget.token);
      setState(() {
        _vendors = vendors;
        _filteredVendors = vendors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load pending vendors: $e';
        _isLoading = false;
      });
    }
  }

  /// Filters vendors based on search query
  void _filterVendors(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredVendors = _vendors;
      } else {
        _filteredVendors = _vendors.where((vendor) {
          final businessName = vendor.businessName.toLowerCase();
          final city = vendor.city?.toLowerCase() ?? '';
          final state = vendor.state?.toLowerCase() ?? '';
          final searchLower = query.toLowerCase();

          return businessName.contains(searchLower) ||
              city.contains(searchLower) ||
              state.contains(searchLower);
        }).toList();
      }
    });
  }

  /// Navigates to vendor detail screen
  void _navigateToVendorDetail(VendorWithApproval vendor) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => VendorApprovalDetailScreen(
          token: widget.token,
          vendor: vendor,
        ),
      ),
    );

    // Reload list if vendor was approved/rejected
    if (result == true) {
      _loadPendingVendors();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Vendors'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),

          // Vendor count
          if (!_isLoading && _errorMessage == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${_filteredVendors.length} vendor${_filteredVendors.length == 1 ? '' : 's'} pending approval',
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
                    : _buildVendorsList(),
          ),
        ],
      ),
    );
  }

  /// Builds search bar for filtering vendors
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
        onChanged: _filterVendors,
        decoration: InputDecoration(
          hintText: 'Search by business name or location...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterVendors('');
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
              onPressed: _loadPendingVendors,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds vendors list or empty state
  Widget _buildVendorsList() {
    if (_filteredVendors.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadPendingVendors,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredVendors.length,
        itemBuilder: (context, index) {
          return _buildVendorCard(_filteredVendors[index]);
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
                  ? 'No vendors found matching "${_searchController.text}"'
                  : 'No vendors pending approval',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            if (_searchController.text.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'All vendors have been processed!',
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

  /// Builds individual vendor card
  Widget _buildVendorCard(VendorWithApproval vendor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: DashboardConstants.cardElevationSmall,
      child: InkWell(
        onTap: () => _navigateToVendorDetail(vendor),
        borderRadius:
            BorderRadius.circular(DashboardConstants.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with business name and pending badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      vendor.businessName,
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

              // Location
              if (vendor.city != null || vendor.state != null)
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        vendor.location,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),

              // Phone
              if (vendor.phone != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      vendor.phone!,
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
                    vendor.rating.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    'Applied ${_formatDate(vendor.createdAt)}',
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
