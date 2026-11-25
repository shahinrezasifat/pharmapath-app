import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ai_doctor_module/ai_doctor.dart';

import 'app/theme.dart';
import 'controllers/favorites_controller.dart';
import 'controllers/home_controller.dart';
import 'controllers/learning_controller.dart';
import 'controllers/navigation_controller.dart';
import 'controllers/search_controller.dart';
import 'controllers/settings_controller.dart';
import 'core/app_config.dart';
import 'core/storage.dart';
import 'data/ai_dao.dart';
import 'data/app_database.dart';
import 'data/learning_dao.dart';
import 'data/learning_repository.dart';
import 'data/medicine_dao.dart';
import 'services/backup_service.dart';
import 'services/ai_learning_tools.dart';
import 'services/app_update_service.dart';
import 'services/medicine_api.dart';
import 'services/oxion_assistant.dart';
import 'services/sync_service.dart';
import 'views/shell_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStorage.init();
  final uiLanguage = AppStorage.read<String>(AppStorage.kUiLanguage) ?? 'bn';
  AppStorage.write(AppStorage.kUiLanguage, uiLanguage);
  AiDoctorConfig.init(
    baseUrl: AppConfig.defaultAssistantApiBase,
    apiKey: AppConfig.normalizedAssistantKey(AppConfig.defaultAssistantApiKey),
    languageCode: uiLanguage,
    onLanguageChanged: (value) =>
        AppStorage.write(AppStorage.kUiLanguage, value),
  );

  try {
    final db = await AppDatabase.open();
    final medicineDao = MedicineDao(db, pageSize: AppConfig.searchPageSize);
    AiDoctorConfig.medicineLookup = (query) async {
      final page = await medicineDao.search(query: query, limit: 8);
      return [
        for (final medicine in page.items)
          AiMedicineOption(
            name: medicine.brandName,
            genericName: medicine.genericName ?? '',
            strength: medicine.strength ?? '',
            dosageForm: medicine.dosageForm ?? '',
          ),
      ];
    };
    final learningDao = LearningDao(db);
    final aiDao = AiDao(db);
    final learningRepository = LearningRepository(learningDao);
    final settings = SettingsController(db);
    final api = MedicineApi(baseUrl: () => settings.apiBase.value);
    final sync = SyncService(api: api, db: db, dao: medicineDao);
    final backup = BackupService(db);
    final assistant = OxionAssistant();
    Get.put(AppUpdateService(), permanent: true);

    // One-shot AI helpers for the শেখা module and medicine pages: Bangla
    // translation, detailed explanation, lesson summaries and the re-ranking of
    // suggested lessons. Every result is cached in SQLite, so a repeat visit
    // costs nothing and offline still shows what was fetched before.
    final learningAi = AiLearningTools(assistant, aiDao);

    Get.put(db, permanent: true);
    Get.put(medicineDao, permanent: true);
    Get.put(learningRepository, permanent: true);
    Get.put(aiDao, permanent: true);
    Get.put(learningAi, permanent: true);
    Get.put(settings, permanent: true);
    Get.put(sync, permanent: true);
    Get.put(backup, permanent: true);
    Get.put(
      HomeController(medicineDao, learningRepository, sync, db, settings),
      permanent: true,
    );
    Get.put(
      LearningController(learningRepository, learningAi),
      permanent: true,
    );
    Get.put(FavoritesController(medicineDao), permanent: true);
    Get.put(MedicineSearchController(medicineDao), permanent: true);
    Get.put(NavigationController(), permanent: true);

    // Keep the OxionAI client for cached, one-shot learning and medicine
    // explanations. Patient consultations use the dedicated AI doctor module.
    Get.put(assistant, permanent: true);

    // Automated ingestion. Normally the bundled seed already fills the
    // database, so the first connection just confirms it is up to date. If the
    // database is empty (no seed installed — e.g. a slim/web build, or a fresh
    // wipe) we run the initial full download automatically. Otherwise we only
    // do a quiet incremental check when the user opted into sync-on-start.
    if (await db.medicineCount() == 0) {
      Future<void>.delayed(const Duration(seconds: 1), () {
        Get.find<HomeController>().syncNow(notify: true);
      });
    } else if (settings.syncOnStart.value) {
      // Best effort: never block startup, never clear existing data on failure.
      Future<void>.delayed(const Duration(seconds: 2), () {
        Get.find<HomeController>().syncNow(notify: false);
      });
    }

    runApp(const PharmaPathApp());
  } catch (error) {
    runApp(FatalApp(message: '$error'));
  }
}

class PharmaPathApp extends StatelessWidget {
  const PharmaPathApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsController>();
    return Obx(
      () => GetMaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: switch (settings.themeMode.value) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          final systemScale = mediaQuery.textScaler.scale(1.0);
          // Anek Bangla renders visually larger than standard Latin fonts.
          // Calibrate so that UI font scaling matches sleek mobile app proportions.
          final calibratedScale = (systemScale * 0.94).clamp(0.85, 1.05);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(calibratedScale),
            ),
            child: child!,
          );
        },
        home: const _UpdateAwareShell(),
        defaultTransition: Transition.fadeIn,
      ),
    );
  }
}

class _UpdateAwareShell extends StatefulWidget {
  const _UpdateAwareShell();

  @override
  State<_UpdateAwareShell> createState() => _UpdateAwareShellState();
}

class _UpdateAwareShellState extends State<_UpdateAwareShell> {
  bool _checking = true;
  bool _updateRequired = false;
  String? _checkError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    final updater = Get.find<AppUpdateService>();
    if (!updater.isConfigured) {
      setState(() {
        _checking = false;
        _checkError = 'এই অ্যাপের GitHub repository কনফিগার করা নেই।';
      });
      return;
    }
    try {
      final release = await updater.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _checking = false;
        _updateRequired = release != null;
        _checkError = null;
      });
    } catch (error) {
      debugPrint('PharmaPath update check failed: $error');
      if (mounted) {
        setState(() {
          _checking = false;
          _checkError = 'আপডেট যাচাই করা যায়নি। ইন্টারনেট সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('আপডেট খোঁজা হচ্ছে…'),
            ],
          ),
        ),
      );
    }
    if (_updateRequired) {
      return Scaffold(
        body: Center(
          child: _UpdateDialog(
            release: Get.find<AppUpdateService>().latestRelease!,
            updater: Get.find<AppUpdateService>(),
            onInstalled: () {
              if (mounted) setState(() => _updateRequired = false);
            },
          ),
        ),
      );
    }
    if (_checkError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 42),
                const SizedBox(height: 16),
                Text(_checkError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => setState(() {
                    _checking = true;
                    _checkError = null;
                    _checkForUpdate();
                  }),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('আবার চেষ্টা করুন'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const ShellView();
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.release,
    required this.updater,
    required this.onInstalled,
  });

  final AppRelease release;
  final AppUpdateService updater;
  final VoidCallback onInstalled;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  bool _permissionRequired = false;
  double? _progress;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _downloading = true;
      _error = null;
      _permissionRequired = false;
    });
    try {
      await widget.updater.downloadAndInstall(
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (mounted && !Platform.isAndroid) widget.onInstalled();
    } on MissingPluginException {
      if (mounted) {
        setState(() => _error = 'এই Android সংস্করণে ইন-অ্যাপ ইনস্টল সমর্থিত নয়।');
      }
    } on AppInstallPermissionRequired {
      if (mounted) setState(() => _permissionRequired = true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final canInstall = isAndroid && widget.release.apkUrl != null;
    final notes = widget.release.notes;
    return AlertDialog(
      icon: const Icon(Icons.system_update_alt_rounded),
      title: const Text('নতুন আপডেট এসেছে'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 360),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PharmaPath ${widget.release.version}'),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(notes, maxLines: 12, overflow: TextOverflow.ellipsis),
              ],
              if (_downloading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 6),
                const Text('আপডেট ডাউনলোড হচ্ছে…'),
              ],
              if (_permissionRequired) ...[
                const SizedBox(height: 12),
                const Text('ইনস্টল অনুমতি চালু করে আবার ইনস্টল চাপুন।'),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (canInstall)
          FilledButton.icon(
            onPressed: _downloading
                ? null
                : _permissionRequired
                ? () async {
                    setState(() => _downloading = true);
                    try {
                      await widget.updater.resumeInstall();
                    } catch (error) {
                      if (mounted) setState(() => _error = '$error');
                    } finally {
                      if (mounted) setState(() => _downloading = false);
                    }
                  }
                : _install,
            icon: const Icon(Icons.download_rounded),
            label: Text(_permissionRequired ? 'ইনস্টল করুন' : 'আপডেট ইনস্টল'),
          )
        else
          FilledButton(
            onPressed: _downloading ? null : widget.updater.openReleasePage,
            child: const Text('রিলিজ খুলে আপডেট করুন'),
          ),
      ],
    );
  }
}

class FatalApp extends StatelessWidget {
  const FatalApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                const Text('ফার্মাপাথ চালু করা যায়নি'),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
