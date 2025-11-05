import 'package:flutter/material.dart';
import '../../models/vendor_settings.dart';
import 'time_input_field.dart';

/// Widget for editing a single day's hours with override option
class DayHoursEditor extends StatefulWidget {
  final String dayName;
  final DaySchedule daySchedule;
  final DaySchedule defaultSchedule;
  final bool useDefault;
  final Function(DaySchedule) onScheduleChanged;
  final Function(bool) onUseDefaultChanged;

  const DayHoursEditor({
    super.key,
    required this.dayName,
    required this.daySchedule,
    required this.defaultSchedule,
    required this.useDefault,
    required this.onScheduleChanged,
    required this.onUseDefaultChanged,
  });

  @override
  State<DayHoursEditor> createState() => _DayHoursEditorState();
}

class _DayHoursEditorState extends State<DayHoursEditor> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    // Start expanded if not using default hours
    _expanded = !widget.useDefault;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSchedule = widget.useDefault ? widget.defaultSchedule : widget.daySchedule;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Day name
                  SizedBox(
                    width: 100,
                    child: Text(
                      widget.dayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  // Current hours display
                  Expanded(
                    child: effectiveSchedule.closed
                        ? const Text(
                            'Closed',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : Text(
                            '${_formatTime(effectiveSchedule.open)} - ${_formatTime(effectiveSchedule.close)}',
                            style: TextStyle(
                              color: widget.useDefault ? Colors.grey[600] : Colors.black87,
                            ),
                          ),
                  ),
                  // Use default badge
                  if (widget.useDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Default',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[900],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Custom',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[900],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Use default hours toggle
                  SwitchListTile(
                    title: const Text('Use default daily hours'),
                    subtitle: Text(
                      widget.defaultSchedule.closed
                          ? 'Closed all day'
                          : '${_formatTime(widget.defaultSchedule.open)} - ${_formatTime(widget.defaultSchedule.close)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: widget.useDefault,
                    activeTrackColor: Colors.deepOrange,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      widget.onUseDefaultChanged(value);
                      if (!value) {
                        // When switching to custom, initialize with default values
                        widget.onScheduleChanged(widget.defaultSchedule);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Custom hours section (only if not using default)
                  if (!widget.useDefault) ...[
                    // Closed all day toggle
                    CheckboxListTile(
                      title: const Text('Closed all day'),
                      value: widget.daySchedule.closed,
                      activeColor: Colors.deepOrange,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        widget.onScheduleChanged(
                          widget.daySchedule.copyWith(closed: value ?? false),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Time inputs (only if not closed)
                    if (!widget.daySchedule.closed) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TimeInputField(
                              label: 'Open',
                              initialTime: widget.daySchedule.open,
                              onTimeChanged: (time) {
                                widget.onScheduleChanged(
                                  widget.daySchedule.copyWith(open: time),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TimeInputField(
                              label: 'Close',
                              initialTime: widget.daySchedule.close,
                              onTimeChanged: (time) {
                                widget.onScheduleChanged(
                                  widget.daySchedule.copyWith(close: time),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(String time24) {
    // Convert 24-hour format to 12-hour format with AM/PM
    final parts = time24.split(':');
    final hour24 = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final hour12 = hour24 == 0
        ? 12
        : hour24 > 12
            ? hour24 - 12
            : hour24;
    final period = hour24 >= 12 ? 'PM' : 'AM';

    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }
}
