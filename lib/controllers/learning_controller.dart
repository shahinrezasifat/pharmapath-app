import 'package:get/get.dart';

import '../core/app_config.dart';
import '../data/learning_repository.dart';
import '../models/learning.dart';
import '../services/ai_learning_tools.dart';

/// The শেখা module's state: catalogue, body systems, disease topics, progress,
/// bookmarks, quiz results, and the reading history that drives recommendations.
class LearningController extends GetxController {
  LearningController(this._repository, [this._ai]);

  final LearningRepository _repository;

  /// Optional AI helper used to re-rank the locally scored suggestions.
  final AiLearningTools? _ai;

  final RxList<Course> courses = <Course>[].obs;
  final RxList<LearningTrack> tracks = <LearningTrack>[].obs;

  /// Subjects shown on the redesigned শেখা page (course library only).
  final RxList<StudySubject> subjects = <StudySubject>[].obs;

  /// Shelf id -> its courses, alphabetical inside, computed by the repository.
  final RxMap<String, List<Course>> coursesByTrack =
      <String, List<Course>>{}.obs;
  final RxList<BodySystem> bodySystems = <BodySystem>[].obs;
  final RxList<DiseaseTopic> diseaseTopics = <DiseaseTopic>[].obs;
  final RxSet<String> completed = <String>{}.obs;
  final RxSet<String> bookmarks = <String>{}.obs;
  final RxSet<String> startedCourses = <String>{}.obs;
  final RxMap<String, ({int score, int total, int takenAt})> bestResults =
      <String, ({int score, int total, int takenAt})>{}.obs;
  final RxBool loading = true.obs;
  final RxString error = ''.obs;

  /// Lessons the reader opened, most recent first.
  final RxList<LessonRead> history = <LessonRead>[].obs;

  /// Next lessons to read, best first, each carrying its Bangla reason.
  final RxList<LessonSuggestion> recommendations = <LessonSuggestion>[].obs;

  /// The AI's one-line justification for the current order, if it gave one.
  final RxString recommendationNote = ''.obs;

  /// True while the model is re-ranking (local order stays visible throughout).
  final RxBool ranking = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    error.value = '';
    try {
      courses.assignAll(await _repository.courses());
      subjects.assignAll(await _repository.subjects());
      tracks.assignAll(await _repository.tracks());
      final grouped = await _repository.coursesByTrack();
      coursesByTrack
        ..clear()
        ..addAll(grouped);
      bodySystems.assignAll(await _repository.bodySystems());
      diseaseTopics.assignAll(await _repository.diseaseTopics());
      completed.assignAll(await _repository.completedLessons());
      bookmarks.assignAll(await _repository.bookmarkedLessons());
      bestResults.assignAll(await _repository.bestResults());
      history.assignAll(await _repository.readingHistory());
      startedCourses.assignAll(await _repository.startedCourseIds());
      refreshRecommendations();
    } catch (e) {
      error.value = 'শেখার কনটেন্ট লোড করা যায়নি: $e';
    } finally {
      loading.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Reading history & recommendations
  // ---------------------------------------------------------------------------

  /// Bangla headings for the atlas groups, in the order they should be shown.
  Map<String, String> get atlasGroupLabels => LearningRepository.groupLabels;

  /// The shelves that actually hold courses, in shelf order.
  List<LearningTrack> get liveTracks => tracks
      .where((t) => (coursesByTrack[t.id] ?? const []).isNotEmpty)
      .toList();

  List<Course> shelfCourses(String trackId) =>
      List.unmodifiable(coursesByTrack[trackId] ?? const []);

  /// How often one lesson was opened — the struggle signal for the adaptive
  /// "easier first" rule.
  int visitsOf(String courseId, String lessonId) {
    for (final read in history) {
      if (read.courseId == courseId && read.lessonId == lessonId) {
        return read.visits;
      }
    }
    return 0;
  }

  /// Records that a lesson was opened and re-suggestions afterwards.
  Future<void> markRead(String courseId, String lessonId) async {
    await _repository.markRead(courseId, lessonId);
    startedCourses.add(courseId);
    final existing = history.firstWhereOrNull(
      (r) => r.courseId == courseId && r.lessonId == lessonId,
    );
    if (existing == null) {
      history.insert(
        0,
        LessonRead(
          courseId: courseId,
          lessonId: lessonId,
          visits: 1,
          lastReadAt: DateTime.now().millisecondsSinceEpoch,
          completed: isCompleted(courseId, lessonId),
        ),
      );
    } else {
      history[history.indexOf(existing)] = LessonRead(
        courseId: courseId,
        lessonId: lessonId,
        visits: existing.visits + 1,
        lastReadAt: DateTime.now().millisecondsSinceEpoch,
        completed: existing.completed,
      );
      history.refresh();
    }
    refreshRecommendations();
  }

  /// The lesson to resume: the last one opened that is still unfinished.
  ({Course course, Lesson lesson})? get continueReading {
    for (final read in history) {
      if (read.completed) continue;
      final course = courses.firstWhereOrNull((c) => c.id == read.courseId);
      final lesson = course?.lessons.firstWhereOrNull(
        (l) => l.id == read.lessonId,
      );
      if (course != null && lesson != null) {
        return (course: course, lesson: lesson);
      }
    }
    return null;
  }

  /// Deterministic, offline scoring of what to read next.
  List<LessonSuggestion> computeRecommendations({
    int limit = AppConfig.learningRecommendLimit,
  }) {
    if (courses.isEmpty) return const [];
    final readCourses = history.map((r) => r.courseId).toSet();
    final lastCourse = history.isEmpty ? null : history.first.courseId;
    final lastCategory = courses
        .firstWhereOrNull((c) => c.id == lastCourse)
        ?.category;
    final stuck = <String, LessonRead>{
      for (final read in history)
        if (!read.completed && read.visits >= AppConfig.learningStruggleVisits)
          read.courseId: read,
    };

    final result = <LessonSuggestion>[];
    for (final course in courses) {
      var firstOpen = -1;
      for (var i = 0; i < course.lessons.length; i++) {
        if (!isCompleted(course.id, course.lessons[i].id)) {
          firstOpen = i;
          break;
        }
      }
      if (firstOpen < 0) continue; // course already finished
      final struggling = stuck[course.id];
      // The shortest lesson of a stuck course is the easier entry point.
      var easierIndex = -1;
      if (struggling != null) {
        var minutes = 1 << 30;
        for (var i = 0; i < course.lessons.length; i++) {
          final lesson = course.lessons[i];
          if (isCompleted(course.id, lesson.id)) continue;
          if (lesson.minutes < minutes) {
            minutes = lesson.minutes;
            easierIndex = i;
          }
        }
      }
      for (var i = 0; i < course.lessons.length; i++) {
        final lesson = course.lessons[i];
        if (isCompleted(course.id, lesson.id)) continue;
        var score = 1;
        var reason = 'নতুন বিষয় — ${course.title}';
        if (readCourses.contains(course.id)) {
          score += 4;
          reason = '${course.title} চালিয়ে যান';
        }
        if (i == firstOpen && readCourses.contains(course.id)) {
          score += 6;
          reason = 'এই কোর্সের পরের পাঠ — ${course.title}';
        }
        if (lastCategory != null && course.category == lastCategory) {
          score += 2;
        }
        if (isBookmarked(course.id, lesson.id)) {
          score += 3;
          reason = 'বুকমার্ক করা পাঠ';
        }
        final easier = struggling != null && i == easierIndex && i != firstOpen;
        if (easier) {
          score += 7;
          reason = 'বারবার পড়া হচ্ছে — আগে সহজ ভিত্তি পাঠটি';
        }
        if (lesson.minutes <= 5) score += 1;
        result.add(
          LessonSuggestion(
            course: course,
            lesson: lesson,
            reason: reason,
            score: score,
            easierEntry: easier,
          ),
        );
      }
    }
    result.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byMinutes = a.lesson.minutes.compareTo(b.lesson.minutes);
      if (byMinutes != 0) return byMinutes;
      return a.course.title.compareTo(b.course.title);
    });
    return result.take(limit).toList();
  }

  /// Publishes the local order immediately, then lets the model re-rank it in
  /// the background when an AI helper and some reading history exist.
  Future<void> refreshRecommendations({bool useAi = true}) async {
    final local = computeRecommendations();
    recommendations.assignAll(local);
    if (recommendationNote.isNotEmpty) recommendationNote.value = '';
    final tools = _ai;
    if (!useAi || tools == null || history.isEmpty || local.length < 3) return;
    ranking.value = true;
    try {
      final rankingResult = await tools.rankLessons(
        readingHistory: _historySummary(),
        candidates: local,
      );
      if (rankingResult == null || rankingResult.order.isEmpty) return;
      final reordered = <LessonSuggestion>[];
      for (final position in rankingResult.order) {
        if (position >= 1 && position <= local.length) {
          final suggestion = local[position - 1];
          if (!reordered.any((s) => s.key == suggestion.key)) {
            reordered.add(suggestion);
          }
        }
      }
      for (final suggestion in local) {
        if (!reordered.any((s) => s.key == suggestion.key)) {
          reordered.add(suggestion);
        }
      }
      recommendations.assignAll(reordered.take(local.length).toList());
      recommendationNote.value = rankingResult.note;
    } catch (_) {
      // Keep deterministic order
    } finally {
      ranking.value = false;
    }
  }

  String _historySummary() {
    final lines = <String>[];
    for (final read in history.take(8)) {
      final course = courses.firstWhereOrNull((c) => c.id == read.courseId);
      final lesson = course?.lessons.firstWhereOrNull(
        (l) => l.id == read.lessonId,
      );
      if (course == null || lesson == null) continue;
      lines.add(
        '${lesson.title} (${course.title}) — ${read.visits} বার পড়া, '
        '${read.completed ? 'সম্পন্ন' : 'অসম্পূর্ণ'}',
      );
    }
    return lines.join('\n');
  }

  bool isCompleted(String courseId, String lessonId) =>
      completed.contains('$courseId::$lessonId');

  bool isBookmarked(String courseId, String lessonId) =>
      bookmarks.contains('$courseId::$lessonId');

  int completedIn(Course course) =>
      course.lessons.where((l) => isCompleted(course.id, l.id)).length;

  double progressOf(Course course) =>
      course.lessons.isEmpty ? 0 : completedIn(course) / course.lessons.length;

  /// Default passing score ratio is 80% (0.8) as mandated by PRD Section 11.5.
  static const double passRatio = 0.8;

  double effectivePassRatio(Course? course, [Lesson? lesson]) {
    if (lesson != null && lesson.passingScoreRatio > 0) {
      return lesson.passingScoreRatio;
    }
    if (course != null && course.passingScoreRatio > 0) {
      return course.passingScoreRatio;
    }
    return passRatio;
  }

  bool isPassed(String courseId) {
    final best = bestResults[courseId];
    if (best == null || best.total <= 0) return false;
    final course = courses.firstWhereOrNull((c) => c.id == courseId);
    return best.score / best.total >= effectivePassRatio(course);
  }

  static String lessonQuizKey(String courseId, String lessonId) =>
      '$courseId::$lessonId';

  ({int score, int total, int takenAt})? lessonBest(
    String courseId,
    String lessonId,
  ) => bestResults[lessonQuizKey(courseId, lessonId)];

  bool isLessonPassed(String courseId, String lessonId) {
    final best = lessonBest(courseId, lessonId);
    if (best == null || best.total <= 0) return false;
    final course = courses.firstWhereOrNull((c) => c.id == courseId);
    final lesson = course?.lessons.firstWhereOrNull((l) => l.id == lessonId);
    return best.score / best.total >= effectivePassRatio(course, lesson);
  }

  /// Stores the lesson-quiz outcome and syncs the completion flag:
  /// passing marks the lesson completed, failing keeps it in-progress.
  Future<void> submitLessonQuiz(
    Course course,
    Lesson lesson,
    int score,
    int total,
  ) async {
    await _repository.saveQuiz(
      lessonQuizKey(course.id, lesson.id),
      score,
      total,
    );
    bestResults.assignAll(await _repository.bestResults());
    final threshold = effectivePassRatio(course, lesson);
    // Completion follows the learner's BEST attempt, matching
    // isLessonPassed(): a poor retake must not undo an earlier pass.
    final best = lessonBest(course.id, lesson.id);
    final passed =
        best != null && best.total > 0 && best.score / best.total >= threshold;
    await setLessonCompleted(course.id, lesson.id, passed);
  }

  Future<void> setLessonCompleted(
    String courseId,
    String lessonId,
    bool value,
  ) async {
    final key = '$courseId::$lessonId';
    await _repository.setLessonCompleted(courseId, lessonId, value);
    if (value) {
      completed.add(key);
      startedCourses.add(courseId);
    } else {
      completed.remove(key);
    }
    _syncHistoryFlag(courseId, lessonId, value);
    refreshRecommendations();
  }

  void _syncHistoryFlag(String courseId, String lessonId, bool value) {
    final read = history.firstWhereOrNull(
      (r) => r.courseId == courseId && r.lessonId == lessonId,
    );
    if (read == null) return;
    history[history.indexOf(read)] = LessonRead(
      courseId: courseId,
      lessonId: lessonId,
      visits: read.visits,
      lastReadAt: read.lastReadAt,
      completed: value,
    );
    history.refresh();
  }

  // ---------------------------------------------------------------------------
  // Overall Learning Statistics (PRD Section 4.4)
  // ---------------------------------------------------------------------------

  int get totalCourses => courses.length;

  int get startedCourseCount {
    final ids = <String>{};
    for (final course in courses) {
      if (completedIn(course) > 0 || startedCourses.contains(course.id)) {
        ids.add(course.id);
      }
    }
    return ids.length;
  }

  int get completedCourseCount => courses.where((course) {
    return course.lessons.isNotEmpty &&
        completedIn(course) == course.lessons.length;
  }).length;

  int get totalLessons =>
      courses.fold(0, (sum, course) => sum + course.lessons.length);

  int get completedLessonCount =>
      courses.fold(0, (sum, course) => sum + completedIn(course));

  int get inProgressLessonCount {
    var count = 0;
    for (final read in history) {
      if (!read.completed && read.visits > 0) {
        count++;
      }
    }
    return count;
  }

  int get totalQuizzes =>
      courses.where((course) => course.quiz.isNotEmpty).length;

  int get passedQuizCount =>
      courses.where((course) => isPassed(course.id)).length;

  double get overallProgress =>
      totalLessons == 0 ? 0 : completedLessonCount / totalLessons;

  int get totalMinutes => courses.fold(
    0,
    (sum, course) => sum + course.lessons.fold(0, (s, l) => s + l.minutes),
  );

  /// Average performance across all taken quizzes (in percentage)
  int get quizPerformanceAverage {
    if (bestResults.isEmpty) return 0;
    var totalPct = 0.0;
    var count = 0;
    for (final res in bestResults.values) {
      if (res.total > 0) {
        totalPct += (res.score / res.total) * 100;
        count++;
      }
    }
    return count == 0 ? 0 : (totalPct / count).round();
  }

  /// Lessons where user has visited or failed quiz but not completed
  List<({Course course, Lesson lesson})> get revisionPendingList {
    final list = <({Course course, Lesson lesson})>[];
    for (final read in history) {
      if (!read.completed) {
        final course = courses.firstWhereOrNull((c) => c.id == read.courseId);
        final lesson = course?.lessons.firstWhereOrNull(
          (l) => l.id == read.lessonId,
        );
        if (course != null && lesson != null) {
          list.add((course: course, lesson: lesson));
        }
      }
    }
    return list;
  }

  int get revisionPendingCount => revisionPendingList.length;

  Future<void> toggleCompleted(Course course, Lesson lesson) async {
    final key = '${course.id}::${lesson.id}';
    final next = !completed.contains(key);
    await _repository.setLessonCompleted(course.id, lesson.id, next);
    if (next) {
      completed.add(key);
      startedCourses.add(course.id);
    } else {
      completed.remove(key);
    }
    _syncHistoryFlag(course.id, lesson.id, next);
    refreshRecommendations();
  }

  Future<void> toggleBookmark(Course course, Lesson lesson) async {
    final key = '${course.id}::${lesson.id}';
    final added = await _repository.toggleBookmark(course.id, lesson.id);
    if (added) {
      bookmarks.add(key);
    } else {
      bookmarks.remove(key);
    }
  }

  Future<void> saveQuiz(String courseId, int score, int total) async {
    await _repository.saveQuiz(courseId, score, total);
    bestResults.assignAll(await _repository.bestResults());
  }

  Future<void> clearAllProgress() async {
    await _repository.clearProgress();
    completed.clear();
    bookmarks.clear();
    startedCourses.clear();
    bestResults.clear();
    history.clear();
    recommendations.clear();
    recommendationNote.value = '';
  }
}
