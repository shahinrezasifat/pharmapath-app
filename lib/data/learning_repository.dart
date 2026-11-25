import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/learning.dart';
import 'learning_dao.dart';

class LearningRepository {
  LearningRepository(this._dao);

  final LearningDao _dao;

  List<Course>? _cache;
  List<StudySubject>? _subjectsCache;
  List<LearningTrack>? _tracksCache;
  List<BodySystem>? _bodySystemsCache;
  List<DiseaseTopic>? _diseaseTopicsCache;

  /// The learning library is split by topic so each file stays reviewable.
  /// Missing optional files are skipped, which keeps slim test builds working.
  static const _assetPaths = [
    'assets/learning/body_systems_curriculum.json',
    'assets/learning/courses.json',
    'assets/learning/conditions_general.json',
    'assets/learning/conditions_infections.json',
    'assets/learning/conditions_heart_lungs.json',
    'assets/learning/conditions_metabolic_kidney.json',
    'assets/learning/conditions_digestive.json',
    'assets/learning/conditions_brain_mind.json',
    'assets/learning/conditions_bones_skin.json',
    'assets/learning/conditions_senses_women_child.json',
    'assets/learning/academy_home_pharmacy.json',
    'assets/learning/academy_clinical_pharmacy.json',
    'assets/learning/academy_medicine_safety.json',
  ];

  /// Body-condition guides, one file per shelf, in the order the library lists
  /// them. Each shelf is a readable subject area rather than a flat list.
  static const shelfTracks = [
    'daily',
    'infection',
    'heart',
    'lungs',
    'gut',
    'kidney',
    'hormone',
    'nerve',
    'mental',
    'eye',
    'ent',
    'mouth',
    'skin',
    'bone',
    'blood',
    'women',
    'child',
    'elderly',
    'emergency',
    'environment',
    'medicine',
    'practice',
  ];

  static String shelfPath(String track) =>
      'assets/learning/library_$track.json';

  /// The original catalogue predates the shelves; file each course onto one.
  static const _legacyTracks = <String, String>{
    'basics': 'medicine',
    'antibiotics': 'medicine',
    'longterm': 'medicine',
    'med-safety': 'medicine',
    'prescription': 'medicine',
    'pharmacology': 'practice',
    'special-populations': 'practice',
    'vitals-labs': 'practice',
    'home-remedies': 'practice',
    'pharmacy-ops': 'practice',
    'general-health': 'daily',
    'emergency': 'emergency',
    'infections': 'infection',
    'heart-circulation': 'heart',
    'breathing': 'lungs',
    'digestive-liver': 'gut',
    'diabetes-hormone': 'hormone',
    'kidney-urinary': 'kidney',
    'bones-joints': 'bone',
    'skin': 'skin',
    'brain-nerve': 'nerve',
    'mental-health': 'mental',
    'senses': 'ent',
    'sore_throat_master': 'ent',
    'women-health': 'women',
    'child-health': 'child',
  };

  /// Bangla headings for the atlas groups, in the order the atlas is shown.
  static const groupLabels = <String, String>{
    'core': 'মূল অঙ্গতন্ত্র',
    'organ': 'অঙ্গ-প্রত্যঙ্গভেদে',
    'region': 'শারীরিক অঞ্চল',
    'life': 'জীবনচক্র ও বিশেষায়িত যত্ন',
    'group': 'রোগের শ্রেণি',
  };

  static String _trackOf(Course course) => course.track.isNotEmpty
      ? course.track
      : (_legacyTracks[course.id] ?? 'daily');

  /// Pharmacy-oriented subjects for the redesigned course library. Falls back
  /// to an empty list on slim builds that ship without the asset.
  Future<List<StudySubject>> subjects() async {
    final cached = _subjectsCache;
    if (cached != null) return cached;
    try {
      final raw = await rootBundle.loadString('assets/learning/subjects.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final subjects = (decoded['subjects'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (e) => StudySubject.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
      _subjectsCache = subjects;
      return subjects;
    } catch (_) {
      return const <StudySubject>[];
    }
  }

  Future<List<Course>> courses() async {
    if (_cache != null) return _cache!;
    final merged = <Course>[];
    final seen = <String>{};
    for (final path in [
      ..._assetPaths,
      for (final track in shelfTracks) shelfPath(track),
    ]) {
      String raw;
      try {
        raw = await rootBundle.loadString(path);
      } catch (_) {
        continue;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) continue;

      // Check standard courses array
      for (final entry
          in (decoded['courses'] as List? ?? const []).whereType<Map>()) {
        final course = Course.fromJson(entry.cast<String, dynamic>());
        if (course.id.isEmpty || !seen.add(course.id)) continue;
        merged.add(course);
      }

      // Check sample_course key (from body_systems_curriculum.json)
      if (decoded['sample_course'] is Map) {
        final sampleCourse = Course.fromJson(
          Map<String, dynamic>.from(decoded['sample_course'] as Map),
        );
        if (sampleCourse.id.isNotEmpty && seen.add(sampleCourse.id)) {
          merged.add(sampleCourse);
        }
      }
    }
    if (merged.isEmpty) {
      throw const FormatException('শেখার কনটেন্ট লোড করা যায়নি।');
    }
    _cache = merged;
    return merged;
  }

  /// Shelf ids and their Bangla labels, in library order. Falls back to the
  /// compiled shelf list when the label file is not in the build.
  Future<List<LearningTrack>> tracks() async {
    if (_tracksCache != null) return _tracksCache!;
    final loaded = <LearningTrack>[];
    try {
      final raw = await rootBundle.loadString(
        'assets/learning/library_tracks.json',
      );
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['tracks'] is List) {
        loaded.addAll(
          (decoded['tracks'] as List).whereType<Map>().map(
            (e) => LearningTrack.fromJson(Map<String, dynamic>.from(e)),
          ),
        );
      }
    } catch (_) {
      // Slim test build: use the ids the app knows about.
    }
    final byId = {for (final track in loaded) track.id: track};
    _tracksCache = [
      for (final id in shelfTracks)
        byId[id] ?? LearningTrack(id: id, labelBn: id),
      for (final track in loaded)
        if (!shelfTracks.contains(track.id)) track,
    ];
    return _tracksCache!;
  }

  /// Courses grouped by shelf, in shelf order, each shelf alphabetical inside.
  Future<Map<String, List<Course>>> coursesByTrack() async {
    final all = await courses();
    final grouped = <String, List<Course>>{};
    for (final course in all) {
      grouped.putIfAbsent(_trackOf(course), () => <Course>[]).add(course);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.title.compareTo(b.title));
    }
    return grouped;
  }

  Future<List<BodySystem>> bodySystems() async {
    if (_bodySystemsCache != null) return _bodySystemsCache!;
    final systems = <String, BodySystem>{};
    for (final file in const [
      'assets/learning/body_systems_curriculum.json',
      'assets/learning/body_systems_atlas.json',
    ]) {
      try {
        final decoded = jsonDecode(await rootBundle.loadString(file));
        if (decoded is Map && decoded['body_systems'] is List) {
          for (final entry
              in (decoded['body_systems'] as List).whereType<Map>()) {
            final system = BodySystem.fromJson(
              Map<String, dynamic>.from(entry),
            );
            if (system.id.isEmpty || systems.containsKey(system.id)) continue;
            systems[system.id] = system;
          }
        }
      } catch (_) {
        // Fallback: skip whatever is unreadable so slim builds still render.
      }
    }
    if (systems.isEmpty) return const [];

    // The original curriculum has no explicit links, so file each course under
    // its own body system; atlas rows already carry the guides that tag them.
    final courses = await this.courses();
    final bySystem = <String, List<String>>{};
    for (final course in courses) {
      final id = course.bodySystemId;
      if (id == null || id.isEmpty) continue;
      bySystem.putIfAbsent(id, () => <String>[]).add(course.id);
    }
    final list = [
      for (final system in systems.values)
        system.relatedCourseIds.isNotEmpty
            ? system
            : _linkSystem(system, bySystem[system.id] ?? const []),
    ];
    list.sort((a, b) {
      final byGroup = _groupRank(a.group).compareTo(_groupRank(b.group));
      return byGroup != 0 ? byGroup : a.sortOrder.compareTo(b.sortOrder);
    });
    _bodySystemsCache = list;
    return list;
  }

  static int _groupRank(String group) {
    final index = groupLabels.keys.toList().indexOf(group);
    return index < 0 ? groupLabels.length : index;
  }

  static BodySystem _linkSystem(BodySystem system, List<String> courseIds) =>
      BodySystem(
        id: system.id,
        nameBn: system.nameBn,
        nameEn: system.nameEn,
        descriptionBn: system.descriptionBn,
        descriptionEn: system.descriptionEn,
        iconKey: system.iconKey,
        group: system.group.isEmpty ? 'core' : system.group,
        relatedCourseIds: courseIds,
        sortOrder: system.sortOrder,
        bodyParts: system.bodyParts,
        diseaseTopics: system.diseaseTopics,
      );

  Future<List<DiseaseTopic>> diseaseTopics() async {
    if (_diseaseTopicsCache != null) return _diseaseTopicsCache!;
    try {
      final raw = await rootBundle.loadString(
        'assets/learning/body_systems_curriculum.json',
      );
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['disease_topics'] is List) {
        final list = (decoded['disease_topics'] as List)
            .whereType<Map>()
            .map((e) => DiseaseTopic.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _diseaseTopicsCache = list;
        return list;
      }
    } catch (_) {
      // Fallback empty list
    }
    return const [];
  }

  Future<DiseaseTopic?> findDiseaseTopic(String id) async {
    final list = await diseaseTopics();
    for (final topic in list) {
      if (topic.id == id) return topic;
    }
    return null;
  }

  Future<BodySystem?> findBodySystem(String id) async {
    final list = await bodySystems();
    for (final system in list) {
      if (system.id == id) return system;
    }
    return null;
  }

  Course? findCourse(List<Course> courses, String id) {
    for (final course in courses) {
      if (course.id == id) return course;
    }
    return null;
  }

  Lesson? findLesson(Course course, String id) {
    for (final lesson in course.lessons) {
      if (lesson.id == id) return lesson;
    }
    return null;
  }

  Future<Set<String>> completedLessons() => _dao.completedLessonKeys();

  Future<void> setLessonCompleted(
    String courseId,
    String lessonId,
    bool value,
  ) => _dao.markCompleted(courseId, lessonId, value);

  /// Notes that a lesson was opened, feeding the reading history that the
  /// recommendation and adaptive-difficulty logic run on.
  Future<void> markRead(String courseId, String lessonId) =>
      _dao.markRead(courseId, lessonId);

  Future<List<LessonRead>> readingHistory() => _dao.readingHistory();

  Future<Set<String>> bookmarkedLessons() => _dao.bookmarkedKeys();

  Future<bool> toggleBookmark(String courseId, String lessonId) =>
      _dao.toggleBookmark(courseId, lessonId);

  Future<void> saveQuiz(String courseId, int score, int total) =>
      _dao.saveQuizResult(courseId, score, total);

  Future<Map<String, ({int score, int total, int takenAt})>> bestResults() =>
      _dao.bestResults();

  Future<int> completedCount(String courseId) => _dao.completedCount(courseId);

  Future<Set<String>> startedCourseIds() => _dao.startedCourseIds();

  Future<int> inProgressLessonCount() => _dao.inProgressLessonCount();

  Future<int> totalCompletedLessons() => _dao.totalCompletedLessons();

  Future<void> clearProgress() => _dao.clearProgress();
}
