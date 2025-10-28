import 'package:flutter/material.dart';
import '../config/dashboard_constants.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;

  const SectionHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: iconColor,
          size: DashboardConstants.sectionHeaderIconSize,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
