import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pharmapath_app/controllers/favorites_controller.dart';
import 'package:pharmapath_app/core/storage.dart';
import 'package:pharmapath_app/data/app_database.dart';
import 'package:pharmapath_app/data/medicine_dao.dart';
import 'package:pharmapath_app/models/medicine.dart';
import 'package:pharmapath_app/services/image_api_client.dart';
import 'package:pharmapath_app/services/medicine_api.dart';
import 'package:pharmapath_app/services/sync_service.dart';
import 'package:pharmapath_app/views/detail_view.dart';

class _NoApi extends MedicineApi {
  _NoApi() : super(baseUrl: () => 'http://fake');
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppStorage.write(AppStorage.kUiLanguage, null));
  tearDown(() => AppStorage.write(AppStorage.kUiLanguage, null));

  group('Alternatives Sheet Tap Test', () {
    late AppDatabase db;
    late MedicineDao dao;
    late _NoApi api;

    const med1 = Medicine(
      id: 101,
      brandName: 'Napa',
      genericName: 'Paracetamol',
      dosageForm: 'Tablet',
      strength: '500 mg',
      company: 'Beximco',
      unitPrice: '1.20',
      detailLoaded: true,
      dosageAndAdministration: '1 tablet daily',
    );

    const med2 = Medicine(
      id: 102,
      brandName: 'Ace',
      genericName: 'Paracetamol',
      dosageForm: 'Tablet',
      strength: '500 mg',
      company: 'Square',
      unitPrice: '1.20',
      detailLoaded: true,
      dosageAndAdministration: '1 tablet daily',
    );

    setUp(() async {
      db = await AppDatabase.openForTesting();
      await db.upsertDetailBatch([med1, med2]);
      dao = MedicineDao(db);
      api = _NoApi();
      Get.put<MedicineDao>(dao);
      Get.put<SyncService>(SyncService(api: api, db: db, dao: dao));
      Get.put<FavoritesController>(FavoritesController(dao));
      Get.put<ImageApiClient>(ImageApiClient());
    });

    tearDown(() async {
      Get.reset();
      api.dispose();
      await db.close();
    });

    testWidgets('Tapping alternative when MedicineDetailView was pushed via Get.to', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // Home is a dummy search view or page
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Get.to(() => const MedicineDetailView(medicine: med1));
                },
                child: const Text('Search Result: Napa'),
              ),
            ),
          ),
        ),
      );
      await settle(tester);

      // User taps search result Napa
      await tester.tap(find.text('Search Result: Napa'));
      await settle(tester);

      // Verify Napa is open
      expect(find.text('Napa'), findsWidgets);

      // Find and tap 'বিকল্প ওষুধ'
      final altBtn = find.text('বিকল্প ওষুধ');
      expect(altBtn, findsOneWidget);
      await tester.tap(altBtn);
      await settle(tester);

      // Verify bottom sheet is open and Ace is shown
      expect(find.text('Ace'), findsOneWidget);

      // Tap Ace
      await tester.tap(find.text('Ace'));
      await settle(tester);

      expect(Get.currentRoute, '/MedicineDetailView');
      final detailViews = tester.widgetList<MedicineDetailView>(
        find.byType(MedicineDetailView, skipOffstage: false),
      ).toList();
      expect(detailViews.length, 2);
      expect(detailViews.any((v) => v.medicine.brandName == 'Ace'), isTrue);
    });
  });
}
