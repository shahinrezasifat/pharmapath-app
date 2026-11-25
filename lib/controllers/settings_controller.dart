import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart' show SystemChrome, SystemUiMode;
import 'package:get/get.dart';

import '../core/app_config.dart';
import '../core/storage.dart';
import '../data/app_database.dart';

class SettingsController extends GetxController {
  SettingsController(this._db);

  final AppDatabase _db;

  final RxString apiBase = AppConfig.defaultMedicineApiBase.obs;
  final RxString themeMode = 'dark'.obs;
  final RxBool syncOnStart = false.obs;
  final RxBool fullscreenMode = false.obs;

  final RxBool busy = false.obs;
  final RxString apiBaseError = ''.obs;
  final RxMap<String, Object?> dbStats = <String, Object?>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    final savedBase = AppStorage.box.read<String>(AppStorage.kApiBase);
    if (savedBase != null && savedBase.trim().isNotEmpty) {
      apiBase.value = savedBase.trim();
    }
    themeMode.value =
        AppStorage.box.read<String>(AppStorage.kThemeMode) ?? 'dark';
    syncOnStart.value =
        AppStorage.box.read<bool>(AppStorage.kSyncOnStart) ?? false;
    fullscreenMode.value =
        AppStorage.box.read<bool>('fullscreen_mode') ?? false;
    if (fullscreenMode.value) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    await refreshStats();
  }

  Future<void> refreshStats() async {
    dbStats.value = await _db.stats();
  }

  bool saveApiBase(String value) {
    var trimmed = value.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    final uri = Uri.tryParse(trimmed);
    if (trimmed.isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        uri.host.trim().isEmpty ||
        !(uri.isScheme('http') || uri.isScheme('https'))) {
      apiBaseError.value =
          'সম্পূর্ণ http(s) ঠিকানা দিন, যেমন http://127.0.0.1:8000';
      return false;
    }
    apiBaseError.value = '';
    apiBase.value = trimmed;
    AppStorage.box.write(AppStorage.kApiBase, trimmed);
    return true;
  }

  Future<void> setThemeMode(String mode) async {
    themeMode.value = mode;
    await AppStorage.box.write(AppStorage.kThemeMode, mode);
    Get.changeThemeMode(switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    });
  }

  Future<void> setFullscreenMode(bool value) async {
    fullscreenMode.value = value;
    await AppStorage.box.write('fullscreen_mode', value);
    if (value) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Future<void> setSyncOnStart(bool value) async {
    syncOnStart.value = value;
    await AppStorage.box.write(AppStorage.kSyncOnStart, value);
  }

  Future<void> resetAllData() async {
    await _db.resetEverything();
    await refreshStats();
  }
}
