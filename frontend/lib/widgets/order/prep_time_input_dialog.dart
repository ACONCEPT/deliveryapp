import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dialog for inputting preparation time when confirming an order
///
/// This widget displays:
/// - Read-only average prep time from restaurant settings
/// - Editable prep time input field (pre-filled with average)
/// - Validation (5-240 minutes range)
/// - Increment/decrement buttons for easy adjustment
/// - Confirm and cancel buttons
class PrepTimeInputDialog extends StatefulWidget {
  final int averagePrepTime;
  final VoidCallback onCancel;
  final Function(int prepTimeMinutes) onConfirm;

  const PrepTimeInputDialog({
    super.key,
    required this.averagePrepTime,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  State<PrepTimeInputDialog> createState() => _PrepTimeInputDialogState();
}

class _PrepTimeInputDialogState extends State<PrepTimeInputDialog> {
  late TextEditingController _prepTimeController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // Validation constants
  static const int minPrepTime = 5;
  static const int maxPrepTime = 240;
  static const int incrementStep = 5;

  @override
  void initState() {
    super.initState();
    // Pre-fill with average prep time
    _prepTimeController = TextEditingController(
      text: widget.averagePrepTime.toString(),
    );
  }

  @override
  void dispose() {
    _prepTimeController.dispose();
    super.dispose();
  }

  void _incrementPrepTime() {
    final currentValue = int.tryParse(_prepTimeController.text) ?? widget.averagePrepTime;
    final newValue = (currentValue + incrementStep).clamp(minPrepTime, maxPrepTime);
    setState(() {
      _prepTimeController.text = newValue.toString();
    });
  }

  void _decrementPrepTime() {
    final currentValue = int.tryParse(_prepTimeController.text) ?? widget.averagePrepTime;
    final newValue = (currentValue - incrementStep).clamp(minPrepTime, maxPrepTime);
    setState(() {
      _prepTimeController.text = newValue.toString();
    });
  }

  void _handleConfirm() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isSubmitting = true;
      });

      final prepTime = int.parse(_prepTimeController.text);
      widget.onConfirm(prepTime);
    }
  }

  String? _validatePrepTime(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter preparation time';
    }

    final prepTime = int.tryParse(value);
    if (prepTime == null) {
      return 'Please enter a valid number';
    }

    if (prepTime < minPrepTime) {
      return 'Minimum prep time is $minPrepTime minutes';
    }

    if (prepTime > maxPrepTime) {
      return 'Maximum prep time is $maxPrepTime minutes';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.timer, color: Colors.deepOrange),
          SizedBox(width: 8),
          Text('Confirm Order'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Average prep time display (read-only)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Average prep time: ${widget.averagePrepTime} minutes',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Prep time input label
            const Text(
              'Preparation time for this order',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            // Prep time input with increment/decrement buttons
            Row(
              children: [
                // Decrement button
                IconButton(
                  onPressed: _isSubmitting ? null : _decrementPrepTime,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.deepOrange,
                  tooltip: 'Decrease by $incrementStep minutes',
                ),

                // Input field
                Expanded(
                  child: TextFormField(
                    controller: _prepTimeController,
                    enabled: !_isSubmitting,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      suffixText: 'min',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    validator: _validatePrepTime,
                  ),
                ),

                // Increment button
                IconButton(
                  onPressed: _isSubmitting ? null : _incrementPrepTime,
                  icon: const Icon(Icons.add_circle_outline),
                  color: Colors.deepOrange,
                  tooltip: 'Increase by $incrementStep minutes',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Helper text
            Text(
              'Adjust based on order complexity ($minPrepTime-$maxPrepTime min)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Cancel button
        TextButton(
          onPressed: _isSubmitting ? null : widget.onCancel,
          child: const Text('Cancel'),
        ),

        // Confirm button
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _handleConfirm,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.check),
          label: Text(_isSubmitting ? 'Confirming...' : 'Confirm Order'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}