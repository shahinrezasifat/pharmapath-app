import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ai_doctor_module/ai_doctor.dart';
import 'package:pharmapath_app/controllers/navigation_controller.dart';
import 'package:pharmapath_app/views/shell_view.dart';

void main() {
  setUp(() {
    Get.reset();
    Get.put(NavigationController());
  });

  tearDown(() {
    Get.reset();
  });

  final mockPages = [
    const Center(child: Text('Page 0: ঔষধ')),
    const Center(child: Text('Page 1: অনুসন্ধান')),
    const Center(child: Text('Page 2: শেখা')),
    const Center(child: Text('Page 3: রোগী')),
    const Center(child: Text('Page 4: প্রিয়')),
    const Center(child: Text('Page 5: সেটিংস')),
  ];

  testWidgets(
    'Bottom navigation bar is pinned at bottom and navigates cleanly',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        GetMaterialApp(home: ShellView(pages: mockPages)),
      );
      await tester.pumpAndSettle();

      final shellScaffold = tester.widget<Scaffold>(
        find.byType(Scaffold).first,
      );
      // The bar is a floating overlay, so the body extends to the screen edge.
      expect(shellScaffold.extendBody, isTrue);

      // 1. Initial State: active tab label is 'ঔষধ'
      expect(find.text('ঔষধ'), findsWidgets);
      expect(find.text('Page 0: ঔষধ'), findsOneWidget);

      // Unselected items do not render text label in the navigation bar
      expect(find.text('শেখা'), findsNothing);
      expect(find.text('রোগী'), findsNothing);
      expect(find.text('প্রিয়'), findsNothing);
      expect(find.text('সেটিংস'), findsNothing);

      // 2. Bar position: a 60dp pill with 14dp bottom margin on an 800dp
      // screen -> top 726, bottom 786. It never sits mid-screen.
      final barContainer = find.byType(BackdropFilter);
      expect(barContainer, findsWidgets);
      final navRect = tester.getRect(barContainer.first);
      expect(
        navRect.top,
        closeTo(726.0, 5.0),
        reason: 'Nav bar must be at bottom, not in the middle',
      );
      expect(navRect.bottom, closeTo(786.0, 5.0));
      // Content flows underneath the floating bar instead of stopping above
      // a reserved docked band.
      expect(
        tester.getRect(find.byType(IndexedStack)).bottom,
        greaterThan(navRect.top),
      );

      // 3. Switch to 'শেখা' tab
      final learnTab = find.byTooltip('শেখা');
      expect(learnTab, findsOneWidget);
      await tester.tap(learnTab);
      await tester.pumpAndSettle();

      expect(find.text('শেখা'), findsWidgets);
      expect(find.text('Page 2: শেখা'), findsOneWidget);
      expect(find.text('Page 0: ঔষধ'), findsNothing);

      // 4. Switch to 'রোগী' tab
      final patientTab = find.byTooltip('রোগী');
      expect(patientTab, findsOneWidget);
      await tester.tap(patientTab);
      await tester.pumpAndSettle();

      expect(find.text('রোগী'), findsWidgets);
      expect(find.text('Page 3: রোগী'), findsOneWidget);

      // 5. Switch to 'প্রিয়' tab
      final favTab = find.byTooltip('প্রিয়');
      expect(favTab, findsOneWidget);
      await tester.tap(favTab);
      await tester.pumpAndSettle();

      expect(find.text('প্রিয়'), findsWidgets);
      expect(find.text('Page 4: প্রিয়'), findsOneWidget);

      // 6. Switch to 'সেটিংস' tab
      final settingsTab = find.byTooltip('সেটিংস');
      expect(settingsTab, findsOneWidget);
      await tester.tap(settingsTab);
      await tester.pumpAndSettle();

      expect(find.text('সেটিংস'), findsWidgets);
      expect(find.text('Page 5: সেটিংস'), findsOneWidget);

      // 7. Tap back to 'ঔষধ' tab
      final medicineTab = find.byTooltip('ঔষধ');
      expect(medicineTab, findsOneWidget);
      await tester.tap(medicineTab);
      await tester.pumpAndSettle();

      expect(find.text('ঔষধ'), findsWidgets);
      expect(find.text('Page 0: ঔষধ'), findsOneWidget);
    },
  );

  testWidgets('Bottom navigation bar on narrow screen (360 width)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(GetMaterialApp(home: ShellView(pages: mockPages)));
    await tester.pumpAndSettle();

    final barContainer = find.byType(BackdropFilter);
    final navRect = tester.getRect(barContainer.first);
    expect(navRect.top, closeTo(666.0, 5.0));
    expect(navRect.bottom, closeTo(726.0, 5.0));
    expect(
      tester.getRect(find.byType(IndexedStack)).bottom,
      greaterThan(navRect.top),
    );

    // Tap through tabs without any layout overflow
    for (final name in ['শেখা', 'রোগী', 'প্রিয়', 'সেটিংস', 'ঔষধ']) {
      await tester.tap(find.byTooltip(name));
      await tester.pumpAndSettle();
      expect(find.text(name), findsWidgets);
    }
  });

  testWidgets(
    'Bottom navigation bar with system gesture insets (padding bottom = 24)',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewPadding();
        tester.view.resetPadding();
      });

      await tester.pumpWidget(
        GetMaterialApp(home: ShellView(pages: mockPages)),
      );
      await tester.pumpAndSettle();

      final barContainer = find.byType(BackdropFilter);
      final navRect = tester.getRect(barContainer.first);
      // Bottom margin = 14 + 24 = 38, pill height = 60.
      // 800 - 38 = 762 (bottom), 762 - 60 = 702 (top).
      expect(navRect.bottom, closeTo(762.0, 5.0));
      expect(navRect.top, closeTo(702.0, 5.0));
      expect(
        tester.getRect(find.byType(IndexedStack)).bottom,
        greaterThan(navRect.top),
      );
    },
  );

  testWidgets(
    'AiDoctorHomePage FloatingActionButton position relative to nav bar',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewPadding();
        tester.view.resetPadding();
      });

      await tester.pumpWidget(
        const GetMaterialApp(
          home: ShellView(
            pages: [
              AiDoctorHomePage(),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);
      final fabRect = tester.getRect(fabFinder);
      final barContainer = find.byType(BackdropFilter);
      final navRect = tester.getRect(barContainer.first);

      // Verify that the FAB is strictly ABOVE the floating navigation bar!
      expect(
        fabRect.bottom,
        lessThanOrEqualTo(navRect.top),
        reason: 'FAB bottom (${fabRect.bottom}) must be at or above nav bar top (${navRect.top})',
      );
    },
  );
}
