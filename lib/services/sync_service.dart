import 'dart:collection';
import 'dart:convert';

import '../core/api_exception.dart';
import '../core/app_config.dart';
import '../data/app_database.dart';
import '../data/medicine_dao.dart';
import '../models/medicine.dart';
import 'medicine_api.dart';

enum SyncPhase { connecting, listing, details }

/// Human-readable phase caption for the sync UI.
extension SyncPhaseLabel on SyncPhase {
  String get label => switch (this) {
    SyncPhase.connecting => 'সংযোগ হচ্ছে…',
    SyncPhase.listing => 'তালিকা যাচাই হচ্ছে…',
    SyncPhase.details => 'বিস্তারিত ডাউনলোড হচ্ছে…',
  };
}

class SyncProgress {
  const SyncProgress({
    required this.phase,
    required this.page,
    required this.totalPages,
    required this.imported,
    required this.total,
    this.details = 0,
    this.detailTotal = 0,
    this.newRecords = 0,
    this.updatedRecords = 0,
  });

  final SyncPhase phase;
  final int page;
  final int totalPages;
  final int imported;
  final int total;
  final int details;
  final int detailTotal;
  final int newRecords;
  final int updatedRecords;

  double get ratio => phase == SyncPhase.details
      ? (detailTotal == 0 ? 0 : details / detailTotal)
      : (totalPages == 0 ? 0 : page / totalPages);
}

class SyncResult {
  const SyncResult({
    required this.total,
    required this.pages,
    this.imported = 0,
    this.newRecords = 0,
    this.updatedRecords = 0,
    this.detailsFetched = 0,
    this.detailsFailed = 0,
    this.unchanged = false,
    this.initial = false,
    this.lastSyncAt,
  });

  /// Summary rows merged during this run.
  final int imported;
  final int newRecords;
  final int updatedRecords;
  final int detailsFetched;
  final int detailsFailed;
  final int total;
  final int pages;

  /// True when the server matched our local fingerprint and we skipped every
  /// download. The UI shows "Already Downloaded" with [lastSyncAt].
  final bool unchanged;

  /// True when this was the first full download into an empty database.
  final bool initial;

  final String? lastSyncAt;
}

/// Offline-first catalogue synchroniser.
///
/// Strategy, given the shape of the BD Medicine API:
///
/// * The listing endpoint (`/medicines`) returns **summary rows only** — no
///   `last_updated`/`content_hash` and it ignores any `updated_since` filter —
///   while per-record change timestamps live only on `/medicines/{id}`. There
///   is therefore no server-side delta endpoint to lean on.
/// * So a sync opens with a cheap **fingerprint** built from the aggregate
///   `/stats` payload. If it equals the stored one and the row count matches,
///   nothing changed upstream: every download is skipped (the "Already
///   Downloaded" path). `force` bypasses this for a manual refresh.
/// * When the fingerprint *has* moved, we page the listing once, merging
///   summaries transactionally and classifying rows as **new** (id unseen) or
///   **updated** (summary fields differ). Only those ids — plus a bounded
///   back-fill when the server reports more scraped detail than we hold — get
///   their clinical detail re-downloaded. Already-detailed, unchanged rows are
///   never re-fetched, which is where the bandwidth is actually saved.
/// * A first run into an empty database downloads every detail (the same full
///   crawl the seed builder does), so the app ends up wholly offline-capable.
///
/// Failures are non-destructive: a dropped listing page stops the fingerprint
/// from being committed so the next launch retries; a dropped detail request is
/// simply left for on-demand loading. Existing rows are never truncated.
class SyncService {
  SyncService({required this.api, required this.db, required this.dao});

  final MedicineApi api;
  final AppDatabase db;
  final MedicineDao dao;

  bool _running = false;
  bool get isRunning => _running;

  /// Deterministic, aggregate change signal for the remote dataset. Must stay
  /// byte-identical to the seed builder's fingerprint (tool/build_seed_db.dart)
  /// so a freshly seeded install is recognised as already up to date.
  static String fingerprint(Map<String, dynamic> stats) {
    final run = stats['last_run'];
    final runPart = run is Map
        ? '${run['started_at']}~${run['finished_at']}~'
              '${run['new_count']}~${run['updated_count']}~${run['mode']}'
        : '';
    return 'v1|${stats['total_medicines']}|${stats['detail_scraped']}|'
        '${stats['pending_detail']}|${stats['distinct_companies']}|'
        '${stats['distinct_generics']}|$runPart';
  }

  /// Cheap pre-flight used by the UI to phrase a status before syncing.
  Future<bool> isUpToDate() async {
    try {
      final stats = await api.stats();
      final fp = fingerprint(stats);
      final stored = await db.meta(AppConfig.metaFingerprint);
      return stored != null && stored == fp && await db.catalogCount() > 0;
    } on ApiException {
      return false;
    }
  }

  Future<SyncResult> syncAll({
    bool force = false,
    bool full = false,
    void Function(SyncProgress)? onProgress,
  }) async {
    if (_running) {
      throw ApiException('ডেটাবেস আপডেট ইতিমধ্যে চলছে।');
    }
    // A full download is an explicit, complete re-crawl: never short-circuit on
    // the fingerprint, and pull clinical detail for every record (not just the
    // delta) so the local database mirrors the entire source API.
    final recrawl = force || full;
    _running = true;
    try {
      onProgress?.call(
        const SyncProgress(
          phase: SyncPhase.connecting,
          page: 0,
          totalPages: 0,
          imported: 0,
          total: 0,
        ),
      );
      await api.health();
      final stats = await api.stats();
      final fp = fingerprint(stats);
      final remoteTotal =
          int.tryParse(stats['total_medicines']?.toString() ?? '') ?? 0;
      final scrapedNow =
          int.tryParse(stats['detail_scraped']?.toString() ?? '') ?? 0;

      final storedFp = await db.meta(AppConfig.metaFingerprint);
      final localCatalog = await db.catalogCount();

      // Smart caching: identical fingerprint and a non-empty catalogue means
      // nothing changed upstream. Skip every download. We compare against the
      // stored fingerprint rather than the raw remote total because only
      // complete (core-identity) records are imported, so local and remote
      // counts intentionally differ, and manual stock lives outside the count.
      if (!recrawl && storedFp != null && storedFp == fp && localCatalog > 0) {
        return SyncResult(
          total: remoteTotal,
          pages: 0,
          unchanged: true,
          lastSyncAt: await db.meta(AppConfig.metaLastSync),
        );
      }

      final initial = localCatalog == 0 || full;
      final startedAt = DateTime.now().toIso8601String();
      final known = await db.allMedicineIds();
      final detailQueue = <int>{};

      var page = 1;
      var totalPages = 1;
      var imported = 0;
      var newRecords = 0;
      var updatedRecords = 0;
      var pageFails = 0;

      // Listing pass: transactional merge + classify new vs changed.
      while (page <= totalPages && page <= AppConfig.maxPagesPerSync) {
        MedicinePage result;
        try {
          result = await api.medicines(
            page: page,
            limit: AppConfig.syncPageSize,
          );
        } on ApiException {
          pageFails++;
          page++;
          continue;
        }
        totalPages = result.totalPages == 0 ? page : result.totalPages;
        // Never insert an incomplete record: keep only rows that carry the
        // full core identity (brand + generic + company + type + strength).
        final items = result.items
            .where((m) => m.hasCoreIdentity)
            .toList(growable: false);
        if (items.isEmpty) {
          page++;
          continue;
        }

        final newOnes = <int>[];
        for (final m in items) {
          if (known.add(m.id)) newOnes.add(m.id);
        }
        final changedOnes = await db.changedSummaryIds(items);

        newRecords += newOnes.length;
        updatedRecords += changedOnes.length;
        detailQueue.addAll(newOnes);
        detailQueue.addAll(changedOnes);
        // First download (or an explicit full recrawl) wants every detail,
        // not just the diff.
        if (initial) detailQueue.addAll(items.map((m) => m.id));

        await db.upsertSummaries(items, sourceUpdated: startedAt);
        imported += items.length;
        onProgress?.call(
          SyncProgress(
            phase: SyncPhase.listing,
            page: page,
            totalPages: totalPages,
            imported: imported,
            total: result.total,
            newRecords: newRecords,
            updatedRecords: updatedRecords,
          ),
        );
        if (remoteTotal > 0 && imported >= remoteTotal) break;
        page++;
      }

      // Bounded back-fill: server scraped more detail than we hold locally.
      final prevScraped =
          int.tryParse(
            await db.meta(AppConfig.metaSourceDetailScraped) ?? '0',
          ) ??
          0;
      if (!initial && scrapedNow > prevScraped) {
        detailQueue.addAll(
          await db.idsMissingDetail(limit: AppConfig.deltaDetailBackfill),
        );
      }

      // Detail delta (or full crawl on the very first run).
      final detailIds = detailQueue.toList();
      var detailsFetched = 0;
      var detailsFailed = 0;
      if (detailIds.isNotEmpty) {
        final outcome = await _fetchDetails(
          detailIds,
          onDone: (done) => onProgress?.call(
            SyncProgress(
              phase: SyncPhase.details,
              page: 0,
              totalPages: 0,
              imported: imported,
              total: remoteTotal,
              details: done,
              detailTotal: detailIds.length,
              newRecords: newRecords,
              updatedRecords: updatedRecords,
            ),
          ),
        );
        detailsFetched = outcome.fetched;
        detailsFailed = outcome.failed;
      }

      final finishedAt = DateTime.now().toIso8601String();
      await db.setMeta(AppConfig.metaLastSync, finishedAt);
      await db.setMeta(AppConfig.metaSourceBase, api.baseUrl());
      await db.setMeta(AppConfig.metaSourceTotal, '$remoteTotal');
      await db.setMeta(AppConfig.metaSourceDetailScraped, '$scrapedNow');
      await db.setMeta(AppConfig.metaSourceStats, jsonEncode(stats));
      // Only pin the fingerprint when the listing was complete; a dropped page
      // must leave the next launch free to retry rather than falsely skip.
      if (pageFails == 0) {
        await db.setMeta(AppConfig.metaFingerprint, fp);
      }

      return SyncResult(
        imported: imported,
        newRecords: newRecords,
        updatedRecords: updatedRecords,
        detailsFetched: detailsFetched,
        detailsFailed: detailsFailed,
        total: remoteTotal,
        pages: page - 1 - pageFails,
        initial: initial,
        lastSyncAt: finishedAt,
      );
    } finally {
      _running = false;
    }
  }

  /// Downloads clinical detail for [ids] with a bounded worker pool, writing in
  /// batches. A per-record network failure is tolerated (that row just stays
  /// undetailed) rather than aborting the whole pass.
  Future<({int fetched, int failed})> _fetchDetails(
    List<int> ids, {
    required void Function(int done) onDone,
  }) async {
    if (ids.isEmpty) return (fetched: 0, failed: 0);
    final queue = ListQueue<int>.from(ids);
    final buffer = <Medicine>[];
    var done = 0;
    var fetched = 0;
    var failed = 0;

    Future<void> flush() async {
      if (buffer.isEmpty) return;
      final drain = List<Medicine>.of(buffer);
      buffer.clear();
      // No sourceUpdated: each row keeps the API's own last_updated.
      await dao.saveDetailsBatch(drain);
    }

    await Future.wait(
      List.generate(AppConfig.detailConcurrency, (_) async {
        while (queue.isNotEmpty) {
          final id = queue.removeFirst();
          try {
            buffer.add(await api.medicine(id));
            fetched++;
            if (buffer.length >= AppConfig.detailWriteBatch) await flush();
          } on ApiException {
            failed++;
          }
          done++;
          onDone(done);
        }
      }),
    );
    await flush();
    return (fetched: fetched, failed: failed);
  }

  /// Fetches and caches a full record. Returns the cached row when the network
  /// fails so the detail screen can still show what is already offline.
  Future<Medicine> ensureDetail(Medicine cached, {bool force = false}) async {
    if (cached.detailLoaded && !force) return cached;
    try {
      final fresh = await api.medicine(cached.id);
      await dao.saveDetail(fresh);
      return fresh;
    } on ApiException {
      if (cached.hasClinicalData || cached.detailLoaded) return cached;
      rethrow;
    }
  }
}
