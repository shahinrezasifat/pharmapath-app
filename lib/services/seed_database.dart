import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/app_config.dart';

/// Installs the prebuilt offline catalogue ([AppConfig.seedAssetPath]) into
/// app storage on a fresh install, so the app works 100% offline with no
/// network round-trip and no per-row insert cost — the whole SQLite file (FTS
/// index included) is copied verbatim.
///
/// Design notes:
/// * Only runs when no database file exists yet. Existing installs keep their
///   data; the normal [SyncService] refreshes them. This guarantees we never
///   clobber favourites, history or a newer user sync.
/// * The asset is a Flutter bundle resource, so it must be copied out of the
///   read-only asset store into a writable directory before SQLite can open it.
/// * Web has no filesystem SQLite here, so it is skipped.
abstract final class SeedInstaller {
  /// Returns true when a seed file was written to [dbPath].
  static Future<bool> installIfNeeded(String dbPath) async {
    if (AppConfig.seedDisabled) return false;
    if (kIsWeb) return false;

    final file = File(dbPath);
    // A database (even an empty one) already on disk means this is not a fresh
    // install — leave it untouched.
    if (await file.exists()) return false;

    try {
      late final ByteData data;
      try {
        data = await rootBundle.load(AppConfig.seedAssetPath);
      } on FlutterError {
        // Asset not bundled (e.g. a slim dev build). Not an error.
        return false;
      }
      // A valid SQLite page is 4096 bytes; anything smaller isn't our seed.
      if (data.lengthInBytes < 4096) return false;
      // Guard the "SQLite format 3\0" magic header before writing.
      final magic = String.fromCharCodes(
        data.buffer.asUint8List(data.offsetInBytes, 16),
      );
      if (!magic.startsWith('SQLite format 3')) return false;

      final dir = file.parent;
      if (!await dir.exists()) await dir.create(recursive: true);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      return true;
    } catch (error) {
      // Never let seeding block startup; an empty DB still syncs normally.
      debugPrint('Seed install skipped: $error');
      return false;
    }
  }
}
