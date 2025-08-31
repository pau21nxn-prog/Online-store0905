import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';

/// Utility class for mobile-only layout configurations
class MobileLayoutUtils {
  
  /// Mobile viewport constants for optimal smartphone experience
  static const double mobileViewportWidth = 430.0; // iPhone 15 Pro Max & modern large phones
  static const double mobileViewportMinWidth = 320.0; // Minimum mobile width
  static const double mobileViewportBorderRadius = 12.0;
  static const double mobileViewportElevation = 8.0;
  static const Color mobileViewportShadowColor = Color(0x1A000000);
  static const Color mobileViewportBackgroundColor = Color(0xFFF5F5F5);
  
  /// Fixed mobile grid configuration for user screens
  static const int mobileGridColumns = 2;
  static const double mobileGridAspectRatio = 0.75;
  static const double mobileGridSpacing = 12.0;
  static const double mobileGridPadding = 16.0;
  
  /// Check if current user should see mobile layout (non-admin users)
  static bool shouldUseMobileLayout({required bool isAdmin}) {
    return !isAdmin; // All non-admin users get mobile layout
  }
  
  /// Check if current user should see desktop layout (admin users)
  static bool shouldUseDesktopLayout({required bool isAdmin}) {
    return isAdmin; // Only admin users get desktop layout
  }
  
  /// Get cross axis count - always 2 for mobile user screens, responsive for admin
  static int getCrossAxisCount({
    required BuildContext context,
    required bool isAdmin,
  }) {
    if (isAdmin) {
      // Admin screens: responsive grid based on screen size
      final width = MediaQuery.of(context).size.width;
      if (width > 1024) return 6; // Desktop
      if (width > 600) return 4;  // Tablet
      return 2; // Mobile fallback
    } else {
      // User screens: always 2 columns
      return mobileGridColumns;
    }
  }
  
  /// Get grid delegate for product/content grids
  static SliverGridDelegate getProductGridDelegate({
    required bool isAdmin,
    required BuildContext context,
  }) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: getCrossAxisCount(context: context, isAdmin: isAdmin),
      childAspectRatio: mobileGridAspectRatio,
      crossAxisSpacing: mobileGridSpacing,
      mainAxisSpacing: mobileGridSpacing,
    );
  }
  
  /// Get category grid delegate
  static SliverGridDelegate getCategoryGridDelegate({
    required bool isAdmin,
    required BuildContext context,
  }) {
    if (isAdmin) {
      // Admin category grid - responsive
      final width = MediaQuery.of(context).size.width;
      final crossAxisCount = width > 1024 ? 4 : (width > 600 ? 3 : 2);
      return SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
      );
    } else {
      // User category grid - fixed 2 columns
      return SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: mobileGridColumns,
        childAspectRatio: 0.85,
        crossAxisSpacing: mobileGridSpacing,
        mainAxisSpacing: mobileGridSpacing,
      );
    }
  }
  
  /// Get padding for mobile screens
  static EdgeInsets getMobilePadding() {
    return const EdgeInsets.all(mobileGridPadding);
  }
  
  /// Get horizontal padding for mobile screens
  static EdgeInsets getMobileHorizontalPadding() {
    return const EdgeInsets.symmetric(horizontal: mobileGridPadding);
  }
  
  /// Get vertical padding for mobile screens
  static EdgeInsets getMobileVerticalPadding() {
    return const EdgeInsets.symmetric(vertical: mobileGridPadding);
  }
  
  /// Responsive layout builder that switches between mobile and desktop based on admin status
  static Widget buildResponsiveLayout({
    required BuildContext context,
    required bool isAdmin,
    required Widget mobileLayout,
    required Widget desktopLayout,
  }) {
    if (isAdmin) {
      // Admin always gets desktop layout
      return desktopLayout;
    } else {
      // Users always get mobile layout
      return mobileLayout;
    }
  }
  
  /// Get screen type for layout decisions
  static DeviceScreenType getEffectiveScreenType({required bool isAdmin}) {
    if (isAdmin) {
      return DeviceScreenType.desktop; // Force desktop for admin
    } else {
      return DeviceScreenType.mobile; // Force mobile for users
    }
  }
  
  /// Get effective viewport width for mobile container
  static double getEffectiveViewportWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < mobileViewportMinWidth) {
      return screenWidth; // Use full width on very small screens
    }
    return mobileViewportWidth.clamp(mobileViewportMinWidth, screenWidth);
  }
  
  /// Check if screen needs mobile viewport wrapper
  static bool shouldUseViewportWrapper(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth > mobileViewportWidth;
  }
  
  /// Get mobile viewport decoration
  static BoxDecoration getMobileViewportDecoration() {
    return BoxDecoration(
      color: Colors.white,
      // Removed borderRadius for clean rectangular appearance
      boxShadow: [
        BoxShadow(
          color: mobileViewportShadowColor,
          blurRadius: mobileViewportElevation,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}