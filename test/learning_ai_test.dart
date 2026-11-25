import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pharmapath_app/controllers/learning_controller.dart';
import 'package:pharmapath_app/controllers/lesson_ai_controller.dart';
import 'package:pharmapath_app/controllers/medicine_detail_controller.dart';
import 'package:pharmapath_app/core/app_config.dart';
import 'package:pharmapath_app/core/json_utils.dart' show stripHtml;
import 'package:pharmapath_app/core/storage.dart';
import 'package:pharmapath_app/data/ai_dao.dart';
import 'package:pharmapath_app/data/app_database.dart';
import 'package:pharmapath_app/data/learning_dao.dart';
import 'package:pharmapath_app/data/learning_repository.dart';
import 'package:pharmapath_app/data/medicine_dao.dart';
import 'package:pharmapath_app/models/learning.dart';
import 'package:pharmapath_app/models/medicine.dart';
import 'package:pharmapath_app/services/ai_learning_tools.dart';
import 'package:pharmapath_app/services/medicine_api.dart';
import 'package:pharmapath_app/services/oxion_assistant.dart';
import 'package:pharmapath_app/services/sync_service.dart';
import 'package:pharmapath_app/views/detail_view.dart';
import 'package:pharmapath_app/views/learning_view.dart';
import 'package:pharmapath_app/views/lesson_view.dart';
import 'package:pharmapath_app/widgets/company_logo.dart';

/// A cloud that is always unreachable, and loud about it: every one-shot task
/// throws, so a test that accidentally depends on the network fails instead of
/// quietly passing on a fabricated answer.
class _OfflineAssistant extends OxionAssistant {
  _OfflineAssistant() : super();

  int calls = 0;

  @override
  bool get ready => false;

  @override
  Future<void> refreshModels() async {}

  @override
  Future<String> translateMedicineFields(Map<String, String> fields) async {
    calls++;
    throw const AssistantUnavailable('no model');
  }

  @override
  Future<String> explainMedicine({required String context}) async {
    calls++;
    throw const AssistantUnavailable('no model');
  }

  @override
  Future<String> summarizeLesson({
    required String title,
    required String body,
  }) async {
    calls++;
    throw const AssistantUnavailable('no model');
  }

  @override
  Future<String> askAboutLesson({
    required String lessonContext,
    required String question,
    List<({String role, String text})> history = const [],
  }) async {
    calls++;
    throw const AssistantUnavailable('no model');
  }

  @override
  Future<String> rankLessons({
    required String readingHistory,
    required String candidates,
  }) async {
    calls++;
    throw const AssistantUnavailable('no model');
  }
}

class _ScriptedAssistant extends _OfflineAssistant {
  _ScriptedAssistant(this.replyText, {this.chatReply});

  final String replyText;
  final String? chatReply;
  String? chatContext;
  String? chatQuestion;
  List<({String role, String text})> chatHistory = const [];

  @override
  bool get ready => true;

  @override
  Future<String> translateMedicineFields(Map<String, String> fields) async =>
      replyText;

  @override
  Future<String> askAboutMedicine({
    required String medicineContext,
    required String question,
    List<({String role, String text})> history = const [],
  }) async {
    chatContext = medicineContext;
    chatQuestion = question;
    chatHistory = history;
    return chatReply ?? replyText;
  }
}

/// A model that always answers, with scripted Bangla, so everything built on
/// top of it (buttons, badges, preference writes, the carousel) is testable
/// without a network.
class _StubTools extends AiLearningTools {
  _StubTools(AppDatabase db) : super(_OfflineAssistant(), AiDao(db));

  Map<String, String> banglaFields = const {};
  String explanation = '';
  LessonRanking? ranking;
  int translateCalls = 0;
  int rankCalls = 0;
  int explainCalls = 0;
  int medicineChatCalls = 0;
  int summarizeCalls = 0;
  String lastQuestion = '';
  List<({String role, String text})> lastMedicineChatHistory = const [];

  @override
  bool get available => true;

  @override
  Future<MedicineTranslation> translateMedicine(Medicine medicine) async {
    translateCalls++;
    return MedicineTranslation(fields: banglaFields);
  }

  @override
  Future<AiAnswer> explainMedicine(Medicine medicine) async {
    explainCalls++;
    return AiAnswer(text: explanation);
  }

  @override
  Future<AiAnswer> askAboutMedicine({
    required Medicine medicine,
    required String question,
    List<({String role, String text})> history = const [],
  }) async {
    medicineChatCalls++;
    lastQuestion = question;
    lastMedicineChatHistory = history;
    return const AiAnswer(
      text: 'এই ওষুধের তথ্য অনুযায়ী জ্বর কমাতে ব্যবহৃত হয়।',
    );
  }

  @override
  Future<AiAnswer> summarizeLesson(Course course, Lesson lesson) async {
    summarizeCalls++;
    return const AiAnswer(text: '• প্রথম কথা\n• দ্বিতীয় কথা');
  }

  @override
  Future<AiAnswer> askAboutLesson({
    required Course course,
    required Lesson lesson,
    required String question,
    List<({String role, String text})> history = const [],
  }) async {
    lastQuestion = question;
    return const AiAnswer(text: 'পাঠের তথ্য থেকে উত্তর।');
  }

  @override
  Future<LessonRanking?> rankLessons({
    required String readingHistory,
    required List<LessonSuggestion> candidates,
  }) async {
    rankCalls++;
    return ranking;
  }
}

/// Never touches the network: the detail page only asks SyncService for a
/// record it already holds with `detailLoaded`, which is served locally.
class _NoApi extends MedicineApi {
  _NoApi() : super(baseUrl: () => 'http://fake');
}

/// A course-scoped stub repository: the catalogue is supplied in memory while
/// progress, bookmarks and reading history still run through the real database.
class _StubRepository extends LearningRepository {
  _StubRepository(AppDatabase db, this._courses) : super(LearningDao(db));

  final List<Course> _courses;

  @override
  Future<List<Course>> courses() async => _courses;

  @override
  Future<List<BodySystem>> bodySystems() async => const [];

  @override
  Future<List<DiseaseTopic>> diseaseTopics() async => const [];
}

Medicine detailedMedicine({
  int id = 1,
  String brand = 'Napa',
  String? dosageText,
}) => Medicine(
  id: id,
  brandName: brand,
  genericName: 'Paracetamol',
  company: 'Beximco',
  strength: '500 mg',
  dosageForm: 'Tablet',
  detailLoaded: true,
  indications: 'Fever and mild pain.',
  dosageAndAdministration:
      dosageText ?? 'Take after food, 1 tablet three times daily.',
  sideEffects: 'Rash in rare cases.',
  pregnancyAndLactation:
      'গর্ভাবস্থা ও স্তন্যদানে ব্যবহারের আগে চিকিৎসকের পরামর্শ নিন।',
);

Lesson lesson(
  String id, {
  String title = 'পাঠ',
  int minutes = 6,
  String body = '<p>টিউ</p>',
}) => Lesson(
  id: id,
  title: title,
  summary: 'সংক্ষিপ্ত সারক।',
  body: body,
  keyPoints: const ['মূল কথা'],
  minutes: minutes,
);

Course course(
  String id, {
  String category = 'body',
  String title = 'কোর্স',
  List<Lesson>? lessons,
  int lessonCount = 3,
}) => Course(
  id: id,
  title: title,
  subtitle: 'উপশিরোনাম',
  icon: 'book',
  category: category,
  lessons:
      lessons ??
      [for (var i = 0; i < lessonCount; i++) lesson('$id-l$i', minutes: 6)],
  quiz: const [],
);

/// Long enough to clear [AppConfig.learningSummaryMinChars].
String longBody() => '<p>${'জ্বর নিয়ে বিস্তারিত আলোচনা। ' * 60}</p>';

/// Lets real (sqflite / isolate) work finish while the tree keeps pumping,
/// then settles animations *outside* the real-async zone.
///
/// `pumpAndSettle` inside [WidgetTester.runAsync] can spin forever, and a
/// pending database write that outlives the test closes the database under
/// its feet — so every DB-backed screen is driven through here.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The Bangla-first preference lives in global storage; never let one test
  /// leak into the next.
  setUp(() => AppStorage.write(AppStorage.kUiLanguage, null));
  tearDown(() => AppStorage.write(AppStorage.kUiLanguage, null));

  group('AiDao content-addressed caches', () {
    late AppDatabase db;
    late AiDao dao;

    setUp(() async {
      db = await AppDatabase.openForTesting();
      dao = AiDao(db);
    });
    tearDown(() async => db.close());

    test('sourceHash is stable and reacts to any edit', () {
      final a = AiDao.sourceHash('Fever and mild pain.');
      expect(AiDao.sourceHash('Fever and mild pain.'), a);
      expect(AiDao.sourceHash('Fever and mild pain'), isNot(a));
      expect(AiDao.sourceHash(''), isNot(a));
      // Only hex and separators: a safe cache key on any platform.
      expect(a, matches(RegExp(r'^[0-9a-f]+-[0-9a-f]+-[0-9a-f]+$')));
    });

    test(
      'a translation is only served while its source still matches',
      () async {
        await dao.saveTranslation(7, 'indications', 'hash-1', 'জ্বরের জন্য।');
        expect(
          await dao.translation(7, 'indications', 'hash-1'),
          'জ্বরের জন্য।',
        );
        // The upstream text changed: the stale Bangla must not be reused.
        expect(await dao.translation(7, 'indications', 'hash-2'), isNull);

        final matched = await dao.translationsMatching(7, {
          'indications': 'hash-1',
          'dosage_and_administration': 'hash-9',
        });
        expect(matched, {'indications': 'জ্বরের জন্য।'});
      },
    );

    test('ai_cache keeps summaries, explanations and rankings apart', () async {
      await dao.saveCache('lesson_summary', 'c::l', 'h1', '• সংক্ষেপ');
      await dao.saveCache('medicine_explain', '7', 'h1', 'ব্যাখ্যা');
      expect(await dao.cache('lesson_summary', 'c::l', 'h1'), '• সংক্ষেপ');
      expect(await dao.cache('lesson_summary', 'c::l', 'h2'), isNull);
      expect(await dao.cache('medicine_explain', '7', 'h1'), 'ব্যাখ্যা');
      // A re-generation overwrites the same (kind, ref) row instead of growing.
      await dao.saveCache('medicine_explain', '7', 'h1', 'নতুন ব্যাখ্যা');
      expect(await dao.cache('medicine_explain', '7', 'h1'), 'নতুন ব্যাখ্যা');
    });
  });

  group('AI reply parsing', () {
    test('translation markers are read, unknown and empty ones dropped', () {
      final parsed = AiLearningTools.parseTranslation(
        '@@indications@@\nজ্বরে ব্যবহার হয়।\n@@composition@@\n\n'
        '@@bogus_key@@\nলাগে না\n@@side_effects@@   র‍্যাশ হতে পারে',
        ['indications', 'composition', 'side_effects'],
      );
      expect(parsed['indications'], 'জ্বরে ব্যবহার হয়।');
      expect(parsed['side_effects'], 'র‍্যাশ হতে পারে');
      expect(parsed.containsKey('composition'), isFalse); // empty body
      expect(parsed.containsKey('bogus_key'), isFalse); // not requested
    });

    test('explanations become scannable and lose the duplicated footer', () {
      final tidy = AiLearningTools.tidyExplanation(
        '## কেন এই ওষুধ\n'
        '- জ্বর কমাতে **দেখান**।\n'
        'কীভাবে খাবেন\n'
        '* খাওয়ার পরে\n'
        'এই তথ্য শিক্ষামূলক। কোনো ওষুধ শুরু বা বন্ধ করার আগে '
        'চিকিৎসকের পরামর্শ নিন।',
      );
      expect(tidy, contains('কেন এই ওষুধ'));
      expect(tidy, contains('• জ্বর কমাতে দেখান।'));
      expect(tidy, contains('• খাওয়ার পরে'));
      expect(tidy, isNot(contains('##')));
      expect(tidy, isNot(contains('**')));
      // The panel renders the disclaimer as its own footer.
      expect(tidy, isNot(contains('শিক্ষামূলক')));
    });

    test('numbered and dashed model replies both become bullets', () {
      expect(
        AiLearningTools.bulletList('1. প্রথম\n- দ্বিতীয়\n• তৃতীয়\n\n'),
        '• প্রথম\n• দ্বিতীয়\n• তৃতীয়',
      );
    });

    test('ranking accepts Bangla digits and ignores out-of-range codes', () {
      final parsed = AiLearningTools.parseRanking(
        'K৩, K১, K৯\n— ওজন কমানোর পাঠটি আগে পড়ুন',
        3,
      );
      expect(parsed, isNotNull);
      expect(parsed!.order, [3, 1]); // K9 was not a candidate
      expect(parsed.note, contains('ওজন কমানোর'));
      expect(AiLearningTools.parseRanking('কিছুই না', 3), isNull);
    });

    test('toAsciiDigits normalises the digit sets models mix up', () {
      expect(AiLearningTools.toAsciiDigits('১২৩'), '123');
      expect(AiLearningTools.toAsciiDigits('४५'), '45');
      expect(AiLearningTools.toAsciiDigits('٦٧'), '67');
    });
  });

  group('AiLearningTools offline behaviour', () {
    late AppDatabase db;
    late _OfflineAssistant assistant;
    late AiLearningTools tools;

    setUp(() async {
      db = await AppDatabase.openForTesting();
      assistant = _OfflineAssistant();
      tools = AiLearningTools(assistant, AiDao(db));
    });
    tearDown(() async {
      expect(assistant.calls, 0, reason: 'no test may reach the network');
      await db.close();
    });

    test('the Bangla preference is remembered globally', () {
      expect(tools.prefersBangla, isFalse);
      tools.setPrefersBangla(true);
      expect(AppStorage.read<String>(AppStorage.kUiLanguage), 'bn');
      expect(tools.prefersBangla, isTrue);
      tools.setPrefersBangla(false);
      expect(tools.prefersBangla, isFalse);
    });

    test(
      'cached Bangla is served offline, the rest reports the notice',
      () async {
        final medicine = detailedMedicine(id: 3);
        final sections = medicine.clinicalSections;
        await AiDao(db).saveTranslation(
          3,
          sections.first.key,
          AiDao.sourceHash(sections.first.value),
          'জ্বর ও হালকা ব্যথার জন্য।',
        );

        final result = await tools.translateMedicine(medicine);
        expect(result.cached, isTrue);
        expect(result.fields[sections.first.key], 'জ্বর ও হালকা ব্যথার জন্য।');
        // Untranslated fields stay absent instead of leaking source text.
        expect(result.error, AiLearningTools.offlineNotice);
        expect(result.translatedCount, 1);
      },
    );

    test('English text in a partial model reply is never accepted', () async {
      final medicine = detailedMedicine(id: 30);
      final scripted = _ScriptedAssistant(
        '@@brand_name@@\nNapa\n'
        '@@indications@@\nজ্বর ও হালকা ব্যথায় ব্যবহার হয়।',
      );
      final result = await AiLearningTools(
        scripted,
        AiDao(db),
      ).translateMedicine(medicine);

      expect(result.fields.keys, {'indications'});
      expect(
        result.fields.values.every(
          (value) => !RegExp(r'[A-Za-z]').hasMatch(value),
        ),
        isTrue,
      );
      expect(result.error, contains('বাংলা অনুবাদ'));
    });

    test('medicine follow-up uses the selected medicine as context', () async {
      final scripted = _ScriptedAssistant(
        '',
        chatReply: 'এই ওষুধের তথ্য অনুযায়ী জ্বর কমাতে ব্যবহার হয়।',
      );
      final medicine = detailedMedicine(id: 31);
      final answer = await AiLearningTools(scripted, AiDao(db))
          .askAboutMedicine(
            medicine: medicine,
            question: 'এটি কী কাজে লাগে?',
            history: const [(role: 'user', text: 'ওষুধটি কী?')],
          );

      expect(answer.text, contains('জ্বর'));
      expect(scripted.chatContext, contains('Napa'));
      expect(scripted.chatQuestion, 'এটি কী কাজে লাগে?');
      expect(scripted.chatHistory, hasLength(1));
    });

    test('medicine chat rejects answers containing English', () async {
      final scripted = _ScriptedAssistant('', chatReply: 'It treats fever.');
      final answer = await AiLearningTools(scripted, AiDao(db))
          .askAboutMedicine(
            medicine: detailedMedicine(id: 32),
            question: 'এটি কী কাজে লাগে?',
          );
      expect(answer.ok, isFalse);
      expect(answer.error, contains('বাংলা'));
    });

    test('a cached explanation opens instantly offline', () async {
      final medicine = detailedMedicine(id: 4);
      await AiDao(db).saveCache(
        AiLearningTools.kindMedicineExplain,
        '4',
        AiDao.sourceHash(medicine.toAiContext()),
        'কেন এই ওষুধ\n• জ্বরে।',
      );
      final answer = await tools.explainMedicine(medicine);
      expect(answer.cached, isTrue);
      expect(answer.text, contains('জ্বরে'));
    });

    test('an uncached explanation reports the offline notice', () async {
      final answer = await tools.explainMedicine(detailedMedicine(id: 5));
      expect(answer.ok, isFalse);
      expect(answer.error, AiLearningTools.offlineNotice);
    });

    test('short lessons are never summarised', () async {
      final c = course('c', lessons: [lesson('l')]);
      final answer = await tools.summarizeLesson(c, c.lessons.first);
      expect(answer.ok, isFalse);
      expect(answer.error, isEmpty);
      expect(answer.text, isEmpty);
    });

    test('a long lesson reads its summary from the cache', () async {
      final long = lesson('l', body: longBody());
      final c = course('c', lessons: [long]);
      await AiDao(db).saveCache(
        AiLearningTools.kindLessonSummary,
        'c::l',
        AiDao.sourceHash(stripHtml(long.body).trim()),
        '• জ্বরে গুরুত্বপূর্ণ কথা',
      );
      final answer = await tools.summarizeLesson(c, long);
      expect(answer.cached, isTrue);
      expect(answer.text, contains('জ্বরে'));
    });

    test('the lesson tutor answers politely offline', () async {
      final c = course('c', lessons: [lesson('l')]);
      final answer = await tools.askAboutLesson(
        course: c,
        lesson: c.lessons.first,
        question: 'ডোজ কত?',
      );
      expect(answer.ok, isFalse);
      expect(answer.error, contains('অফলাইন'));
      expect(answer.error, contains('ইন্টারনেট'));
    });

    test('ranking gives up quietly so the local order survives', () async {
      final suggestions = [
        for (var i = 0; i < 3; i++)
          LessonSuggestion(
            course: course('c'),
            lesson: lesson('l$i'),
            reason: 'কারণ',
            score: 3 - i,
          ),
      ];
      final result = await tools.rankLessons(
        readingHistory: 'পাঠ ১ — ২ বার পড়া',
        candidates: suggestions,
      );
      expect(result, isNull);
    });
  });

  group('Reading history and recommendations', () {
    late AppDatabase db;

    setUp(() async {
      db = await AppDatabase.openForTesting();
    });
    tearDown(() async => db.close());

    Future<LearningController> open(
      List<Course> courses, {
      AiLearningTools? ai,
    }) async {
      final controller = LearningController(_StubRepository(db, courses), ai);
      await controller.load();
      return controller;
    }

    test('markRead counts visits and a later completion keeps them', () async {
      final dao = LearningDao(db);
      await dao.markRead('a', 'a-l0');
      await dao.markRead('a', 'a-l0');
      await dao.markCompleted('a', 'a-l0', true);
      final history = await dao.readingHistory();
      expect(history.single.visits, 2);
      expect(history.single.completed, isTrue);
      expect(history.single.courseId, 'a');
    });

    test('history is newest-first and ignores lessons never opened', () async {
      final dao = LearningDao(db);
      await dao.markRead('a', 'a-l0');
      await Future<void>.delayed(const Duration(milliseconds: 8));
      await dao.markRead('b', 'b-l1');
      await dao.markCompleted('a', 'a-l2', true); // progress, not a read
      final history = await dao.readingHistory();
      expect(history.map((h) => h.key).toList(), ['b::b-l1', 'a::a-l0']);
    });

    test('the next lesson of a started course leads the carousel', () async {
      final controller = await open([
        course('a', lessons: [lesson('a-l0'), lesson('a-l0b')]),
        course('b', category: 'medicine', lessons: [lesson('b-l0')]),
      ]);
      await controller.markRead('a', 'a-l0');
      await controller.setLessonCompleted('a', 'a-l0', true);

      final top = controller.computeRecommendations().first;
      expect(top.lesson.id, 'a-l0b');
      expect(top.reason, contains('পরের পাঠ'));
      expect(top.easierEntry, isFalse);
    });

    test('a repeatedly read lesson proposes the shortest one first', () async {
      final controller = await open([
        course(
          'a',
          lessons: [
            lesson('a-hard', title: 'কঠিন পাঠ', minutes: 12),
            lesson('a-easy', title: 'সহজ পাঠ', minutes: 3),
          ],
        ),
      ]);
      for (var i = 0; i < AppConfig.learningStruggleVisits; i++) {
        await controller.markRead('a', 'a-hard');
      }

      final top = controller.computeRecommendations().first;
      expect(top.lesson.id, 'a-easy');
      expect(top.easierEntry, isTrue);
      expect(top.reason, contains('সহজ ভিত্তি'));
      expect(controller.visitsOf('a', 'a-hard'), 3);
    });

    test('continueReading points at the last unfinished lesson', () async {
      final controller = await open([
        course('a', lessons: [lesson('a-l0'), lesson('a-l1')]),
      ]);
      expect(controller.continueReading, isNull);

      await controller.markRead('a', 'a-l0');
      expect(controller.continueReading?.lesson.id, 'a-l0');

      await controller.setLessonCompleted('a', 'a-l0', true);
      expect(controller.continueReading, isNull);
    });

    test('the local order survives when the AI helper is absent', () async {
      final controller = await open([
        course('a', lessons: [lesson('a-l0'), lesson('a-l1')]),
        course('b', category: 'medicine'),
        course('c', category: 'pharmacy'),
      ]);
      await controller.markRead('a', 'a-l0');
      await controller.refreshRecommendations();
      expect(controller.recommendations, isNotEmpty);
      expect(controller.recommendationNote.value, isEmpty);
    });

    test('the AI re-ranks the carousel and its reason is shown', () async {
      final stub = _StubTools(db);
      final controller = await open([
        course('a', lessons: [lesson('a-l0'), lesson('a-l1'), lesson('a-l2')]),
        course('b', category: 'medicine'),
        course('c', category: 'pharmacy'),
      ], ai: stub);
      await controller.markRead('a', 'a-l0');
      final local = controller.recommendations.map((s) => s.key).toList();
      expect(local.length, greaterThanOrEqualTo(3));

      stub.ranking = const LessonRanking(
        order: [3, 1, 2],
        note: 'আপনার পড়া অনুযায়ী সাজানো',
      );
      final before = stub.rankCalls;
      await controller.refreshRecommendations();
      expect(stub.rankCalls, before + 1);
      expect(controller.recommendations.first.key, local[2]);
      expect(controller.recommendationNote.value, 'আপনার পড়া অনুযায়ী সাজানো');

      // useAi: false must not spend a request at all.
      final after = stub.rankCalls;
      await controller.refreshRecommendations(useAi: false);
      expect(stub.rankCalls, after);
    });

    test('clearing progress empties the history and the carousel', () async {
      final controller = await open([
        course('a', lessons: [lesson('a-l0')]),
      ]);
      await controller.markRead('a', 'a-l0');
      expect(controller.history, isNotEmpty);
      await controller.clearAllProgress();
      expect(controller.history, isEmpty);
      expect(controller.recommendations, isEmpty);
      expect(await LearningDao(db).readingHistory(), isEmpty);
    });
  });

  group('LessonAiController', () {
    late AppDatabase db;
    setUp(() async {
      db = await AppDatabase.openForTesting();
    });
    tearDown(() async => db.close());

    test('a short lesson never asks for a summary', () async {
      final stub = _StubTools(db);
      final c = course('a', lessons: [lesson('a-l0')]);
      final controller = LessonAiController(c, c.lessons.first, stub);
      controller.onInit();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.isLong, isFalse);
      expect(stub.summarizeCalls, 0);
      expect(controller.summary.value, isEmpty);
    });

    test('a long lesson gets its AI bullets', () async {
      final stub = _StubTools(db);
      final long = lesson('a-l0', body: longBody());
      final c = course('a', lessons: [long]);
      final controller = LessonAiController(c, long, stub);
      controller.onInit();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.isLong, isTrue);
      expect(stub.summarizeCalls, 1);
      expect(controller.summary.value, contains('প্রথম কথা'));
      expect(controller.summarizing.value, isFalse);
    });

    test('a question appends both turns to the thread', () async {
      final stub = _StubTools(db);
      final c = course('a', lessons: [lesson('a-l0')]);
      final controller = LessonAiController(c, c.lessons.first, stub);
      await controller.ask('  গরম পানি খাবার?  ');
      expect(stub.lastQuestion, 'গরম পানি খাবার?');
      expect(controller.chat.map((t) => t.role).toList(), ['user', 'ai']);
      expect(controller.chatError.value, isEmpty);
      expect(controller.hasChat, isTrue);

      controller.clearChat();
      expect(controller.chat, isEmpty);
    });

    test('without any helper the thread still says why', () async {
      final c = course('a', lessons: [lesson('a-l0')]);
      final controller = LessonAiController(c, c.lessons.first, null);
      await controller.ask('কেন?');
      expect(controller.chat.map((t) => t.role).toList(), ['user']);
      expect(controller.chatError.value, isNotEmpty);
    });
  });

  group('medicine detail translation UI', () {
    late AppDatabase db;
    late MedicineApi api;
    late _StubTools tools;

    setUp(() async {
      db = await AppDatabase.openForTesting();
      await db.upsertDetailBatch([detailedMedicine(id: 11)]);
      api = _NoApi();
      final dao = MedicineDao(db, pageSize: 5);
      Get.put<MedicineDao>(dao);
      Get.put<SyncService>(SyncService(api: api, db: db, dao: dao));
      tools = _StubTools(db);
      tools.banglaFields = const {
        'brand_name': 'নাপা',
        'generic_name': 'প্যারাসিটামল',
        'company': 'বেক্সিমকো',
        'strength': '৫০০ মিলিগ্রাম',
        'dosage_form': 'ট্যাবলেট',
        'indications': 'জ্বর ও হালকা ব্যথায়।',
        'dosage_and_administration': 'খাবারের পরে, দিনে তিনবার।',
        'side_effects': 'বিরল ক্ষেত্রে র‍্যাশ।',
        'pregnancy_and_lactation':
            'গর্ভাবস্থা ও স্তন্যদানে ব্যবহারের আগে চিকিৎসকের পরামর্শ নিন।',
      };
      Get.put<AiLearningTools>(tools, permanent: true);
    });

    tearDown(() async {
      Get.reset();
      api.dispose();
      await db.close();
    });

    testWidgets('automatically shows the complete record in Bangla', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MedicineDetailView(medicine: detailedMedicine(id: 11)),
        ),
      );
      await settle(tester);
      expect(tools.translateCalls, 1);
      expect(find.text('বিস্তারিত ব্যাখ্যা'), findsOneWidget);
      expect(find.text('নাপা'), findsWidgets);
      expect(
        find.text('প্যারাসিটামল · ৫০০ মিলিগ্রাম · ট্যাবলেট'),
        findsOneWidget,
      );
      expect(find.text('বেক্সিমকো'), findsWidgets);
      expect(find.byType(CompanyLogo), findsOneWidget);
      expect(find.text('জ্বর ও হালকা ব্যথায়।'), findsOneWidget);
      expect(find.text('খাবারের পরে, দিনে তিনবার।'), findsNothing);
      expect(find.text('ডোজ ও ব্যবহারবিধি'), findsOneWidget);
      expect(find.text('অনূদিত'), findsWidgets);
      expect(find.text('Fever and mild pain.'), findsNothing);
      expect(find.text('Paracetamol'), findsNothing);
      expect(find.text('Beximco'), findsNothing);
      expect(find.text('ইংরেজিতে দেখুন'), findsNothing);
      expect(find.text('বাংলা অনুবাদ পাওয়া যায়নি'), findsNothing);
    });

    testWidgets('an existing language preference cannot switch to English', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      AppStorage.write(AppStorage.kUiLanguage, 'bn');

      await tester.pumpWidget(
        MaterialApp(
          home: MedicineDetailView(medicine: detailedMedicine(id: 11)),
        ),
      );
      await settle(tester);
      expect(tools.translateCalls, greaterThan(0));
      expect(find.text('জ্বর ও হালকা ব্যথায়।'), findsOneWidget);
      expect(find.text('ইংরেজিতে দেখুন'), findsNothing);
    });

    test('a summary-only medicine loads from the local database', () async {
      final summary = Medicine(
        id: 12,
        brandName: 'Napa',
        genericName: 'Paracetamol',
        company: 'Beximco',
        strength: '500 mg',
        dosageForm: 'Tablet',
      );
      await db.upsertDetailBatch([summary]);

      final controller = MedicineDetailController(
        initial: summary,
        dao: Get.find<MedicineDao>(),
        sync: Get.find<SyncService>(),
        ai: tools,
      );
      await controller.loadDetail();

      expect(controller.medicine.value.brandName, 'Napa');
      expect(controller.detailError.value, isEmpty);
      expect(tools.translateCalls, greaterThan(0));
    });

    testWidgets('detailed explanation opens with the mandatory disclaimer', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tools.explanation =
          'কেন এই ওষুধ\n• জ্বর কমাতে।\nকীভাবে খাবেন\n• খাওয়ার পরে।';

      await tester.pumpWidget(
        MaterialApp(
          home: MedicineDetailView(medicine: detailedMedicine(id: 11)),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('বিস্তারিত ব্যাখ্যা'));
      await settle(tester);
      expect(tools.explainCalls, 1);
      expect(find.text('জ্বর কমাতে।'), findsOneWidget);
      expect(find.text('কেন এই ওষুধ'), findsOneWidget);
      expect(
        find.text(AiLearningTools.disclaimer),
        findsOneWidget,
        reason: 'the educational footer is mandatory',
      );
    });

    testWidgets('medicine explanation popup supports follow-up chat', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MedicineDetailView(medicine: detailedMedicine(id: 11)),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('বিস্তারিত ব্যাখ্যা'));
      await settle(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'এই ওষুধ সম্পর্কে প্রশ্ন লিখুন'),
        'এই ওষুধটি কী কাজে লাগে?',
      );
      await tester.tap(find.byTooltip('প্রশ্ন পাঠান'));
      await settle(tester);

      expect(tools.medicineChatCalls, 1);
      expect(tools.lastQuestion, 'এই ওষুধটি কী কাজে লাগে?');
      expect(
        find.text('এই ওষুধের তথ্য অনুযায়ী জ্বর কমাতে ব্যবহৃত হয়।'),
        findsOneWidget,
      );
    });

    testWidgets(
      'dosage popup asks patient details before showing instructions',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const doseSample =
            'Adult dose: 1-2 tablets every 4-6 hours. '
            'Maximum dose: 8 tablets daily. '
            'Child dose: Not recommended for children below 12 years.';
        tools.banglaFields = {
          ...tools.banglaFields,
          'dosage_and_administration': doseSample,
        };

        await tester.pumpWidget(
          MaterialApp(
            home: MedicineDetailView(
              medicine: detailedMedicine(
                id: 11,
                brand: 'Napa Extra',
                dosageText: doseSample,
              ),
            ),
          ),
        );
        await settle(tester);

        expect(find.text('প্রতি ৪–৬ ঘণ্টা পরপর ১–২টি ট্যাবলেট।'), findsNothing);
        await tester.tap(find.text('ডোজ ও ব্যবহারবিধি'));
        await tester.pumpAndSettle();
        expect(find.text('লিঙ্গ'), findsOneWidget);

        await tester.enterText(find.byType(TextField).last, '৩২');
        await tester.tap(find.text('মহিলা'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('পরবর্তী'));
        await tester.pumpAndSettle();
        expect(find.text('কয়েকটি প্রশ্ন'), findsOneWidget);

        await tester.tap(find.text('হ্যাঁ').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('না').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('ফলাফল দেখুন'));
        await tester.pumpAndSettle();

        expect(
          find.text('প্রতি ৪–৬ ঘণ্টা পরপর ১–২টি ট্যাবলেট।'),
          findsOneWidget,
        );
        expect(find.text('দিনে সর্বোচ্চ ৮টি ট্যাবলেট।'), findsOneWidget);
        // Age filtering is deliberate: a 32-year-old must not be shown the
        // paediatric section, and the adult/maximum guidance stays visible.
        expect(
          find.text('১২ বছরের কম বয়সী শিশুদের জন্য সুপারিশ করা হয় না।'),
          findsNothing,
        );
        expect(find.text('প্রাপ্তবয়স্কদের ডোজ'), findsOneWidget);
        expect(find.text('সর্বোচ্চ ডোজ'), findsOneWidget);
        expect(find.text('শিশুদের ডোজ'), findsNothing);
        expect(
          find.text(
            'গর্ভাবস্থা ও স্তন্যদানে ব্যবহারের আগে চিকিৎসকের পরামর্শ নিন।',
          ),
          findsWidgets,
        );
        expect(find.text('রোগীর তথ্য'), findsOneWidget);
        expect(find.text('ডেটাবেসে থাকা নির্দেশনা'), findsNothing);
        expect(find.text('আবার শুরু করুন'), findsNothing);
        expect(find.textContaining('৩২ বছর'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('medicine detail redesign fits a narrow screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MedicineDetailView(medicine: detailedMedicine(id: 11)),
        ),
      );
      await settle(tester);

      expect(find.text('বিস্তারিত ব্যাখ্যা'), findsOneWidget);
      expect(find.text('ওষুধের বিস্তারিত তথ্য'), findsOneWidget);
      expect(find.byType(CompanyLogo), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('redesigned learning screens', () {
    late AppDatabase db;
    late LearningController controller;

    setUp(() async {
      Get.deleteAll(force: true);
      // Enough courses to prove the list is capped and filterable.
      db = await AppDatabase.openForTesting();
      controller = LearningController(
        _StubRepository(db, [
          course('b1', title: 'জ্বর ও সংক্রমণ'),
          course('b2', title: 'হৃদরোগ'),
          course(
            'b3',
            title: 'ডায়াবেটিস',
            lessons: [
              lesson('b3-l0', title: 'ডায়াবেটিস কী', body: longBody()),
            ],
          ),
          course('b4', title: 'শ্বাসতন্ত্র'),
          course('m1', category: 'medicine', title: 'ঔষধ নিরাপত্তা'),
          course('m2', category: 'medicine', title: 'অ্যান্টিবায়োটিক'),
          course('p1', category: 'pharmacy', title: 'ফার্মেসি পরিচালনা'),
          course('p2', category: 'pharmacy', title: 'রিপোর্ট পড়া'),
        ]),
      );
      Get.put(controller);
      await controller.load();
    });

    tearDown(() async {
      Get.deleteAll(force: true);
      await db.close();
    });

    testWidgets('shows only the subject-based course library', (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: LearningView()));
      await tester.pumpAndSettle();

      expect(find.text('বিষয়, কোর্স বা পাঠ খুঁজুন…'), findsOneWidget);
      expect(find.text('কোর্স লাইব্রেরি'), findsOneWidget);
      expect(find.text('অ্যান্টিবায়োটিক'), findsWidgets);

      // Everything the reader asked to remove is gone from this page.
      for (final gone in [
        'সার্বিক অগ্রগতি',
        'সুপারিশকৃত পাঠ',
        'চিকিৎসা পরিভাষা',
        'রিভিশন',
        'অঙ্গতন্ত্র',
        'কুইজ',
      ]) {
        expect(find.text(gone), findsNothing, reason: '$gone is still visible');
      }
    });

    testWidgets('a subject opens its subtopics and indication guide', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const GetMaterialApp(home: LearningView()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('অ্যান্টিবায়োটিক').first);
      await tester.pumpAndSettle();

      expect(find.text('উপবিষয়'), findsOneWidget);
      expect(find.text('পেনিসিলিন গ্রুপ'), findsWidgets);
      expect(find.text('কোন অবস্থায় কোন গ্রুপ'), findsOneWidget);
      expect(find.text('এই বিষয়ের কোর্স'), findsOneWidget);
      expect(
        find.text('শিক্ষামূলক গাইড — চিকিৎসকের পরামর্শের বিকল্প নয়।'),
        findsOneWidget,
      );
    });

    testWidgets('lesson page opens the Ask AI mini-chat overlay', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: LessonView(courseId: 'b3', lessonId: 'b3-l0'),
        ),
      );
      await settle(tester);

      expect(find.text('ডায়াবেটিস কী'), findsWidgets);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('AI-এ জিজ্ঞাসা'), findsOneWidget);

      await tester.tap(find.text('AI-এ জিজ্ঞাসা'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // The overlay is grounded in this lesson and offers one-tap starters.
      expect(find.text('এই পাঠ নিয়ে জানুন'), findsOneWidget);
      expect(find.text('মূল কথাগুলো সহজ করে বলুন'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('a long lesson shows the AI summary block', (tester) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final stub = _StubTools(db);
      Get.put<AiLearningTools>(stub);
      addTearDown(() => Get.delete<AiLearningTools>());

      await tester.pumpWidget(
        const MaterialApp(
          home: LessonView(courseId: 'b3', lessonId: 'b3-l0'),
        ),
      );
      await settle(tester);

      expect(stub.summarizeCalls, 1);
      expect(find.text('সংক্ষিপ্ত সারক'), findsOneWidget);
      expect(find.text('প্রথম কথা'), findsOneWidget);
    });
  });
}
