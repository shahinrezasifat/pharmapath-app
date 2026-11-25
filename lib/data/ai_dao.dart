import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// Persistence for the AI assistant: multiple named chat conversations, each
/// owning its message thread in `ai_history`.
class AiDao {
  AiDao(this._app);

  final AppDatabase _app;
  Database get _db => _app.db;

  /// Title given to a freshly created chat until the first user message names
  /// it (see [autoTitle]).
  static const defaultTitle = 'নতুন কথোপকথন';

  /// Most recent conversation, creating one so the assistant always has a
  /// thread to write into.
  Future<int> ensureLatestConversation() async {
    final rows = await _db.query(
      'conversations',
      columns: ['id'],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as int;
    return createConversation(defaultTitle);
  }

  Future<int> createConversation(String title) {
    return _db.insert('conversations', {
      'title': title,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Conversations newest-first, each carrying its message count and the
  /// timestamp of its last message (falling back to creation time).
  Future<List<Map<String, Object?>>> conversations() {
    return _db.rawQuery('''
      SELECT c.id, c.title, c.created_at,
             IFNULL((SELECT MAX(h.created_at) FROM ai_history h
                     WHERE h.conversation_id = c.id), c.created_at) AS updated_at,
             (SELECT COUNT(*) FROM ai_history h
              WHERE h.conversation_id = c.id) AS messages
      FROM conversations c
      ORDER BY updated_at DESC, c.id DESC
    ''');
  }

  /// Names an untouched conversation after its first user message.
  Future<void> autoTitle(int conversationId, String firstMessage) async {
    final compact = firstMessage.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) return;
    final title = compact.length <= 40
        ? compact
        : '${compact.substring(0, 40)}…';
    await _db.update(
      'conversations',
      {'title': title},
      where: 'id = ? AND title = ?',
      whereArgs: [conversationId, defaultTitle],
    );
  }

  Future<void> deleteConversation(int id) async {
    await _db.delete(
      'ai_history',
      where: 'conversation_id = ?',
      whereArgs: [id],
    );
    await _db.delete('conversations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addMessage(
    int conversationId,
    String role,
    String content, {
    String? attachmentsJson,
  }) async {
    await _db.insert('ai_history', {
      'conversation_id': conversationId,
      'role': role,
      'content': content,
      'attachments': attachmentsJson,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    // Keep each thread bounded without ever touching other conversations.
    await _db.rawDelete(
      '''
      DELETE FROM ai_history WHERE conversation_id = ? AND id NOT IN (
        SELECT id FROM ai_history WHERE conversation_id = ?
        ORDER BY id DESC LIMIT 80
      )
    ''',
      [conversationId, conversationId],
    );
  }

  /// Messages of one conversation, newest first.
  Future<List<Map<String, Object?>>> messagesFor(
    int conversationId, {
    int limit = 40,
  }) {
    return _db.query(
      'ai_history',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'id DESC',
      limit: limit,
    );
  }

  // ---------------------------------------------------------------------------
  // Model-output caches. Both are content-addressed: the row is only ever
  // returned when [sourceHash] of the current text matches the hash stored with
  // the output, so a re-synced medicine or an edited lesson invalidates its own
  // cache entry automatically and nothing else.
  // ---------------------------------------------------------------------------

  /// Stable fingerprint of the text an output was derived from.
  ///
  /// Two rolling hashes over a ~2^30 prime with a ~2^20 multiplier, so every
  /// intermediate stays below 2^50 and the digest is bit-identical on the Dart
  /// VM and in JavaScript/web builds. Only ever compared against the hash of
  /// another version of the same field, so a collision would merely serve one
  /// more page of stale Bangla until the next translation.
  static String sourceHash(String text) {
    final normalized = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    const modulus = 1073741789;
    var left = 5381;
    var right = 0x811c9dc5 % modulus;
    for (final unit in normalized.codeUnits) {
      left = (left * 1000003 + unit) % modulus;
      right = (right * 1043953 + left) % modulus;
    }
    return '${left.toRadixString(16)}-${right.toRadixString(16)}-${normalized.length.toRadixString(16)}';
  }

  /// Cached Bangla translation of one clinical field, or null when nothing
  /// usable is stored (never cached, or the English source has since changed).
  Future<String?> translation(
    int medicineId,
    String field,
    String srcHash,
  ) async {
    final rows = await _db.query(
      'translations',
      columns: ['bn'],
      where: 'medicine_id = ? AND field = ? AND src_hash = ?',
      whereArgs: [medicineId, field, srcHash],
      limit: 1,
    );
    final text = rows.isEmpty ? '' : (rows.first['bn'] as String? ?? '').trim();
    return text.isEmpty ? null : text;
  }

  /// Every cached field translation of one medicine that still matches its
  /// current source text. [hashes] maps field → hash of the English value.
  Future<Map<String, String>> translationsMatching(
    int medicineId,
    Map<String, String> hashes,
  ) async {
    if (hashes.isEmpty) return const {};
    final rows = await _db.query(
      'translations',
      columns: ['field', 'src_hash', 'bn'],
      where: 'medicine_id = ?',
      whereArgs: [medicineId],
    );
    final result = <String, String>{};
    for (final row in rows) {
      final field = row['field'] as String? ?? '';
      final expected = hashes[field];
      final text = (row['bn'] as String? ?? '').trim();
      if (expected == null || text.isEmpty) continue;
      if (row['src_hash'] == expected) result[field] = text;
    }
    return result;
  }

  Future<void> saveTranslation(
    int medicineId,
    String field,
    String srcHash,
    String bangla,
  ) async {
    final text = bangla.trim();
    if (text.isEmpty) return;
    await _db.insert('translations', {
      'medicine_id': medicineId,
      'field': field,
      'src_hash': srcHash,
      'bn': text,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Cached output of a one-shot task ([kind] — `lesson_summary`,
  /// `medicine_explain`, `recommendations`…), or null on a miss.
  Future<String?> cache(String kind, String ref, String srcHash) async {
    final rows = await _db.query(
      'ai_cache',
      columns: ['out'],
      where: 'kind = ? AND ref = ? AND src_hash = ?',
      whereArgs: [kind, ref, srcHash],
      limit: 1,
    );
    final text = rows.isEmpty
        ? ''
        : (rows.first['out'] as String? ?? '').trim();
    return text.isEmpty ? null : text;
  }

  Future<void> saveCache(
    String kind,
    String ref,
    String srcHash,
    String output,
  ) async {
    final text = output.trim();
    if (text.isEmpty) return;
    await _db.insert('ai_cache', {
      'kind': kind,
      'ref': ref,
      'src_hash': srcHash,
      'out': text,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
