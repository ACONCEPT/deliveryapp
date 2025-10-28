import 'package:flutter/material.dart';
import '../../config/dashboard_constants.dart';

/// Widget displayed when an error occurs, with retry button.
///
/// Example usage:
/// ```dart
/// ErrorStateWidget(
///   message: 'Failed to load data',
///   onRetry: _loadData,
/// )
/// ```
class ErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final IconData? icon;

  const ErrorStateWidget({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: DashboardConstants.sectionSpacing),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DashboardConstants.sectionSpacing),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: DashboardConstants.cardPadding,
                  vertical: DashboardConstants.cardPaddingSmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget displayed when a list is empty, with helpful message and optional action.
///
/// Example usage:
/// ```dart
/// EmptyStateWidget(
///   icon: Icons.location_off,
///   title: 'No addresses yet',
///   message: 'Add your first delivery address',
/// )
/// ```
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DashboardConstants.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: DashboardConstants.sectionSpacing),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: DashboardConstants.sectionSpacing),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget displayed while data is loading.
///
/// Example usage:
/// ```dart
/// LoadingStateWidget()
/// // or with message:
/// LoadingStateWidget(message: 'Loading addresses...')
/// ```
class LoadingStateWidget extends StatelessWidget {
  final String? message;

  const LoadingStateWidget({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: DashboardConstants.sectionSpacing),
            Text(
              message!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
