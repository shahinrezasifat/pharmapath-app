// Builds the offline seed database shipped with the app.
//
// Fetches the entire catalogue from the local BD Medicine API
// (https://github.com/NasirSunny50/Bangladeshi-Medicine-API, default
// http://127.0.0.1:8000 — the same server an Android emulator reaches at
// http://10.0.2.2:8000) and writes a SQLite file whose schema is identical to
// lib/data/app_database.dart, including the FTS5 index and triggers.
//
// Usage:
//   dart run tool/build_seed_db.dart \
//     --api http://127.0.0.1:8000 \
//     --out assets/learning/medicines_seed.db \
//     [--concurrency 24] [--no-details]
//
// The app installs this asset verbatim on a fresh install (see
// lib/services/seed_database.dart), so the shipped app is 100% offline
// without ever contacting the API. Re-run this tool whenever the upstream
// dataset changes and bump AppDatabase.seedVersion.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _defaultApi = 'http://127.0.0.1:8000';
const _defaultOut = 'assets/learning/medicines_seed.db';

void main(List<String> args) async {
  final api = _arg(args, '--api') ?? _defaultApi;
  // Resolve to an absolute path: the sqflite FFI factory remaps any relative
  // database name into its own sandbox directory, which would defeat the
  // final rename into assets/.
  final out = File(_arg(args, '--out') ?? _defaultOut).absolute.path;
  final concurrency = int.tryParse(_arg(args, '--concurrency') ?? '') ?? 24;
  final withDetails = !args.contains('--no-details');

  _stdout('API      : $api');
  _stdout('Output   : $out');
  _stdout('Workers  : $concurrency');

  final client = HttpClient()
    ..maxConnectionsPerHost = concurrency
    ..connectionTimeout = const Duration(seconds: 10);

  try {
    final stopwatch = Stopwatch()..start();
    final stats = await _getJson(
      client,
      '$api/stats',
      retries: 3,
    ) as Map<String, dynamic>;
    final totalRemote = (stats['total_medicines'] as num?)?.toInt() ?? 0;
    _stdout(
      'Remote   : $totalRemote medicines, ${stats['distinct_companies']} companies, '
      '${stats['distinct_generics']} generics',
    );

    // 1. Page through the full listing (limit is capped at 100 server-side).
    final listing = <Map<String, dynamic>>[];
    var page = 1;
    var totalPages = 1;
    while (page <= totalPages) {
      final payload = await _retry('listing page $page', () async {
        final body = await _getJson(
          client,
          '$api/medicines?page=$page&limit=100',
        );
        return body as Map<String, dynamic>;
      });
      totalPages = (payload['total_pages'] as num?)?.toInt() ?? page;
      final results = (payload['results'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      listing.addAll(results);
      _progress(
        'listing',
        listing.length,
        totalPages == 0 ? 1 : totalPages,
        page,
      );
      if (results.isEmpty) break;
      page++;
    }
    _stdout('Listing  : ${listing.length} rows fetched');

    // 2. Fetch every detail record concurrently. Not-yet-scraped ids answer
    //    instantly with just the summary fields; 404 means an id gap.
    final details = <int, Map<String, dynamic>>{};
    if (withDetails) {
      final ids =
          listing
              .map((e) => (e['id'] as num?)?.toInt() ?? 0)
              .where((id) => id > 0)
              .toList()
            ..sort();
      final maxId = ids.isEmpty ? 0 : ids.last;
      var done = 0, found = 0, missing = 0, failed = 0;
      final queue = ListQueue<int>.from(ids);
      await Future.wait(
        List.generate(concurrency, (_) async {
          while (queue.isNotEmpty) {
            final id = queue.removeFirst();
            try {
              final body = await _getJson(
                client,
                '$api/medicines/$id',
                notFoundOk: true,
              );
              if (body is Map) {
                details[id] = body.cast<String, dynamic>();
                found++;
              } else {
                missing++;
              }
            } catch (_) {
              failed++;
            }
            done++;
            _progressRaw(
              'details $done/$maxId (ok $found, gap $missing, err $failed)',
            );
          }
        }),
      );
      _stdout(
        'Details  : ${details.length} records (${_countScraped(details)} with clinical text)',
      );
    }

    // 3. Build the SQLite file. Write the temp next to the destination so the
    //    final rename never crosses a filesystem/mount boundary.
    final tmpPath = '$out.build-tmp.db';
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      final stale = File('$tmpPath$suffix');
      if (await stale.exists()) await stale.delete();
    }
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(tmpPath);
    await _createSchema(db);
    // Stamp the schema version the app expects (v2 has the inventory columns),
    // so opening the copied seed neither runs onCreate nor onUpgrade.
    await db.execute('PRAGMA user_version = 2');
    await _insertMedicines(db, listing, details);
    await _insertMeta(db, api, stats, listing.length, details.length);
    await db.execute(
      'INSERT INTO medicines_fts(medicines_fts) VALUES(\'rebuild\')',
    );
    // Close checkpoints the WAL so the single .db file carries every row.
    await db.close();
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      final stray = File('$tmpPath$suffix');
      if (await stray.exists()) await stray.delete();
    }
    await File(tmpPath).rename(out);

    final bytes = await File(out).length();
    _stdout(
      'Built    : $out (${(bytes / 1024 / 1024).toStringAsFixed(1)} MB) in '
      '${stopwatch.elapsed.toString().split('.').first}',
    );
  } finally {
    client.close(force: true);
  }
}

int _countScraped(Map<int, Map<String, dynamic>> details) => details.values
    .where(
      (m) =>
          (m['detail_scraped'] == 1 || m['detail_scraped'] == true) ||
          _hasClinical(m),
    )
    .length;

bool _hasClinical(Map<String, dynamic> m) {
  const clinicalKeys = [
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
  ];
  for (final key in clinicalKeys) {
    final value = m[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return true;
  }
  final sections = m['sections'];
  return sections is Map && sections.isNotEmpty;
}

// ---------------------------------------------------------------------------
// Schema — keep in lockstep with lib/data/app_database.dart (_createSchema).
// ---------------------------------------------------------------------------

Future<void> _createSchema(Database db) async {
  await db.execute('PRAGMA foreign_keys = ON');
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
      image_url TEXT
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
    CREATE TABLE ai_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      role TEXT NOT NULL,
      content TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE meta (
      key TEXT PRIMARY KEY,
      value TEXT
    )
  ''');
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
}

Future<void> _insertMedicines(
  Database db,
  List<Map<String, dynamic>> listing,
  Map<int, Map<String, dynamic>> details,
) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final seen = <int>{};
  await db.transaction((txn) async {
    final batch = txn.batch();
    for (final summary in listing) {
      final id = (summary['id'] as num?)?.toInt() ?? 0;
      if (id <= 0 || !seen.add(id)) continue;
      final record = details[id] ?? summary;
      // Never ship an incomplete record: require brand + generic + company +
      // dosage form + strength, matching the app's core-identity import rule.
      if (!_hasCoreIdentity(record)) continue;
      batch.insert(
        'medicines',
        _rowToDb(record, id, now),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    // Records only reachable via detail (shouldn't happen, but be safe).
    for (final entry in details.entries) {
      if (seen.contains(entry.key)) continue;
      seen.add(entry.key);
      batch.insert(
        'medicines',
        _rowToDb(entry.value, entry.key, now),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  });
}

Map<String, Object?> _rowToDb(Map<String, dynamic> m, int id, int now) {
  String? s(String key) {
    final value = m[key]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  int? i(String key) {
    final value = m[key];
    if (value is int) return value;
    if (value is bool) return value ? 1 : 0;
    return int.tryParse(value?.toString() ?? '');
  }

  final sectionsRaw = m['sections'];
  final sections = <String, String>{};
  if (sectionsRaw is Map) {
    sectionsRaw.forEach((key, value) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) sections[key.toString()] = text;
    });
  }

  // "Loaded" means the server actually returned clinical content, not merely
  // answered; summary-only rows keep detail_loaded = 0 so the app can still
  // lazily refresh them once the upstream scraper catches up.
  final scraped = i('detail_scraped') == 1 || _hasClinical(m);

  return {
    'id': id,
    'slug': s('slug'),
    'url': s('url'),
    'brand_name': s('brand_name') ?? 'নামহীন ওষুধ',
    'dosage_form': s('dosage_form'),
    'strength': s('strength'),
    'generic_name': s('generic_name'),
    'generic_id': i('generic_id'),
    'company': s('company'),
    'company_id': i('company_id'),
    'unit_price': s('unit_price'),
    'price_text': s('price_text'),
    'pack_sizes': s('pack_sizes'),
    'indications': s('indications'),
    'composition': s('composition'),
    'pharmacology': s('pharmacology'),
    'dosage_and_administration': s('dosage_and_administration'),
    'interaction': s('interaction'),
    'contraindications': s('contraindications'),
    'side_effects': s('side_effects'),
    'pregnancy_and_lactation': s('pregnancy_and_lactation'),
    'precautions_and_warnings': s('precautions_and_warnings'),
    'overdose_effects': s('overdose_effects'),
    'therapeutic_class': s('therapeutic_class'),
    'storage_conditions': s('storage_conditions'),
    'common_questions': s('common_questions'),
    'sections_json': sections.isEmpty ? null : jsonEncode(sections),
    'detail_loaded': scraped ? 1 : 0,
    'source': 'Bangladeshi-Medicine-API',
    'source_updated': s('last_updated') ?? s('first_seen'),
    'first_seen': now,
    'last_updated': now,
    // Shop-specific inventory never comes from the reference API; left null so
    // the app treats these rows as pure catalogue entries.
    'trade_price': null,
    'mrp': null,
    'stock_quantity': null,
    'batch_number': null,
    'rack_no': null,
    'mfg_date': null,
    'expiry_date': null,
    'image_url': null,
  };
}

bool _hasCoreIdentity(Map<String, dynamic> m) {
  bool ne(String key) {
    final v = m[key]?.toString().trim();
    return v != null && v.isNotEmpty;
  }

  return ne('brand_name') &&
      ne('generic_name') &&
      ne('company') &&
      ne('dosage_form') &&
      ne('strength');
}

Future<void> _insertMeta(
  Database db,
  String api,
  Map<String, dynamic> stats,
  int medicines,
  int details,
) async {
  final now = DateTime.now().toIso8601String();
  final values = {
    'last_sync_at': now,
    'source_base': api,
    'source_total':
        '${(stats['total_medicines'] as num?)?.toInt() ?? medicines}',
    'source_stats': jsonEncode(stats),
    'source_detail_scraped':
        '${(stats['detail_scraped'] as num?)?.toInt() ?? 0}',
    // Mirrors SyncService.fingerprint() exactly, so an install seeded from this
    // file is recognised as already up to date on its first connection and the
    // app shows "Already Downloaded" instead of re-crawling the API.
    'sync_fingerprint': _fingerprint(stats),
    'seed_medicines': '$medicines',
    'seed_details': '$details',
  };
  for (final entry in values.entries) {
    await db.insert('meta', {
      'key': entry.key,
      'value': entry.value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

/// Aggregate change signal; kept byte-identical to the app's SyncService so the
/// shipped seed and a runtime sync share one fingerprint format.
String _fingerprint(Map<String, dynamic> stats) {
  final run = stats['last_run'];
  final runPart = run is Map
      ? '${run['started_at']}~${run['finished_at']}~'
            '${run['new_count']}~${run['updated_count']}~${run['mode']}'
      : '';
  return 'v1|${stats['total_medicines']}|${stats['detail_scraped']}|'
      '${stats['pending_detail']}|${stats['distinct_companies']}|'
      '${stats['distinct_generics']}|$runPart';
}

// ---------------------------------------------------------------------------
// HTTP helpers with retry.
// ---------------------------------------------------------------------------

Future<Object?> _getJson(
  HttpClient client,
  String url, {
  bool notFoundOk = false,
  int retries = 0,
}) async {
  for (var attempt = 0; ; attempt++) {
    try {
      final request = await client.openUrl('GET', Uri.parse(url));
      request.headers.set('Accept', 'application/json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'PharmaPathSeedBuilder/2.0',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode == 404) {
        if (notFoundOk) return null;
        throw HttpException('404 $url');
      }
      if (response.statusCode >= 400) {
        throw HttpException('HTTP ${response.statusCode} $url');
      }
      return jsonDecode(body);
    } catch (error) {
      if (attempt >= retries) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
    }
  }
}

Future<T> _retry<T>(
  String label,
  Future<T> Function() action, {
  int attempts = 4,
}) async {
  Object? lastError;
  for (var attempt = 0; attempt < attempts; attempt++) {
    try {
      return await action();
    } catch (error) {
      lastError = error;
      await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
    }
  }
  throw StateError('Failed "$label": $lastError');
}

String? _arg(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index >= 0 && index + 1 < args.length) return args[index + 1];
  final prefix = '$name=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) return arg.substring(prefix.length);
  }
  return null;
}

void _stdout(String message) {
  _stdoutNewline();
  stdout.writeln(message);
}

int _lastProgressLength = 0;

void _stdoutNewline() {
  if (_lastProgressLength > 0) {
    stdout.write('\n');
    _lastProgressLength = 0;
  }
}

void _progressRaw(String label) {
  final text = '\r$label';
  if (text.length > 78) return; // avoid wrapping on narrow terminals
  // Overwrite any longer leftover line from the previous update.
  stdout.write(text.padRight(_lastProgressLength));
  _lastProgressLength = text.length;
}

void _progress(String label, int done, int totalUnits, int unit) {
  _progressRaw('$label: page $unit/$totalUnits ($done rows)');
}
