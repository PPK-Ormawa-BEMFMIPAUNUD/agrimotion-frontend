import 'package:flutter/material.dart';
import 'package:agrimotion/core/constants/app_constants.dart';

/// Responsive layout builder that renders different widgets
/// based on screen width breakpoints.
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
          return desktop;
        } else if (constraints.maxWidth >= AppConstants.tabletBreakpoint) {
          return tablet ?? desktop;
        }
        return mobile;
      },
    );
  }

  /// Returns true if current width qualifies as desktop.
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppConstants.desktopBreakpoint;

  /// Returns true if current width qualifies as tablet.
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= AppConstants.tabletBreakpoint &&
        width < AppConstants.desktopBreakpoint;
  }

  /// Returns true if current width qualifies as mobile.
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppConstants.tabletBreakpoint;
}
