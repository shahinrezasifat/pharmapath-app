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

  group('DetailView Clinical Sections Tests', () {
    late AppDatabase db;
    late MedicineDao dao;
    late _NoApi api;

    const testMed = Medicine(
      id: 7777,
      brandName: 'Napa Test',
      genericName: 'Paracetamol',
      dosageForm: 'Tablet',
      strength: '500 mg',
      company: 'Beximco',
      unitPrice: '1.20',
      detailLoaded: true,
      indications: 'জ্বর এবং ব্যথায় নির্দেশিত।',
      dosageAndAdministration: '১-২টি ট্যাবলেট প্রতি ৪-৬ ঘণ্টা পর পর।',
      precautionsAndWarnings: 'লিভার বা কিডনির সমস্যা থাকলে সতর্ক থাকুন।',
      overdoseEffects: 'অতিরিক্ত মাত্রায় গ্রহণ করলে অবিলম্বে হাসপাতালে যান।',
    );

    setUp(() async {
      db = await AppDatabase.openForTesting();
      await db.upsertDetailBatch([testMed]);
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

    testWidgets(
      'overdose_effects does not render as duplicate dosage card under সতর্কতা ও সাবধানতা',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 4000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          const GetMaterialApp(
            home: MedicineDetailView(medicine: testMed),
          ),
        );

        await settle(tester);

        // Top action button for dosage guidance is present exactly once
        expect(find.text('ডোজ ও ব্যবহারবিধি'), findsOneWidget);

        // Precautions section is present
        expect(find.text('সতর্কতা ও সাবধানতা'), findsOneWidget);

        // Overdose effects section is present with its own heading
        expect(find.text('অতিরিক্ত ডোজের প্রভাব'), findsOneWidget);
        expect(
          find.textContaining('অতিরিক্ত মাত্রায় গ্রহণ করলে অবিলম্বে হাসপাতালে যান'),
          findsOneWidget,
        );

        // The duplicate slider/calculator header must NOT exist in the clinical sections
        expect(find.text('বয়সভিত্তিক প্রয়োগমাত্রা ও ক্যালকুলেটর'), findsNothing);
      },
    );
  });
}
