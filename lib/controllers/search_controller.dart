import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../core/essential_medicines.dart';
import '../core/medicine_form.dart';
import '../data/medicine_dao.dart';
import '../models/medicine.dart';

class MedicineSearchController extends GetxController {
  MedicineSearchController(this._dao);

  final MedicineDao _dao;
  Timer? _debounce;

  final RxString query = ''.obs;
  final RxString company = ''.obs;
  final RxString generic = ''.obs;

  /// Selected Bengali category chip, holding a [MedicineForm] key.
  final RxString dosageForm = ''.obs;

  /// Raw API `dosage_form` spellings bucketed per category key, loaded lazily
  /// so a chip like “ট্যাবলেট” also matches "Tablet (Extended Release)".
  final Map<String, List<String>> _formRaw = {};
  Future<void>? _formRawLoad;

  Future<void> _ensureFormRaw() => _formRawLoad ??= () async {
    try {
      final raws = await _dao.distinctDosageForms();
      _formRaw.clear();
      for (final raw in raws) {
        _formRaw.putIfAbsent(MedicineForm.classify(raw).key, () => []).add(raw);
      }
      // Manual rows store the Bengali label as `dosage_form`; make every chip
      // match those too, and guarantee no selected chip can ever be filter-less.
      for (final f in MedicineForm.selectable) {
        _formRaw.putIfAbsent(f.key, () => []).add(f.label);
      }
    } catch (_) {
      // Do not cache a failed future forever: the next tap must be able to
      // retry the dosage-form lookup.
      _formRawLoad = null;
      rethrow;
    }
  }();

  final RxList<Medicine> results = <Medicine>[].obs;
  final RxList<Medicine> recentMedicines = <Medicine>[].obs;
  final RxList<Medicine> featured = <Medicine>[].obs;
  final RxBool featuredLoading = false.obs;
  final RxList<String> history = <String>[].obs;
  final RxBool loading = false.obs;
  final RxBool loadingMore = false.obs;
  final RxBool searched = false.obs;
  final RxString error = ''.obs;
  final RxInt page = 0.obs;
  final RxInt totalPages = 0.obs;
  final RxInt total = 0.obs;

  bool get hasFilters =>
      company.value.isNotEmpty ||
      generic.value.isNotEmpty ||
      dosageForm.value.isNotEmpty;

  bool get hasMore => page.value < totalPages.value;

  @override
  void onInit() {
    super.onInit();
    _loadHistory();
    _loadFeatured();
    _ensureFormRaw();
  }

  /// The Bangladesh counter-list (নাপা, প্যারাসিটামল, ভিটামিন সি…) shown the
  /// moment the ঔষধ page opens, before any query is typed.
  Future<void> _loadFeatured() async {
    featuredLoading.value = true;
    try {
      featured.assignAll(await _dao.featuredMedicines(essentialMedicineTokens));
    } catch (_) {
      // A broken feature list must never block searching.
    } finally {
      featuredLoading.value = false;
    }
  }

  Future<void> _loadHistory() async {
    try {
      final terms = await _dao.searchHistory();
      history.assignAll(terms);
      recentMedicines.assignAll(await _dao.fromSearchHistory(terms));
    } catch (_) {
      // History is a convenience; a read failure must not block searching.
    }
  }

  /// Re-reads recent searches, e.g. after they are cleared from Settings.
  Future<void> refreshHistory() => _loadHistory();

  void onQueryChanged(String value) {
    query.value = value;
    _debounce?.cancel();
    if (value.trim().isEmpty && !hasFilters) {
      results.clear();
      searched.value = false;
      error.value = '';
      total.value = 0;
      totalPages.value = 0;
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 140),
      () => search(record: false),
    );
  }

  Future<void> search({bool record = true}) async {
    final term = query.value.trim();
    if (term.isEmpty && !hasFilters) return;
    loading.value = true;
    searched.value = true;
    error.value = '';
    try {
      if (dosageForm.value.isNotEmpty) await _ensureFormRaw();
      final result = await _dao.search(
        query: term,
        company: company.value,
        generic: generic.value,
        dosageForms: dosageForm.value.isEmpty
            ? null
            : _formRaw[dosageForm.value],
        page: 1,
      );
      results.assignAll(result.items);
      page.value = result.page;
      totalPages.value = result.totalPages;
      total.value = result.total;
      if (record && term.isNotEmpty) {
        unawaited(
          _dao
              .addSearchTerm(term)
              .then((_) => _loadHistory())
              .catchError((Object error) {
                debugPrint('Search history update failed: $error');
              }),
        );
      }
    } catch (e) {
      error.value = 'সার্চ করা যায়নি: $e';
      results.clear();
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (loading.value || loadingMore.value || !hasMore) return;
    loadingMore.value = true;
    try {
      if (dosageForm.value.isNotEmpty) await _ensureFormRaw();
      final result = await _dao.search(
        query: query.value.trim(),
        company: company.value,
        generic: generic.value,
        dosageForms: dosageForm.value.isEmpty
            ? null
            : _formRaw[dosageForm.value],
        page: page.value + 1,
      );
      final seen = results.map((e) => e.id).toSet();
      results.addAll(result.items.where((e) => seen.add(e.id)));
      page.value = result.page;
      totalPages.value = result.totalPages;
      total.value = result.total;
    } catch (e) {
      error.value = 'আরও ফলাফল লোড করা যায়নি: $e';
    } finally {
      loadingMore.value = false;
    }
  }

  void setCompany(String value) {
    company.value = value;
    applyFilters();
  }

  void setGeneric(String value) {
    generic.value = value;
    applyFilters();
  }

  void setDosageForm(String value) {
    dosageForm.value = value;
    applyFilters();
  }

  void applyFilters() {
    if (query.value.trim().isEmpty && !hasFilters) {
      results.clear();
      searched.value = false;
      return;
    }
    search();
  }

  void clearFilters() {
    company.value = '';
    generic.value = '';
    dosageForm.value = '';
    if (query.value.trim().isNotEmpty) {
      search();
    } else {
      results.clear();
      searched.value = false;
    }
  }

  Future<void> useHistoryTerm(String term) async {
    query.value = term;
    await search();
  }

  /// Saves the current query when the user opens a result, so a search they
  /// acted on always appears in the "previously searched" list next time.
  Future<void> rememberCurrentQuery() async {
    final term = query.value.trim();
    if (term.isEmpty) return;
    await _dao.addSearchTerm(term);
    await _loadHistory();
  }

  Future<void> clearHistory() async {
    await _dao.clearSearchHistory();
    history.clear();
    recentMedicines.clear();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}
