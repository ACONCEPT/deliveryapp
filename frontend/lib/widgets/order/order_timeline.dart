import 'package:flutter/material.dart';
import '../../models/order.dart';

/// Timeline widget showing order status progression
/// Displays vertical stepper with completed and upcoming steps
class OrderTimeline extends StatelessWidget {
  final OrderStatus currentStatus;
  final DateTime? createdAt;
  final DateTime? estimatedDeliveryTime;

  const OrderTimeline({
    super.key,
    required this.currentStatus,
    this.createdAt,
    this.estimatedDeliveryTime,
  });

  /// Get all timeline steps in order
  List<TimelineStep> _getTimelineSteps() {
    return [
      TimelineStep(
        status: OrderStatus.pending,
        title: 'Order Placed',
        description: createdAt != null
            ? _formatDateTime(createdAt!)
            : 'Awaiting confirmation',
      ),
      TimelineStep(
        status: OrderStatus.confirmed,
        title: 'Order Confirmed',
        description: 'Restaurant accepted your order',
      ),
      TimelineStep(
        status: OrderStatus.preparing,
        title: 'Preparing',
        description: 'Your food is being prepared',
      ),
      TimelineStep(
        status: OrderStatus.ready,
        title: 'Ready for Pickup',
        description: 'Waiting for driver',
      ),
      TimelineStep(
        status: OrderStatus.pickedUp,
        title: 'Picked Up',
        description: 'Driver picked up your order',
      ),
      TimelineStep(
        status: OrderStatus.enRoute,
        title: 'On the Way',
        description: estimatedDeliveryTime != null
            ? 'ETA: ${_formatTime(estimatedDeliveryTime!)}'
            : 'Heading to your location',
      ),
      TimelineStep(
        status: OrderStatus.delivered,
        title: 'Delivered',
        description: 'Order completed',
      ),
    ];
  }

  /// Check if step is completed based on current status
  bool _isStepCompleted(OrderStatus stepStatus) {
    final steps = OrderStatus.values;
    final currentIndex = steps.indexOf(currentStatus);
    final stepIndex = steps.indexOf(stepStatus);
    return stepIndex <= currentIndex;
  }

  /// Check if step is current active step
  bool _isCurrentStep(OrderStatus stepStatus) {
    return stepStatus == currentStatus;
  }

  /// Format DateTime to readable string
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Format time to readable string
  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    // Handle cancelled status separately
    if (currentStatus == OrderStatus.cancelled) {
      return _buildCancelledTimeline();
    }

    final steps = _getTimelineSteps();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: steps.length,
      itemBuilder: (context, index) {
        final step = steps[index];
        final isCompleted = _isStepCompleted(step.status);
        final isCurrent = _isCurrentStep(step.status);
        final isLast = index == steps.length - 1;

        return _buildTimelineItem(
          step: step,
          isCompleted: isCompleted,
          isCurrent: isCurrent,
          isLast: isLast,
        );
      },
    );
  }

  Widget _buildTimelineItem({
    required TimelineStep step,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
  }) {
    final iconColor = isCompleted
        ? Colors.green
        : isCurrent
            ? Colors.blue
            : Colors.grey;

    final lineColor = isCompleted ? Colors.green : Colors.grey.shade300;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              // Icon/Circle
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withOpacity(0.1),
                  border: Border.all(
                    color: iconColor,
                    width: 2,
                  ),
                ),
                child: Icon(
                  isCompleted ? Icons.check : Icons.circle,
                  size: 20,
                  color: iconColor,
                ),
              ),
              // Connecting line
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: lineColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Step content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCompleted || isCurrent
                          ? Colors.black87
                          : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isCompleted || isCurrent
                          ? Colors.black54
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledTimeline() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.cancel, color: Colors.red.shade700, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Cancelled',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This order has been cancelled',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Data class for timeline step
class TimelineStep {
  final OrderStatus status;
  final String title;
  final String description;

  const TimelineStep({
    required this.status,
    required this.title,
    required this.description,
  });
}
