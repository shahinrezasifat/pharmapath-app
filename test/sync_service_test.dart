import 'package:flutter_test/flutter_test.dart';
import 'package:pharmapath_app/core/api_exception.dart';
import 'package:pharmapath_app/core/app_config.dart';
import 'package:pharmapath_app/data/app_database.dart';
import 'package:pharmapath_app/data/medicine_dao.dart';
import 'package:pharmapath_app/models/medicine.dart';
import 'package:pharmapath_app/services/medicine_api.dart';
import 'package:pharmapath_app/services/sync_service.dart';

/// A scriptable stand-in for the BD Medicine API. It serves a summary listing
/// and per-id detail from an in-memory catalog, so the whole sync engine
/// (fingerprint gate, initial full crawl, delta classification) runs against
/// a deterministic dataset with no network.
class _FakeApi extends MedicineApi {
  _FakeApi() : super(baseUrl: () => 'http://fake');

  Map<String, dynamic> statsData = <String, dynamic>{};
  final Map<int, Medicine> catalog = <int, Medicine>{};

  int healthCalls = 0;
  int listingCalls = 0;
  int detailCalls = 0;
  int failListingFromPage = 0; // when > 0, pages >= this throw ApiException

  @override
  Future<void> health() async {
    healthCalls++;
  }

  @override
  Future<Map<String, dynamic>> stats() async => statsData;

  @override
  Future<MedicinePage> medicines({
    int page = 1,
    int limit = AppConfig.syncPageSize,
    String? search,
    String? company,
    String? generic,
    String? dosageForm,
  }) async {
    listingCalls++;
    if (failListingFromPage > 0 && page >= failListingFromPage) {
      throw ApiException('simulated outage');
    }
    final ids = catalog.keys.toList()..sort();
    final summaries = ids.map((i) => catalog[i]!.summaryOnly()).toList();
    final start = (page - 1) * limit;
    final slice = start >= summaries.length
        ? <Medicine>[]
        : summaries.sublist(start, (start + limit).clamp(0, summaries.length));
    final totalPages = (summaries.length / limit).ceil();
    return MedicinePage(
      items: slice,
      page: page,
      totalPages: totalPages,
      total: summaries.length,
    );
  }

  @override
  Future<Medicine> medicine(int id) async {
    detailCalls++;
    final m = catalog[id];
    if (m == null) throw ApiException('not found', statusCode: 404);
    return m;
  }
}

Medicine _detail(int id, {String price = '10'}) => Medicine(
  id: id,
  brandName: 'Brand$id',
  genericName: 'Generic$id',
  company: 'Company$id',
  unitPrice: price,
  dosageForm: 'Tablet',
  strength: '500mg',
  indications: 'Fever and pain relief.',
);

Map<String, dynamic> _stats({
  required int total,
  required int scraped,
  int newCount = 0,
}) => {
  'total_medicines': total,
  'detail_scraped': scraped,
  'pending_detail': total - scraped,
  'distinct_companies': total,
  'distinct_generics': total,
  'last_run': {
    'started_at': '2026-10-25T10:00:00Z',
    'finished_at': '2026-10-25T10:05:00Z',
    'new_count': newCount,
    'updated_count': 0,
    'mode': 'full',
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MedicineDao dao;
  late _FakeApi api;
  late SyncService sync;

  setUp(() async {
    db = await AppDatabase.openForTesting();
    dao = MedicineDao(db);
    api = _FakeApi();
    sync = SyncService(api: api, db: db, dao: dao);
  });

  tearDown(() async {
    await db.close();
    api.dispose();
  });

  test('fingerprint is a stable, ordered aggregate of stats', () {
    final fp = SyncService.fingerprint(_stats(total: 5, scraped: 2));
    expect(
      fp,
      'v1|5|2|3|5|5|2026-10-25T10:00:00Z~2026-10-25T10:05:00Z~0~0~full',
    );
    // Different dataset → different signal.
    expect(SyncService.fingerprint(_stats(total: 6, scraped: 2)), isNot(fp));
  });

  test('initial sync into an empty db performs a full crawl', () async {
    for (var i = 1; i <= 3; i++) {
      api.catalog[i] = _detail(i);
    }
    api.statsData = _stats(total: 3, scraped: 3);

    final result = await sync.syncAll();

    expect(result.initial, isTrue);
    expect(result.unchanged, isFalse);
    expect(result.imported, 3);
    expect(result.newRecords, 3);
    expect(result.detailsFetched, 3);
    expect(await db.medicineCount(), 3);
    // Detail was actually written (clinical content marks rows detailed).
    final stored = await dao.byId(1);
    expect(stored!.detailLoaded, isTrue);
    expect(stored.indications, 'Fever and pain relief.');
    expect(
      await db.meta(AppConfig.metaFingerprint),
      SyncService.fingerprint(api.statsData),
    );
  });

  test(
    'unchanged second sync skips every download ("Already Downloaded")',
    () async {
      for (var i = 1; i <= 3; i++) {
        api.catalog[i] = _detail(i);
      }
      api.statsData = _stats(total: 3, scraped: 3);
      await sync.syncAll();

      final before = api.listingCalls;
      final beforeDetail = api.detailCalls;
      final again = await sync.syncAll();

      expect(again.unchanged, isTrue);
      expect(again.initial, isFalse);
      expect(again.lastSyncAt, isNotNull);
      // No listing pages and no detail requests were issued on the skip path.
      expect(api.listingCalls, before);
      expect(api.detailCalls, beforeDetail);
    },
  );

  test('force re-syncs even when the fingerprint matches', () async {
    for (var i = 1; i <= 2; i++) {
      api.catalog[i] = _detail(i);
    }
    api.statsData = _stats(total: 2, scraped: 2);
    await sync.syncAll();
    final forced = await sync.syncAll(force: true);
    expect(forced.unchanged, isFalse);
  });

  test('delta sync downloads only new and changed records', () async {
    for (var i = 1; i <= 3; i++) {
      api.catalog[i] = _detail(i);
    }
    api.statsData = _stats(total: 3, scraped: 3);
    await sync.syncAll();

    // Upstream adds a 4th medicine and changes brand 1's price only.
    api.catalog[4] = _detail(4);
    api.catalog[1] = _detail(1, price: '12');
    api.statsData = _stats(total: 4, scraped: 4, newCount: 1);
    api.detailCalls = 0;

    final result = await sync.syncAll();

    expect(result.unchanged, isFalse);
    expect(result.initial, isFalse);
    expect(result.newRecords, 1);
    expect(result.updatedRecords, 1);
    // Only the changed row + the new row had their detail re-fetched.
    expect(result.detailsFetched, 2);
    expect(await db.medicineCount(), 4);
    expect((await dao.byId(1))!.unitPrice, '12');
  });

  test('a dropped listing page withholds the fingerprint for retry', () async {
    // Two pages worth of catalog; page 2 always fails, so the merge is
    // incomplete and the skip-gate must not be armed.
    for (var i = 1; i <= 150; i++) {
      api.catalog[i] = _detail(i);
    }
    api.statsData = _stats(total: 150, scraped: 150);
    api.failListingFromPage = 2;

    final result = await sync.syncAll();

    expect(result.imported, 100);
    expect(result.unchanged, isFalse);
    expect(await db.medicineCount(), 100);
    // Fingerprint not pinned on a partial listing → next launch retries
    // instead of falsely reporting "Already Downloaded".
    expect(
      await db.meta(AppConfig.metaFingerprint),
      isNot(SyncService.fingerprint(api.statsData)),
    );

    // Recovered server: a clean run now completes the crawl and pins it.
    api.failListingFromPage = 0;
    final retry = await sync.syncAll();
    expect(retry.imported, 150);
    expect(
      await db.meta(AppConfig.metaFingerprint),
      SyncService.fingerprint(api.statsData),
    );
  });
}

extension on Medicine {
  /// Strip clinical content, mirroring the summary-only `/medicines` listing.
  Medicine summaryOnly() => Medicine(
    id: id,
    brandName: brandName,
    slug: slug,
    url: url,
    dosageForm: dosageForm,
    strength: strength,
    genericName: genericName,
    genericId: genericId,
    company: company,
    companyId: companyId,
    unitPrice: unitPrice,
    priceText: priceText,
    packSizes: packSizes,
  );
}
