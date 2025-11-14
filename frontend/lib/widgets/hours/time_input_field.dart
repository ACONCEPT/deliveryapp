import 'package:flutter/material.dart';

/// Custom time input widget with 12-hour format and AM/PM selector
/// Uses dropdown selectors instead of text fields
class TimeInputField extends StatefulWidget {
  final String label;
  final String initialTime; // 24-hour format "HH:MM"
  final Function(String) onTimeChanged; // Returns 24-hour format "HH:MM"
  final bool enabled;

  const TimeInputField({
    super.key,
    required this.label,
    required this.initialTime,
    required this.onTimeChanged,
    this.enabled = true,
  });

  @override
  State<TimeInputField> createState() => _TimeInputFieldState();
}

class _TimeInputFieldState extends State<TimeInputField> {
  int _hour12 = 12;
  int _minute = 0;
  bool _isPM = false;

  @override
  void initState() {
    super.initState();
    _updateFromTime(widget.initialTime);
  }

  @override
  void didUpdateWidget(TimeInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTime != widget.initialTime) {
      _updateFromTime(widget.initialTime);
    }
  }

  void _updateFromTime(String time24) {
    // Parse 24-hour format "HH:MM"
    final parts = time24.split(':');
    final hour24 = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    // Convert to 12-hour format
    final hour12 = hour24 == 0
        ? 12
        : hour24 > 12
            ? hour24 - 12
            : hour24;
    _isPM = hour24 >= 12;

    setState(() {
      _hour12 = hour12;
      _minute = minute;
    });
  }

  void _notifyTimeChange() {
    // Convert 12-hour to 24-hour format
    int hour24;
    if (_isPM) {
      hour24 = _hour12 == 12 ? 12 : _hour12 + 12;
    } else {
      hour24 = _hour12 == 12 ? 0 : _hour12;
    }

    final time24 = '${hour24.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';
    widget.onTimeChanged(time24);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hour dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButton<int>(
                value: _hour12,
                isDense: true,
                underline: const SizedBox(),
                items: List.generate(12, (index) {
                  final hour = index + 1;
                  return DropdownMenuItem<int>(
                    value: hour,
                    child: Text(
                      hour.toString().padLeft(2, '0'),
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }),
                onChanged: widget.enabled
                    ? (value) {
                        setState(() {
                          _hour12 = value!;
                        });
                        _notifyTimeChange();
                      }
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                ':',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: widget.enabled ? Colors.black87 : Colors.grey,
                ),
              ),
            ),
            // Minute dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButton<int>(
                value: _minute,
                isDense: true,
                underline: const SizedBox(),
                items: List.generate(60, (index) {
                  return DropdownMenuItem<int>(
                    value: index,
                    child: Text(
                      index.toString().padLeft(2, '0'),
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }),
                onChanged: widget.enabled
                    ? (value) {
                        setState(() {
                          _minute = value!;
                        });
                        _notifyTimeChange();
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            // AM/PM selector
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAmPmButton('AM', !_isPM),
                  Container(
                    width: 1,
                    height: 32,
                    color: Colors.grey,
                  ),
                  _buildAmPmButton('PM', _isPM),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmPmButton(String label, bool isSelected) {
    return InkWell(
      onTap: widget.enabled
          ? () {
              setState(() {
                _isPM = label == 'PM';
                _notifyTimeChange();
              });
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : widget.enabled
                    ? Colors.black87
                    : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
