import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/favorites_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/learning_controller.dart';
import '../controllers/search_controller.dart';
import '../controllers/settings_controller.dart';
import '../core/api_exception.dart';
import '../core/app_config.dart';
import '../core/format.dart';
import '../data/medicine_dao.dart';
import '../services/medicine_api.dart';
import '../services/sync_service.dart';
import '../widgets/glass.dart';

/// Offline catalogue control centre: server source, sync, local database
/// health and the destructive data-cleaning actions. Backups live on their own
/// page so no action is repeated in two places.
class DataManagementView extends StatefulWidget {
  const DataManagementView({super.key});

  @override
  State<DataManagementView> createState() => _DataManagementViewState();
}

class _DataManagementViewState extends State<DataManagementView> {
  late final SettingsController _settings;
  late final TextEditingController _apiBase;
  bool _testingApi = false;
  String _apiStatus = '';
  bool _apiOk = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _settings = Get.find<SettingsController>();
    _apiBase = TextEditingController(text: _settings.apiBase.value);
  }

  @override
  void dispose() {
    _apiBase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = Get.find<HomeController>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('অফলাইন ডেটা')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Obx(() {
            final stats = _settings.dbStats;
            final total = (stats['medicines'] as int?) ?? 0;
            final detailed = (stats['detailed'] as int?) ?? 0;
            final catalogTotal = (stats['catalog_total'] as int?) ?? total;
            return GlassCard(
              padding: const EdgeInsets.all(18),
              gradient: AppTheme.heroGradient(context),
              borderColor: Colors.white.withValues(alpha: 0.18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.offline_bolt_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              total > 0
                                  ? 'অফলাইন ডেটা প্রস্তুত'
                                  : 'এখনো ডেটা ডাউনলোড হয়নি',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            Text(
                              total > 0
                                  ? 'ইন্টারনেট ছাড়াই সব ওষুধ ও শেখার পাঠ ব্যবহার করুন।'
                                  : 'একবার ডাউনলোড করলে পরে ইন্টারনেট লাগবে না।',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.72),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: StatBlock(
                          value: bn(total),
                          label: 'ব্যবহারযোগ্য ওষুধ',
                          icon: Icons.medication_outlined,
                          onLight: true,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: StatBlock(
                          value: bn(detailed),
                          label: 'সম্পূর্ণ তথ্য',
                          icon: Icons.description_outlined,
                          onLight: true,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: StatBlock(
                          value: bn(stats['companies'] ?? 0),
                          label: 'কোম্পানি',
                          icon: Icons.factory_outlined,
                          onLight: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'সর্বশেষ আপডেট: ${bnDateFromIso(stats['last_sync']?.toString())}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                        ),
                      ),
                    ],
                  ),
                  if (catalogTotal > total) ...[
                    const SizedBox(height: 8),
                    Text(
                      'ক্যাটালগে ${bn(catalogTotal)}টি রেকর্ড আছে। যেগুলোর ক্লিনিক্যাল '
                      'তথ্য এখনো সম্পূর্ণ নয়, সেগুলো অ্যাপে দেখানো হচ্ছে না।',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
          const SectionTitle(
            title: 'সিঙ্ক',
            subtitle: 'নতুন বা পরিবর্তিত তথ্য আনুন',
          ),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Obx(() {
              final syncing = home.syncing.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (syncing) ...[
                    LinearProgressIndicator(
                      value: home.syncProgress.value > 0
                          ? home.syncProgress.value
                          : null,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      home.syncMessage.value.isEmpty
                          ? home.syncPhase.value.label
                          : home.syncMessage.value,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: syncing ? null : _fullDownload,
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: Text(
                        syncing ? 'ডাউনলোড চলছে…' : 'সম্পূর্ণ ক্যাটালগ ডাউনলোড',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: syncing ? null : _syncNow,
                      icon: const Icon(Icons.sync_rounded),
                      label: const Text('শুধু নতুন / পরিবর্তিত যাচাই'),
                    ),
                  ),
                  if (home.syncError.value.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      home.syncError.value,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.error),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    '“সম্পূর্ণ ক্যাটালগ” আপনার দেওয়া সার্ভার থেকে সব ওষুধ ও '
                    'ক্লিনিক্যাল তথ্য এনে ডিভাইসে সংরক্ষণ করে। দ্বিতীয় বাটনটি '
                    'শুধু নতুন বা পরিবর্তিত রেকর্ড আনে।',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              );
            }),
          ),
          const SectionTitle(
            title: 'সোর্স সার্ভার',
            subtitle: 'নিজের চালু করা Bangladeshi Medicine API',
          ),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _apiBase,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'API ঠিকানা',
                    hintText: 'http://127.0.0.1:8000',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                if (_settings.apiBaseError.value.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _settings.apiBaseError.value,
                      style: TextStyle(color: scheme.error, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _saveApiBase,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('সংরক্ষণ'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _testingApi ? null : _testApi,
                        icon: _testingApi
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.wifi_tethering_rounded),
                        label: const Text('পরীক্ষা'),
                      ),
                    ),
                  ],
                ),
                if (_apiStatus.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    _apiStatus,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _apiOk ? scheme.primary : scheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'উৎস: ${AppConfig.dataSourceName}। ডেটা শুধু আপনার ডিভাইসে '
                  'সংরক্ষিত হয়; কোনো অ্যাকাউন্ট বা ক্লাউড লাগে না।',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SectionTitle(
            title: 'রক্ষণাবেক্ষণ',
            subtitle: 'অ্যাপের লোকাল ডেটা পরিষ্কার করুন',
          ),
          SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.search_off_outlined,
                title: 'সার্চ ইতিহাস মুছুন',
                subtitle: 'সাম্প্রতিক সার্চ শুধু এই ডিভাইস থেকে মুছে যাবে',
                onTap: _busy ? null : _clearSearchHistory,
              ),
              SettingsTile(
                icon: Icons.school_outlined,
                title: 'শেখার অগ্রগতি রিসেট',
                subtitle: 'পাঠ সম্পূর্ণতা, বুকমার্ক ও কুইজ ফলাফল মুছে যাবে',
                onTap: _busy ? null : _resetProgress,
              ),
              SettingsTile(
                icon: Icons.delete_forever_outlined,
                title: 'সব লোকাল ডেটা মুছুন',
                subtitle: 'ওষুধ ডেটাবেস, পছন্দ, ইতিহাস ও অগ্রগতি',
                danger: true,
                onTap: _busy ? null : _resetEverything,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _saveApiBase() {
    final ok = _settings.saveApiBase(_apiBase.text);
    if (ok) {
      Get.snackbar('সংরক্ষিত', 'API ঠিকানা আপডেট হয়েছে।');
      setState(() => _apiStatus = '');
    }
  }

  Future<void> _testApi() async {
    if (!_settings.saveApiBase(_apiBase.text)) return;
    setState(() {
      _testingApi = true;
      _apiStatus = 'সংযোগ পরীক্ষা চলছে…';
      _apiOk = false;
    });
    final api = MedicineApi(baseUrl: () => _settings.apiBase.value);
    try {
      await api.health();
      final stats = await api.stats();
      final total = stats['total_medicines'] ?? 0;
      if (!mounted) return;
      setState(() {
        _apiOk = true;
        _apiStatus = 'সংযোগ সফল · সার্ভারে ${bn(total)}টি ওষুধ আছে।';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _apiOk = false;
        _apiStatus = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _apiOk = false;
        _apiStatus = 'সংযোগ ব্যর্থ: $e';
      });
    } finally {
      api.dispose();
      if (mounted) setState(() => _testingApi = false);
    }
  }

  Future<void> _syncNow() async {
    await Get.find<HomeController>().syncNow();
    await _settings.refreshStats();
  }

  Future<void> _fullDownload() async {
    if (!_settings.saveApiBase(_apiBase.text)) return;
    await Get.find<HomeController>().syncNow(full: true);
    await _settings.refreshStats();
  }

  Future<void> _clearSearchHistory() async {
    final ok = await _confirm(
      'সার্চ ইতিহাস মুছবেন?',
      'এই ডিভাইসের সাম্প্রতিক সার্চ মুছে যাবে।',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await Get.find<MedicineDao>().clearSearchHistory();
      await Get.find<MedicineSearchController>().refreshHistory();
      Get.snackbar('সম্পন্ন', 'সার্চ ইতিহাস মুছে ফেলা হয়েছে।');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetProgress() async {
    final ok = await _confirm(
      'শেখার অগ্রগতি রিসেট করবেন?',
      'পাঠ সম্পূর্ণতা, বুকমার্ক ও কুইজ ফলাফল মুছে যাবে।',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await Get.find<LearningController>().clearAllProgress();
      await Get.find<HomeController>().load();
      Get.snackbar('সম্পন্ন', 'শেখার অগ্রগতি রিসেট হয়েছে।');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetEverything() async {
    final ok = await _confirm(
      'সব লোকাল ডেটা মুছবেন?',
      'ওষুধ ডেটাবেস, ফেভারিট, ইতিহাস, শেখার অগ্রগতি, AI ইতিহাস — সব মুছে যাবে। '
          'এটি ফেরানো যাবে না।',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await _settings.resetAllData();
      await Get.find<HomeController>().load();
      await Get.find<FavoritesController>().load();
      await Get.find<LearningController>().load();
      await Get.find<MedicineSearchController>().refreshHistory();
      await _settings.refreshStats();
      Get.snackbar('সম্পন্ন', 'সব লোকাল ডেটা মুছে ফেলা হয়েছে।');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('হ্যাঁ'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
