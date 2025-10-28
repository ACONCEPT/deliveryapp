import 'package:flutter/material.dart';
import '../../models/approval.dart';
import '../../services/approval_service.dart';
import '../../config/dashboard_constants.dart';
import 'pending_vendors_screen.dart';
import 'pending_restaurants_screen.dart';

/// Admin Approvals Dashboard Screen
///
/// Main entry point for admin approval workflow. Displays summary statistics
/// and provides navigation to pending vendors and restaurants lists.
class ApprovalsDashboardScreen extends StatefulWidget {
  final String token;

  const ApprovalsDashboardScreen({
    super.key,
    required this.token,
  });

  @override
  State<ApprovalsDashboardScreen> createState() =>
      _ApprovalsDashboardScreenState();
}

class _ApprovalsDashboardScreenState extends State<ApprovalsDashboardScreen> {
  final ApprovalService _approvalService = ApprovalService();
  ApprovalDashboardStats? _stats;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  /// Loads approval statistics from API
  Future<void> _loadDashboardStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final stats = await _approvalService.getDashboardStats(widget.token);
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load approval statistics: $e';
        _isLoading = false;
      });
    }
  }

  /// Navigates to pending vendors list
  void _navigateToPendingVendors() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PendingVendorsScreen(token: widget.token),
      ),
    ).then((_) {
      // Reload stats when returning from vendor list
      _loadDashboardStats();
    });
  }

  /// Navigates to pending restaurants list
  void _navigateToPendingRestaurants() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PendingRestaurantsScreen(token: widget.token),
      ),
    ).then((_) {
      // Reload stats when returning from restaurant list
      _loadDashboardStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approval Dashboard'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildDashboardContent(),
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
              onPressed: _loadDashboardStats,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds main dashboard content with statistics cards
  Widget _buildDashboardContent() {
    if (_stats == null) {
      return const Center(child: Text('No data available'));
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(DashboardConstants.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary section
            _buildSummaryCard(),
            const SizedBox(height: DashboardConstants.sectionSpacing),

            // Pending approvals section
            _buildSectionHeader('Pending Approvals', Icons.pending_actions),
            const SizedBox(height: 12),
            _buildPendingCards(),
            const SizedBox(height: DashboardConstants.sectionSpacing),

            // Statistics section
            _buildSectionHeader('Statistics', Icons.analytics),
            const SizedBox(height: 12),
            _buildStatisticsCards(),
          ],
        ),
      ),
    );
  }

  /// Builds summary card with total counts
  Widget _buildSummaryCard() {
    return Card(
      elevation: DashboardConstants.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dashboard, size: 28, color: Colors.red),
                const SizedBox(width: 12),
                const Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Pending',
                    _stats!.totalPending,
                    Colors.orange,
                    Icons.hourglass_empty,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Total Approved',
                    _stats!.totalApproved,
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Total Rejected',
                    _stats!.totalRejected,
                    Colors.red,
                    Icons.cancel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds summary item with count and icon
  Widget _buildSummaryItem(String label, int count, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  /// Builds section header with icon and title
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: DashboardConstants.sectionHeaderIconSize),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Builds pending approval action cards
  Widget _buildPendingCards() {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            'Pending Vendors',
            _stats!.pendingVendors,
            Icons.store,
            Colors.deepOrange,
            _navigateToPendingVendors,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionCard(
            'Pending Restaurants',
            _stats!.pendingRestaurants,
            Icons.restaurant,
            Colors.orange,
            _navigateToPendingRestaurants,
          ),
        ),
      ],
    );
  }

  /// Builds statistics cards for approved/rejected items
  Widget _buildStatisticsCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Approved Vendors',
                _stats!.approvedVendors,
                Icons.store_outlined,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Approved Restaurants',
                _stats!.approvedRestaurants,
                Icons.restaurant_outlined,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Rejected Vendors',
                _stats!.rejectedVendors,
                Icons.store_outlined,
                Colors.red,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Rejected Restaurants',
                _stats!.rejectedRestaurants,
                Icons.restaurant_outlined,
                Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds clickable action card for pending items
  Widget _buildActionCard(
    String title,
    int count,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final bool hasPending = count > 0;

    return Card(
      elevation: hasPending ? DashboardConstants.cardElevation : 2,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(DashboardConstants.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(DashboardConstants.cardPadding),
          child: Column(
            children: [
              Stack(
                children: [
                  Icon(icon, size: 48, color: color),
                  if (hasPending)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$count pending',
                style: TextStyle(
                  fontSize: 12,
                  color: hasPending ? color : Colors.grey,
                  fontWeight: hasPending ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds read-only statistics card
  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      child: Padding(
        padding:
            const EdgeInsets.all(DashboardConstants.cardPaddingSmall + 4),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
