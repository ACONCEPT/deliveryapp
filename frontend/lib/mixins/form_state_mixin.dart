import 'package:flutter/material.dart';

/// Mixin that provides common form state management functionality including:
/// - Form key management
/// - Text controller lifecycle management
/// - Save operation with loading state
/// - Confirmation dialogs
/// - Standard loading button builder
///
/// Example usage:
/// ```dart
/// class _MyFormScreenState extends State<MyFormScreen> with FormStateMixin {
///   @override
///   void initState() {
///     super.initState();
///     createController('name', initialValue: widget.item?.name);
///     createController('email', initialValue: widget.item?.email);
///   }
///
///   Future<void> _save() async {
///     await executeSave(
///       operation: () => myService.save(getText('name'), getText('email')),
///       successMessage: 'Saved successfully',
///       popOnSuccess: true,
///     );
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Form(
///       key: formKey,
///       child: Column(
///         children: [
///           TextFormField(controller: controller('name')),
///           TextFormField(controller: controller('email')),
///           buildLoadingButton(
///             onPressed: _save,
///             label: 'Save',
///           ),
///         ],
///       ),
///     );
///   }
/// }
/// ```
mixin FormStateMixin<T extends StatefulWidget> on State<T> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = false;

  /// Form key for validation
  GlobalKey<FormState> get formKey => _formKey;

  /// Current loading state
  bool get isLoading => _isLoading;

  /// Create a text controller with optional initial value
  ///
  /// Should be called in initState() for each form field.
  /// Controllers are automatically disposed.
  TextEditingController createController(String key, {String? initialValue}) {
    if (_controllers.containsKey(key)) {
      throw StateError('Controller with key "$key" already exists');
    }
    final controller = TextEditingController(text: initialValue ?? '');
    _controllers[key] = controller;
    return controller;
  }

  /// Get a controller by key
  TextEditingController controller(String key) {
    final controller = _controllers[key];
    if (controller == null) {
      throw StateError(
          'Controller with key "$key" not found. Did you call createController?');
    }
    return controller;
  }

  /// Get trimmed text from a controller
  String getText(String key) {
    return controller(key).text.trim();
  }

  /// Get trimmed text or null if empty
  String? getTextOrNull(String key) {
    final text = getText(key);
    return text.isEmpty ? null : text;
  }

  /// Set loading state
  void _setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
      });
    }
  }

  /// Execute a save operation with loading state and user feedback
  ///
  /// [operation] The async function to execute (e.g., API call)
  /// [successMessage] Message to show on success (optional)
  /// [errorMessagePrefix] Prefix for error messages (default: 'Error: ')
  /// [popOnSuccess] Whether to pop the screen on success (default: false)
  /// [popResult] Value to return when popping (default: true)
  /// [validateForm] Whether to validate form before executing (default: true)
  Future<void> executeSave({
    required Future<void> Function() operation,
    String? successMessage,
    String errorMessagePrefix = 'Error: ',
    bool popOnSuccess = false,
    dynamic popResult = true,
    bool validateForm = true,
  }) async {
    // Validate form if required
    if (validateForm && !_formKey.currentState!.validate()) {
      return;
    }

    _setLoading(true);

    try {
      await operation();

      if (!mounted) return;

      // Show success message if provided
      if (successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }

      // Pop screen if requested
      if (popOnSuccess) {
        Navigator.pop(context, popResult);
      } else {
        _setLoading(false);
      }
    } catch (e) {
      _setLoading(false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$errorMessagePrefix$e')),
      );
    }
  }

  /// Show a confirmation dialog and return the result
  ///
  /// [title] Dialog title
  /// [content] Dialog content/message
  /// [confirmText] Text for confirm button (default: 'Confirm')
  /// [cancelText] Text for cancel button (default: 'Cancel')
  /// [isDestructive] Whether the action is destructive (uses red color) (default: false)
  Future<bool> confirmAction({
    required String title,
    required String content,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: isDestructive
                ? TextButton.styleFrom(foregroundColor: Colors.red)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result == true;
  }

  /// Build a standard loading button for forms
  ///
  /// [onPressed] Callback when button is pressed (disabled when loading)
  /// [label] Button text
  /// [backgroundColor] Button background color (optional)
  /// [icon] Optional icon to display before label
  Widget buildLoadingButton({
    required VoidCallback onPressed,
    required String label,
    Color? backgroundColor,
    IconData? icon,
  }) {
    return ElevatedButton(
      onPressed: _isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : icon != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
    );
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }
}
