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
    final isMobile = DashboardConstants.isMobile(context);

    return Card(
      elevation: DashboardConstants.cardElevationSmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DashboardConstants.cardBorderRadiusSmall),
        child: Padding(
          padding: EdgeInsets.all(DashboardConstants.responsiveCardPaddingSmall(context)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: DashboardConstants.responsiveDashboardIconSize(context),
                color: color,
              ),
              SizedBox(height: isMobile ? 6 : 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: DashboardConstants.responsiveDashboardCardTextSize(context),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: DashboardConstants.restaurantCardMaxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
