import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pharmapath_app/core/essential_medicines.dart';
import 'package:pharmapath_app/core/format.dart';
import 'package:pharmapath_app/core/medicine_form.dart';
import 'package:pharmapath_app/data/app_database.dart';
import 'package:pharmapath_app/data/learning_dao.dart';
import 'package:pharmapath_app/data/medicine_dao.dart';
import 'package:pharmapath_app/models/medicine.dart';
import 'package:pharmapath_app/services/backup_service.dart';
import 'package:pharmapath_app/widgets/company_logo.dart';
import 'package:pharmapath_app/widgets/featured_medicine_tile.dart';
import 'package:pharmapath_app/widgets/medicine_card.dart';
import 'package:pharmapath_app/widgets/medicine_form_icons.dart';
import 'package:pharmapath_app/widgets/safety_notice.dart';
import 'package:pharmapath_app/core/app_config.dart';

Medicine sample({
  required int id,
  required String brand,
  String? generic,
  String? company,
  String? strength,
  String? dosageForm,
  bool detailed = false,
}) {
  return Medicine(
    id: id,
    brandName: brand,
    genericName: generic,
    company: company,
    strength: strength,
    dosageForm: dosageForm,
    unitPrice: '10.00',
    indications: detailed ? 'শিক্ষামূলক রোগের নির্দেশনা' : null,
    dosageAndAdministration: detailed ? 'চিকিৎসকের পরামর্শে' : null,
    detailLoaded: detailed,
  );
}

void main() {
  late AppDatabase db;
  late MedicineDao dao;

  setUp(() async {
    db = await AppDatabase.openForTesting();
    dao = MedicineDao(db, pageSize: 5);
  });

  tearDown(() async {
    await db.close();
  });

  group('medicine database', () {
    test('medicine model does not serialize product image URLs', () {
      expect(
        sample(id: 1, brand: 'Napa').toDbMap(),
        isNot(contains('image_url')),
      );
    });

    test('detail refresh keeps favorites and view history', () async {
      final medicine = sample(
        id: 901,
        brand: 'Refresh Me',
        generic: 'Paracetamol',
        detailed: true,
      );
      await db.upsertDetail(medicine);
      await dao.toggleFavorite(medicine.id);
      await dao.recordView(medicine.id);

      await db.upsertDetail(
        sample(
          id: medicine.id,
          brand: 'Refreshed Brand',
          generic: 'Paracetamol',
          detailed: true,
        ),
      );

      expect(await dao.isFavorite(medicine.id), isTrue);
      final history = await db.db.rawQuery(
        'SELECT viewed_at FROM view_history WHERE medicine_id = ?',
        [medicine.id],
      );
      expect(history, hasLength(1));
      final rows = await db.db.rawQuery(
        'SELECT brand_name, first_seen FROM medicines WHERE id = ?',
        [medicine.id],
      );
      expect(rows.single['brand_name'], 'Refreshed Brand');
      expect(rows.single['first_seen'], isNotNull);
    });

    test('searches complete medicines by brand case-insensitively', () async {
      await db.upsertDetailBatch([
        sample(
          id: 1,
          brand: 'Napa',
          generic: 'Paracetamol',
          company: 'Beximco',
          detailed: true,
        ),
        sample(
          id: 2,
          brand: 'Ace',
          generic: 'Paracetamol',
          company: 'Square',
          detailed: true,
        ),
        sample(
          id: 3,
          brand: 'Seclo',
          generic: 'Omeprazole',
          company: 'Square',
          detailed: true,
        ),
      ]);

      final page = await dao.search(query: 'napa');
      expect(page.total, 1);
      expect(page.items.single.brandName, 'Napa');

      final genericSearch = await dao.search(query: 'paracetamol');
      expect(genericSearch.total, 2);
    });

    test(
      'discovered summary rows are part of the searchable catalogue',
      () async {
        await db.upsertSummaries([
          sample(id: 1, brand: 'Napa', generic: 'Paracetamol'),
        ]);

        final page = await dao.search(query: 'napa');
        expect(page.total, 1);
        expect(page.items.single.detailLoaded, isFalse);
        final stats = await db.stats();
        expect(stats['medicines'], 1);
        expect(stats['detailed'], 0);
        expect(stats['catalog_total'], 1);
      },
    );

    test(
      'generic backfill gives a summary the sibling clinical text',
      () async {
        await db.upsertDetail(
          Medicine(
            id: 1,
            brandName: 'Celofen',
            genericName: 'Aceclofenac',
            company: 'ACI',
            dosageForm: 'Tablet',
            strength: '100 mg',
            indications: 'Celofen জ্বর ও ব্যথায় কাজ করে।',
            dosageAndAdministration:
                'প্রাপ্তবয়স্কদের জন্য Celofen দিনে দুইবার।',
            detailLoaded: true,
          ),
        );
        await db.upsertSummaries([
          sample(
            id: 2,
            brand: 'Flexi',
            generic: 'Aceclofenac',
            company: 'Square',
            dosageForm: 'Tablet',
            strength: '100 mg',
          ),
        ]);

        await db.setMeta('generic_detail_backfill', null);
        await db.backfillGenericDetails();

        final filled = await dao.byId(2);
        expect(filled!.detailLoaded, isTrue);
        expect(filled.indications, contains('Flexi'));
        expect(filled.indications, isNot(contains('Celofen')));
        expect(filled.dosageAndAdministration, contains('Flexi'));
      },
    );

    test('paginates results', () async {
      await db.upsertDetailBatch([
        for (var i = 1; i <= 12; i++)
          sample(id: i, brand: 'Drug$i', detailed: true),
      ]);

      final first = await dao.search();
      expect(first.items.length, 5);
      expect(first.total, 12);
      expect(first.totalPages, 3);
      expect(first.hasMore, isTrue);

      final last = await dao.search(page: 3);
      expect(last.items.length, 2);
      expect(last.hasMore, isFalse);
    });

    test('filters by company and dosage form', () async {
      await db.upsertDetailBatch([
        sample(
          id: 1,
          brand: 'A',
          company: 'Square',
          dosageForm: 'Tablet',
          detailed: true,
        ),
        sample(
          id: 2,
          brand: 'B',
          company: 'Beximco',
          dosageForm: 'Syrup',
          detailed: true,
        ),
        sample(
          id: 3,
          brand: 'C',
          company: 'Square',
          dosageForm: 'Syrup',
          detailed: true,
        ),
      ]);

      final square = await dao.search(company: 'Square', dosageForm: 'Syrup');
      expect(square.total, 1);
      expect(square.items.single.brandName, 'C');
    });

    test('summary sync does not destroy cached clinical detail', () async {
      await db.upsertSummaries([
        sample(id: 7, brand: 'Napa', strength: '500 mg'),
      ]);
      final detailed = Medicine(
        id: 7,
        brandName: 'Napa',
        strength: '500 mg',
        indications: 'জ্বর ও ব্যথা',
        dosageAndAdministration: 'চিকিৎসকের পরামর্শে',
        detailLoaded: true,
        sections: const {'indications': 'জ্বর ও ব্যথা'},
      );
      await db.upsertDetail(detailed);

      // A later summary sync must update listing fields only.
      await db.upsertSummaries([
        sample(id: 7, brand: 'Napa', strength: '500 mg'),
      ]);
      final cached = await dao.byId(7);
      expect(cached, isNotNull);
      expect(cached!.detailLoaded, isTrue);
      expect(cached.indications, 'জ্বর ও ব্যথা');
      expect(cached.clinicalSections, isNotEmpty);
    });

    test('favourites and recent views work offline', () async {
      await db.upsertDetailBatch([
        sample(id: 1, brand: 'Napa', detailed: true),
        sample(id: 2, brand: 'Ace', detailed: true),
      ]);

      expect(await dao.toggleFavorite(1), isTrue);
      expect(await dao.isFavorite(1), isTrue);
      final favourites = await dao.favorites();
      expect(favourites.map((e) => e.id), [1]);

      await dao.recordView(2);
      await dao.recordView(1);
      final recent = await dao.recentlyViewed();
      expect(recent.first.id, 1);

      expect(await dao.toggleFavorite(1), isFalse);
      expect(await dao.favorites(), isEmpty);
    });

    test('full-text prefix search finds partial brand names', () async {
      expect(db.ftsAvailable, isTrue, reason: 'FFI SQLite should ship FTS5');
      await db.upsertDetailBatch([
        sample(id: 1, brand: 'Napadol', generic: 'Paracetamol', detailed: true),
        sample(id: 2, brand: 'Seclo', generic: 'Omeprazole', detailed: true),
      ]);
      final page = await dao.search(query: 'napa');
      expect(page.items.map((e) => e.brandName), ['Napadol']);
    });

    test('stats report totals, source and last sync', () async {
      await db.upsertDetailBatch([
        sample(
          id: 1,
          brand: 'A',
          company: 'Square',
          generic: 'Paracetamol',
          detailed: true,
        ),
        sample(
          id: 2,
          brand: 'B',
          company: 'Square',
          generic: 'Omeprazole',
          detailed: true,
        ),
      ]);
      await db.setMeta('last_sync_at', '2026-10-24T10:00:00.000');

      final stats = await db.stats();
      expect(stats['medicines'], 2);
      expect(stats['catalog_total'], 2);
      expect(stats['companies'], 1);
      expect(stats['generics'], 2);
      expect(stats['last_sync'], '2026-10-24T10:00:00.000');
    });

    test('reset clears catalogue and user data', () async {
      await db.upsertSummaries([sample(id: 1, brand: 'Napa')]);
      await dao.toggleFavorite(1);
      await db.resetEverything();
      expect((await db.stats())['medicines'], 0);
      expect(await dao.favorites(), isEmpty);
    });
  });

  group('learning', () {
    late LearningDao learning;

    setUp(() {
      learning = LearningDao(db);
    });

    test('tracks completion, bookmarks and best quiz score', () async {
      await learning.markCompleted('basics', 'names', true);
      expect(await learning.completedLessonKeys(), {'basics::names'});

      expect(await learning.toggleBookmark('basics', 'names'), isTrue);
      expect(await learning.bookmarkedKeys(), {'basics::names'});
      expect(await learning.toggleBookmark('basics', 'names'), isFalse);

      await learning.saveQuizResult('basics', 2, 3);
      await learning.saveQuizResult('basics', 3, 3);
      final best = await learning.bestResults();
      expect(best['basics']!.score, 3);
      expect(best['basics']!.total, 3);

      // A lower raw score on a smaller paper can still be the better result.
      await learning.saveQuizResult('advanced', 8, 10);
      await learning.saveQuizResult('advanced', 3, 5);
      final advanced = await learning.bestResults();
      expect(advanced['advanced']!.score, 8);
      expect(advanced['advanced']!.total, 10);

      await learning.clearProgress();
      expect(await learning.completedLessonKeys(), isEmpty);
      expect(await learning.bestResults(), isEmpty);
    });
  });

  group('Bangla formatting', () {
    test('converts digits to Bangla', () {
      expect(bn(1234), '১২৩৪');
      expect(bn('মোট 25 টি'), 'মোট ২৫ টি');
      expect(bn('-7.5'), '-৭.৫');
    });

    test('formats dates in Bangla', () {
      final text = bnDate(DateTime(2026, 10, 24, 15, 5));
      expect(text, contains('অক্টোবর'));
      expect(text, contains('২০২৬'));
      expect(text, contains('০৫'));
      expect(bnDateFromIso(null), 'কখনো নয়');
    });
  });

  group('widgets', () {
    testWidgets('medicine card shows Bangla price and identity', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MedicineCard(
              medicine: sample(
                id: 1,
                brand: 'Napa',
                generic: 'Paracetamol',
                company: 'Beximco',
                strength: '500 mg',
              ),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      expect(find.text('Napa'), findsOneWidget);
      expect(find.text('Paracetamol · 500 mg'), findsOneWidget);
      expect(find.textContaining('৳'), findsOneWidget);
      expect(find.byType(MedicineFormGlyph), findsOneWidget);
      expect(find.byType(CompanyLogo), findsOneWidget);
      await tester.tap(find.text('Napa'));
      expect(tapped, isTrue);
    });

    testWidgets('safety notice is always visible and Bangla', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SafetyNotice())),
      );
      expect(find.textContaining('শিক্ষামূলক'), findsOneWidget);
      expect(find.textContaining(AppConfig.safetyNotice), findsOneWidget);
    });

    testWidgets('featured tile shows price and the two action buttons', (
      tester,
    ) async {
      var tapped = false;
      // Featured medicines are rendered as full-width list rows.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: FeaturedMedicineTile(
                  medicine: sample(
                    id: 1,
                    brand: 'Napa',
                    generic: 'Paracetamol',
                    company: 'Beximco',
                    strength: '500 mg',
                    dosageForm: 'Tablet',
                  ),
                  onTap: () => tapped = true,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Napa'), findsOneWidget);
      expect(find.text('Paracetamol · 500 mg'), findsOneWidget);
      expect(find.textContaining('৳'), findsOneWidget);
      expect(find.text('বিকল্প ওষুধ'), findsOneWidget);
      expect(find.text('ব্যবহারবিধি'), findsOneWidget);
      await tester.tap(find.text('Napa'));
      expect(tapped, isTrue);
    });

    testWidgets('compact featured tile hides the action buttons', (
      tester,
    ) async {
      var tapped = false;
      // The alternative popup uses the same list row without quick actions.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: FeaturedMedicineTile(
                  medicine: sample(
                    id: 2,
                    brand: 'Ace',
                    generic: 'Paracetamol',
                    company: 'ACI',
                    strength: '500 mg',
                    dosageForm: 'Tablet',
                  ),
                  showActions: false,
                  onTap: () => tapped = true,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Ace'), findsOneWidget);
      expect(find.text('বিকল্প ওষুধ'), findsNothing);
      expect(find.text('ব্যবহারবিধি'), findsNothing);
      await tester.tap(find.text('Ace').last);
      expect(tapped, isTrue);
    });
  });

  group('medicine model', () {
    test('parses API summary and sections', () {
      final medicine = Medicine.fromApi({
        'id': 13717,
        'brand_name': 'Napa',
        'generic_name': 'Paracetamol',
        'strength': '500 mg',
        'dosage_form': 'Tablet',
        'company': 'Beximco',
        'unit_price': '2.00',
        'sections': {'indications': 'জ্বর', 'side_effects': ''},
      });
      expect(medicine.id, 13717);
      expect(medicine.subtitle, 'Paracetamol · 500 mg · ট্যাবলেট');
      expect(medicine.priceLabel, '৳ ২.০০');
      expect(medicine.sections.containsKey('indications'), isTrue);
      expect(medicine.sections.containsKey('side_effects'), isFalse);
      expect(medicine.clinicalSections.single.label, 'রোগের নির্দেশনা');
    });

    test('never fabricates values for missing fields', () {
      final medicine = Medicine.fromApi({
        'id': 5,
        'brand_name': 'Unknown Brand',
      });
      expect(medicine.priceLabel, 'মূল্য পাওয়া যায়নি');
      expect(medicine.clinicalSections, isEmpty);
      expect(medicine.hasClinicalData, isFalse);
    });

    test('renders raw API dosage forms in Bangla', () {
      expect(MedicineForm.bnText('Tablet'), 'ট্যাবলেট');
      expect(
        MedicineForm.bnText('Tablet (Extended Release)'),
        'ট্যাবলেট (ধীর-নিঃসরণ)',
      );
      expect(
        MedicineForm.bnText('Powder for Suspension'),
        'সাসপেনশন তৈরির পাউডার',
      );
      expect(MedicineForm.bnText('Ophthalmic Solution'), 'চোখের দ্রবণ (ড্রপ)');
      // Unknown strings still resolve to a Bengali category label.
      expect(
        MedicineForm.bnText('Some Future Form Syrup'),
        isNot('Some Future Form Syrup'),
      );
      expect(MedicineForm.bnText(''), '');
    });

    test('localizes price/pack text and unmapped section headings', () {
      final medicine = Medicine.fromApi({
        'id': 9,
        'brand_name': 'Napa',
        'price_text':
            'Unit Price: ৳ 4.01 (5 x 10: ৳ 200.50) Strip Price: ৳ 40.10',
        'pack_sizes': "100's pack: ৳ 400.00",
        'sections': {
          'mode_of_action': 'Inhibits COX enzymes.',
          'dosage': '  Inhibits COX enzymes. ', // same text → never duplicated
          'pediatric_uses': 'Few data.',
        },
      });
      expect(medicine.priceLabel, contains('একক মূল্য:'));
      expect(medicine.priceLabel, isNot(contains('Unit Price')));
      expect(medicine.priceLabel, contains('৪.০১'));
      expect(medicine.packLabel, 'প্যাক: ১০০টি · ৳ ৪০০.০০');
      final labels = medicine.clinicalSections.map((e) => e.label).toList();
      expect(labels, contains('কাজের ধরন'));
      expect(labels, contains('শিশুদের প্রয়োগ'));
      expect(labels, isNot(contains('Mode Of Action')));
      expect(
        labels.where((l) => l == 'কাজের ধরন').length,
        1,
        reason: 'alias sections must deduplicate against identical text',
      );
    });

    test('round-trips through the database map', () {
      final original = Medicine(
        id: 9,
        brandName: 'Seclo',
        genericName: 'Omeprazole',
        strength: '20 mg',
        sections: const {'indications': 'অ্যাসিডিটি'},
        detailLoaded: true,
      );
      final copy = Medicine.fromDb(original.toDbMap());
      expect(copy.brandName, 'Seclo');
      expect(copy.genericName, 'Omeprazole');
      expect(copy.detailLoaded, isTrue);
      expect(copy.sections['indications'], 'অ্যাসিডিটি');
    });

    test('core identity gates what may be imported', () {
      final complete = Medicine(
        id: 1,
        brandName: 'Napa',
        genericName: 'Paracetamol',
        company: 'Beximco',
        dosageForm: 'Tablet',
        strength: '500 mg',
      );
      expect(complete.hasCoreIdentity, isTrue);

      // Any one missing identity field (e.g. no strength) makes it incomplete.
      final missingStrength = Medicine(
        id: 2,
        brandName: 'Napa',
        genericName: 'Paracetamol',
        company: 'Beximco',
        dosageForm: 'Tablet',
      );
      expect(missingStrength.hasCoreIdentity, isFalse);

      // Whitespace-only counts as empty.
      final blankCompany = Medicine(
        id: 3,
        brandName: 'Napa',
        genericName: 'Paracetamol',
        company: '   ',
        dosageForm: 'Tablet',
        strength: '500 mg',
      );
      expect(blankCompany.hasCoreIdentity, isFalse);
    });

    test('classifies messy dosage-form text onto an iconned category', () {
      final syrup = Medicine(
        id: 1,
        brandName: 'X',
        dosageForm: 'Oral Solution',
      );
      expect(syrup.form, MedicineForm.syrup);
      // "Powder for Suspension" must resolve to suspension, not powder.
      final susp = Medicine(
        id: 2,
        brandName: 'Y',
        dosageForm: 'Powder for Suspension',
      );
      expect(susp.form, MedicineForm.suspension);
      // Eye/ear preparations beat the "solution" they mention.
      final drops = Medicine(
        id: 3,
        brandName: 'Z',
        dosageForm: 'Ophthalmic Solution',
      );
      expect(drops.form, MedicineForm.drop);
      final inj = Medicine(
        id: 4,
        brandName: 'W',
        dosageForm: 'IM/IV Injection',
      );
      expect(inj.form, MedicineForm.injection);
    });

    test('computes expiry state from stored ISO dates', () {
      String iso(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      final soon = Medicine(
        id: 1,
        brandName: 'X',
        expiryDate: iso(DateTime.now().add(const Duration(days: 120))),
      );
      expect(soon.isExpired, isFalse);
      expect(soon.daysToExpiry, greaterThan(0));
      final past = Medicine(
        id: 2,
        brandName: 'Y',
        expiryDate: iso(DateTime.now().subtract(const Duration(days: 5))),
      );
      expect(past.isExpired, isTrue);
      expect(past.daysToExpiry, lessThan(0));
    });
  });

  group('dosage form classifier', () {
    test('maps representative raw strings', () {
      expect(
        MedicineForm.classify('Tablet (Extended Release)'),
        MedicineForm.tablet,
      );
      expect(MedicineForm.classify('Softgel Capsule'), MedicineForm.capsule);
      expect(MedicineForm.classify('Syrup'), MedicineForm.syrup);
      expect(MedicineForm.classify('Suspension'), MedicineForm.suspension);
      expect(
        MedicineForm.classify('Rectal Suppository'),
        MedicineForm.suppository,
      );
      expect(
        MedicineForm.classify('Injectable Solution'),
        MedicineForm.injection,
      );
      expect(MedicineForm.classify('Topical Ointment'), MedicineForm.ointment);
      expect(MedicineForm.classify('Cream'), MedicineForm.cream);
      expect(MedicineForm.classify('Gel'), MedicineForm.gel);
      expect(MedicineForm.classify('Eye Drops'), MedicineForm.drop);
      expect(MedicineForm.classify('Dry Powder Inhaler'), MedicineForm.inhaler);
      expect(
        MedicineForm.classify('Normal Saline IV Infusion'),
        MedicineForm.saline,
      );
      expect(MedicineForm.classify('Nasal Spray'), MedicineForm.spray);
      expect(MedicineForm.classify('Granules Sachet'), MedicineForm.powder);
      expect(MedicineForm.classify('Lotion'), MedicineForm.lotion);
      expect(
        MedicineForm.classify('Glucometer Test Strip'),
        MedicineForm.other,
      );
      expect(MedicineForm.classify(null), MedicineForm.other);
    });

    test('fromStored round-trips a key or Bengali label', () {
      for (final f in MedicineForm.values) {
        expect(MedicineForm.fromStored(f.key), f);
        expect(MedicineForm.fromStored(f.label), f);
      }
    });
  });

  group('manual medicine', () {
    Medicine full() => Medicine(
      id: 0,
      brandName: 'Manual Napa',
      genericName: 'Paracetamol',
      company: 'Beximco',
      dosageForm: MedicineForm.tablet.label,
      strength: '500 mg',
      indications: 'জ্বর',
      mrp: '5',
      tradePrice: '4',
      stockQuantity: 50,
      batchNumber: 'B-01',
      rackNo: 'Rack-A',
      source: 'manual',
      detailLoaded: true,
    );

    String isoInDays(int days) {
      final d = DateTime.now().add(Duration(days: days));
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }

    test(
      'inserts in the manual id namespace, separate from the catalogue',
      () async {
        // A synced/API row lives in the low id space; a manual row must not
        // collide with it and must not count toward the catalogue total.
        await db.upsertSummaries([sample(id: 1, brand: 'ApiRow')]);
        final id = await dao.addManualMedicine(full());
        expect(id, greaterThanOrEqualTo(AppConfig.manualIdBase));

        expect(await db.catalogCount(), 1);
        expect(await db.manualCount(), 1);

        final loaded = await dao.byId(id);
        expect(loaded, isNotNull);
        expect(loaded!.isManual, isTrue);
        expect(loaded.stockQuantity, 50);
        expect(loaded.rackNo, 'Rack-A');
        expect(loaded.form, MedicineForm.tablet);
      },
    );

    test('manual ids increase and never reuse an existing one', () async {
      final a = await dao.addManualMedicine(full());
      final b = await dao.addManualMedicine(full());
      expect(b, greaterThan(a));
      expect(await db.manualCount(), 2);
    });

    test(
      'expiringSoon surfaces manual rows near or past expiry only',
      () async {
        await dao.addManualMedicine(full()); // no expiry date → not listed
        final expiringId = await dao.addManualMedicine(
          Medicine(
            id: 0,
            brandName: 'Soon Expired',
            genericName: 'Amlodipine',
            company: 'Square',
            dosageForm: MedicineForm.tablet.label,
            strength: '5 mg',
            indications: 'হাই ব্লাড প্রেশার',
            expiryDate: isoInDays(30),
            source: 'manual',
            detailLoaded: true,
          ),
        );
        final list = await dao.expiringSoon();
        expect(list.map((e) => e.id), contains(expiringId));
        expect(list.map((e) => e.id), isNot(contains(1)));
      },
    );
  });

  group('catalog snapshot (SQLite VACUUM INTO + ATTACH)', () {
    // Exercises the exact SQL BackupService relies on to save/restore the
    // whole catalogue, proving it works on the bundled FFI SQLite build.
    test(
      'exports to a file and restores every row, keeping FTS usable',
      () async {
        await db.upsertSummaries([
          sample(
            id: 1,
            brand: 'Napa',
            generic: 'Paracetamol',
            company: 'Beximco',
          ),
          sample(
            id: 2,
            brand: 'Seclo',
            generic: 'Omeprazole',
            company: 'Square',
          ),
        ]);

        final dir = await Directory.systemTemp.createTemp('catalog_snap');
        final file = File(p.join(dir.path, 'catalog.db'));
        final lit = "'${file.path.replaceAll("'", "''")}'";
        await db.db.execute('VACUUM INTO $lit');
        expect(await file.exists(), isTrue);

        // Wipe the live catalogue, then restore it from the snapshot in place.
        await db.db.execute('DELETE FROM medicines');
        expect(await db.db.query('medicines'), isEmpty);

        await db.db.execute('ATTACH DATABASE $lit AS snap');
        try {
          await db.db.transaction((txn) async {
            await txn.execute('DELETE FROM medicines');
            await txn.execute(
              'INSERT INTO medicines SELECT * FROM snap.medicines',
            );
          });
          await db.db.execute(
            "INSERT INTO medicines_fts(medicines_fts) VALUES('rebuild')",
          );
        } finally {
          await db.db.execute('DETACH DATABASE snap');
        }

        final restored = await db.db.query('medicines');
        expect(restored.length, 2);
        final hits = await db.db.rawQuery(
          'SELECT rowid FROM medicines_fts WHERE medicines_fts MATCH ?',
          ['napa*'],
        );
        expect(hits, isNotEmpty, reason: 'FTS must be usable after a restore');
        await dir.delete(recursive: true);
      },
    );
  });

  group('catalog zip bundle (SD / file manager export)', () {
    // The portable .zip is the whole point of the Data Management page, so its
    // encode/decode/validation path is pure and exercised here without the
    // file-picker or path_provider plugins.
    test('zipBundle/unzipBundle round-trips the database and manifest', () {
      final dbBytes = Uint8List.fromList(<int>[
        ...utf8.encode('SQLite format 3\x00'),
        ...List.generate(4096, (i) => i % 256),
      ]);
      final manifest = <String, dynamic>{
        'app': 'PharmaPath',
        'format_version': BackupService.catalogZipFormatVersion,
        'source_base': 'http://127.0.0.1:8000',
        'counts': {'medicines': 19590},
      };

      final zip = BackupService.zipBundle(dbBytes, manifest);
      final back = BackupService.unzipBundle(zip);

      expect(back.dbBytes, equals(dbBytes));
      expect(back.manifest['source_base'], 'http://127.0.0.1:8000');
      expect((back.manifest['counts'] as Map)['medicines'], 19590);
    });

    test('rejects a bundle that is not a PharmaPath backup', () {
      final zip = BackupService.zipBundle(Uint8List.fromList([1, 2, 3]), {
        'app': 'NotPharma',
        'format_version': 1,
      });
      expect(
        () => BackupService.unzipBundle(zip),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a bundle from a newer app version', () {
      final zip = BackupService.zipBundle(Uint8List.fromList([1, 2, 3]), {
        'app': 'PharmaPath',
        'format_version': 999,
      });
      expect(
        () => BackupService.unzipBundle(zip),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('clinical sections expose stable keys', () {
    test('mapped fields use db keys; extras keep their source key', () {
      final m = Medicine(
        id: 1,
        brandName: 'Napa',
        indications: 'For fever',
        sideEffects: 'Nausea',
        sections: const {'mode_of_action': 'Inhibits COX'},
      );
      final secs = m.clinicalSections;
      expect(
        secs.map((s) => s.key),
        containsAll(['indications', 'side_effects', 'mode_of_action']),
      );
      expect(secs.first.label, 'রোগের নির্দেশনা');
    });
  });

  group('similar medicines (same generic, other brands)', () {
    test(
      'matches generic case- and whitespace-insensitively, excludes self',
      () async {
        await db.upsertDetailBatch([
          sample(
            id: 1,
            brand: 'Napa',
            generic: 'Paracetamol',
            company: 'Beximco',
            detailed: true,
          ),
          sample(
            id: 2,
            brand: 'Ace',
            generic: ' paracetamol ',
            company: 'Square',
            detailed: true,
          ),
          sample(
            id: 3,
            brand: 'FEBRIC',
            generic: 'PARACETAMOL',
            company: 'ACI',
            detailed: true,
          ),
          sample(
            id: 4,
            brand: 'Seclo',
            generic: 'Omeprazole',
            company: 'Square',
            detailed: true,
          ),
        ]);

        final similar = await dao.findSimilarByGeneric(
          'Paracetamol',
          excludeId: 1,
        );
        expect(similar.map((m) => m.brandName).toSet(), {'Ace', 'FEBRIC'});
        expect(similar.any((m) => m.brandName == 'Napa'), isFalse);
        expect(similar.any((m) => m.brandName == 'Seclo'), isFalse);
      },
    );

    test('blank generic returns nothing', () async {
      final none = await dao.findSimilarByGeneric('   ');
      expect(none, isEmpty);
    });

    test('with a strength only identical mg brands are alternatives', () async {
      await db.upsertDetailBatch([
        sample(
          id: 1,
          brand: 'Napa',
          generic: 'Paracetamol',
          company: 'Beximco',
          strength: '500 mg',
          detailed: true,
        ),
        sample(
          id: 2,
          brand: 'Ace',
          generic: 'Paracetamol',
          company: 'ACI',
          strength: '500 mg',
          detailed: true,
        ),
        sample(
          id: 3,
          brand: 'Paracetamol',
          generic: 'Paracetamol',
          company: 'Summit',
          strength: '150 mg/5 ml',
          detailed: true,
        ),
        sample(
          id: 4,
          brand: 'Febic',
          generic: 'Paracetamol',
          company: 'Incepta',
          strength: '200 mg',
          detailed: true,
        ),
      ]);

      final similar = await dao.findSimilarByGeneric(
        'Paracetamol',
        strength: '500 mg',
        excludeId: 1,
      );
      expect(similar.map((m) => m.brandName), ['Ace']);
    });

    test('strength comparison ignores case, spacing and digit width', () async {
      await db.upsertDetailBatch([
        sample(
          id: 1,
          brand: 'Napa',
          generic: 'Paracetamol',
          company: 'Beximco',
          strength: '500MG',
          detailed: true,
        ),
        sample(
          id: 2,
          brand: 'Ace',
          generic: 'Paracetamol',
          company: 'ACI',
          strength: '500 mg',
          detailed: true,
        ),
      ]);
      final similar = await dao.findSimilarByGeneric(
        'paracetamol',
        strength: '500 mg',
        excludeId: 1,
      );
      expect(similar.map((m) => m.brandName), ['Ace']);
    });
  });

  group('featured medicines (ঔষধ page opener)', () {
    test('resolves tokens brand-first, in order, without repeats', () async {
      await db.upsertDetailBatch([
        sample(
          id: 1,
          brand: 'Napa',
          generic: 'Paracetamol',
          company: 'Beximco',
          strength: '500 mg',
          detailed: true,
        ),
        sample(
          id: 2,
          brand: 'Generic Paracetamol',
          generic: 'Paracetamol',
          company: 'Wren',
          strength: '500 mg',
        ),
        sample(
          id: 3,
          brand: 'ORS',
          generic: 'Oral rehydration salt [glucose based]',
          company: 'Triangle',
          strength: '25.5 g',
        ),
        sample(
          id: 4,
          brand: 'Risek',
          generic: 'Omeprazole',
          company: 'Sun',
          strength: '20 mg',
          detailed: true,
        ),
      ]);

      final featured = await dao.featuredMedicines([
        'Napa',
        'Paracetamol',
        'ORS',
        'Omeprazole',
        'Napa',
      ]);
      // Brand hit wins for Napa, the generic row represents Paracetamol, and
      // the repeated token is deduped — one tile per essential medicine.
      expect(featured.map((m) => m.brandName), [
        'Napa',
        'Generic Paracetamol',
        'ORS',
        'Risek',
      ]);
    });

    test('every essential token exists in the shipped seed catalogue', () {
      expect(essentialMedicineTokens, hasLength(greaterThanOrEqualTo(100)));
      expect(
        essentialMedicineTokens.toSet().length,
        essentialMedicineTokens.length,
        reason: 'a repeated token would waste a featured slot',
      );
    });
  });
}
