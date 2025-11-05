import 'package:flutter/material.dart';
import '../../models/vendor_settings.dart';
import 'time_input_field.dart';

/// Widget for editing the default daily hours of operation
class DefaultHoursEditor extends StatelessWidget {
  final DaySchedule defaultSchedule;
  final Function(DaySchedule) onScheduleChanged;

  const DefaultHoursEditor({
    super.key,
    required this.defaultSchedule,
    required this.onScheduleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  color: Colors.deepOrange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Default Daily Hours',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Set the default hours that apply to all days',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            // Closed all day toggle
            CheckboxListTile(
              title: const Text('Closed all day'),
              subtitle: const Text(
                'Restaurant is closed by default',
                style: TextStyle(fontSize: 12),
              ),
              value: defaultSchedule.closed,
              activeColor: Colors.deepOrange,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                onScheduleChanged(
                  defaultSchedule.copyWith(closed: value ?? false),
                );
              },
            ),
            const SizedBox(height: 16),
            // Time inputs (only if not closed)
            if (!defaultSchedule.closed) ...[
              Row(
                children: [
                  Expanded(
                    child: TimeInputField(
                      label: 'Open',
                      initialTime: defaultSchedule.open,
                      onTimeChanged: (time) {
                        onScheduleChanged(
                          defaultSchedule.copyWith(open: time),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TimeInputField(
                      label: 'Close',
                      initialTime: defaultSchedule.close,
                      onTimeChanged: (time) {
                        onScheduleChanged(
                          defaultSchedule.copyWith(close: time),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You can override specific days below',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
