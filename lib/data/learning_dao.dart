import 'package:sqflite/sqflite.dart';

import '../models/learning.dart';
import 'app_database.dart';

class LearningDao {
  LearningDao(this._app);

  final AppDatabase _app;
  Database get _db => _app.db;

  Future<Set<String>> completedLessonKeys() async {
    final rows = await _db.query('learning_progress', where: 'completed = 1');
    return rows.map((e) => '${e['course_id']}::${e['lesson_id']}').toSet();
  }

  Future<void> markCompleted(String courseId, String lessonId, bool completed) {
    // Upsert instead of INSERT OR REPLACE: a replace would drop the reading
    // history (visits / last read) that the recommender depends on.
    return _db.execute(
      '''
      INSERT INTO learning_progress
        (course_id, lesson_id, completed, visits, last_read_at, updated_at)
      VALUES (?, ?, ?, 0, 0, ?)
      ON CONFLICT(course_id, lesson_id) DO UPDATE SET
        completed = excluded.completed, updated_at = excluded.updated_at
    ''',
      [
        courseId,
        lessonId,
        completed ? 1 : 0,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  /// Registers one opening of a lesson: creates the progress row when absent
  /// and otherwise only bumps the visit counter and timestamp. Completion is
  /// deliberately left alone, so reading never marks a lesson "done".
  Future<void> markRead(String courseId, String lessonId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.execute(
      '''
      INSERT INTO learning_progress
        (course_id, lesson_id, completed, visits, last_read_at, updated_at)
      VALUES (?, ?, 0, 1, ?, ?)
      ON CONFLICT(course_id, lesson_id) DO UPDATE SET
        visits = visits + 1, last_read_at = excluded.last_read_at
    ''',
      [courseId, lessonId, now, now],
    );
  }

  /// Reading history, most recently opened first — the signal behind "আপনার
  /// জন্য সুপারিশকৃত" and the progressive-difficulty rule.
  Future<List<LessonRead>> readingHistory() async {
    final rows = await _db.rawQuery('''
      SELECT course_id, lesson_id, visits, last_read_at, completed
      FROM learning_progress
      WHERE visits > 0
      ORDER BY last_read_at DESC, visits DESC
      LIMIT 40
    ''');
    return [
      for (final row in rows)
        LessonRead(
          courseId: row['course_id'] as String? ?? '',
          lessonId: row['lesson_id'] as String? ?? '',
          visits: (row['visits'] as num?)?.toInt() ?? 0,
          lastReadAt: (row['last_read_at'] as num?)?.toInt() ?? 0,
          completed: (row['completed'] as num?)?.toInt() == 1,
        ),
    ];
  }

  Future<Set<String>> bookmarkedKeys() async {
    final rows = await _db.query('bookmarks');
    return rows.map((e) => '${e['course_id']}::${e['lesson_id']}').toSet();
  }

  Future<bool> toggleBookmark(String courseId, String lessonId) async {
    final key = '$courseId::$lessonId';
    final bookmarks = await bookmarkedKeys();
    if (bookmarks.contains(key)) {
      await _db.delete(
        'bookmarks',
        where: 'course_id = ? AND lesson_id = ?',
        whereArgs: [courseId, lessonId],
      );
      return false;
    }
    await _db.insert('bookmarks', {
      'course_id': courseId,
      'lesson_id': lessonId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return true;
  }

  Future<void> saveQuizResult(String courseId, int score, int total) async {
    await _db.insert('quiz_results', {
      'course_id': courseId,
      'score': score,
      'total': total,
      'taken_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<Map<String, ({int score, int total, int takenAt})>>
  bestResults() async {
    final rows = await _db.rawQuery('''
      SELECT course_id, MAX(score) AS score, total, MAX(taken_at) AS taken_at
      FROM quiz_results GROUP BY course_id
    ''');
    return {
      for (final row in rows)
        row['course_id'] as String: (
          score: (row['score'] as num?)?.toInt() ?? 0,
          total: (row['total'] as num?)?.toInt() ?? 0,
          takenAt: (row['taken_at'] as num?)?.toInt() ?? 0,
        ),
    };
  }

  Future<int> completedCount(String courseId) async {
    return Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COUNT(*) FROM learning_progress WHERE course_id = ? AND completed = 1',
            [courseId],
          ),
        ) ??
        0;
  }

  Future<Set<String>> startedCourseIds() async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT course_id FROM learning_progress WHERE visits > 0 OR completed = 1',
    );
    return rows.map((e) => e['course_id'] as String).toSet();
  }

  Future<int> inProgressLessonCount() async {
    return Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COUNT(*) FROM learning_progress WHERE visits > 0 AND completed = 0',
          ),
        ) ??
        0;
  }

  Future<int> totalCompletedLessons() async {
    return Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COUNT(*) FROM learning_progress WHERE completed = 1',
          ),
        ) ??
        0;
  }

  Future<void> clearProgress() async {
    await _db.delete('learning_progress');
    await _db.delete('quiz_results');
    await _db.delete('bookmarks');
  }
}
