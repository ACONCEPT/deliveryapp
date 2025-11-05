import 'package:flutter/material.dart';
import '../../models/approval.dart';
import '../../services/approval_service.dart';
import '../../config/dashboard_constants.dart';

/// Driver Approval Detail Screen
///
/// Displays detailed information about a pending driver and provides
/// approve/reject actions with reason dialogs.
class DriverApprovalDetailScreen extends StatefulWidget {
  final String token;
  final DriverWithApproval driver;

  const DriverApprovalDetailScreen({
    super.key,
    required this.token,
    required this.driver,
  });

  @override
  State<DriverApprovalDetailScreen> createState() =>
      _DriverApprovalDetailScreenState();
}

class _DriverApprovalDetailScreenState
    extends State<DriverApprovalDetailScreen> {
  final ApprovalService _approvalService = ApprovalService();
  List<ApprovalHistory> _history = [];
  bool _isLoadingHistory = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadApprovalHistory();
  }

  /// Loads approval history for this driver
  Future<void> _loadApprovalHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final history = await _approvalService.getApprovalHistory(
        widget.token,
        'driver',
        widget.driver.id,
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
        title: const Text('Approve Driver'),
        content: Text(
          'Are you sure you want to approve "${widget.driver.fullName}"?\n\n'
          'This will allow the driver to accept and deliver orders.',
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
      _approveDriver();
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
          title: const Text('Reject Driver'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please provide a reason for rejecting "${widget.driver.fullName}":',
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
                    'Invalid license',
                    'Failed background check',
                    'Incomplete vehicle info',
                    'Policy violation',
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
      _rejectDriver(reasonController.text.trim());
    }
  }

  /// Approves the driver
  Future<void> _approveDriver() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await _approvalService.approveDriver(widget.token, widget.driver.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.driver.fullName} has been approved'),
          backgroundColor: Colors.green,
        ),
      );

      // Return true to indicate driver was processed
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve driver: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Rejects the driver with reason
  Future<void> _rejectDriver(String reason) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await _approvalService.rejectDriver(
        widget.token,
        widget.driver.id,
        reason: reason,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.driver.fullName} has been rejected'),
          backgroundColor: Colors.orange,
        ),
      );

      // Return true to indicate driver was processed
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject driver: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Details'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Driver information card
            _buildDriverInfoCard(),

            // Action buttons
            if (widget.driver.approvalStatus == ApprovalStatus.pending)
              _buildActionButtons(),

            // Approval history
            if (_history.isNotEmpty || _isLoadingHistory)
              _buildApprovalHistory(),
          ],
        ),
      ),
    );
  }

  /// Builds driver information card
  Widget _buildDriverInfoCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: DashboardConstants.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Driver name and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.driver.fullName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusBadge(widget.driver.approvalStatus),
              ],
            ),
            const SizedBox(height: 20),

            // Driver Details Section
            const Text(
              'Driver Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
            const SizedBox(height: 12),

            // Contact information
            _buildInfoRow(
              Icons.phone,
              'Phone',
              widget.driver.phone ?? 'Not provided',
            ),
            const SizedBox(height: 12),

            _buildInfoRow(
              Icons.location_on,
              'Location',
              widget.driver.location,
            ),
            const SizedBox(height: 12),

            _buildInfoRow(
              Icons.star,
              'Rating',
              widget.driver.rating.toStringAsFixed(1),
            ),
            const SizedBox(height: 12),

            _buildInfoRow(
              Icons.circle,
              'Availability',
              widget.driver.availabilityStatus,
              valueColor: widget.driver.isAvailable ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 12),

            _buildInfoRow(
              Icons.calendar_today,
              'Applied',
              _formatDate(widget.driver.createdAt),
            ),

            // Vehicle Information Section
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Vehicle Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
            const SizedBox(height: 12),

            _buildInfoRow(
              Icons.directions_car,
              'Vehicle Type',
              widget.driver.vehicleType ?? 'Not provided',
            ),
            const SizedBox(height: 12),

            _buildInfoRow(
              Icons.pin,
              'License Plate',
              widget.driver.vehiclePlate ?? 'Not provided',
            ),
            const SizedBox(height: 12),

            _buildInfoRow(
              Icons.badge,
              'License Number',
              widget.driver.licenseNumber ?? 'Not provided',
            ),

            // Rejection reason if rejected
            if (widget.driver.approvalStatus == ApprovalStatus.rejected &&
                widget.driver.rejectionReason != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Rejection Reason',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.driver.rejectionReason!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],

            // Approval information if approved
            if (widget.driver.approvalStatus == ApprovalStatus.approved) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Approval Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              if (widget.driver.approvedByAdminName != null)
                _buildInfoRow(
                  Icons.person,
                  'Approved by',
                  widget.driver.approvedByAdminName!,
                ),
              if (widget.driver.approvedAt != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.check_circle,
                  'Approved on',
                  _formatDate(widget.driver.approvedAt!),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Builds action buttons for approve/reject
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _showRejectDialog,
              icon: const Icon(Icons.cancel),
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
              icon: const Icon(Icons.check_circle),
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
      elevation: DashboardConstants.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Approval History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoadingHistory)
              const Center(child: CircularProgressIndicator())
            else if (_history.isEmpty)
              const Text(
                'No approval history available',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ..._history.map((entry) => _buildHistoryEntry(entry)),
          ],
        ),
      ),
    );
  }

  /// Builds a single history entry
  Widget _buildHistoryEntry(ApprovalHistory entry) {
    final isApproval = entry.action == ApprovalStatus.approved;
    final color = isApproval ? Colors.green : Colors.red;
    final icon = isApproval ? Icons.check_circle : Icons.cancel;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                isApproval ? 'Approved' : 'Rejected',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(entry.createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          if (entry.reason != null) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: ${entry.reason}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds status badge
  Widget _buildStatusBadge(ApprovalStatus status) {
    Color color;
    String label;

    switch (status) {
      case ApprovalStatus.pending:
        color = Colors.orange;
        label = 'PENDING';
        break;
      case ApprovalStatus.approved:
        color = Colors.green;
        label = 'APPROVED';
        break;
      case ApprovalStatus.rejected:
        color = Colors.red;
        label = 'REJECTED';
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
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Builds information row
  Widget _buildInfoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Formats DateTime for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes} minutes ago';
      }
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
