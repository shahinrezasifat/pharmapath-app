import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/app_config.dart';
import '../models/medicine.dart';
import '../services/seed_database.dart';

/// Owns the SQLite connection and schema. Search, favourites and learning
/// queries live in dedicated DAOs that share the same [Database].
class AppDatabase {
  AppDatabase._(this.db, {required this.ftsAvailable});

  final Database db;
  final bool ftsAvailable;

  static bool _ffiReady = false;

  /// All supported targets use the FFI factory backed by a bundled SQLite
  /// (`sqlite3_flutter_libs`) instead of the OS copy, because several Android
  /// builds ship a SQLite without the FTS5 module. Bundling makes full-text
  /// search and tokenization behave identically on Android, Linux and Windows.
  static void configureFactory() {
    if (kIsWeb) return;
    if (_ffiReady) return;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _ffiReady = true;
  }

  static Future<AppDatabase> open({String? path}) async {
    configureFactory();
    // Resolve an explicit app-private directory: the FFI factory's default
    // path is a desktop temp folder and is not suitable on Android.
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    final dbPath = path ?? p.join(dir.path, 'pharmapath.db');
    // Fresh install: drop the prebuilt offline catalogue in place before
    // SQLite opens, so the app is fully populated with zero network use.
    await SeedInstaller.installIfNeeded(dbPath);
    final database = await openDatabase(
      dbPath,
      version: 9,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v2 added the manual inventory / visual columns.
        if (oldVersion < 2) await _addInventoryColumns(db);
        // v3 added the cached AI translations table.
        if (oldVersion < 3) await _createTranslationsTable(db);
        // v4 added chat conversations; older threads fold into one row.
        if (oldVersion < 4) await _createConversationsTable(db);
        // v5 added company_logo_url (the model has always written it; the
        // column was missing from every earlier schema).
        if (oldVersion < 5) await _addInventoryColumns(db);
        // v6 lets assistant messages carry multimodal attachments (JSON).
        if (oldVersion < 6) await _addAiAttachmentsColumn(db);
        // v7 backs the learning AI helpers: a generic model-output cache and
        // the reading history (visits / last read) that powers suggestions.
        if (oldVersion < 7) {
          await _createAiCacheTable(db);
          await _addReadingHistoryColumns(db);
        }
        // v8 repairs image_url on databases that were seeded with a stale
        // schema version and therefore skipped the earlier inventory upgrades.
        if (oldVersion < 8) await _ensureMedicineImageUrlColumn(db);
      },
    );
    // Seeded files may already claim the latest version while still carrying
    // an older schema, so validate this column independently of onUpgrade.
    await _ensureMedicineImageUrlColumn(database);
    final fts = await _ensureFts(database);
    final app = AppDatabase._(database, ftsAvailable: fts);
    if (await app.meta('medicine_image_urls_cleared') != 'v1') {
      await _clearMedicineImageUrls(database);
      await app.setMeta('medicine_image_urls_cleared', 'v1');
    }
    // Record which bundled seed this database came from, so the settings screen
    // and future migrations can reason about the offline baseline.
    await app.setMeta('seed_version', '${AppConfig.seedVersion}');
    // Some brands were discovered without their own clinical detail even
    // though a sibling brand of the same generic has a complete record. Copy
    // that generic-level text (with the brand name substituted) once, so more
    // catalogue entries can show real clinical content instead of an empty
    // detail page.
    await app.backfillGenericDetails();
    return app;
  }

  /// One-time, idempotent generic-level backfill.
  ///
  /// A brand row that already has its own detail is never overwritten. Rows
  /// that share a generic with a complete record inherit the same clinical
  /// sections; the brand name inside those sections is replaced so the text
  /// does not point at another product. Records with no documented sibling
  /// stay `detail_loaded = 0`; they remain part of the searchable catalogue
  /// and simply offer the "বিস্তারিত আনুন" action on the detail page.
  Future<void> backfillGenericDetails() async {
    const marker = 'generic_detail_backfill';
    if (await meta(marker) == 'v1') return;

    final representatives = await db.rawQuery('''
      SELECT LOWER(TRIM(generic_name)) AS generic_key, MIN(id) AS rep_id
      FROM medicines
      WHERE detail_loaded = 1
        AND generic_name IS NOT NULL
        AND TRIM(generic_name) != ''
        AND indications IS NOT NULL
        AND TRIM(indications) != ''
      GROUP BY generic_key
    ''');

    const clinicalColumns = [
      'indications',
      'composition',
      'pharmacology',
      'dosage_and_administration',
      'interaction',
      'contraindications',
      'side_effects',
      'pregnancy_and_lactation',
      'precautions_and_warnings',
      'overdose_effects',
      'therapeutic_class',
      'storage_conditions',
      'common_questions',
      'sections_json',
    ];

    var hasUpdates = false;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final representative in representatives) {
        final repId = representative['rep_id'];
        final genericKey = representative['generic_key'];
        if (repId == null || genericKey == null) continue;
        final repRows = await txn.query(
          'medicines',
          where: 'id = ?',
          whereArgs: [repId],
          limit: 1,
        );
        if (repRows.isEmpty) continue;
        final rep = repRows.first;
        final sourceBrand = (rep['brand_name'] as String? ?? '').trim();
        final targets = await txn.query(
          'medicines',
          columns: ['id', 'brand_name'],
          where: 'detail_loaded = 0 AND LOWER(TRIM(generic_name)) = ?',
          whereArgs: [genericKey],
        );
        for (final target in targets) {
          final targetBrand = (target['brand_name'] as String? ?? '').trim();
          final values = <String, Object?>{
            'detail_loaded': 1,
            'source_updated': rep['source_updated'],
          };
          for (final column in clinicalColumns) {
            final raw = rep[column] as String?;
            if (raw == null || raw.trim().isEmpty) continue;
            values[column] = sourceBrand.isEmpty
                ? raw
                : raw.replaceAll(sourceBrand, targetBrand);
          }
          hasUpdates = true;
          batch.update(
            'medicines',
            values,
            where: 'id = ?',
            whereArgs: [target['id']],
          );
        }
      }
      if (hasUpdates) await batch.commit(noResult: true);
    });
    await setMeta(marker, 'v1');
  }

  /// Used by tests with an in-memory FFI database.
  static Future<AppDatabase> openForTesting() async {
    sqfliteFfiInit();
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 9,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _createSchema(db),
      ),
    );
    await _ensureMedicineImageUrlColumn(database);
    final fts = await _ensureFts(database);
    return AppDatabase._(database, ftsAvailable: fts);
  }

  Future<void> close() => db.close();

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE medicines (
        id INTEGER PRIMARY KEY,
        slug TEXT,
        url TEXT,
        brand_name TEXT NOT NULL,
        dosage_form TEXT,
        strength TEXT,
        generic_name TEXT,
        generic_id INTEGER,
        company TEXT,
        company_id INTEGER,
        unit_price TEXT,
        price_text TEXT,
        pack_sizes TEXT,
        indications TEXT,
        composition TEXT,
        pharmacology TEXT,
        dosage_and_administration TEXT,
        interaction TEXT,
        contraindications TEXT,
        side_effects TEXT,
        pregnancy_and_lactation TEXT,
        precautions_and_warnings TEXT,
        overdose_effects TEXT,
        therapeutic_class TEXT,
        storage_conditions TEXT,
        common_questions TEXT,
        sections_json TEXT,
        detail_loaded INTEGER NOT NULL DEFAULT 0,
        source TEXT,
        source_updated TEXT,
        first_seen INTEGER,
        last_updated INTEGER,
        trade_price TEXT,
        mrp TEXT,
        stock_quantity INTEGER,
        batch_number TEXT,
        rack_no TEXT,
        mfg_date TEXT,
        expiry_date TEXT,
        image_url TEXT,
        company_logo_url TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_med_brand ON medicines(brand_name)');
    await db.execute('CREATE INDEX idx_med_generic ON medicines(generic_name)');
    await db.execute('CREATE INDEX idx_med_company ON medicines(company)');
    await db.execute('CREATE INDEX idx_med_dosage ON medicines(dosage_form)');
    await db.execute('CREATE INDEX idx_med_expiry ON medicines(expiry_date)');

    await db.execute('''
      CREATE TABLE favorites (
        medicine_id INTEGER PRIMARY KEY,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (medicine_id) REFERENCES medicines(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE view_history (
        medicine_id INTEGER PRIMARY KEY,
        viewed_at INTEGER NOT NULL,
        FOREIGN KEY (medicine_id) REFERENCES medicines(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE search_history (
        query TEXT PRIMARY KEY,
        used_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE learning_progress (
        course_id TEXT NOT NULL,
        lesson_id TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        visits INTEGER NOT NULL DEFAULT 0,
        last_read_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (course_id, lesson_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE quiz_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_id TEXT NOT NULL,
        score INTEGER NOT NULL,
        total INTEGER NOT NULL,
        taken_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE bookmarks (
        course_id TEXT NOT NULL,
        lesson_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (course_id, lesson_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE ai_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id INTEGER NOT NULL DEFAULT 1,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        attachments TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_ai_history_conv ON ai_history(conversation_id)',
    );
    await db.execute('''
      CREATE TABLE meta (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await _createTranslationsTable(db);
    await _createAiCacheTable(db);
  }

  /// General-purpose model-output cache (v7). One row per generated artefact:
  /// `kind` says what it is (`lesson_summary`, `medicine_explain`,
  /// `recommendations`), `ref` identifies the source record, and `src_hash`
  /// fingerprints the text the output was derived from so a stale row is simply
  /// missed on read instead of needing a migration or a prune job.
  static Future<void> _createAiCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_cache (
        kind TEXT NOT NULL,
        ref TEXT NOT NULL,
        src_hash TEXT NOT NULL,
        out TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (kind, ref)
      )
    ''');
  }

  /// v7: reading history on learning_progress. Idempotent, because databases
  /// created before this change have the table but not the columns.
  static Future<void> _addReadingHistoryColumns(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(learning_progress)');
    final existing = cols.map((c) => c['name'].toString()).toSet();
    if (!existing.contains('visits')) {
      await db.execute(
        'ALTER TABLE learning_progress ADD COLUMN visits INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!existing.contains('last_read_at')) {
      await db.execute(
        'ALTER TABLE learning_progress ADD COLUMN last_read_at INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  /// Cached per-field Bangla translations of clinical text. Deliberately has no
  /// foreign key to `medicines`: a detail re-sync uses `INSERT OR REPLACE`,
  /// which deletes and re-inserts the medicine row, and a cascade FK would wipe
  /// every stored translation on each sync. Stale rows are pruned by [src_hash]
  /// (the hash of the English source) on read instead.
  static Future<void> _createTranslationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS translations (
        medicine_id INTEGER NOT NULL,
        field TEXT NOT NULL,
        src_hash TEXT NOT NULL,
        bn TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (medicine_id, field)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_trans_medicine ON translations(medicine_id)',
    );
  }

  /// Chat conversations for the AI assistant (v4). `ai_history` intentionally
  /// carries no foreign key here: the table trims old rows itself and a
  /// deleted conversation's messages are pruned explicitly in [AiDao]. The
  /// single pre-v4 thread (if any) is folded into one named conversation.
  static Future<void> _createConversationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    final columns = await db.rawQuery('PRAGMA table_info(ai_history)');
    final hasLink = columns.any((c) => c['name'] == 'conversation_id');
    if (!hasLink) {
      await db.execute(
        'ALTER TABLE ai_history ADD COLUMN conversation_id INTEGER NOT NULL DEFAULT 1',
      );
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_history_conv ON ai_history(conversation_id)',
    );
    final seeded = await db.rawQuery('SELECT id FROM conversations LIMIT 1');
    if (seeded.isEmpty) {
      await db.insert('conversations', {
        'id': 1,
        'title': 'আগের কথোপকথন',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// v6: assistant messages can carry multimodal attachments — a JSON array
  /// of {kind, path, name} describing images / voice notes bound to a bubble.
  /// Idempotent, so re-running an upgrade or a healed seed never errors.
  static Future<void> _addAiAttachmentsColumn(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='ai_history'",
    );
    if (tables.isEmpty) return; // fresh dbs get it from _createSchema
    final columns = await db.rawQuery('PRAGMA table_info(ai_history)');
    final hasColumn = columns.any((c) => c['name'] == 'attachments');
    if (!hasColumn) {
      await db.execute('ALTER TABLE ai_history ADD COLUMN attachments TEXT');
    }
  }

  /// Adds the manual inventory / visual columns to a pre-v2 database. Uses
  /// PRAGMA table_info so re-running an upgrade never errors on a column that
  /// already exists (a seeded v2 file skipped onCreate but is already current).
  static Future<void> _addInventoryColumns(Database db) async {
    final existing = <String>{};
    final cols = await db.rawQuery('PRAGMA table_info(medicines)');
    for (final c in cols) {
      existing.add(c['name'].toString());
    }

    const additions = <String, String>{
      'trade_price': 'TEXT',
      'mrp': 'TEXT',
      'stock_quantity': 'INTEGER',
      'batch_number': 'TEXT',
      'rack_no': 'TEXT',
      'mfg_date': 'TEXT',
      'expiry_date': 'TEXT',
      'image_url': 'TEXT',
      'company_logo_url': 'TEXT',
    };
    for (final entry in additions.entries) {
      if (existing.contains(entry.key)) continue;
      await db.execute(
        'ALTER TABLE medicines ADD COLUMN ${entry.key} ${entry.value}',
      );
    }
    try {
      await db.execute('CREATE INDEX idx_med_expiry ON medicines(expiry_date)');
    } catch (_) {
      // Index already present — ignore.
    }
  }

  static Future<void> _ensureMedicineImageUrlColumn(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(medicines)');
    if (columns.isEmpty) {
      throw StateError('The medicines table is missing from the database.');
    }
    if (columns.any((column) => column['name'] == 'image_url')) return;
    await db.execute('ALTER TABLE medicines ADD COLUMN image_url TEXT');
  }

  static Future<void> _clearMedicineImageUrls(Database db) async {
    await db.update('medicines', {'image_url': null});
  }

  /// FTS5 is present on modern Android/iOS and desktop SQLite. If a platform
  /// build lacks it, search transparently falls back to LIKE.
  static Future<bool> _ensureFts(Database db) async {
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS medicines_fts USING fts5(
          brand_name, generic_name, company, strength, dosage_form, therapeutic_class,
          content='medicines', content_rowid='id', tokenize='unicode61 remove_diacritics 2'
        )
      ''');
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS medicines_ai AFTER INSERT ON medicines BEGIN
          INSERT INTO medicines_fts(rowid, brand_name, generic_name, company, strength, dosage_form, therapeutic_class)
          VALUES (new.id, new.brand_name, new.generic_name, new.company, new.strength, new.dosage_form, new.therapeutic_class);
        END
      ''');
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS medicines_ad AFTER DELETE ON medicines BEGIN
          INSERT INTO medicines_fts(medicines_fts, rowid, brand_name, generic_name, company, strength, dosage_form, therapeutic_class)
          VALUES ('delete', old.id, old.brand_name, old.generic_name, old.company, old.strength, old.dosage_form, old.therapeutic_class);
        END
      ''');
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS medicines_au AFTER UPDATE ON medicines BEGIN
          INSERT INTO medicines_fts(medicines_fts, rowid, brand_name, generic_name, company, strength, dosage_form, therapeutic_class)
          VALUES ('delete', old.id, old.brand_name, old.generic_name, old.company, old.strength, old.dosage_form, old.therapeutic_class);
          INSERT INTO medicines_fts(rowid, brand_name, generic_name, company, strength, dosage_form, therapeutic_class)
          VALUES (new.id, new.brand_name, new.generic_name, new.company, new.strength, new.dosage_form, new.therapeutic_class);
        END
      ''');
      // Populate the index for rows that already existed before the table.
      await db.execute(
        'INSERT INTO medicines_fts(medicines_fts) VALUES(\'rebuild\')',
      );
      return true;
    } catch (error) {
      debugPrint('FTS5 unavailable, using LIKE search: $error');
      return false;
    }
  }

  /// Inserts listing rows without destroying cached clinical detail.
  Future<void> upsertSummaries(
    List<Medicine> items, {
    String? sourceUpdated,
  }) async {
    if (items.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final m in items) {
        batch.insert('medicines', {
          'id': m.id,
          'slug': m.slug,
          'url': m.url,
          'brand_name': m.brandName,
          'dosage_form': m.dosageForm,
          'strength': m.strength,
          'generic_name': m.genericName,
          'generic_id': m.genericId,
          'company': m.company,
          'company_id': m.companyId,
          'unit_price': m.unitPrice,
          'price_text': m.priceText,
          'pack_sizes': m.packSizes,
          'source': m.source,
          'source_updated': sourceUpdated ?? m.sourceUpdated,
          'first_seen': now,
          'last_updated': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        // Update mutable listing fields but never clinical columns.
        batch.rawUpdate(
          '''
          UPDATE medicines SET
            slug = COALESCE(?, slug),
            url = COALESCE(?, url),
            brand_name = COALESCE(?, brand_name),
            dosage_form = COALESCE(?, dosage_form),
            strength = COALESCE(?, strength),
            generic_name = COALESCE(?, generic_name),
            generic_id = COALESCE(?, generic_id),
            company = COALESCE(?, company),
            company_id = COALESCE(?, company_id),
            unit_price = COALESCE(?, unit_price),
            price_text = COALESCE(?, price_text),
            pack_sizes = COALESCE(?, pack_sizes),
            last_updated = ?
          WHERE id = ?
        ''',
          [
            m.slug,
            m.url,
            m.brandName,
            m.dosageForm,
            m.strength,
            m.genericName,
            m.genericId,
            m.company,
            m.companyId,
            m.unitPrice,
            m.priceText,
            m.packSizes,
            now,
            m.id,
          ],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Full record, marks the row as detail-loaded.
  Future<void> upsertDetail(Medicine m, {String? sourceUpdated}) async {
    await db.insert('medicines', {
      ...m.toDbMap(),
      'detail_loaded': 1,
      'source_updated': sourceUpdated ?? m.sourceUpdated,
      'first_seen': m.firstSeen ?? DateTime.now().millisecondsSinceEpoch,
      'last_updated': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Batched variant of [upsertDetail] for the initial full download and the
  /// delta detail refresh. Rows the server answered without any clinical
  /// content keep `detail_loaded = 0`, so they stay eligible for a later retry
  /// instead of being falsely marked complete.
  Future<void> upsertDetailBatch(
    List<Medicine> items, {
    String? sourceUpdated,
  }) async {
    if (items.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final m in items) {
        batch.insert('medicines', {
          ...m.toDbMap(),
          'detail_loaded': m.hasClinicalData || m.detailLoaded ? 1 : 0,
          'source_updated': sourceUpdated ?? m.sourceUpdated,
          'first_seen': m.firstSeen ?? now,
          'last_updated': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> medicineCount() async =>
      Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM medicines'),
      ) ??
      0;

  /// Every medicine id currently stored, for O(1) new-versus-known checks.
  Future<Set<int>> allMedicineIds() async {
    final rows = await db.rawQuery('SELECT id FROM medicines');
    return rows.map((e) => (e['id'] as num).toInt()).toSet();
  }

  /// Ids among [incoming] that already exist locally whose summary fields
  /// differ from what we have — the "updated records" of a delta sync. A single
  /// keyed lookup per page keeps memory flat; brand-new ids (absent from the
  /// query) are ignored here because the caller classifies them separately.
  Future<List<int>> changedSummaryIds(List<Medicine> incoming) async {
    if (incoming.isEmpty) return const [];
    final byId = <int, Medicine>{for (final m in incoming) m.id: m};
    final placeholders = List<String>.filled(byId.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT id, slug, url, brand_name, dosage_form, strength, generic_name, '
      'generic_id, company, company_id, unit_price, price_text, pack_sizes, '
      'detail_loaded FROM medicines WHERE id IN ($placeholders)',
      byId.keys.toList(),
    );
    final changed = <int>[];
    for (final row in rows) {
      final id = (row['id'] as num).toInt();
      final remote = byId[id];
      if (remote == null) continue;
      if (!Medicine.fromDb(row).sameSummaryAs(remote)) changed.add(id);
    }
    return changed;
  }

  /// Known medicines whose clinical detail has never been loaded, by id. Used
  /// for the bounded back-fill when the server reports more scraped detail
  /// than we hold locally.
  Future<List<int>> idsMissingDetail({
    int limit = AppConfig.deltaDetailBackfill,
  }) async {
    final rows = await db.rawQuery(
      'SELECT id FROM medicines WHERE detail_loaded = 0 '
      'AND (source IS NULL OR source != \'manual\') ORDER BY id LIMIT ?',
      [limit],
    );
    return rows.map((e) => (e['id'] as num).toInt()).toList();
  }

  /// Rows imported from the API/seed (excludes manual entries). The sync
  /// fingerprint compares against this so adding your own stock never breaks
  /// the "Already Downloaded" smart-caching check.
  Future<int> catalogCount() async =>
      Sqflite.firstIntValue(
        await db.rawQuery(
          "SELECT COUNT(*) FROM medicines WHERE source IS NULL OR source != 'manual'",
        ),
      ) ??
      0;

  Future<int> manualCount() async =>
      Sqflite.firstIntValue(
        await db.rawQuery(
          "SELECT COUNT(*) FROM medicines WHERE source = 'manual'",
        ),
      ) ??
      0;

  /// Allocate the next id in the manual namespace: a value above every API id
  /// so a synced record can never overwrite a hand-entered one and vice versa.
  Future<int> nextManualId() async {
    final rows = await db.rawQuery(
      'SELECT MAX(id) AS m FROM medicines WHERE id >= ?',
      [AppConfig.manualIdBase],
    );
    final current = (rows.first['m'] as num?)?.toInt();
    return current == null ? AppConfig.manualIdBase + 1 : current + 1;
  }

  /// Inserts a fully-populated manual medicine. The caller must already have
  /// filled every required field (the form enforces this); id is auto-allocated
  /// in the manual namespace and the row is immediately marked detail-loaded.
  Future<int> insertManualMedicine(Medicine m) async {
    final id = m.id > 0 ? m.id : await nextManualId();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('medicines', {
      ...m.toDbMap(),
      'id': id,
      'source': 'manual',
      'detail_loaded': 1,
      'first_seen': m.firstSeen ?? now,
      'last_updated': now,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
    return id;
  }

  /// Manually-entered medicines expiring on or before [days] days from today
  /// (expired ones included), soonest first. Backs the home expiry alert.
  Future<List<Medicine>> medicinesExpiringWithin(int days) async {
    final cutoff = DateTime.now()
        .add(Duration(days: days))
        .toIso8601String()
        .substring(0, 10);
    final rows = await db.rawQuery(
      "SELECT * FROM medicines WHERE source = 'manual' AND expiry_date IS NOT NULL "
      'AND expiry_date <= ? ORDER BY expiry_date ASC',
      [cutoff],
    );
    return rows.map(Medicine.fromDb).toList();
  }

  Future<String?> meta(String key) async {
    final rows = await db.query(
      'meta',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String? value) async {
    await db.insert('meta', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Object?>> stats() async {
    final total =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM medicines'),
        ) ??
        0;
    final detailed =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM medicines WHERE detail_loaded = 1',
          ),
        ) ??
        0;
    final companies =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(DISTINCT company) FROM medicines '
            'WHERE company IS NOT NULL',
          ),
        ) ??
        0;
    final generics =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(DISTINCT generic_name) FROM medicines '
            'WHERE generic_name IS NOT NULL',
          ),
        ) ??
        0;
    final manual =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM medicines WHERE source = 'manual'",
          ),
        ) ??
        0;
    final cutoff = DateTime.now()
        .add(const Duration(days: AppConfig.expiringSoonDays))
        .toIso8601String()
        .substring(0, 10);
    final expiring =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM medicines WHERE source = 'manual' AND expiry_date IS NOT NULL AND expiry_date <= ?",
            [cutoff],
          ),
        ) ??
        0;
    return {
      // `medicines` is the usable catalogue: every row with a complete core
      // identity (seeded, synced or manual) is searchable in the app.
      // `detailed` is the subset that also carries clinical sections, and
      // `catalog_total` stays the raw row count for the data screen.
      'medicines': total,
      'catalog_total': total,
      'detailed': detailed,
      'companies': companies,
      'generics': generics,
      'manual': manual,
      'expiring': expiring,
      'last_sync': await meta('last_sync_at'),
      'source': await meta('source_base'),
    };
  }

  Future<void> clearCatalog() async {
    await db.delete('medicines');
    await db.delete('translations');
    // Model outputs are derived from catalogue text, so they go with it.
    await db.delete('ai_cache');
    await setMeta('last_sync_at', null);
    // Forget the upstream baseline too, so the next connection re-verifies
    // against the server instead of reporting the wiped database as current.
    await setMeta(AppConfig.metaFingerprint, null);
    await setMeta(AppConfig.metaSourceDetailScraped, null);
  }

  Future<void> clearUserData() async {
    await db.transaction((txn) async {
      await txn.delete('favorites');
      await txn.delete('view_history');
      await txn.delete('search_history');
      await txn.delete('learning_progress');
      await txn.delete('quiz_results');
      await txn.delete('bookmarks');
      await txn.delete('ai_history');
      await txn.delete('conversations');
      // Recommendation ranks are derived from the reading history being cleared.
      await txn.delete('ai_cache');
    });
  }

  Future<void> resetEverything() async {
    await db.transaction((txn) async {
      await txn.delete('medicines');
      await txn.delete('favorites');
      await txn.delete('view_history');
      await txn.delete('search_history');
      await txn.delete('learning_progress');
      await txn.delete('quiz_results');
      await txn.delete('bookmarks');
      await txn.delete('ai_history');
      await txn.delete('conversations');
      await txn.delete('translations');
      await txn.delete('ai_cache');
      await txn.delete('meta');
    });
  }
}
