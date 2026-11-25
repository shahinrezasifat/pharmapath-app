import 'package:get_storage/get_storage.dart';

/// Non-secret preferences persisted with GetStorage.
abstract final class AppStorage {
  static late final GetStorage _box;

  static Future<void> init() async {
    await GetStorage.init();
    _box = GetStorage();
  }

  static GetStorage get box => _box;

  static const String kApiBase = 'medicine_api_base';
  static const String kAiEnabled = 'ai_enabled';
  static const String kAiModel = 'ai_model';
  static const String kThemeMode = 'theme_mode';
  static const String kSyncOnStart = 'sync_on_start';
  static const String kAttributionAck = 'attribution_ack';

  /// Chat language greeting: 'bn' | 'en' and whether it was already asked.
  /// Reading either script is always honoured; replies are Bangla-only.
  static const String kAiLanguage = 'ai_language';
  static const String kAiLanguageAsked = 'ai_language_asked';

  /// Global display language for medicine detail pages: 'bn' shows the AI
  /// Bangla translation of every clinical field, 'en' the original source text.
  /// Chosen once on any medicine and remembered until it is changed again.
  static const String kUiLanguage = 'ui_language';

  /// Values written while GetStorage was unreachable (unit tests run without
  /// the path_provider plugin). Kept in sync with the box on every write so a
  /// read always sees the freshest value instead of silently losing a choice.
  static final Map<String, Object?> _volatile = {};

  /// Null-safe read that never throws when storage is not initialised.
  static T? read<T>(String key) {
    try {
      final stored = _box.read<T>(key);
      if (stored != null) return stored;
    } catch (_) {
      // Fall through to the in-memory copy below.
    }
    final fallback = _volatile[key];
    return fallback is T ? fallback : null;
  }

  /// Never-throwing write — persists when possible, always keeps the value.
  static void write(String key, Object? value) {
    if (value == null) {
      _volatile.remove(key);
    } else {
      _volatile[key] = value;
    }
    try {
      _box.write(key, value);
    } catch (_) {
      // Storage unavailable; the in-memory copy carries this session.
    }
  }
}
