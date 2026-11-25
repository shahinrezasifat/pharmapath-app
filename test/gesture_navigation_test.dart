import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmapath_app/core/navigation_mode.dart';

void main() {
  group('GestureNavigation Automatic Detection & Layout Spacing', () {
    testWidgets('accurately detects gesture-navigation mode (bottom inset > 0)',
        (tester) async {
      bool? detectedGestureMode;
      double? detectedHeight;
      double? detectedSpacing;
      double? detectedShellPadding;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              viewPadding: EdgeInsets.only(bottom: 24),
              padding: EdgeInsets.only(bottom: 24),
            ),
            child: Builder(
              builder: (context) {
                detectedGestureMode =
                    GestureNavigation.hasGestureNavigation(context);
                detectedHeight = GestureNavigation.gestureBarHeight(context);
                detectedSpacing = GestureNavigation.bottomSpacing(
                  context,
                  safeMarginAboveGesture: 10,
                  fullscreenMargin: 14,
                );
                detectedShellPadding =
                    GestureNavigation.shellContentBottomPadding(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      // Gesture buttons are active (24dp)
      expect(detectedGestureMode, isTrue);
      expect(detectedHeight, 24.0);
      // Spacing must be gesture height + safe margin (24 + 10 = 34dp)
      expect(detectedSpacing, 34.0);
      // Shell content clearance = navBarHeight (78) + spacing (34) + buffer (16) = 128dp
      expect(detectedShellPadding, 128.0);
    });

    testWidgets('accurately detects 3-button navigation mode (bottom inset = 48)',
        (tester) async {
      bool? detectedGestureMode;
      double? detectedSpacing;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              viewPadding: EdgeInsets.only(bottom: 48),
            ),
            child: Builder(
              builder: (context) {
                detectedGestureMode =
                    GestureNavigation.hasGestureNavigation(context);
                detectedSpacing = GestureNavigation.bottomSpacing(
                  context,
                  safeMarginAboveGesture: 8,
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(detectedGestureMode, isTrue);
      // 48 + 8 = 56dp
      expect(detectedSpacing, 56.0);
    });

    testWidgets('accurately detects full-screen mode (bottom inset = 0)',
        (tester) async {
      bool? detectedGestureMode;
      double? detectedHeight;
      double? detectedSpacing;
      double? detectedShellPadding;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              viewPadding: EdgeInsets.zero,
              padding: EdgeInsets.zero,
            ),
            child: Builder(
              builder: (context) {
                detectedGestureMode =
                    GestureNavigation.hasGestureNavigation(context);
                detectedHeight = GestureNavigation.gestureBarHeight(context);
                detectedSpacing = GestureNavigation.bottomSpacing(
                  context,
                  safeMarginAboveGesture: 10,
                  fullscreenMargin: 14,
                );
                detectedShellPadding =
                    GestureNavigation.shellContentBottomPadding(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      // In full-screen mode, bottom inset is 0
      expect(detectedGestureMode, isFalse);
      expect(detectedHeight, 0.0);
      // Spacing falls back to the clean fullscreen margin (14dp)
      expect(detectedSpacing, 14.0);
      // Shell content clearance = navBarHeight (78) + spacing (14) + buffer (16) = 108dp
      expect(detectedShellPadding, 108.0);
    });

    testWidgets('SafeBottom widget wraps child with safe margin in gesture mode',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              viewPadding: EdgeInsets.only(bottom: 20),
            ),
            child: Scaffold(
              body: SafeBottom(
                safeMarginAboveGesture: 12,
                child: Text('Safe Content'),
              ),
            ),
          ),
        ),
      );

      final paddingFinder = find.byType(Padding);
      expect(paddingFinder, findsWidgets);

      final paddingWidget = tester.widget<Padding>(paddingFinder.first);
      final edgeInsets = paddingWidget.padding as EdgeInsets;
      // 20 + 12 = 32dp
      expect(edgeInsets.bottom, 32.0);
    });

    testWidgets('SafeBottom widget wraps child with fullscreenMargin when inset is 0',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              viewPadding: EdgeInsets.zero,
            ),
            child: Scaffold(
              body: SafeBottom(
                fullscreenMargin: 18,
                child: Text('Fullscreen Content'),
              ),
            ),
          ),
        ),
      );

      final paddingFinder = find.byType(Padding);
      expect(paddingFinder, findsWidgets);

      final paddingWidget = tester.widget<Padding>(paddingFinder.first);
      final edgeInsets = paddingWidget.padding as EdgeInsets;
      expect(edgeInsets.bottom, 18.0);
    });
  });
}
