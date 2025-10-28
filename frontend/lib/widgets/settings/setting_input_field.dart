import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/system_setting.dart';

/// Smart input field that adapts to setting data type
///
/// Provides appropriate input widget based on SettingDataType:
/// - String: TextFormField with text input
/// - Number: TextFormField with numeric keyboard and validation
/// - Boolean: Switch widget
/// - JSON: TextFormField with JSON validation and formatting
class SettingInputField extends StatefulWidget {
  final SystemSetting setting;
  final String currentValue;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const SettingInputField({
    super.key,
    required this.setting,
    required this.currentValue,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<SettingInputField> createState() => _SettingInputFieldState();
}

class _SettingInputFieldState extends State<SettingInputField> {
  late TextEditingController _textController;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.currentValue);
  }

  @override
  void didUpdateWidget(SettingInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentValue != oldWidget.currentValue) {
      _textController.text = widget.currentValue;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _validateAndNotify(String value) {
    setState(() {
      _validationError = _getValidationError(value);
    });
    if (_validationError == null) {
      widget.onChanged(value);
    }
  }

  String? _getValidationError(String value) {
    switch (widget.setting.dataType) {
      case SettingDataType.number:
        final num = double.tryParse(value);
        if (num == null) {
          return 'Must be a valid number';
        }
        return null;
      case SettingDataType.boolean:
        if (value.toLowerCase() != 'true' && value.toLowerCase() != 'false') {
          return 'Must be true or false';
        }
        return null;
      case SettingDataType.json:
        // JSON validation would happen here
        return null;
      case SettingDataType.string:
        if (value.isEmpty) {
          return 'Cannot be empty';
        }
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.setting.dataType) {
      case SettingDataType.boolean:
        return _buildBooleanInput();
      case SettingDataType.number:
        return _buildNumberInput();
      case SettingDataType.json:
        return _buildJsonInput();
      case SettingDataType.string:
        return _buildStringInput();
    }
  }

  Widget _buildBooleanInput() {
    final currentBoolValue = widget.currentValue.toLowerCase() == 'true';

    return Row(
      children: [
        Expanded(
          child: Text(
            currentBoolValue ? 'Enabled' : 'Disabled',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        Switch(
          value: currentBoolValue,
          onChanged: widget.enabled
              ? (value) {
                  widget.onChanged(value.toString());
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildNumberInput() {
    return TextFormField(
      controller: _textController,
      enabled: widget.enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        errorText: _validationError,
        suffixIcon: _getNumberSuffix(),
        filled: true,
        fillColor: widget.enabled
            ? null
            : Theme.of(context).disabledColor.withOpacity(0.1),
      ),
      onChanged: _validateAndNotify,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Required';
        }
        return _getValidationError(value);
      },
    );
  }

  Widget? _getNumberSuffix() {
    // Add suffix based on setting key for better UX
    if (widget.setting.settingKey.contains('rate') ||
        widget.setting.settingKey.contains('commission')) {
      return const Padding(
        padding: EdgeInsets.only(right: 12.0),
        child: Icon(Icons.percent, size: 20),
      );
    }
    if (widget.setting.settingKey.contains('amount') ||
        widget.setting.settingKey.contains('fee') ||
        widget.setting.settingKey.contains('price')) {
      return const Padding(
        padding: EdgeInsets.only(right: 12.0),
        child: Icon(Icons.attach_money, size: 20),
      );
    }
    return null;
  }

  Widget _buildStringInput() {
    return TextFormField(
      controller: _textController,
      enabled: widget.enabled,
      maxLines: widget.setting.settingKey.contains('description') ? 3 : 1,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        errorText: _validationError,
        filled: true,
        fillColor: widget.enabled
            ? null
            : Theme.of(context).disabledColor.withOpacity(0.1),
      ),
      onChanged: _validateAndNotify,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Required';
        }
        return null;
      },
    );
  }

  Widget _buildJsonInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _textController,
          enabled: widget.enabled,
          maxLines: 5,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            errorText: _validationError,
            helperText: 'Valid JSON required',
            filled: true,
            fillColor: widget.enabled
                ? null
                : Theme.of(context).disabledColor.withOpacity(0.1),
          ),
          onChanged: _validateAndNotify,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Required';
            }
            return _getValidationError(value);
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: widget.enabled ? _formatJson : null,
              icon: const Icon(Icons.format_align_left, size: 16),
              label: const Text('Format'),
            ),
          ],
        ),
      ],
    );
  }

  void _formatJson() {
    try {
      final dynamic decoded = _textController.text.trim().isNotEmpty
          ? JsonDecoder().convert(_textController.text)
          : null;
      if (decoded != null) {
        final encoder = JsonEncoder.withIndent('  ');
        final formatted = encoder.convert(decoded);
        _textController.text = formatted;
        _validateAndNotify(formatted);
      }
    } catch (e) {
      // Invalid JSON, show error
      setState(() {
        _validationError = 'Invalid JSON format';
      });
    }
  }
}
