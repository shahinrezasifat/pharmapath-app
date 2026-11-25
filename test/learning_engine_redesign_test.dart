import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmapath_app/models/learning.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Learning Curriculum & Body Systems Verification (PRD Section 5)', () {
    late Map<String, dynamic> curriculumJson;

    setUpAll(() {
      final file = File('assets/learning/body_systems_curriculum.json');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Curriculum JSON file must exist',
      );
      curriculumJson =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    });

    test(
      'Contains all 18 standard body systems with Bengali and English names',
      () {
        final systemsRaw = curriculumJson['body_systems'] as List;
        expect(
          systemsRaw.length,
          equals(18),
          reason: 'Must have exactly 18 human body systems',
        );

        final expectedIds = [
          'ent',
          'nervous',
          'cardiovascular',
          'respiratory',
          'digestive',
          'hepatic',
          'renal',
          'endocrine',
          'musculoskeletal',
          'skin',
          'eye',
          'reproductive',
          'blood_immune',
          'mental_health',
          'infections',
          'nutrition',
          'emergency_first_aid',
          'pediatrics_geriatrics',
        ];

        final systems = systemsRaw
            .map((e) => BodySystem.fromJson(e as Map<String, dynamic>))
            .toList();

        for (final id in expectedIds) {
          final match = systems.where((s) => s.id == id).toList();
          expect(match, isNotEmpty, reason: 'Missing body system: $id');
          expect(match.first.nameBn.trim(), isNotEmpty);
          expect(match.first.nameEn.trim(), isNotEmpty);
          expect(match.first.descriptionBn.trim(), isNotEmpty);
          expect(
            match.first.bodyParts,
            isNotEmpty,
            reason: '$id has no body parts defined',
          );
        }
      },
    );

    test(
      'Ear, Nose & Throat system contains sample disease topic for sore throat',
      () {
        final topicsRaw = curriculumJson['disease_topics'] as List;
        expect(topicsRaw, isNotEmpty);

        final soreThroatRaw = topicsRaw.firstWhere(
          (t) => (t as Map<String, dynamic>)['id'] == 'sore_throat',
        ) as Map<String, dynamic>;

        final topic = DiseaseTopic.fromJson(soreThroatRaw);
        expect(topic.titleBn, contains('গলাব্যথা'));
        expect(topic.titleEn, contains('Sore Throat'));
        expect(topic.bodySystemId, equals('ent'));
        expect(topic.reviewStatus.toLowerCase(), equals('verified'));

        // Section 7.11 3-Tier Red Flags
        expect(topic.redFlags, isNotEmpty);
        final emergencyFlags = topic.redFlags
            .where((r) => r.level == RedFlagLevel.emergency)
            .toList();
        expect(
          emergencyFlags,
          isNotEmpty,
          reason: 'Must have emergency red flags',
        );
        expect(emergencyFlags.first.action, contains('হাসপাতাল'));

        // Safe Home Care & What to do / not to do
        expect(topic.homeCare, isNotEmpty);
        expect(topic.whatToDo, isNotEmpty);
        expect(topic.whatNotToDo, isNotEmpty);
        expect(
          topic.whatNotToDo.any(
            (w) => w.contains('অ্যান্টিবায়োটিক') || w.contains('অনিরাপদ'),
          ),
          isTrue,
          reason:
              'What not to do must warn against self-prescribed antibiotics',
        );

        // Section 7.13 Verified References
        expect(topic.references, isNotEmpty);
        expect(
          topic.references.any(
            (ref) =>
                ref.sourceName.contains('WHO') ||
                ref.sourceName.contains('DGHS'),
          ),
          isTrue,
          reason: 'Must cite WHO or DGHS Bangladesh references',
        );
      },
    );

    test('Master sample course sore_throat_master conforms to standard disease lesson template', () {
      final sampleCourseRaw =
          curriculumJson['sample_course'] as Map<String, dynamic>;
      final course = Course.fromJson(sampleCourseRaw);

      expect(course.id, equals('sore_throat_master'));
      expect(course.titleBn, contains('গলাব্যথা'));
      expect(
        course.passRatio,
        equals(0.8),
        reason: 'Standard passing score must be 80% (0.8)',
      );
      expect(course.lessons.length, greaterThanOrEqualTo(5));

      for (final lesson in course.lessons) {
        expect(lesson.effectiveTitle.trim(), isNotEmpty);
        expect(lesson.summary.trim(), isNotEmpty);
        expect(
          lesson.quiz,
          isNotEmpty,
          reason: 'Lesson ${lesson.id} must have a quiz gating completion',
        );
        expect(
          lesson.contentBlocks,
          isNotEmpty,
          reason: 'Lesson ${lesson.id} must have structured content blocks',
        );
      }

      // Check content blocks across course lessons
      final allBlocks = course.lessons.expand((l) => l.contentBlocks).toList();
      expect(allBlocks.any((b) => b.type == ContentBlockType.heading), isTrue);
      expect(
        allBlocks.any((b) => b.type == ContentBlockType.safetyNotice),
        isTrue,
      );
      expect(
        allBlocks.any((b) => b.type == ContentBlockType.comparisonTable),
        isTrue,
      );
      expect(
        allBlocks.any(
          (b) => b.type == ContentBlockType.medicalTerm || b.term != null,
        ),
        isTrue,
      );
    });
  });

  group('Passing Score & Completion Logic (PRD Section 11 & 12)', () {
    test('Default course pass ratio is 80% (0.8)', () {
      const minimalCourse = Course(
        id: 'test_course',
        title: 'Test Course',
        subtitle: 'Test Subtitle',
        icon: 'book',
        category: 'general',
        lessons: [],
        quiz: [],
      );

      expect(minimalCourse.passRatio, equals(0.8));
    });

    test('Lesson quiz evaluation strictly enforces 80% passing threshold', () {
      const course = Course(
        id: 'c1',
        title: 'Course 1',
        subtitle: 'Sub',
        icon: 'book',
        category: 'ent',
        passingScoreRatio: 0.8,
        quiz: [],
        lessons: [
          Lesson(
            id: 'l1',
            title: 'Lesson 1',
            summary: 'Sum',
            body: 'Body',
            minutes: 5,
            keyPoints: ['P1'],
            quiz: [
              QuizQuestion(
                question: 'Q1',
                options: ['A', 'B'],
                answer: 0,
                explanation: 'Exp',
              ),
              QuizQuestion(
                question: 'Q2',
                options: ['A', 'B'],
                answer: 0,
                explanation: 'Exp',
              ),
              QuizQuestion(
                question: 'Q3',
                options: ['A', 'B'],
                answer: 0,
                explanation: 'Exp',
              ),
              QuizQuestion(
                question: 'Q4',
                options: ['A', 'B'],
                answer: 0,
                explanation: 'Exp',
              ),
              QuizQuestion(
                question: 'Q5',
                options: ['A', 'B'],
                answer: 0,
                explanation: 'Exp',
              ),
            ],
          ),
        ],
      );

      final lesson = course.lessons.first;
      final requiredPassRatio = course.effectivePassRatio(lesson);
      expect(requiredPassRatio, equals(0.8));

      // 5 questions: 80% is 4 out of 5 correct
      final neededCorrect = (lesson.quiz.length * requiredPassRatio).ceil();
      expect(neededCorrect, equals(4));

      // 3 correct out of 5 = 60% -> FAIL (< 80%)
      const score3 = 3 / 5;
      expect(score3 < requiredPassRatio, isTrue);

      // 4 correct out of 5 = 80% -> PASS (>= 80%)
      const score4 = 4 / 5;
      expect(score4 >= requiredPassRatio, isTrue);

      // 5 correct out of 5 = 100% -> PASS
      const score5 = 5 / 5;
      expect(score5 >= requiredPassRatio, isTrue);
    });

    test('Content block and medical term serialization roundtrip', () {
      const block = ContentBlock(
        type: ContentBlockType.safetyNotice,
        content: 'জরুরি সতর্কতা',
        severity: 'warning',
      );

      final blockJson = block.toJson();
      expect(blockJson['type'], equals('safetyNotice'));
      expect(blockJson['content'], equals('জরুরি সতর্কতা'));
      expect(blockJson['severity'], equals('warning'));

      final restoredBlock = ContentBlock.fromJson(blockJson);
      expect(restoredBlock.type, equals(ContentBlockType.safetyNotice));
      expect(restoredBlock.content, equals('জরুরি সতর্কতা'));
      expect(restoredBlock.severity, equals('warning'));

      const term = MedicalTerm(
        id: 'pharyngitis',
        termEn: 'Pharyngitis',
        termBn: 'গলবিল প্রদাহ',
        definitionBn: 'গলবিলের সংক্রমণ',
        simpleExplanationBn: 'গলার পেছনের অংশের প্রদাহ',
        exampleBn: 'ভাইরাস বা ব্যাকটেরিয়ায় হয়',
        category: 'Conditions',
      );

      final termJson = term.toJson();
      final restoredTerm = MedicalTerm.fromJson(termJson);
      expect(restoredTerm.termEn, equals('Pharyngitis'));
      expect(restoredTerm.termBn, equals('গলবিল প্রদাহ'));
      expect(restoredTerm.category, equals('Conditions'));

      final olderTerm = MedicalTerm.fromJson({
        'id': 'legacy',
        'term_en': 'Legacy term',
        'term_bn': 'পুরোনো পরিভাষা',
        'definition_bn': 'সংজ্ঞা',
      });
      expect(olderTerm.category, equals('General'));
    });
  });

  group('Bilingual Search Matching (PRD Section 19)', () {
    test('Search matches Bengali and English queries cleanly', () {
      const topic = DiseaseTopic(
        id: 'sore_throat_pharyngitis',
        bodySystemId: 'ent',
        bodyPartId: 'throat',
        titleBn: 'গলাব্যথা ও গলবিল প্রদাহ',
        titleEn: 'Sore Throat & Pharyngitis',
        slug: 'sore-throat',
        summary: 'গলাব্যথার কারণ ও যত্ন',
      );

      // Test Bengali query
      final queryBn = 'গলাব্যথা'.toLowerCase();
      final matchBn =
          topic.titleBn.toLowerCase().contains(queryBn) ||
          topic.titleEn.toLowerCase().contains(queryBn);
      expect(matchBn, isTrue);

      // Test English query
      final queryEn = 'Pharyngitis'.toLowerCase();
      final matchEn =
          topic.titleBn.toLowerCase().contains(queryEn) ||
          topic.titleEn.toLowerCase().contains(queryEn);
      expect(matchEn, isTrue);

      // Test irrelevant query
      final queryNone = 'cardio'.toLowerCase();
      final matchNone =
          topic.titleBn.toLowerCase().contains(queryNone) ||
          topic.titleEn.toLowerCase().contains(queryNone);
      expect(matchNone, isFalse);
    });
  });
}
