import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Custom time input widget with 12-hour format and AM/PM selector
/// Replaces the circular clock time picker with simple text input fields
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
  late TextEditingController _hourController;
  late TextEditingController _minuteController;
  late bool _isPM;

  @override
  void initState() {
    super.initState();
    _initializeFromTime(widget.initialTime);
  }

  @override
  void didUpdateWidget(TimeInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTime != widget.initialTime) {
      _initializeFromTime(widget.initialTime);
    }
  }

  void _initializeFromTime(String time24) {
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

    _hourController = TextEditingController(text: hour12.toString());
    _minuteController = TextEditingController(text: minute.toString().padLeft(2, '0'));
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _notifyTimeChange() {
    final hour12 = int.tryParse(_hourController.text) ?? 12;
    final minute = int.tryParse(_minuteController.text) ?? 0;

    // Convert 12-hour to 24-hour format
    int hour24;
    if (_isPM) {
      hour24 = hour12 == 12 ? 12 : hour12 + 12;
    } else {
      hour24 = hour12 == 12 ? 0 : hour12;
    }

    // Validate ranges
    if (hour12 < 1 || hour12 > 12) return;
    if (minute < 0 || minute > 59) return;

    final time24 = '${hour24.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
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
            // Hour field
            SizedBox(
              width: 60,
              child: TextFormField(
                controller: _hourController,
                enabled: widget.enabled,
                decoration: const InputDecoration(
                  hintText: '12',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _HourInputFormatter(),
                ],
                onChanged: (_) => _notifyTimeChange(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                ':',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: widget.enabled ? Colors.black87 : Colors.grey,
                ),
              ),
            ),
            // Minute field
            SizedBox(
              width: 60,
              child: TextFormField(
                controller: _minuteController,
                enabled: widget.enabled,
                decoration: const InputDecoration(
                  hintText: '00',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _MinuteInputFormatter(),
                ],
                onChanged: (_) => _notifyTimeChange(),
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

/// Input formatter for hour field (1-12)
class _HourInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final value = int.tryParse(newValue.text);
    if (value == null) {
      return oldValue;
    }

    // Allow 0-12, but will be validated on blur
    if (value > 12) {
      return oldValue;
    }

    return newValue;
  }
}

/// Input formatter for minute field (0-59)
class _MinuteInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final value = int.tryParse(newValue.text);
    if (value == null) {
      return oldValue;
    }

    if (value > 59) {
      return oldValue;
    }

    return newValue;
  }
}
