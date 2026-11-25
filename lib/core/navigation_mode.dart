import 'package:flutter/material.dart';

/// Centralized utility and automatic detection logic for gesture navigation
/// buttons and full-screen modes on mobile devices.
class GestureNavigation {
  GestureNavigation._();

  /// Detects whether the device currently has gesture navigation buttons or
  /// system navigation buttons enabled at the bottom of the screen.
  ///
  /// In gesture-navigation mode (and 3-button navigation mode), the operating
  /// system reserves a bottom inset (`viewPadding.bottom > 0`), typically:
  /// - 16–28dp for Android gesture navigation bar / pill
  /// - 34dp for iOS home indicator bar
  /// - 48dp for Android 3-button navigation bar
  ///
  /// In full-screen mode (immersive sticky, edge-to-edge with hidden nav, or
  /// desktop/web platforms without gesture buttons), this inset is 0.
  static bool hasGestureNavigation(BuildContext context) {
    return gestureBarHeight(context) > 0;
  }

  /// Returns the height of the gesture navigation bar / system buttons.
  /// Checks `View.of(context).viewPadding.bottom` first so nested Scaffolds with
  /// extendBody do not mask the real hardware system window insets.
  static double gestureBarHeight(BuildContext context) {
    try {
      final view = View.of(context);
      final pixelRatio = view.devicePixelRatio;
      if (pixelRatio > 0) {
        final logical = view.viewPadding.bottom / pixelRatio;
        if (logical > 0) return logical;
        final logicalPad = view.padding.bottom / pixelRatio;
        if (logicalPad > 0) return logicalPad;
      }
    } catch (_) {}
    final viewPad = MediaQuery.viewPaddingOf(context).bottom;
    if (viewPad > 0) return viewPad;
    return MediaQuery.paddingOf(context).bottom;
  }

  /// Calculates the safe bottom margin to ensure interface elements start
  /// immediately above the gesture buttons:
  /// - When gesture navigation is active: [gestureBarHeight] + [safeMarginAboveGesture]
  ///   so content and buttons start cleanly above the gesture buttons with a safe gap.
  /// - When in full-screen mode (no gesture buttons): [fullscreenMargin].
  static double bottomSpacing(
    BuildContext context, {
    double safeMarginAboveGesture = 10.0,
    double fullscreenMargin = 14.0,
  }) {
    final gestureHeight = gestureBarHeight(context);
    if (gestureHeight > 0) {
      return gestureHeight + safeMarginAboveGesture;
    }
    return fullscreenMargin;
  }

  /// Height of the floating pill itself. Kept in sync with `height: 60` in
  /// `shell_view.dart`; the shell overlays the bar instead of reserving a band.
  static const double navBarHeight = 60.0;

  /// Bottom margin of the pill: 14dp plus the system gesture inset.
  static const double navBarBottomMargin = 14.0;

  /// Distance from the screen bottom to the top edge of the pill.
  static double floatingNavBarHeight(BuildContext context) {
    return navBarHeight + navBarBottomMargin + gestureBarHeight(context);
  }

  /// Safe bottom margin for floating action buttons or bottom-floating elements
  /// on pages hosted inside ShellView, so they float cleanly above the navigation bar.
  static double fabBottomSpacing(BuildContext context, {double gapAboveBar = 14.0}) {
    return floatingNavBarHeight(context) + gapAboveBar;
  }

  /// Distance from the screen bottom to the top of the pill, without the
  /// gesture inset. Useful for nested Scaffolds that already account for the
  /// system inset themselves.
  static double get floatingNavBarHeightWithoutInset =>
      navBarHeight + navBarBottomMargin;

  /// Total bottom clearance required for scrollable views (lists, grids) when
  /// hosted in the main shell with the floating bottom navigation bar.
  /// Ensures the last scrollable item scrolls comfortably above the navigation bar
  /// and gesture buttons in both full-screen and gesture-navigation modes.
  static double shellContentBottomPadding(
    BuildContext context, {
    double additionalBuffer = 20.0,
  }) {
    return floatingNavBarHeight(context) + additionalBuffer;
  }

  /// Total bottom clearance for standalone pages without the shell nav bar
  /// (e.g. detail view, lesson view) to ensure content is never covered by gesture buttons.
  static double pageBottomPadding(
    BuildContext context, {
    double additionalBuffer = 20.0,
  }) {
    return bottomSpacing(context) + additionalBuffer;
  }
}

/// A convenience widget that applies automatic safe bottom margins
/// above gesture buttons when present, or clean margins in full-screen mode.
class SafeBottom extends StatelessWidget {
  const SafeBottom({
    super.key,
    required this.child,
    this.safeMarginAboveGesture = 10.0,
    this.fullscreenMargin = 14.0,
    this.horizontal = 0.0,
    this.top = 0.0,
  });

  final Widget child;
  final double safeMarginAboveGesture;
  final double fullscreenMargin;
  final double horizontal;
  final double top;

  @override
  Widget build(BuildContext context) {
    final bottom = GestureNavigation.bottomSpacing(
      context,
      safeMarginAboveGesture: safeMarginAboveGesture,
      fullscreenMargin: fullscreenMargin,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom),
      child: child,
    );
  }
}
