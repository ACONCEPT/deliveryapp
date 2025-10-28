import 'package:flutter/material.dart';
import '../config/dashboard_constants.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const DashboardCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
        child: Container(
          padding: const EdgeInsets.all(DashboardConstants.cardPaddingSmall),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: DashboardConstants.dashboardIconSize,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: DashboardConstants.dashboardCardTextSize,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: DashboardConstants.restaurantCardMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
