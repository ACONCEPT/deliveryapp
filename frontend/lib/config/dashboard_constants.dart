import 'package:flutter/material.dart';

class DashboardConstants {
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  // Grid Layout - Keep static defaults for const contexts
  static const int dashboardGridColumns = 5;
  static const double gridSpacing = 12.0;
  static const double dashboardCardAspectRatio = 1.0;
  static const double restaurantCardAspectRatio = 0.85;

  // Responsive aspect ratios
  static double responsiveDashboardCardAspectRatio(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return 1.1;  // Taller cards on mobile for better text visibility
    return 1.0;
  }

  static double responsiveRestaurantCardAspectRatio(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return 0.95;  // Slightly taller on mobile
    return 0.85;
  }

  // Responsive Grid Columns (use these when you have BuildContext)
  static int responsiveGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return 2; // Mobile: 2 columns
    if (width < tabletBreakpoint) return 3;  // Tablet: 3 columns
    if (width < desktopBreakpoint) return 4; // Small desktop: 4 columns
    return 5; // Large desktop: 5 columns
  }

  // Responsive Grid Spacing (use these when you have BuildContext)
  static double responsiveGridSpacing(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return 8.0;  // Tighter on mobile
    if (width < tabletBreakpoint) return 10.0;
    return 12.0;
  }

  // Padding & Spacing - Keep static defaults for const contexts
  static const double cardPadding = 24.0;
  static const double cardPaddingSmall = 12.0;
  static const double sectionSpacing = 24.0;
  static const double screenPadding = 32.0;

  // Responsive Padding (use these when you have BuildContext)
  static double responsiveCardPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return 12.0;  // Less padding on mobile
    if (width < tabletBreakpoint) return 16.0;
    return 24.0;
  }

  static double responsiveCardPaddingSmall(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return 8.0;
    return 12.0;
  }

  static double responsiveSectionSpacing(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return 16.0;
    return 24.0;
  }

  static double responsiveScreenPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return 16.0;  // Much less on mobile
    if (width < tabletBreakpoint) return 24.0;
    return 32.0;
  }

  // Card Styling (keep static)
  static const double cardElevation = 8.0;
  static const double cardElevationSmall = 3.0;
  static const double cardElevationRestaurant = 2.0;
  static const double cardBorderRadius = 16.0;
  static const double cardBorderRadiusSmall = 12.0;
  static const double cardBorderRadiusExtraSmall = 8.0;

  // Icon Sizes - Keep static defaults for const contexts
  static const double dashboardIconSize = 32.0;
  static const double restaurantIconSize = 40.0;
  static const double sectionHeaderIconSize = 24.0;

  // Responsive Icon Sizes (use these when you have BuildContext)
  static double responsiveDashboardIconSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return 32.0;  // Keep consistent size on mobile
    return 32.0;
  }

  static double responsiveRestaurantIconSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return 36.0;
    return 40.0;
  }

  static double responsiveSectionHeaderIconSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return 20.0;
    return 24.0;
  }

  // Text Sizes - Keep static defaults for const contexts
  static const double dashboardCardTextSize = 12.0;
  static const double restaurantNameTextSize = 14.0;
  static const double restaurantCuisineTextSize = 12.0;
  static const double restaurantInfoTextSize = 12.0;
  static const double restaurantInfoSmallTextSize = 11.0;

  // Responsive Text Sizes (use these when you have BuildContext)
  static double responsiveDashboardCardTextSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return 14.0;  // Larger on mobile for readability
    return 12.0;
  }

  static double responsiveRestaurantNameTextSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return 15.0;  // Larger on mobile
    return 14.0;
  }

  static double responsiveRestaurantCuisineTextSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return 13.0;  // Larger on mobile
    return 12.0;
  }

  static double responsiveRestaurantInfoTextSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return 12.0;  // Keep readable on mobile
    return 12.0;
  }

  static double responsiveRestaurantInfoSmallTextSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return 11.0;
    return 11.0;
  }

  // Other
  static const int restaurantCardMaxLines = 2;
  static const double restaurantImageHeight = 80.0;

  static double responsiveRestaurantImageHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return 100.0;  // Taller on mobile
    return 80.0;
  }

  static const double userInfoPopupWidth = 280.0;
  static const double userInfoPopupMaxHeight = 400.0;

  // Helper methods to check device type
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }
}
