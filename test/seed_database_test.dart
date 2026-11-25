import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pharmapath_app/core/app_config.dart';
import 'package:pharmapath_app/services/seed_database.dart';
import 'package:pharmapath_app/services/sync_service.dart';

/// Guards the offline catalogue that ships in `assets/learning/`. If someone
/// regenerates the seed with a broken build or forgets to commit it, these
/// fail loudly instead of the app silently starting empty.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final seedPath = p.join('assets', 'learning', 'medicines_seed.db');

  test('shipped seed asset exists and is a real SQLite file', () {
    final file = File(seedPath);
    expect(
      file.existsSync(),
      isTrue,
      reason: 'run: dart run tool/build_seed_db.dart',
    );
    final bytes = file.readAsBytesSync().sublist(0, 15);
    expect(String.fromCharCodes(bytes), 'SQLite format 3');
  });

  test('seed carries the full catalogue, FTS index and detail', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      File(seedPath).absolute.path,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    try {
      final integrity = (await db.rawQuery('PRAGMA integrity_check'))
          .first
          .values
          .first;
      expect(integrity, 'ok');

      final medicines = _firstInt(
        await db.rawQuery('SELECT COUNT(*) FROM medicines'),
      );
      // The upstream dataset is ~19.5k, but only records carrying the full
      // core identity (brand+generic+company+dosage form+strength) are
      // imported (~18.9k). Assert a healthy floor so a truncated build is
      // caught without pinning an exact moving number.
      expect(medicines, greaterThan(18000));

      // Strict-import invariant: every seeded row must have a complete core
      // identity — an incomplete API record must never make it into the DB.
      final incomplete = _firstInt(
        await db.rawQuery("""SELECT COUNT(*) FROM medicines
             WHERE TRIM(COALESCE(brand_name,''))=''
                OR TRIM(COALESCE(generic_name,''))=''
                OR TRIM(COALESCE(company,''))=''
                OR TRIM(COALESCE(dosage_form,''))=''
                OR TRIM(COALESCE(strength,''))=''
          """),
      );
      expect(incomplete, 0, reason: 'core-identity filter leaked an empty row');

      // Schema v2 ships the inventory/visual columns and stamps user_version.
      final version = _firstInt(await db.rawQuery('PRAGMA user_version'));
      expect(version, 2, reason: 'seed must be built with schema v2');
      final cols = (await db.rawQuery('PRAGMA table_info(medicines)'))
          .map((e) => e['name'] as String)
          .toSet();
      for (final c in [
        'trade_price',
        'mrp',
        'stock_quantity',
        'batch_number',
        'rack_no',
        'mfg_date',
        'expiry_date',
        'image_url',
      ]) {
        expect(cols, contains(c), reason: 'missing v2 column $c');
      }
      final productImages = _firstInt(
        await db.rawQuery(
          "SELECT COUNT(*) FROM medicines "
          "WHERE image_url IS NOT NULL AND TRIM(image_url) <> ''",
        ),
      );
      expect(productImages, 0, reason: 'seed must not contain product images');

      final detailed = _firstInt(
        await db.rawQuery(
          'SELECT COUNT(*) FROM medicines WHERE detail_loaded = 1',
        ),
      );
      expect(detailed, greaterThan(0));

      // Search the FTS index the same way MedicineDao does at runtime.
      final hits = await db.rawQuery(
        "SELECT rowid FROM medicines_fts WHERE medicines_fts MATCH ? LIMIT 5",
        ['paracetamol*'],
      );
      expect(hits, isNotEmpty);

      final metaKeys = (await db.rawQuery(
        "SELECT key FROM meta WHERE key = 'seed_version'",
      )).isNotEmpty;
      expect(
        metaKeys,
        isFalse,
        reason: 'seed_version is stamped by the app, not the builder',
      );

      // The seed must carry the sync baseline, otherwise a freshly installed
      // app re-crawls the whole API on first launch instead of reporting
      // "Already Downloaded".
      final meta = Map<String, Object?>.fromEntries(
        (await db.rawQuery('SELECT key, value FROM meta'))
            .map((e) => MapEntry(e['key'] as String, e['value'])),
      );
      final fingerprint = meta['sync_fingerprint']?.toString() ?? '';
      expect(
        fingerprint,
        startsWith('v1|'),
        reason:
            'meta.sync_fingerprint missing — rebuild with build_seed_db.dart',
      );
      final stats = jsonDecode(meta['source_stats']! as String) as Map;
      expect(
        fingerprint,
        SyncService.fingerprint(stats.cast<String, dynamic>()),
        reason: "seed fingerprint must match the app's SyncService format",
      );
      expect(meta['source_detail_scraped'], isNotNull);
      expect(meta['last_sync_at'], isNotNull);
    } finally {
      await db.close();
    }
  });

  test('installer never overwrites an existing database', () async {
    // An already-present file must be left untouched, even without a seed
    // round-trip — this protects user favourites and prior syncs.
    final dir = await Directory.systemTemp.createTemp('seed_guard');
    final target = File(p.join(dir.path, 'pharmapath.db'))
      ..writeAsStringSync('existing');
    final installed = await SeedInstaller.installIfNeeded(target.path);
    expect(installed, isFalse);
    expect(target.readAsStringSync(), 'existing');
    await dir.delete(recursive: true);
  });

  test('seed asset path constant matches the file on disk', () {
    expect(AppConfig.seedAssetPath, 'assets/learning/medicines_seed.db');
    expect(File(AppConfig.seedAssetPath).existsSync(), isTrue);
  });
}

int _firstInt(List<Map<String, Object?>> rows) =>
    (rows.first.values.first as num).toInt();
