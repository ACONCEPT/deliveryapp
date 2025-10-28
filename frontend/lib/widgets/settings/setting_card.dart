import 'package:flutter/material.dart';
import '../../models/system_setting.dart';
import 'setting_input_field.dart';

/// Display card for individual system setting
///
/// Shows setting key, description, current value, and allows editing
/// for editable settings. Provides save/cancel actions and undo functionality.
class SettingCard extends StatefulWidget {
  final SystemSetting setting;
  final ValueChanged<String>? onSave;
  final bool isModified;
  final VoidCallback? onUndo;

  const SettingCard({
    super.key,
    required this.setting,
    this.onSave,
    this.isModified = false,
    this.onUndo,
  });

  @override
  State<SettingCard> createState() => _SettingCardState();
}

class _SettingCardState extends State<SettingCard> {
  bool _isEditing = false;
  late String _editValue;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _editValue = widget.setting.settingValue;
  }

  @override
  void didUpdateWidget(SettingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.setting.settingValue != oldWidget.setting.settingValue) {
      _editValue = widget.setting.settingValue;
      if (_isEditing) {
        setState(() {
          _isEditing = false;
        });
      }
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _editValue = widget.setting.settingValue;
      _validationError = null;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _editValue = widget.setting.settingValue;
      _validationError = null;
    });
  }

  void _saveChanges() {
    if (_editValue != widget.setting.settingValue && widget.onSave != null) {
      widget.onSave!(_editValue);
      setState(() {
        _isEditing = false;
      });
    } else {
      _cancelEditing();
    }
  }

  void _onValueChanged(String value) {
    setState(() {
      _editValue = value;
      _validationError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReadOnly = !widget.setting.isEditable;

    return Card(
      elevation: widget.isModified ? 4 : 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: widget.isModified
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with key and badges
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatSettingKey(widget.setting.settingKey),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isReadOnly)
                  Chip(
                    label: const Text('Read-only'),
                    backgroundColor: theme.colorScheme.surfaceVariant,
                    labelStyle: theme.textTheme.bodySmall,
                    visualDensity: VisualDensity.compact,
                  ),
                const SizedBox(width: 8),
                _buildDataTypeChip(theme),
              ],
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              widget.setting.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            // Value display or input
            if (_isEditing)
              _buildEditMode()
            else
              _buildViewMode(theme, isReadOnly),

            // Modified indicator and actions
            if (widget.isModified && !_isEditing) ...[
              const SizedBox(height: 12),
              _buildModifiedIndicator(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataTypeChip(ThemeData theme) {
    Color chipColor;
    IconData chipIcon;

    switch (widget.setting.dataType) {
      case SettingDataType.string:
        chipColor = Colors.blue.shade100;
        chipIcon = Icons.text_fields;
        break;
      case SettingDataType.number:
        chipColor = Colors.green.shade100;
        chipIcon = Icons.numbers;
        break;
      case SettingDataType.boolean:
        chipColor = Colors.purple.shade100;
        chipIcon = Icons.toggle_on;
        break;
      case SettingDataType.json:
        chipColor = Colors.orange.shade100;
        chipIcon = Icons.code;
        break;
    }

    return Chip(
      avatar: Icon(chipIcon, size: 16),
      label: Text(widget.setting.dataType.displayName),
      backgroundColor: chipColor,
      labelStyle: theme.textTheme.bodySmall,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildViewMode(ThemeData theme, bool isReadOnly) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.setting.formattedValue,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!isReadOnly) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: _startEditing,
              tooltip: 'Edit',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingInputField(
          setting: widget.setting,
          currentValue: _editValue,
          onChanged: _onValueChanged,
          enabled: true,
        ),
        if (_validationError != null) ...[
          const SizedBox(height: 4),
          Text(
            _validationError!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _cancelEditing,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _editValue != widget.setting.settingValue
                  ? _saveChanges
                  : null,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModifiedIndicator(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Unsaved changes',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          if (widget.onUndo != null)
            TextButton.icon(
              onPressed: widget.onUndo,
              icon: const Icon(Icons.undo, size: 16),
              label: const Text('Undo'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onPrimaryContainer,
              ),
            ),
        ],
      ),
    );
  }

  String _formatSettingKey(String key) {
    // Convert snake_case to Title Case
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
