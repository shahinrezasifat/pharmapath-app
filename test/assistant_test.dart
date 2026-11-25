import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pharmapath_app/controllers/assistant_controller.dart';
import 'package:pharmapath_app/core/ai_doctors.dart';
import 'package:pharmapath_app/core/assistant_diseases.dart';
import 'package:pharmapath_app/data/ai_dao.dart';
import 'package:pharmapath_app/data/app_database.dart';
import 'package:pharmapath_app/data/learning_dao.dart';
import 'package:pharmapath_app/data/learning_repository.dart';
import 'package:pharmapath_app/data/medicine_dao.dart';
import 'package:pharmapath_app/models/learning.dart';
import 'package:pharmapath_app/models/medicine.dart';
import 'package:pharmapath_app/services/assistant_knowledge.dart';
import 'package:pharmapath_app/services/oxion_assistant.dart';
import 'package:pharmapath_app/views/assistant_view.dart';

class _FakeAssistant extends OxionAssistant {
  _FakeAssistant() : super();

  @override
  bool get ready => false;

  @override
  Future<void> refreshModels() async {}

  @override
  Future<String> reply({
    required String query,
    required String? context,
    List<({String role, String text})> history = const [],
    List<AssistantMedia> media = const [],
    AssistantReplyMode mode = AssistantReplyMode.consult,
    String? scriptedQuestion,
  }) async {
    throw const AssistantUnavailable('no model');
  }
}

Medicine seed({
  required int id,
  required String brand,
  required String generic,
  bool detailed = false,
}) => Medicine(
  id: id,
  brandName: brand,
  genericName: generic,
  company: 'Test Pharma',
  strength: '500 mg',
  dosageForm: 'Tablet',
  indications: detailed ? 'For symptoms' : null,
  detailLoaded: detailed,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('assistant_diseases script detection', () {
    test('recognises Bangla and Latin scripts', () {
      expect(isBangla('জ্বর'), isTrue);
      expect(isBangla('fever'), isFalse);
      expect(isLatin('fever'), isTrue);
      expect(isLatin('জ্বর'), isFalse);
    });
  });

  group('assistant_diseases autocomplete', () {
    final lessons = const [
      Lesson(
        id: 'fever',
        title: 'জ্বর',
        summary: 'শরীরের তাপমাত্রা স্বাভাবিকের বেশি হওয়া।',
        body: '<p>ওষুধ ও ডোজ: প্র্যাকটিক্যাল পরামর্শ।</p>',
        keyPoints: [],
        minutes: 4,
      ),
      Lesson(
        id: 'hypertension',
        title: 'উচ্চ রক্তচাপ',
        summary: 'রক্তচাপ বেড়ে যাওয়া।',
        body: '<p>কিছু কথা।</p>',
        keyPoints: [],
        minutes: 5,
      ),
    ];

    test('Bangla prefix suggests the fever lesson', () {
      final suggestions = suggestDiseases('জ্বর', lessons);
      expect(suggestions, contains('জ্বর'));
    });

    test('English prefix suggests the mapped Bangla lesson', () {
      final suggestions = suggestDiseases('fev', lessons);
      expect(suggestions, contains('জ্বর'));
    });

    test('findEntry maps a query to curated generics', () {
      final entry = findEntry('fever');
      expect(entry, isNotNull);
      expect(entry!.lessonId, 'fever');
      expect(entry.generics, contains('Paracetamol'));
    });

    test('symptom phrasing lands on the most specific condition', () {
      expect(findEntry('বুক জ্বালা ও টক ঢেকুর')?.lessonId, 'gerd');
      expect(findEntry('টক ঢেঁকুর হচ্ছে')?.lessonId, 'gerd');
      expect(findEntry('গ্যাসের সমস্যা')?.lessonId, 'gerd');
      // The longer, more specific alias still wins over গ্যাস/জ্বালা hits.
      expect(findEntry('প্রস্রাবে জ্বালা')?.lessonId, 'uti');
    });

    test('empty query yields no suggestions', () {
      expect(suggestDiseases('   ', lessons), isEmpty);
    });
  });

  group('AssistantKnowledge grounding', () {
    late AppDatabase db;
    late AssistantKnowledge knowledge;

    setUp(() async {
      db = await AppDatabase.openForTesting();
      await db.upsertDetailBatch([
        seed(id: 1, brand: 'Napa', generic: 'Paracetamol', detailed: true),
        seed(id: 2, brand: 'Ace', generic: 'Paracetamol'),
        seed(id: 3, brand: 'Novate', generic: 'Salbutamol'),
      ]);
      knowledge = AssistantKnowledge(
        LearningRepository(LearningDao(db)),
        MedicineDao(db, pageSize: 5),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'medicinesFor resolves curated generics against the database',
      () async {
        final medicines = await knowledge.medicinesFor('fever', cap: 4);
        expect(medicines, isNotEmpty);
        expect(medicines.map((m) => m.brandName), contains('Napa'));
        // One representative per generic, preferring the detailed row.
        expect(
          medicines.firstWhere((m) => m.brandName == 'Napa').detailLoaded,
          isTrue,
        );
      },
    );

    test('autocomplete works through the knowledge layer', () async {
      expect(await knowledge.suggestDiseases('fev'), contains('জ্বর'));
    });

    test(
      'medicinesFor matches the stored indications text of a medicine',
      () async {
        // Napa is the only seeded row whose indications mention "symptoms".
        final medicines = await knowledge.medicinesFor('symptoms', cap: 4);
        expect(medicines.map((m) => m.brandName), contains('Napa'));
      },
    );

    test('buildContext includes the matched lesson and medicines', () async {
      final context = await knowledge.buildContext('fever');
      expect(context, isNotNull);
      expect(context, contains('জ্বর'));
      expect(context, contains('Paracetamol'));
    });

    test('symptom query builds context from the matching lesson', () async {
      await db.upsertDetailBatch([
        seed(id: 7, brand: 'Prazole', generic: 'Omeprazole', detailed: true),
      ]);
      final context = await knowledge.buildContext('বুক জ্বালা ও টক ঢেকুর');
      expect(context, isNotNull);
      expect(context, contains('রিফ্লাক্স'));
      expect(context, contains('Omeprazole'));
    });

    test('buildContext returns null for an unrecognised query', () async {
      final context = await knowledge.buildContext('অজাবিজ অমনেরোগিল');
      expect(context, isNull);
    });
  });

  group('AssistantView widget', () {
    testWidgets('renders the shell and a graceful knowledge bubble offline', (
      tester,
    ) async {
      AppDatabase? db;
      AssistantController? controller;
      await tester.runAsync(() async {
        db = await AppDatabase.openForTesting();
        final knowledge = AssistantKnowledge(
          LearningRepository(LearningDao(db!)),
          MedicineDao(db!, pageSize: 5),
        );
        // An assistant that always reports unavailable, so no network runs.
        controller = AssistantController(
          knowledge,
          _FakeAssistant(),
          AiDao(db!),
        );
        Get.put(controller!);
      });

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AssistantView())),
      );
      await tester.pump();

      // Static shell: telemedicine header, disease input—no safety banner.
      // The header wears the persona of the selected model, not a fixed name.
      final headerDoctor = doctorFor(
        Get.find<AssistantController>().selectedModel.value,
      );
      expect(find.text(headerDoctor.name), findsOneWidget);
      expect(find.textContaining('টেলিমেডিসিন'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      // The composer keeps its two visible helpers: paperclip and mic.
      expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      // Without persisted storage the one-time language greeting stays quiet.
      expect(find.textContaining('ইংরেজিতে?'), findsNothing);
      // The educational-use disclaimer is deliberately gone from the chat.
      expect(find.textContaining('শিক্ষামূলক'), findsNothing);
      // The removed "AI-generated explanation" disclaimer must stay gone.
      expect(find.textContaining('AI-নির্মিত'), findsNothing);

      // A deterministic (non-model) answer bubble renders without any I/O.
      controller!.messages.add(
        const ChatTurn(
          role: 'assistant',
          text: 'সম্ভাব্য ওষুধ: Paracetamol — Napa',
        ),
      );
      await tester.pump();
      expect(find.textContaining('Paracetamol — Napa'), findsOneWidget);
      // The doctor bubble carries the clinician's name label next to it
      // (the header itself now shows the switched-to doctor's persona).
      expect(find.text('ডা. ফার্মাপাথ'), findsOneWidget);

      await tester.runAsync(() async {
        // The controller restores sessions and messages through a chain of
        // real async queries; let it settle before the database goes away.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        Get.reset();
        await db!.close();
      });
    });
  });

  group('Bangla-only chat and composer helpers', () {
    test('the paperclip routes attached files by extension', () {
      expect(AssistantController.attachmentKindOf('rash-photo.JPG'), 'image');
      expect(AssistantController.attachmentKindOf('voice.m4a'), 'audio');
      expect(AssistantController.attachmentKindOf('bp-log.csv'), 'text');
      expect(AssistantController.attachmentKindOf('scan.pdf'), 'other');
    });

    test(
      'a Latin-script question still gets a Bangla offline answer',
      () async {
        final db = await AppDatabase.openForTesting();
        await db.upsertDetailBatch([
          seed(id: 1, brand: 'Napa', generic: 'Paracetamol', detailed: true),
        ]);
        final controller = AssistantController(
          AssistantKnowledge(
            LearningRepository(LearningDao(db)),
            MedicineDao(db, pageSize: 5),
          ),
          _FakeAssistant(),
          AiDao(db),
        );
        // The model is unavailable, so the deterministic reply must still be
        // fluent Bangla—even though a pure Latin brand query skips the
        // interview and lands on the direct knowledge answer.
        await controller.ask('Napa');
        final reply = controller.messages.last.text;
        expect(reply, matches(RegExp(r'[\u0980-\u09ff]')));
        expect(reply, contains('প্রয়োজনীয় ঔষধ'));
        expect(reply, contains('Napa'));
        expect(reply, isNot(contains('Relevant medicines')));
        expect(reply, isNot(contains('General guidance')));
        await db.close();
      },
    );
  });
}
