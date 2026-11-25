import 'package:sqflite/sqflite.dart';

import '../core/app_config.dart';
import '../models/medicine.dart';
import 'app_database.dart';

class MedicineDao {
  MedicineDao(this._app, {this.pageSize = 20});

  final AppDatabase _app;
  final int pageSize;

  Database get _db => _app.db;
  bool get _fts => _app.ftsAvailable;

  Future<MedicinePage> search({
    String query = '',
    String? company,
    String? generic,
    String? dosageForm,
    List<String>? dosageForms,
    int page = 1,
    int? limit,
  }) async {
    final size = limit ?? pageSize;
    final offset = (page - 1) * size;
    final term = query.trim();
    // The whole catalogue is searchable: every seeded/synced row carries a
    // complete core identity (brand, generic, company, form, strength), and
    // summary-only rows simply open the detail page without clinical text.
    final filters = <String>[];
    final filterArgs = <Object?>[];

    if (company != null && company.trim().isNotEmpty) {
      filters.add('m.company LIKE ?');
      filterArgs.add('%${company.trim()}%');
    }
    if (generic != null && generic.trim().isNotEmpty) {
      filters.add('m.generic_name LIKE ?');
      filterArgs.add('%${generic.trim()}%');
    }
    if (dosageForm != null && dosageForm.trim().isNotEmpty) {
      filters.add('m.dosage_form = ?');
      filterArgs.add(dosageForm.trim());
    }
    if (dosageForms != null && dosageForms.isNotEmpty) {
      // Bengali category chips filter on every raw API string that classifies
      // into the category ("Tablet", "Tablet (Extended Release)"…).
      filters.add(
        'm.dosage_form IN (${List<String>.filled(dosageForms.length, '?').join(',')})',
      );
      filterArgs.addAll(dosageForms);
    }

    if (term.isEmpty) {
      final where = filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')}';
      final total =
          Sqflite.firstIntValue(
            await _db.rawQuery(
              'SELECT COUNT(*) FROM medicines m $where',
              filterArgs,
            ),
          ) ??
          0;
      final rows = await _db.rawQuery(
        'SELECT m.* FROM medicines m $where ORDER BY m.brand_name COLLATE NOCASE LIMIT ? OFFSET ?',
        [...filterArgs, size, offset],
      );
      return MedicinePage(
        items: rows.map(Medicine.fromDb).toList(),
        page: page,
        totalPages: total == 0 ? 0 : (total / size).ceil(),
        total: total,
      );
    }

    final match = _ftsQuery(term);
    if (_fts && match != null) {
      final where = filters.isEmpty ? '' : ' AND ${filters.join(' AND ')}';
      try {
        final total =
            Sqflite.firstIntValue(
              await _db.rawQuery(
                'SELECT COUNT(*) FROM medicines_fts f JOIN medicines m ON m.id = f.rowid '
                'WHERE medicines_fts MATCH ?$where',
                [match, ...filterArgs],
              ),
            ) ??
            0;
        final rows = await _db.rawQuery(
          'SELECT m.* FROM medicines_fts f JOIN medicines m ON m.id = f.rowid '
          'WHERE medicines_fts MATCH ?$where ORDER BY bm25(medicines_fts) LIMIT ? OFFSET ?',
          [match, ...filterArgs, size, offset],
        );
        return MedicinePage(
          items: rows.map(Medicine.fromDb).toList(),
          page: page,
          totalPages: total == 0 ? 0 : (total / size).ceil(),
          total: total,
        );
      } on DatabaseException {
        // Fall through to LIKE if the index is inconsistent.
      }
    }

    final likeFilters = <String>[
      '(m.brand_name LIKE ? OR m.generic_name LIKE ? OR m.company LIKE ? '
          'OR m.strength LIKE ? OR m.dosage_form LIKE ? OR m.therapeutic_class LIKE ?)',
    ];
    final likeArgs = List<Object?>.filled(6, '%$term%');
    final where = [likeFilters.first, ...filters].join(' AND ');
    final args = [...likeArgs, ...filterArgs];

    final total =
        Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COUNT(*) FROM medicines m WHERE $where',
            args,
          ),
        ) ??
        0;
    final rows = await _db.rawQuery(
      'SELECT m.* FROM medicines m WHERE $where '
      'ORDER BY CASE WHEN m.brand_name LIKE ? THEN 0 ELSE 1 END, m.brand_name COLLATE NOCASE '
      'LIMIT ? OFFSET ?',
      [...args, '$term%', size, offset],
    );
    return MedicinePage(
      items: rows.map(Medicine.fromDb).toList(),
      page: page,
      totalPages: total == 0 ? 0 : (total / size).ceil(),
      total: total,
    );
  }

  /// Medicines that share [generic]'s exact active ingredient *and* the exact
  /// [strength] (case/whitespace-insensitive, e.g. "500 mg" = "500mg"), made
  /// by other manufacturers — the "find similar" list. When [strength] is
  /// null or blank the match falls back to generic-only. The current medicine
  /// ([excludeId]) is left out. Results are grouped by company, then brand.
  Future<List<Medicine>> findSimilarByGeneric(
    String generic, {
    String? strength,
    int? excludeId,
    int limit = 100,
  }) async {
    final key = generic.trim().toLowerCase();
    if (key.isEmpty) return const [];
    final strengthKey = (strength ?? '')
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
    final strengthClause = strengthKey.isEmpty
        ? ''
        : "AND REPLACE(REPLACE(LOWER(COALESCE(strength,'')),' ',''),char(9),'') = ?";
    final args = <Object?>[key];
    if (strengthKey.isNotEmpty) args.add(strengthKey);
    args.add(excludeId ?? -1);
    final rows = await _db.rawQuery(
      '''
      SELECT * FROM medicines
      WHERE generic_name IS NOT NULL
        AND LOWER(TRIM(generic_name)) = ?
        $strengthClause
        AND id != ?
      ORDER BY company COLLATE NOCASE, brand_name COLLATE NOCASE
      LIMIT ?
    ''',
      [...args, limit],
    );
    return rows.map(Medicine.fromDb).toList();
  }

  /// One representative medicine per curated token (exact brand name, falling
  /// back to any medicine whose generic matches), returned in token order and
  /// capped at [cap]. Prefers rows that carry clinical detail, then the
  /// earliest catalogue id, so "Napa" resolves to the familiar 500 mg tablet.
  Future<List<Medicine>> featuredMedicines(
    List<String> tokens, {
    int cap = 100,
  }) async {
    if (tokens.isEmpty) return const [];
    final keys = tokens.map((e) => e.trim().toLowerCase()).toList();
    final placeholders = List<String>.filled(keys.length, '?').join(',');
    final rows = await _db.rawQuery(
      '''
      SELECT * FROM medicines
      WHERE LOWER(TRIM(brand_name)) IN ($placeholders)
         OR LOWER(TRIM(generic_name)) IN ($placeholders)
      ORDER BY detail_loaded DESC, id ASC
    ''',
      [...keys, ...keys],
    );
    // Bucket candidate rows per token, brand matches taking priority.
    final byBrand = <String, List<Medicine>>{};
    final byGeneric = <String, List<Medicine>>{};
    for (final row in rows.map(Medicine.fromDb)) {
      final brand = row.brandName.trim().toLowerCase();
      final generic = (row.genericName ?? '').trim().toLowerCase();
      if (brand == generic) continue;
      byBrand.putIfAbsent(brand, () => []).add(row);
    }
    for (final row in rows.map(Medicine.fromDb)) {
      final generic = (row.genericName ?? '').trim().toLowerCase();
      if (generic.isEmpty) continue;
      byGeneric.putIfAbsent(generic, () => []).add(row);
    }
    final picked = <Medicine>[];
    final used = <int>{};
    for (final key in keys) {
      if (picked.length >= cap) break;
      Medicine? candidate;
      for (final m in [...?byBrand[key], ...?byGeneric[key]]) {
        if (used.add(m.id)) {
          candidate = m;
          break;
        }
      }
      if (candidate != null) picked.add(candidate);
    }
    return picked;
  }

  /// Medicines whose stored *indications* or *therapeutic class* text mentions
  /// [term] (case-insensitive substring). This reads the "which disease this
  /// medicine treats" knowledge that already lives inside each catalogue row, so
  /// the assistant can answer a disease question straight from the database
  /// rather than relying only on a curated mapping. Detailed rows come first.
  Future<List<Medicine>> searchByIndication(
    String term, {
    int limit = 12,
  }) async {
    final value = term.trim();
    if (value.isEmpty) return const [];
    final like = '%$value%';
    final rows = await _db.rawQuery(
      '''
      SELECT * FROM medicines
      WHERE indications LIKE ? OR therapeutic_class LIKE ?
      ORDER BY detail_loaded DESC, brand_name COLLATE NOCASE
      LIMIT ?
    ''',
      [like, like, limit],
    );
    return rows.map(Medicine.fromDb).toList();
  }

  /// Searches medicines specifically for a target clinical condition or disease.
  /// Combines [disease] with any [keywords] and ranks direct indications matches first.
  Future<List<Medicine>> searchByDisease(
    String disease, {
    List<String> keywords = const [],
    int limit = 60,
  }) async {
    final clean = disease.trim();
    if (clean.isEmpty) return const [];

    final terms = <String>{clean, ...keywords.map((k) => k.trim())}
        .where((t) => t.isNotEmpty)
        .toList();

    final whereParts = <String>[];
    final args = <Object?>[];

    for (final term in terms) {
      whereParts.add(
        '(indications LIKE ? OR therapeutic_class LIKE ? OR generic_name LIKE ? OR brand_name LIKE ?)',
      );
      final like = '%$term%';
      args.addAll([like, like, like, like]);
    }

    final query = '''
      SELECT * FROM medicines
      WHERE ${whereParts.join(' OR ')}
      ORDER BY 
        CASE 
          WHEN indications LIKE ? THEN 0
          WHEN generic_name LIKE ? THEN 1
          ELSE 2
        END,
        detail_loaded DESC,
        brand_name COLLATE NOCASE
      LIMIT ?
    ''';
    args.add('%$clean%');
    args.add('%$clean%');
    args.add(limit);

    final rows = await _db.rawQuery(query, args);
    return rows.map(Medicine.fromDb).toList();
  }

  Future<Medicine?> byId(int id) async {
    final rows = await _db.query(
      'medicines',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Medicine.fromDb(rows.first);
  }

  Future<void> saveDetail(Medicine medicine) => _app.upsertDetail(medicine);

  /// Persists a fully-validated manual medicine and returns its allocated id.
  Future<int> addManualMedicine(Medicine medicine) =>
      _app.insertManualMedicine(medicine);

  /// Manual stock expiring within [days] days (expired included), soonest first.
  Future<List<Medicine>> expiringSoon({int? days}) =>
      _app.medicinesExpiringWithin(days ?? AppConfig.expiringSoonDays);

  /// Bulk detail write used by the sync engine's initial download and delta
  /// refresh. [sourceUpdated] stamps the API's content timestamp when known.
  Future<void> saveDetailsBatch(
    List<Medicine> medicines, {
    String? sourceUpdated,
  }) => _app.upsertDetailBatch(medicines, sourceUpdated: sourceUpdated);

  Future<List<Medicine>> favorites() async {
    final rows = await _db.rawQuery('''
      SELECT m.* FROM favorites f JOIN medicines m ON m.id = f.medicine_id
      ORDER BY f.created_at DESC
    ''');
    return rows.map(Medicine.fromDb).toList();
  }

  Future<bool> isFavorite(int id) async {
    final rows = await _db.query(
      'favorites',
      where: 'medicine_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> toggleFavorite(int id) async {
    final exists = await isFavorite(id);
    if (exists) {
      await _db.delete('favorites', where: 'medicine_id = ?', whereArgs: [id]);
      return false;
    }
    await _db.insert('favorites', {
      'medicine_id': id,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return true;
  }

  Future<void> recordView(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insert('view_history', {
      'medicine_id': id,
      'viewed_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _db.rawDelete('''
      DELETE FROM view_history WHERE medicine_id NOT IN (
        SELECT medicine_id FROM view_history ORDER BY viewed_at DESC LIMIT 50
      )
    ''');
  }

  Future<List<Medicine>> recentlyViewed({int limit = 8}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT m.* FROM view_history v JOIN medicines m ON m.id = v.medicine_id
      ORDER BY v.viewed_at DESC LIMIT ?
    ''',
      [limit],
    );
    return rows.map(Medicine.fromDb).toList();
  }

  Future<void> addSearchTerm(String term) async {
    final value = term.trim();
    if (value.isEmpty) return;
    await _db.insert('search_history', {
      'query': value,
      'used_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _db.rawDelete('''
      DELETE FROM search_history WHERE query NOT IN (
        SELECT query FROM search_history ORDER BY used_at DESC LIMIT 20
      )
    ''');
  }

  /// Medicines that match the user's recent search terms, used as the default
  /// list on the search screen.
  Future<List<Medicine>> fromSearchHistory(
    List<String> terms, {
    int perTerm = 3,
    int max = 12,
  }) async {
    if (terms.isEmpty) return const [];
    final seen = <int, Medicine>{};
    for (final raw in terms) {
      if (seen.length >= max) break;
      final term = raw.trim();
      if (term.isEmpty) continue;
      final like = '%$term%';
      final rows = await _db.rawQuery(
        '''
        SELECT * FROM medicines
        WHERE (brand_name LIKE ? OR generic_name LIKE ? OR company LIKE ?)
        ORDER BY CASE WHEN brand_name LIKE ? THEN 0 ELSE 1 END,
                 brand_name COLLATE NOCASE
        LIMIT ?
      ''',
        [like, like, like, '$term%', perTerm],
      );
      for (final row in rows) {
        final medicine = Medicine.fromDb(row);
        seen.putIfAbsent(medicine.id, () => medicine);
      }
    }
    return seen.values.toList();
  }

  Future<List<String>> searchHistory({int limit = 10}) async {
    final rows = await _db.query(
      'search_history',
      orderBy: 'used_at DESC',
      limit: limit,
    );
    return rows.map((e) => e['query'] as String).toList();
  }

  Future<void> clearSearchHistory() => _db.delete('search_history');

  Future<List<Map<String, Object?>>> topCompanies({int limit = 8}) async {
    return _db.rawQuery(
      '''
      SELECT company AS name, COUNT(*) AS count FROM medicines
      WHERE company IS NOT NULL AND company != ''
      GROUP BY company ORDER BY count DESC LIMIT ?
    ''',
      [limit],
    );
  }

  Future<List<Map<String, Object?>>> topGenerics({int limit = 8}) async {
    return _db.rawQuery(
      '''
      SELECT generic_name AS name, COUNT(*) AS count FROM medicines
      WHERE generic_name IS NOT NULL AND generic_name != ''
      GROUP BY generic_name ORDER BY count DESC LIMIT ?
    ''',
      [limit],
    );
  }

  /// Every raw `dosage_form` string present in the catalogue. The search
  /// screen buckets these into the Bengali category chips via
  /// `MedicineForm.classify`, so a chip matches all its spelling variants.
  Future<List<String>> distinctDosageForms() async {
    final rows = await _db.rawQuery(
      "SELECT DISTINCT dosage_form FROM medicines WHERE dosage_form IS NOT NULL AND TRIM(dosage_form) != ''",
    );
    return rows
        .map((e) => (e['dosage_form'] as String?)?.trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String? _ftsQuery(String input) {
    final tokens = input
        .replaceAll(RegExp(r'["\u0000-\u001f]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .take(8)
        .toList();
    if (tokens.isEmpty) return null;
    return tokens.map((t) => '"${t.replaceAll('"', '""')}"*').join(' AND ');
  }
}
