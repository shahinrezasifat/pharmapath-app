import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmapath_app/views/medical_terms_view.dart';

void main() {
  testWidgets('medical glossary supports English search and category filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MedicalTermsView()));
    await tester.pumpAndSettle();

    expect(find.text('চিকিৎসা পরিভাষা'), findsOneWidget);
    expect(find.text('৪০টি পরিভাষা · সহজ বাংলা ব্যাখ্যা'), findsOneWidget);
    expect(find.text('Antibiotic'), findsOneWidget);
    expect(find.text('Anemia'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Anemia');
    await tester.pumpAndSettle();

    expect(find.text('Anemia'), findsNWidgets(2));
    expect(find.text('Antibiotic'), findsNothing);
    expect(find.text('১টি পরিভাষা'), findsOneWidget);

    await tester.tap(find.text('ফিল্টার মুছুন'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is ChoiceChip &&
            widget.label is Text &&
            (widget.label as Text).data == 'Medicines & safety',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Antibiotic'), findsOneWidget);
    expect(find.text('Anemia'), findsNothing);
  });
}
