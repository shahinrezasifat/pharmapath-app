import 'dart:async';

import '../core/app_config.dart';
import '../core/json_utils.dart' show stripHtml;
import '../core/storage.dart';
import '../data/ai_dao.dart';
import '../models/learning.dart';
import '../models/medicine.dart';
import 'oxion_assistant.dart';

/// One AI helper result: the Bangla text, whether it came out of the local
/// cache instead of the network, and a user-facing reason when it failed.
class AiAnswer {
  const AiAnswer({this.text = '', this.cached = false, this.error = ''});

  final String text;
  final bool cached;

  /// Bangla notice for the UI when [text] is empty.
  final String error;

  bool get ok => text.trim().isNotEmpty;
}

/// Bangla translation of the fields shown on a medicine detail page.
class MedicineTranslation {
  const MedicineTranslation({
    required this.fields,
    this.cached = false,
    this.error = '',
  });

  /// Detail-field key → Bangla text. Missing translations are omitted so the
  /// page can show a Bengali unavailable notice instead of source text.
  final Map<String, String> fields;
  final bool cached;
  final String error;

  bool get ok => fields.isNotEmpty;
  int get translatedCount => fields.length;
}

/// The AI touchpoints of the শেখা module and the medicine detail page.
///
/// Everything here is one-shot, cache-first and offline-safe: a value already
/// stored in `translations` / `ai_cache` is returned without touching the
/// network, an unavailable cloud yields an empty [AiAnswer] with a Bangla
/// notice, and two identical in-flight requests share one model call (rapid
/// taps on "অনুবাদ করুন" are therefore cheap).
///
/// The prompt templates live in [OxionAssistant]; the reply formats they
/// promise are parsed here and documented in docs/AI_PROMPTS.md.
class AiLearningTools {
  AiLearningTools(this._assistant, this._dao);

  final OxionAssistant _assistant;
  final AiDao _dao;

  /// Graceful offline copy demanded by the spec, kept in one place.
  static const String offlineNotice = 'অফলাইন মোড — অনুবাদ বর্তমানে উপলব্ধ নয়';

  /// The educational-use footer every explanation panel carries. The prompt in
  /// [OxionAssistant.explainMedicine] asks for the same sentence, and
  /// [tidyExplanation] drops it from the body so it is never shown twice.
  static const String disclaimer =
      'এই তথ্য শিক্ষামূলক। কোনো ওষুধ শুরু বা বন্ধ করার আগে চিকিৎসকের পরামর্শ নিন।';

  static const String kindLessonSummary = 'lesson_summary';
  static const String kindMedicineExplain = 'medicine_explain';
  static const String kindRecommendations = 'recommendations';

  /// Latin letters are allowed only inside brackets/parentheses, where the
  /// prompts explicitly ask the model to keep drug names and technical terms
  /// (e.g. "(Napa)", "[PPI]"). Anything else means the answer slipped into
  /// English and must not be shown as a Bangla translation.
  static bool isBanglaText(String text) =>
      !RegExp(r'[A-Za-z]').hasMatch(
        stripHtml(text).replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ''),
      );

  final Map<String, Future<String>> _inFlight = {};

  /// True when a model is selected, i.e. a request could actually be made.
  /// Cache reads always work, so cached Bangla is served even offline.
  bool get available => _assistant.ready;

  /// Global Bangla-first preference for medicine details, remembered as
  /// `AppStorage.kUiLanguage` ('bn' translates every field, 'en' the source).
  bool get prefersBangla =>
      AppStorage.read<String>(AppStorage.kUiLanguage) == 'bn';

  void setPrefersBangla(bool value) =>
      AppStorage.write(AppStorage.kUiLanguage, value ? 'bn' : 'en');

  // ---------------------------------------------------------------------------
  // Medicine detail
  // ---------------------------------------------------------------------------

  /// Bangla for every populated identity and clinical field of [medicine].
  ///
  /// Cached fields are never re-requested: only the missing ones go to the
  /// model, in a single request, and each parsed field is stored against the
  /// hash of its own source text.
  Future<MedicineTranslation> translateMedicine(Medicine medicine) async {
    final fields = medicine.translationFields;
    if (fields.isEmpty) {
      return const MedicineTranslation(
        fields: {},
        error: 'এই ওষুধের অনুবাদযোগ্য তথ্য পাওয়া যায়নি।',
      );
    }
    final hashes = <String, String>{
      for (final entry in fields.entries)
        entry.key: AiDao.sourceHash(entry.value),
    };
    final cached = await _dao.translationsMatching(medicine.id, hashes)
      ..removeWhere((_, value) => !isBanglaText(value));
    // Never present the untranslated source as if it were Bangla: a field that
    // has no cached translation is omitted so the UI can show its own notice.
    final missing = [
      for (final entry in fields.entries)
        if (!cached.containsKey(entry.key)) entry,
    ];
    if (missing.isEmpty) {
      return MedicineTranslation(fields: cached, cached: true);
    }
    if (!available) {
      return MedicineTranslation(
        fields: cached,
        cached: cached.isNotEmpty,
        error: offlineNotice,
      );
    }

    final payload = {for (final entry in missing) entry.key: entry.value};
    final reply = await _deduped(
      'translate:${medicine.id}:${hashes.values.join('|')}',
      () => _assistant.translateMedicineFields(payload),
    );
    if (reply == null) {
      return MedicineTranslation(fields: cached, error: offlineNotice);
    }

    final parsed =
        parseTranslation(reply, [for (final field in missing) field.key])
          ..removeWhere((_, value) => !isBanglaText(value));
    for (final entry in parsed.entries) {
      await _dao.saveTranslation(
        medicine.id,
        entry.key,
        hashes[entry.key] ?? '',
        entry.value,
      );
    }
    final merged = <String, String>{...cached, ...parsed};
    if (merged.isEmpty) {
      return const MedicineTranslation(
        fields: {},
        error: 'অনুবাদ পাওয়া যায়নি — আবার চেষ্টা করুন।',
      );
    }
    if (parsed.length < missing.length) {
      return MedicineTranslation(
        fields: merged,
        error: 'কিছু অংশের বাংলা অনুবাদ পাওয়া যায়নি; সেগুলো দেখানো হচ্ছে না।',
      );
    }
    return MedicineTranslation(fields: merged);
  }

  /// Splits a model reply on its `@@key@@` markers (see
  /// [OxionAssistant.translateMedicineFields]). Unknown or duplicated markers
  /// are ignored, and a marker with no body is treated as missing.
  static Map<String, String> parseTranslation(String reply, List<String> keys) {
    final wanted = keys.toSet();
    final marker = RegExp(r'@@\s*([A-Za-z0-9_]+)\s*@@');
    final matches = marker.allMatches(reply).toList();
    final result = <String, String>{};
    for (var i = 0; i < matches.length; i++) {
      final key = matches[i].group(1) ?? '';
      if (!wanted.contains(key) || result.containsKey(key)) continue;
      final start = matches[i].end;
      final end = i + 1 < matches.length ? matches[i + 1].start : reply.length;
      final text = reply.substring(start, end).trim();
      if (text.isNotEmpty) result[key] = text;
    }
    return result;
  }

  /// The "বিস্তারিত ব্যাখ্যা" panel: a conversational Bangla breakdown, cached
  /// per medicine against the hash of the clinical text it was written from.
  Future<AiAnswer> explainMedicine(Medicine medicine) async {
    final context = medicine.toAiContext();
    if (context.trim().isEmpty) {
      return const AiAnswer(error: 'ব্যাখ্যা করার মতো তথ্য পাওয়া যায়নি।');
    }
    final hash = AiDao.sourceHash(context);
    final ref = '${medicine.id}';
    final cached = await _dao.cache(kindMedicineExplain, ref, hash);
    if (cached != null) {
      return AiAnswer(text: tidyExplanation(cached), cached: true);
    }
    if (!available) return const AiAnswer(error: offlineNotice);

    final reply = await _deduped(
      'explain:$ref:$hash',
      () => _assistant.explainMedicine(context: context),
    );
    if (reply == null) return const AiAnswer(error: offlineNotice);
    final tidy = tidyExplanation(reply);
    await _dao.saveCache(kindMedicineExplain, ref, hash, tidy);
    return AiAnswer(text: tidy);
  }

  /// Asks a follow-up grounded in this one medicine's local catalogue record.
  Future<AiAnswer> askAboutMedicine({
    required Medicine medicine,
    required String question,
    List<({String role, String text})> history = const [],
  }) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) return const AiAnswer();
    if (!available) {
      return const AiAnswer(
        error: 'ইন্টারনেট সংযোগ ছাড়া এই ওষুধ সম্পর্কে প্রশ্নের উত্তর দেওয়া যাচ্ছে না।',
      );
    }

    final context = medicine.toAiContext();
    final historyKey = history
        .map((turn) => '${turn.role}:${turn.text}')
        .join('|');
    final requestKey = AiDao.sourceHash('$context|$historyKey|$trimmed');
    final reply = await _deduped(
      'medicine-chat:${medicine.id}:$requestKey',
      () => _assistant.askAboutMedicine(
        medicineContext: context,
        question: trimmed,
        history: history,
      ),
    );
    if (reply == null) {
      return const AiAnswer(error: 'উত্তর পাওয়া যায়নি। আবার চেষ্টা করুন।');
    }
    if (!isBanglaText(reply)) {
      return const AiAnswer(
        error: 'সম্পূর্ণ বাংলা উত্তর পাওয়া যায়নি। আবার চেষ্টা করুন।',
      );
    }
    return AiAnswer(text: reply);
  }

  /// Normalises the explanation into scannable Bangla: bullet glyphs, no
  /// markdown noise, and the educational disclaimer always last.
  static String tidyExplanation(String raw) {
    final lines = [
      for (final line in raw.replaceAll('\r\n', '\n').split('\n'))
        line.trimRight(),
    ];
    final body = <String>[];
    for (final line in lines) {
      var text = line
          .replaceAll(RegExp(r'^\s*[-*]\s+'), '• ')
          // `replaceAll` has no `$1` backreference, so the emphasis markers are
          // unwrapped through a mapped replacement instead.
          .replaceAllMapped(
            RegExp(r'[*_]{1,2}([^*_]+)[*_]{1,2}'),
            (match) => match[1]!,
          )
          .trim();
      if (text.isEmpty) continue;
      if (text.startsWith('#')) {
        text = text.replaceFirst(RegExp(r'^#+\s*'), '');
      }
      // The panel renders the disclaimer itself as a footer.
      if (text.contains('শিক্ষামূলক') && text.contains('পরামর্শ নিন')) continue;
      body.add(text);
    }
    if (body.isEmpty) return raw.trim();
    return body.join('\n');
  }

  // ---------------------------------------------------------------------------
  // Learning module
  // ---------------------------------------------------------------------------

  /// 3–5 bullet AI summary of a long lesson, shown above the lesson body.
  ///
  /// Short lessons get no summary: their own intro already is one, and the
  /// call would only spend tokens repeating it.
  Future<AiAnswer> summarizeLesson(Course course, Lesson lesson) async {
    final plain = stripHtml(lesson.body).trim();
    if (plain.length < AppConfig.learningSummaryMinChars) {
      return const AiAnswer();
    }
    final hash = AiDao.sourceHash(plain);
    final ref = '${course.id}::${lesson.id}';
    final cached = await _dao.cache(kindLessonSummary, ref, hash);
    if (cached != null) {
      return AiAnswer(text: bulletList(cached), cached: true);
    }
    if (!available) return const AiAnswer(error: offlineNotice);

    final reply = await _deduped(
      'summary:$ref:$hash',
      () => _assistant.summarizeLesson(title: lesson.title, body: plain),
    );
    if (reply == null) return const AiAnswer(error: offlineNotice);
    final bullets = bulletList(reply);
    await _dao.saveCache(kindLessonSummary, ref, hash, bullets);
    return AiAnswer(text: bullets);
  }

  /// Turns a model reply into a clean Bangla bullet list (one bullet per line).
  static String bulletList(String raw) {
    final bullets = <String>[];
    for (final line in raw.replaceAll('\r\n', '\n').split('\n')) {
      final text = line
          .replaceAll(RegExp(r'^\s*(?:[-*•]|\d+[.)])\s*'), '')
          .replaceAll(RegExp(r'[*_]{1,2}([^*_]+)[*_]{1,2}'), r'$1')
          .trim();
      if (text.isEmpty) continue;
      bullets.add('• $text');
    }
    return bullets.join('\n');
  }

  /// One answer in the lesson mini-chat. [history] is the thread inside the
  /// sheet, oldest first; the lesson text itself is the grounding context.
  Future<AiAnswer> askAboutLesson({
    required Course course,
    required Lesson lesson,
    required String question,
    List<({String role, String text})> history = const [],
  }) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) return const AiAnswer();
    if (!available) {
      return const AiAnswer(
        error:
            'অফলাইন মোড — এখন প্রশ্নের উত্তর দেওয়া যাচ্ছে না। '
            'ইন্টারনেট এলে আবার চেষ্টা করুন।',
      );
    }
    final context =
        'কোর্স: ${course.title}\nপাঠ: ${lesson.title}\n'
        '${stripHtml(lesson.body)}';
    final reply = await _deduped(
      'lesson-chat:${course.id}::${lesson.id}:$trimmed',
      () => _assistant.askAboutLesson(
        lessonContext: context,
        question: trimmed,
        history: history,
      ),
    );
    if (reply == null) {
      return const AiAnswer(
        error: 'উত্তর করা যায়নি। ইন্টারনেট সংযোগ ঠিক আছে কিনা দেখুন।',
      );
    }
    return AiAnswer(text: reply);
  }

  /// Re-ranks locally-scored lesson candidates with the model and returns the
  /// 1-based positions it chose, or null when the answer cannot be trusted.
  ///
  /// The reply is cached under [signature] (a hash of the reading history plus
  /// the candidate list), so reopening the learning hub costs nothing until the
  /// reader actually changes what they have read.
  Future<LessonRanking?> rankLessons({
    required String readingHistory,
    required List<LessonSuggestion> candidates,
  }) async {
    if (candidates.isEmpty) return const LessonRanking(order: [], note: '');
    final signature = AiDao.sourceHash(
      '$readingHistory|${candidates.map((c) => c.key).join(',')}',
    );
    final cached = await _dao.cache(kindRecommendations, 'next', signature);
    if (cached != null) {
      final parsed = parseRanking(cached, candidates.length);
      if (parsed != null) return parsed;
    }
    if (!available) return null;

    final lines = <String>[];
    for (var i = 0; i < candidates.length; i++) {
      final suggestion = candidates[i];
      lines.add(
        'K${i + 1}: ${suggestion.course.title} → ${suggestion.lesson.title} '
        '(${suggestion.lesson.minutes} মিনিট, ${suggestion.reason})',
      );
    }
    final reply = await _deduped(
      'rank:$signature',
      () => _assistant.rankLessons(
        readingHistory: readingHistory.trim().isEmpty
            ? 'এখনো কোনো পাঠ পড়া হয়নি।'
            : readingHistory,
        candidates: lines.join('\n'),
      ),
    );
    if (reply == null) return null;
    final parsed = parseRanking(reply, candidates.length);
    if (parsed == null) return null;
    await _dao.saveCache(kindRecommendations, 'next', signature, reply);
    return parsed;
  }

  /// Reads the `K3, K1, …` line (Bangla digits included) plus the optional
  /// one-line reason. Returns null when nothing in range was named, so the
  /// caller keeps its own local ordering.
  static LessonRanking? parseRanking(String reply, int candidateCount) {
    final normalised = toAsciiDigits(reply);
    final found = <int>{};
    String note = '';
    for (final line in normalised.split('\n')) {
      final codes = RegExp(r'K\s*(\d{1,2})', caseSensitive: false)
          .allMatches(line)
          .map((m) => int.tryParse(m.group(1) ?? '') ?? 0)
          .where((n) => n >= 1 && n <= candidateCount)
          .toList();
      codes.forEach(found.add);
      if (codes.isNotEmpty) continue;
      if (note.isEmpty && line.trim().isNotEmpty) {
        note = line.replaceFirst(RegExp(r'^[—–-]\s*'), '').trim();
      }
    }
    if (found.isEmpty) return null;
    // Preserve first-mention order across the whole reply.
    final order = <int>[];
    for (final match in RegExp(
      r'K\s*(\d{1,2})',
      caseSensitive: false,
    ).allMatches(normalised)) {
      final n = int.tryParse(match.group(1) ?? '') ?? 0;
      if (n >= 1 && n <= candidateCount && !order.contains(n)) order.add(n);
    }
    return LessonRanking(order: order, note: note);
  }

  /// Bangla and Devanagari digits → ASCII, so a model that answers "৩, ১" is
  /// still understood.
  static String toAsciiDigits(String value) {
    const sets = [
      (base: 0x09E6, name: 'bn'), // Bengali
      (base: 0x0660, name: 'ar'), // Arabic-Indic (used in some Bangla fonts)
      (base: 0x0966, name: 'de'), // Devanagari
    ];
    var out = value;
    for (final set in sets) {
      for (var digit = 0; digit < 10; digit++) {
        out = out.replaceAll(String.fromCharCode(set.base + digit), '$digit');
      }
    }
    return out;
  }

  /// Runs [body] once per [key]: a second call while the first is still
  /// awaiting gets the same future instead of a second paid request.
  Future<String?> _deduped(String key, Future<String> Function() body) async {
    final existing = _inFlight[key];
    if (existing != null) {
      try {
        return await existing;
      } on AssistantUnavailable {
        return null;
      }
    }
    final future = body();
    _inFlight[key] = future;
    try {
      return await future;
    } on AssistantUnavailable {
      return null;
    } finally {
      _inFlight.remove(key);
    }
  }
}

/// The model's chosen ordering (1-based candidate positions) and its one-line
/// Bangla reason for the carousel heading.
class LessonRanking {
  const LessonRanking({required this.order, required this.note});

  final List<int> order;
  final String note;
}
