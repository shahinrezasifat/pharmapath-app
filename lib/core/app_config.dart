import 'package:flutter/foundation.dart';

/// Compile-time defaults. Everything can be changed at runtime from Settings.
abstract final class AppConfig {
  static const String appName = 'ফার্মাপাথ';
  static const String appNameLatin = 'PharmaPath';
  static const String tagline = 'ওষুধ জানুন। ভালো বুঝুন।';
  static const String version = '2.0.0';
  static const String githubOwner = String.fromEnvironment(
    'GITHUB_REPOSITORY_OWNER',
    defaultValue: '',
  );
  static const String githubRepository = String.fromEnvironment(
    'GITHUB_REPOSITORY_NAME',
    defaultValue: '',
  );

  /// Not a hosted service: this is the FastAPI server from
  /// https://github.com/NasirSunny50/Bangladeshi-Medicine-API run locally.
  /// Override with --dart-define=MEDICINE_API_BASE=http://host:8000
  static const String _envBase = String.fromEnvironment(
    'MEDICINE_API_BASE',
    defaultValue: '',
  );

  static String get defaultMedicineApiBase {
    if (_envBase.isNotEmpty) return _envBase;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator alias for the developer machine.
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static const String dataSourceName = 'Bangladeshi-Medicine-API';
  static const String dataSourceUrl =
      'https://github.com/NasirSunny50/Bangladeshi-Medicine-API';

  /// Prebuilt offline catalogue shipped as a Flutter asset. Produced by
  /// `dart run tool/build_seed_db.dart` against the local API. A fresh install
  /// copies this file verbatim into app storage so the app is usable with no
  /// network at all. Bump [seedVersion] whenever the asset is regenerated.
  static const String seedAssetPath = 'assets/learning/medicines_seed.db';
  static const int seedVersion = 3;

  /// Disable asset seeding (e.g. slim test builds) with
  /// --dart-define=DISABLE_SEED=true.
  static const bool seedDisabled = bool.fromEnvironment(
    'DISABLE_SEED',
    defaultValue: false,
  );

  static const Duration requestTimeout = Duration(seconds: 30);

  static const int searchPageSize = 20;
  static const int syncPageSize = 100;
  static const int maxPagesPerSync = 400; // safety cap, not a data limit

  /// Manually-added medicines live in a high id namespace so they can never
  /// collide with (or be clobbered by) API ids, and so catalogue counts used
  /// by the sync fingerprint stay clean.
  static const int manualIdBase = 2000000000;

  /// A medicine is flagged "expiring soon" when it expires within this many
  /// days; the home screen raises an automatic alert for those.
  static const int expiringSoonDays = 60;

  /// Delta-sync tuning. When the server reports that more clinical detail has
  /// been scraped than we hold locally, we opportunistically back-fill up to
  /// this many not-yet-detailed records per sync (bounded, so a sync never
  /// turns into a full re-crawl). Detail requests run with this concurrency.
  static const int deltaDetailBackfill = 400;
  static const int detailConcurrency = 8;
  static const int detailWriteBatch = 200;

  /// Meta table keys shared by the sync engine and the seed builder. Kept as
  /// constants so the shipped seed and a runtime sync agree on the same
  /// change-detection fingerprint format.
  static const String metaFingerprint = 'sync_fingerprint';
  static const String metaLastSync = 'last_sync_at';
  static const String metaSourceTotal = 'source_total';
  static const String metaSourceDetailScraped = 'source_detail_scraped';
  static const String metaSourceBase = 'source_base';
  static const String metaSourceStats = 'source_stats';

  static const String userAgent = 'PharmaPath/2.0 (Flutter; offline-first)';

  /// OpenRouter / OxionAI cloud assistant. OpenAI-compatible chat completions against
  /// https://openrouter.ai/api/v1 (docs: https://openrouter.ai/docs). The key ships as
  /// a compile-time default and can be overridden with
  /// --dart-define=OXION_API_KEY=... — display keys carry an `api-` prefix
  /// which the API itself does not accept, so [normalizedAssistantKey]
  /// strips it before use.
  static const String _envAssistantKey = String.fromEnvironment(
    'OPENROUTER_API_KEY',
    defaultValue: String.fromEnvironment(
      'OXION_API_KEY',
      defaultValue: '***REMOVED***',
    ),
  );
  static const String _envAssistantKeyName = String.fromEnvironment(
    'OXION_API_KEY_NAME',
    defaultValue: 'OpenRouter',
  );
  static const String _envAssistantBase = String.fromEnvironment(
    'OXION_API_BASE',
    defaultValue: 'https://openrouter.ai/api/v1',
  );

  static String get defaultAssistantApiKey => _envAssistantKey;
  static String get defaultAssistantApiKeyName => _envAssistantKeyName;
  static String get defaultAssistantApiBase => _envAssistantBase;

  /// The wire-format key: OxionAI rejects the `api-` display prefix.
  static String normalizedAssistantKey(String key) {
    final trimmed = key.trim();
    return trimmed.startsWith('api-') ? trimmed.substring(4) : trimmed;
  }

  /// Fallback model id used until the user picks one from the /models list
  /// (free, fast, bilingual — ideal zero-cost model on OpenRouter).
  static const String assistantDefaultModel =
      'nvidia/nemotron-3-ultra-550b-a55b:free';
  static const int assistantMaxTokens = 1400;

  /// How many previous chat turns ride along with every request. The full
  /// consultation is kept locally; only this tail is sent so the model always
  /// reads the recent question-and-answer exchange without blowing the
  /// context budget on a long thread.
  static const int assistantHistoryTurns = 24;

  /// Multimodal consultation attachments: at most this many files per
  /// message, each within the byte cap (base64 payloads get large fast).
  static const int assistantMaxAttachments = 3;
  static const int assistantMaxAttachmentBytes = 4 * 1024 * 1024;

  /// Mic-button voice notes auto-stop after this many seconds.
  static const int assistantMaxVoiceSeconds = 60;

  /// File types the paperclip picker offers — only kinds the consultation
  /// models can actually read: pictures, audio and plain-text documents.
  static const List<String> assistantImageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'gif',
    'bmp',
  ];
  static const List<String> assistantAudioExtensions = [
    'mp3',
    'm4a',
    'aac',
    'wav',
    'ogg',
    'opus',
    'webm',
    'amr',
    'flac',
  ];
  static const List<String> assistantTextExtensions = [
    'txt',
    'md',
    'csv',
    'json',
    'log',
  ];

  /// Plain-text documents are quoted into the message up to this length.
  static const int assistantMaxTextFileChars = 2500;

  // ---------------------------------------------------------------------------
  // Learning-module and medicine-detail AI helpers (one-shot tasks, not chat).
  // Every cap keeps a request cheap and inside the model's comfortable window.
  // ---------------------------------------------------------------------------

  /// A lesson whose readable body is at least this long earns an AI bullet
  /// summary; shorter lessons are already summarized by their own intro.
  static const int learningSummaryMinChars = 900;
  static const int learningSummaryMaxTokens = 500;

  /// Mini-chat that lives on a lesson page — grounded, two-answer length.
  static const int learningChatMaxTokens = 700;

  /// Whole-page Bangla translation of a medicine profile. Sent as a single
  /// request (every clinical section at once), so the cap is generous.
  static const int medicineTranslateMaxTokens = 2400;

  /// "বিস্তারিত ব্যাখ্যা" panel — conversational Bangla breakdown.
  static const int medicineExplainMaxTokens = 1100;

  /// Recommendation re-rank: only the chosen candidate codes + one line.
  static const int recommendMaxTokens = 320;

  /// How many lessons the "আপনার জন্য সুপারিশকৃত" carousel offers.
  static const int learningRecommendLimit = 8;

  /// Re-reading a lesson this many times without finishing it means the reader
  /// is stuck, so simpler foundational lessons are surfaced first.
  static const int learningStruggleVisits = 3;

  static const String safetyNotice =
      'এই অ্যাপের ওষুধ-তথ্য শুধুমাত্র শিক্ষামূলক। কোনো ওষুধ শুরু, বন্ধ বা ডোজ '
      'পরিবর্তন করার আগে অবশ্যই একজন যোগ্য চিকিৎসক বা ফার্মাসিস্টের পরামর্শ নিন। '
      'জরুরি অবস্থা, অতিরিক্ত ডোজ বা তীব্র অ্যালার্জিতে সঙ্গে সঙ্গে হাসপাতালে যান।';
}
