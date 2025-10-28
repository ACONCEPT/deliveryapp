import 'package:flutter/material.dart';
import '../../models/approval.dart';
import '../../services/approval_service.dart';
import '../../config/dashboard_constants.dart';

/// Restaurant Approval Detail Screen
///
/// Displays detailed information about a pending restaurant and provides
/// approve/reject actions with reason dialogs.
class RestaurantApprovalDetailScreen extends StatefulWidget {
  final String token;
  final RestaurantWithApproval restaurant;

  const RestaurantApprovalDetailScreen({
    super.key,
    required this.token,
    required this.restaurant,
  });

  @override
  State<RestaurantApprovalDetailScreen> createState() =>
      _RestaurantApprovalDetailScreenState();
}

class _RestaurantApprovalDetailScreenState
    extends State<RestaurantApprovalDetailScreen> {
  final ApprovalService _approvalService = ApprovalService();
  List<ApprovalHistory> _history = [];
  bool _isLoadingHistory = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadApprovalHistory();
  }

  /// Loads approval history for this restaurant
  Future<void> _loadApprovalHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final history = await _approvalService.getApprovalHistory(
        widget.token,
        'restaurant',
        widget.restaurant.id,
      );
      setState(() {
        _history = history;
        _isLoadingHistory = false;
      });
    } catch (e) {
      // History is optional, don't show error if it fails
      setState(() {
        _history = [];
        _isLoadingHistory = false;
      });
    }
  }

  /// Shows approve confirmation dialog
  Future<void> _showApproveDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Restaurant'),
        content: Text(
          'Are you sure you want to approve "${widget.restaurant.name}"?\n\n'
          'This will make the restaurant active and visible to customers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _approveRestaurant();
    }
  }

  /// Shows reject dialog with reason input
  Future<void> _showRejectDialog() async {
    final TextEditingController reasonController = TextEditingController();
    String? selectedReason;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Reject Restaurant'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please provide a reason for rejecting "${widget.restaurant.name}":',
                ),
                const SizedBox(height: 16),
                // Common rejection reasons
                const Text(
                  'Common reasons:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    'Incomplete information',
                    'Invalid location',
                    'Duplicate listing',
                    'Policy violation',
                    'Health code concerns',
                  ].map((reason) {
                    return ChoiceChip(
                      label: Text(reason),
                      selected: selectedReason == reason,
                      onSelected: (selected) {
                        setState(() {
                          selectedReason = selected ? reason : null;
                          if (selected) {
                            reasonController.text = reason;
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Rejection reason',
                    hintText: 'Enter detailed reason for rejection...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide a rejection reason'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      _rejectRestaurant(reasonController.text.trim());
    }
  }

  /// Approves the restaurant
  Future<void> _approveRestaurant() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await _approvalService.approveRestaurant(
          widget.token, widget.restaurant.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.restaurant.name} has been approved'),
          backgroundColor: Colors.green,
        ),
      );

      // Return true to indicate restaurant was processed
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve restaurant: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Rejects the restaurant with reason
  Future<void> _rejectRestaurant(String reason) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await _approvalService.rejectRestaurant(
        widget.token,
        widget.restaurant.id,
        reason: reason,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.restaurant.name} has been rejected'),
          backgroundColor: Colors.orange,
        ),
      );

      // Return true to indicate restaurant was processed
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject restaurant: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Details'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Restaurant information card
            _buildRestaurantInfoCard(),

            // Action buttons
            if (widget.restaurant.approvalStatus == ApprovalStatus.pending)
              _buildActionButtons(),

            // Approval history
            if (_history.isNotEmpty || _isLoadingHistory)
              _buildApprovalHistory(),
          ],
        ),
      ),
    );
  }

  /// Builds restaurant information card
  Widget _buildRestaurantInfoCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: DashboardConstants.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.restaurant.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusBadge(widget.restaurant.approvalStatus),
              ],
            ),
            const SizedBox(height: 20),

            // Cuisine type
            if (widget.restaurant.cuisine != null)
              _buildInfoRow(
                Icons.restaurant_menu,
                'Cuisine',
                widget.restaurant.cuisine!,
              ),
            if (widget.restaurant.cuisine != null) const SizedBox(height: 12),

            // Address
            if (widget.restaurant.address != null)
              _buildInfoRow(
                Icons.location_on,
                'Address',
                widget.restaurant.address!,
              ),
            if (widget.restaurant.address != null) const SizedBox(height: 12),

            // Location (city/state)
            _buildInfoRow(
              Icons.place,
              'Location',
              widget.restaurant.location,
            ),
            const SizedBox(height: 12),

            // Phone
            _buildInfoRow(
              Icons.phone,
              'Phone',
              widget.restaurant.phone ?? 'Not provided',
            ),
            const SizedBox(height: 12),

            // Rating
            _buildInfoRow(
              Icons.star,
              'Rating',
              widget.restaurant.rating.toStringAsFixed(1),
            ),
            const SizedBox(height: 12),

            // Active status
            _buildInfoRow(
              Icons.toggle_on,
              'Active Status',
              widget.restaurant.isActive ? 'Active' : 'Inactive',
            ),
            const SizedBox(height: 12),

            // Created date
            _buildInfoRow(
              Icons.calendar_today,
              'Created',
              _formatDate(widget.restaurant.createdAt),
            ),

            // Rejection reason if applicable
            if (widget.restaurant.rejectionReason != null) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Rejection Reason:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  widget.restaurant.rejectionReason!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds info row with icon, label, and value
  Widget _buildInfoRow(IconData icon, String label, String value) {
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
    );
  }

  /// Builds status badge
  Widget _buildStatusBadge(ApprovalStatus status) {
    Color color;
    String text;

    switch (status) {
      case ApprovalStatus.pending:
        color = Colors.orange;
        text = 'PENDING';
        break;
      case ApprovalStatus.approved:
        color = Colors.green;
        text = 'APPROVED';
        break;
      case ApprovalStatus.rejected:
        color = Colors.red;
        text = 'REJECTED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Builds action buttons for approve/reject
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _showRejectDialog,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cancel),
              label: const Text('Reject'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _showApproveDialog,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds approval history section
  Widget _buildApprovalHistory() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: DashboardConstants.cardElevationSmall,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history, size: 20),
                SizedBox(width: 8),
                Text(
                  'Approval History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingHistory)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_history.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No approval history yet',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ..._history.map((entry) => _buildHistoryEntry(entry)).toList(),
          ],
        ),
      ),
    );
  }

  /// Builds individual history entry
  Widget _buildHistoryEntry(ApprovalHistory entry) {
    Color color;
    IconData icon;

    switch (entry.action) {
      case ApprovalStatus.approved:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case ApprovalStatus.rejected:
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case ApprovalStatus.pending:
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.action.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (entry.reason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.reason!,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _formatDate(entry.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Formats DateTime for display
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
