import 'package:flutter/material.dart';
import 'mobile_layout_utils.dart';

/// Wrapper component that constrains user screens to mobile viewport width
/// with proper visual styling to simulate mobile app experience on desktop
class MobileViewportWrapper extends StatelessWidget {
  final Widget child;
  final bool forceFullWidth;
  
  const MobileViewportWrapper({
    super.key,
    required this.child,
    this.forceFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    // If forceFullWidth is true, return child without wrapper (for admin screens)
    if (forceFullWidth) {
      return child;
    }

    final shouldUseWrapper = MobileLayoutUtils.shouldUseViewportWrapper(context);
    final effectiveWidth = MobileLayoutUtils.getEffectiveViewportWidth(context);

    // If screen is smaller than mobile viewport width, use full width
    if (!shouldUseWrapper) {
      return child;
    }

    // Create mobile viewport container for larger screens
    return Scaffold(
      backgroundColor: MobileLayoutUtils.mobileViewportBackgroundColor,
      body: Center(
        child: Container(
          width: effectiveWidth,
          height: MediaQuery.of(context).size.height,
          decoration: MobileLayoutUtils.getMobileViewportDecoration(),
          clipBehavior: Clip.none, // Changed from antiAlias since no rounded corners
          child: child,
        ),
      ),
    );
  }
}

/// Simplified wrapper for content that needs mobile viewport constraints
/// without full screen scaffolding
class MobileContentConstraint extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  
  const MobileContentConstraint({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = MobileLayoutUtils.getEffectiveViewportWidth(context);
    
    return Center(
      child: Container(
        width: effectiveWidth,
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Mobile-aware SafeArea that works within viewport constraints
class MobileSafeArea extends StatelessWidget {
  final Widget child;
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;
  
  const MobileSafeArea({
    super.key,
    required this.child,
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: child,
    );
  }
}