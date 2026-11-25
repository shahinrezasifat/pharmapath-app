import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/app_config.dart';
import '../data/app_database.dart';

class BackupInfo {
  const BackupInfo({
    required this.file,
    required this.createdAt,
    required this.bytes,
  });

  final File file;
  final DateTime createdAt;
  final int bytes;
}

/// Exports user data (never the AI key) to a JSON file and restores it.
///
/// The file is written to the app documents directory. On Android that is
/// app-private storage, so a production build should add a system share/save
/// dialog; this is documented as a limitation rather than hidden.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  static const _version = 1;

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'pharmapath_backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<BackupInfo> export() async {
    final data = <String, dynamic>{
      'app': 'PharmaPath',
      'version': _version,
      'app_version': AppConfig.version,
      'created_at': DateTime.now().toIso8601String(),
      'settings': {'api_base': await _db.meta('source_base')},
      'favorites': await _db.db.query('favorites'),
      'view_history': await _db.db.query('view_history'),
      'search_history': await _db.db.query('search_history'),
      'learning_progress': await _db.db.query('learning_progress'),
      'bookmarks': await _db.db.query('bookmarks'),
      'quiz_results': await _db.db.query('quiz_results'),
    };

    final dir = await _dir();
    final stamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final file = File(p.join(dir.path, 'pharmapath_backup_$stamp.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    return BackupInfo(
      file: file,
      createdAt: DateTime.now(),
      bytes: await file.length(),
    );
  }

  Future<List<BackupInfo>> listBackups() async {
    final dir = await _dir();
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.json'))
        .cast<File>()
        .toList();
    final infos = <BackupInfo>[];
    for (final file in files) {
      final stat = await file.stat();
      infos.add(
        BackupInfo(file: file, createdAt: stat.modified, bytes: stat.size),
      );
    }
    infos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return infos;
  }

  Future<void> restore(File file) async {
    final raw = await file.readAsString();
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('ব্যাকআপ ফাইলটি বৈধ JSON নয়।');
    }
    if (decoded is! Map || decoded['app'] != 'PharmaPath') {
      throw const FormatException('এটি PharmaPath ব্যাকআপ ফাইল নয়।');
    }
    final version = int.tryParse(decoded['version']?.toString() ?? '') ?? 0;
    if (version > _version) {
      throw const FormatException(
        'ব্যাকআপটি অ্যাপের নতুন সংস্করণের; এই সংস্করণে খোলা যাবে না।',
      );
    }

    List<Map<String, Object?>> rows(String key) {
      final value = decoded[key];
      if (value is! List) return const [];
      return value.whereType<Map>().map((e) {
        return e.map((k, v) => MapEntry(k.toString(), v));
      }).toList();
    }

    await _db.db.transaction((txn) async {
      for (final key in const [
        'favorites',
        'view_history',
        'search_history',
        'learning_progress',
        'bookmarks',
        'quiz_results',
      ]) {
        await txn.delete(key);
        for (final row in rows(key)) {
          await txn.insert(
            key,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<void> deleteAllBackups() async {
    final dir = await _dir();
    await for (final entity in dir.list()) {
      if (entity is File) await entity.delete();
    }
  }

  // ---- Whole-catalogue snapshot ------------------------------------------
  //
  // The JSON backup above only carries user data. These helpers snapshot the
  // *entire* SQLite database — the downloaded medicine catalogue included — so
  // a device can be moved or wiped and restored without re-hitting the API.
  // Export uses SQLite's `VACUUM INTO` (a single, consistent, compacted copy;
  // it works while the connection is live). Restore `ATTACH`es the snapshot and
  // copies every table back in place, then rebuilds the FTS index. Both run on
  // the already-open connection, so no restart or re-open is needed.

  static const _catalogTables = [
    'medicines', // first: favourites/view_history cascade from it
    'favorites',
    'view_history',
    'search_history',
    'learning_progress',
    'bookmarks',
    'quiz_results',
    'conversations', // before ai_history: messages reference their thread
    'ai_history',
    'translations',
    'ai_cache',
    'meta',
  ];

  /// Writes a compact `.db` snapshot of the current database to storage.
  Future<BackupInfo> exportCatalog() async {
    final dir = await _dir();
    final stamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final file = File(p.join(dir.path, 'pharmapath_catalog_$stamp.db'));
    if (await file.exists()) await file.delete();
    await _db.db.execute('VACUUM INTO ${_sqlLit(file.path)}');
    return BackupInfo(
      file: file,
      createdAt: DateTime.now(),
      bytes: await file.length(),
    );
  }

  /// Lists catalogue `.db` snapshots, newest first.
  Future<List<BackupInfo>> listCatalogSnapshots() async {
    final dir = await _dir();
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.db'))
        .cast<File>()
        .toList();
    final infos = <BackupInfo>[];
    for (final file in files) {
      final stat = await file.stat();
      infos.add(
        BackupInfo(file: file, createdAt: stat.modified, bytes: stat.size),
      );
    }
    infos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return infos;
  }

  /// Replaces the live database's contents with those of [file].
  Future<void> restoreCatalog(File file) async {
    if (!await file.exists()) {
      throw const FormatException('স্ন্যাপশট ফাইলটি খুঁজে পাওয়া যায়নি।');
    }
    await _db.db.execute('ATTACH DATABASE ${_sqlLit(file.path)} AS snap');
    try {
      // Confirm the snapshot is a PharmaPath database before touching anything.
      final ok = await _db.db.rawQuery(
        "SELECT 1 FROM snap.sqlite_master WHERE type='table' AND name='medicines' "
        'LIMIT 1',
      );
      if (ok.isEmpty) {
        throw const FormatException('ফাইলটি বৈধ PharmaPath ডেটাবেস নয়।');
      }
      await _db.db.transaction((txn) async {
        for (final table in _catalogTables) {
          // A snapshot taken by an older app may not have a table that exists
          // now (e.g. `translations`); skip those instead of failing the
          // restore — the live table is already empty from the delete below.
          final present = await _db.db.rawQuery(
            "SELECT 1 FROM snap.sqlite_master WHERE type='table' AND name=? LIMIT 1",
            [table],
          );
          await txn.execute('DELETE FROM $table');
          if (present.isEmpty) continue;
          // Copy only the columns both versions share, in the live order. An
          // older snapshot simply lacks the newest column (e.g. the reading
          // history added in v7) instead of shifting every value sideways.
          final live = await _db.db.rawQuery('PRAGMA table_info($table)');
          final snap = await _db.db.rawQuery('PRAGMA snap.table_info($table)');
          final snapNames = snap.map((c) => c['name'].toString()).toSet();
          final common = live
              .map((c) => c['name'].toString())
              .where(snapNames.contains)
              .toList();
          if (common.isEmpty) continue;
          final columns = common.map((c) => '"$c"').join(', ');
          await txn.execute(
            'INSERT INTO $table ($columns) SELECT $columns FROM snap.$table',
          );
        }
      });
      // Triggers already kept FTS roughly in sync; rebuild guarantees an exact
      // index over the restored rows (contentless-external FTS5).
      await _db.db.execute(
        "INSERT INTO medicines_fts(medicines_fts) VALUES('rebuild')",
      );
    } finally {
      await _db.db.execute('DETACH DATABASE snap');
    }
  }

  /// Escapes [v] as a single-quoted SQLite string literal.
  static String _sqlLit(String v) => "'${v.replaceAll("'", "''")}'";

  // ---- Portable ZIP bundle (SD-card / file-manager friendly) --------------
  //
  // The dataset a user downloads is tied to one source server, so an export
  // ships the whole database *plus* a manifest that records which server it
  // came from, when it was taken, and how many rows it holds. The bundle is a
  // plain .zip — the user can keep it on an SD card and later restore it from
  // any file manager, with no re-download and no dependency on the app's own
  // private storage. The encode/decode helpers are pure so they can be tested
  // without a live database or the file-picker plugin.
  static const _dbEntryName = 'pharmapath_data.db';
  static const _manifestName = 'manifest.json';

  /// Bump when the bundle layout changes; restore rejects a newer version.
  static const int catalogZipFormatVersion = 1;

  /// Builds a .zip byte buffer from a SQLite database and its manifest.
  static List<int> zipBundle(List<int> dbBytes, Map<String, dynamic> manifest) {
    final manifestBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );
    final archive = Archive();
    archive.addFile(ArchiveFile(_dbEntryName, dbBytes.length, dbBytes));
    archive.addFile(
      ArchiveFile(_manifestName, manifestBytes.length, manifestBytes),
    );
    return ZipEncoder().encode(archive);
  }

  /// Reads and validates a bundle produced by [zipBundle].
  static ({Uint8List dbBytes, Map<String, dynamic> manifest}) unzipBundle(
    List<int> zipBytes,
  ) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    Uint8List? db;
    Map<String, dynamic>? manifest;
    for (final f in archive.files) {
      if (!f.isFile) continue;
      if (f.name == _dbEntryName) {
        db = f.content;
      } else if (f.name == _manifestName) {
        final decoded = jsonDecode(utf8.decode(f.content));
        if (decoded is Map) manifest = decoded.cast<String, dynamic>();
      }
    }
    if (db == null || manifest == null) {
      throw const FormatException(
        'জিপ ফাইলে ডেটাবেস বা ম্যানিফেস্ট পাওয়া যায়নি।',
      );
    }
    if (manifest['app'] != 'PharmaPath') {
      throw const FormatException('এটি PharmaPath ডেটা ব্যাকআপ নয়।');
    }
    final version =
        int.tryParse(manifest['format_version']?.toString() ?? '') ?? 0;
    if (version > catalogZipFormatVersion) {
      throw const FormatException(
        'ব্যাকআপটি অ্যাপের নতুন সংস্করণের; এই সংস্করণে রিস্টোর করা যাবে না।',
      );
    }
    return (dbBytes: db, manifest: manifest);
  }

  /// Describes the current database so an export carries its source identity.
  Future<Map<String, dynamic>> _catalogManifest(int dbBytes) async {
    final stats = await _db.stats();
    return {
      'app': 'PharmaPath',
      'format_version': catalogZipFormatVersion,
      'app_version': AppConfig.version,
      'db_version': 2,
      'created_at': DateTime.now().toIso8601String(),
      'source_base': await _db.meta(AppConfig.metaSourceBase),
      'sync_fingerprint': await _db.meta(AppConfig.metaFingerprint),
      'counts': {
        'medicines': stats['medicines'],
        'detailed': stats['detailed'],
        'manual': stats['manual'],
        'favorites': (await _db.db.query('favorites')).length,
      },
      'db_bytes': dbBytes,
    };
  }

  /// Snapshots the live database and packages it as a portable .zip buffer.
  Future<({List<int> bytes, Map<String, dynamic> manifest, String fileName})>
  exportCatalogZip() async {
    final tmp = await getTemporaryDirectory();
    final now = DateTime.now();
    final stamp = now.toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final dbFile = File(p.join(tmp.path, 'pharmapath_export_$stamp.db'));
    if (await dbFile.exists()) await dbFile.delete();
    await _db.db.execute('VACUUM INTO ${_sqlLit(dbFile.path)}');
    final dbBytes = await dbFile.readAsBytes();
    final manifest = await _catalogManifest(dbBytes.length);
    final bytes = zipBundle(dbBytes, manifest);
    await dbFile.delete();
    return (
      bytes: bytes,
      manifest: manifest,
      fileName: 'pharmapath_backup_$stamp.zip',
    );
  }

  /// Restores the whole database from a .zip buffer produced by
  /// [exportCatalogZip]. Returns the manifest of the restored dataset.
  Future<Map<String, dynamic>> restoreCatalogFromZip(List<int> zipBytes) async {
    final bundle = unzipBundle(zipBytes);
    final tmp = await getTemporaryDirectory();
    final dbFile = File(
      p.join(
        tmp.path,
        'pharmapath_restore_${DateTime.now().millisecondsSinceEpoch}.db',
      ),
    );
    await dbFile.writeAsBytes(bundle.dbBytes, flush: true);
    try {
      await restoreCatalog(dbFile);
    } finally {
      if (await dbFile.exists()) await dbFile.delete();
    }
    return bundle.manifest;
  }
}
