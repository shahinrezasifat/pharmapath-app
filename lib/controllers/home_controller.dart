import 'package:get/get.dart';

import '../core/api_exception.dart';
import '../core/format.dart';
import '../data/app_database.dart';
import '../data/learning_repository.dart';
import '../data/medicine_dao.dart';
import '../models/learning.dart';
import '../models/medicine.dart';
import '../services/sync_service.dart';
import 'settings_controller.dart';

class HomeController extends GetxController {
  HomeController(
    this._dao,
    this._learning,
    this._sync,
    this._db,
    this._settings,
  );

  final MedicineDao _dao;
  final LearningRepository _learning;
  final SyncService _sync;
  final AppDatabase _db;
  final SettingsController _settings;

  final RxList<Medicine> recent = <Medicine>[].obs;
  final RxList<Medicine> favorites = <Medicine>[].obs;
  final RxSet<int> favoriteIds = <int>{}.obs;
  final RxMap<String, Object?> stats = <String, Object?>{}.obs;
  final RxList<Course> courses = <Course>[].obs;
  final Rxn<Course> continueCourse = Rxn<Course>();
  final Rxn<Lesson> continueLesson = Rxn<Lesson>();
  final RxBool loading = true.obs;
  final RxBool syncing = false.obs;
  final Rx<SyncPhase> syncPhase = SyncPhase.connecting.obs;
  final RxDouble syncProgress = 0.0.obs;
  final RxString syncMessage = ''.obs;
  final RxString syncError = ''.obs;
  final RxString loadError = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    loadError.value = '';
    try {
      recent.assignAll(await _dao.recentlyViewed(limit: 8));
      final savedFavorites = await _dao.favorites();
      favorites.assignAll(savedFavorites.take(8));
      favoriteIds.assignAll(savedFavorites.map((medicine) => medicine.id));
      stats.value = await _db.stats();
      courses.assignAll(await _learning.courses());
      await _pickContinue();
    } catch (e) {
      loadError.value = 'লোকাল ডেটা পড়া যায়নি: $e';
    } finally {
      loading.value = false;
    }
  }

  Future<void> _pickContinue() async {
    continueCourse.value = null;
    continueLesson.value = null;
    final completed = await _learning.completedLessons();
    for (final course in courses) {
      final done = course.lessons
          .where((l) => completed.contains('${course.id}::${l.id}'))
          .toList();
      if (done.isEmpty) continue;
      if (done.length >= course.lessons.length) continue;
      continueCourse.value = course;
      continueLesson.value = course.lessons.firstWhere(
        (l) => !done.contains(l),
      );
      return;
    }
  }

  bool get isEmptyDatabase => ((stats['medicines'] as int?) ?? 0) == 0;

  Future<void> toggleFavorite(int medicineId) async {
    final isFavorite = await _dao.toggleFavorite(medicineId);
    if (isFavorite) {
      favoriteIds.add(medicineId);
    } else {
      favoriteIds.remove(medicineId);
    }
    final savedFavorites = await _dao.favorites();
    favorites.assignAll(savedFavorites.take(8));
  }

  /// Runs an offline-safe catalogue sync.
  ///
  /// * [force] skips the "already up to date" short-circuit for a manual pull.
  /// * [full] re-crawls the entire source API, re-downloading clinical detail
  ///   for every record so the local database fully mirrors the server. Implies
  ///   [force].
  /// * [notify] pops a snackbar; background auto-sync keeps it quiet and only
  ///   refreshes the inline status text.
  Future<SyncResult?> syncNow({
    bool force = false,
    bool full = false,
    bool notify = true,
  }) async {
    if (syncing.value) return null;
    syncing.value = true;
    syncError.value = '';
    syncPhase.value = SyncPhase.connecting;
    syncProgress.value = 0;
    syncMessage.value = 'সংযোগ করা হচ্ছে…';
    try {
      final result = await _sync.syncAll(
        force: force,
        full: full,
        onProgress: (progress) {
          syncPhase.value = progress.phase;
          syncProgress.value = progress.ratio.clamp(0.0, 1.0);
          syncMessage.value = switch (progress.phase) {
            SyncPhase.details =>
              'বিস্তারিত: ${bn(progress.details)}/${bn(progress.detailTotal)}',
            _ =>
              'পৃষ্ঠা ${bn(progress.page)}/${bn(progress.totalPages)} · '
                  '${bn(progress.imported)}টি ওষুধ',
          };
        },
      );
      await load();
      await _settings.refreshStats();
      _reportSync(result, notify: notify);
      return result;
    } on ApiException catch (e) {
      syncError.value = e.message;
      syncMessage.value = '';
      if (notify) Get.snackbar('ডেটাবেস আপডেট ব্যর্থ', e.message);
      return null;
    } catch (e) {
      syncError.value = 'ডেটাবেস আপডেট ব্যর্থ: $e';
      syncMessage.value = '';
      if (notify) Get.snackbar('ডেটাবেস আপডেট ব্যর্থ', '$e');
      return null;
    } finally {
      syncing.value = false;
    }
  }

  void _reportSync(SyncResult result, {required bool notify}) {
    final lastSync = bnDateFromIso(result.lastSyncAt);
    if (result.unchanged) {
      // The local database already mirrors the server — nothing was downloaded.
      syncMessage.value = 'সর্বশেষ আপডেট: $lastSync';
      if (notify) {
        Get.snackbar(
          'ইতিমধ্যে ডাউনলোড করা আছে',
          'নতুন কোনো তথ্য নেই। সর্বশেষ সিঙ্ক: $lastSync',
        );
      }
      return;
    }
    final parts = <String>[
      if (result.newRecords > 0) '${bn(result.newRecords)}টি নতুন',
      if (result.updatedRecords > 0) '${bn(result.updatedRecords)}টি হালনাগাদ',
      if (result.detailsFetched > 0) '${bn(result.detailsFetched)}টি বিস্তারিত',
    ];
    final summary = parts.isEmpty
        ? '${bn(result.imported)}টি ওষুধ যাচাই করা হয়েছে'
        : parts.join(', ');
    if (result.initial) {
      syncMessage.value = 'প্রাথমিক ডাউনলোড সম্পন্ন · $summary';
      if (notify) {
        Get.snackbar(
          'অফলাইন সেটআপ সম্পন্ন',
          'সম্পূর্ণ ক্যাটালগ সংরক্ষিত হয়েছে · $summary',
        );
      }
    } else {
      syncMessage.value = '$summary · $lastSync';
      if (notify) Get.snackbar('ডেটাবেস হালনাগাদ হয়েছে', summary);
    }
  }
}
