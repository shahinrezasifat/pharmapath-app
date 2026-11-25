import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final files = [
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
  ];

  /// Every condition shelf, discovered rather than listed so a new subject area
  /// is covered the moment it ships.
  final shelves =
      (Directory('assets/learning')
            .listSync()
            .whereType<File>()
            .map((file) => file.path)
            .where(
              (path) =>
                  path.contains('library_') &&
                  !path.endsWith('library_tracks.json'),
            )
            .toList())
        ..sort();

  Map<String, dynamic> decode(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  List<dynamic> coursesOf(String path) =>
      (decode(path)['courses'] as List? ?? const []);

  test('learning library is complete and every lesson is usable', () {
    expect(shelves, isNotEmpty, reason: 'no condition shelves shipped');

    final ids = <String>{};
    var lessons = 0;
    var conditions = 0;

    for (final path in [...files, ...shelves]) {
      final decoded = decode(path);
      expect(decoded, isA<Map>(), reason: '$path must be a JSON object');
      final courses = coursesOf(path);
      expect(courses, isNotEmpty, reason: '$path has no courses');

      for (final raw in courses) {
        final course = raw as Map;
        final courseId = course['id'] as String;
        expect(
          ids.add('course:$courseId'),
          isTrue,
          reason: 'duplicate course id $courseId',
        );
        final courseLessons = course['lessons'] as List;
        expect(courseLessons, isNotEmpty, reason: '$courseId has no lessons');

        for (final rawLesson in courseLessons) {
          final lesson = rawLesson as Map;
          lessons++;
          final id = lesson['id'] as String;
          expect(
            ids.add('lesson:$id'),
            isTrue,
            reason: 'duplicate lesson id $id',
          );
          expect((lesson['title'] as String).trim(), isNotEmpty);
          expect((lesson['summary'] as String).trim(), isNotEmpty);
          final body = lesson['body'] as String;
          expect(
            body.length,
            greaterThan(300),
            reason: '$id body is too short',
          );
          expect(
            (lesson['keyPoints'] as List),
            isNotEmpty,
            reason: '$id has no key points',
          );
          if (!path.endsWith('courses.json')) {
            conditions++;
            expect(body, contains('<h3>'), reason: '$id has no sections');
            expect(
              RegExp(r'<h3>').allMatches(body).length,
              greaterThanOrEqualTo(4),
              reason: '$id needs at least four sections',
            );
          }

          // Every lesson carries the mini-quiz that gates completion.
          final lessonQuiz = lesson['quiz'] as List?;
          expect(lessonQuiz, isNotNull, reason: '$id has no lesson quiz');
          expect(
            lessonQuiz!.length,
            greaterThanOrEqualTo(2),
            reason: '$id needs at least two quiz questions',
          );
          for (final rawQ in lessonQuiz) {
            final q = rawQ as Map;
            final options = q['options'] as List;
            expect(options.length, greaterThanOrEqualTo(2));
            expect(
              q['answer'] as int,
              inInclusiveRange(0, options.length - 1),
              reason: '$id lesson quiz answer out of range',
            );
            expect((q['question'] as String).trim(), isNotEmpty);
            expect((q['explanation'] as String).trim(), isNotEmpty);
          }
        }

        for (final rawQuiz in (course['quiz'] as List? ?? const [])) {
          final quiz = rawQuiz as Map;
          final options = quiz['options'] as List;
          final answer = quiz['answer'] as int;
          expect(options.length, greaterThanOrEqualTo(2));
          expect(
            answer,
            inInclusiveRange(0, options.length - 1),
            reason: '$courseId quiz answer out of range',
          );
        }
      }
    }

    expect(conditions, greaterThanOrEqualTo(150));
    expect(lessons, greaterThanOrEqualTo(160));
  });

  test('every shelf is labelled and holds courses of its own subject', () {
    final tracks =
        (decode('assets/learning/library_tracks.json')['tracks'] as List)
            .cast<Map<String, dynamic>>();
    expect(tracks.length, greaterThanOrEqualTo(20));
    final trackIds = <String>{};
    for (final track in tracks) {
      expect((track['label_bn'] as String).trim(), isNotEmpty);
      expect(
        trackIds.add(track['id'] as String),
        isTrue,
        reason: 'duplicate shelf id ${track['id']}',
      );
    }

    for (final path in shelves) {
      final shelfId = path
          .substring(path.lastIndexOf('library_') + 8)
          .replaceAll('.json', '');
      expect(trackIds, contains(shelfId), reason: '$path has no shelf label');
      for (final raw in coursesOf(path)) {
        final course = raw as Map<String, dynamic>;
        expect(
          course['track'],
          shelfId,
          reason: '${course['id']} sits in the wrong shelf',
        );
        expect(
          (course['atlas_tags'] as List? ?? const []),
          isNotEmpty,
          reason: '${course['id']} links to no body-system category',
        );
      }
    }
  });

  test(
    'body-system atlas covers the body and every row opens a real course',
    () {
      final atlas = decode('assets/learning/body_systems_atlas.json');
      final rows = (atlas['body_systems'] as List).cast<Map<String, dynamic>>();
      final curriculum = decode('assets/learning/body_systems_curriculum.json');
      final systems = (curriculum['body_systems'] as List)
          .cast<Map<String, dynamic>>();

      // 18 organ systems alone left whole body regions with nowhere to go.
      expect(
        rows.length + systems.length,
        greaterThanOrEqualTo(60),
        reason: 'the atlas must widen the organ-system coverage',
      );

      final shipped = <String>{
        for (final path in [...files, ...shelves])
          for (final raw in coursesOf(path)) (raw as Map)['id'] as String,
        'sore_throat_master',
      };
      final knownGroups = {'core', 'organ', 'region', 'life', 'group'};
      final ids = <String>{};

      for (final row in rows) {
        final id = row['id'] as String;
        expect(ids.add(id), isTrue, reason: 'duplicate atlas id $id');
        expect(
          knownGroups,
          contains(row['group']),
          reason: '$id sits in a group the app cannot label',
        );
        expect(
          (row['body_parts'] as List),
          isNotEmpty,
          reason: '$id lists no body parts',
        );
        final related = (row['related_course_ids'] as List).cast<String>();
        expect(related, isNotEmpty, reason: '$id has no course to open');
        for (final courseId in related) {
          expect(
            shipped,
            contains(courseId),
            reason: '$id points at missing course $courseId',
          );
        }
      }

      for (final system in systems) {
        expect(
          ids,
          isNot(contains(system['id'])),
          reason: 'atlas repeats curriculum system ${system['id']}',
        );
      }
    },
  );
}
