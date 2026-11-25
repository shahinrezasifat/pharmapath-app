import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pharmapath_app/controllers/assistant_controller.dart';
import 'package:pharmapath_app/core/ai_doctors.dart';
import 'package:pharmapath_app/core/assistant_diseases.dart';
import 'package:pharmapath_app/core/assistant_triage.dart';
import 'package:pharmapath_app/data/ai_dao.dart';
import 'package:pharmapath_app/data/app_database.dart';
import 'package:pharmapath_app/data/learning_dao.dart';
import 'package:pharmapath_app/data/learning_repository.dart';
import 'package:pharmapath_app/data/medicine_dao.dart';
import 'package:pharmapath_app/services/assistant_knowledge.dart';
import 'package:pharmapath_app/services/oxion_assistant.dart';

/// Offline assistant: never claims ready, never answers from the model, so
/// the interview must fall through to the deterministic knowledge plan.
class _OfflineAssistant extends OxionAssistant {
  _OfflineAssistant() : super();

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

/// A yes/no question of the kind the script asks about red flags, associated
/// symptoms and history—হ্যাঁ/না genuinely completes these.
const String _yesNoQ = 'জরুরি কোনো লক্ষণ আছে কি?';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('triage slots & quick replies', () {
    test('question text maps to the right clinical slot', () {
      expect(slotOf('জ্বরটা কতদিন ধরে হচ্ছে?'), TriageSlot.duration);
      expect(
        slotOf('লক্ষণগুলোর তীব্রতা কেমন (হালকা / মাঝারি / তীব্র)?'),
        TriageSlot.severity,
      );
      expect(
        slotOf('রোগীর বয়স-শ্রেণি কোনটা? (শিশু / কিশোর / প্রাপ্তবয়স্ক / ৬০+)'),
        TriageSlot.age,
      );
    });

    test('structured questions offer tap-to-answer chips', () {
      expect(quickRepliesFor('জ্বরটা কতদিন ধরে হচ্ছে?'), isNotEmpty);
      expect(
        quickRepliesFor('আপনার প্রধান অস্বস্তিটা এক বাক্যে বলুন'),
        isEmpty,
      );
      expect(
        quickRepliesFor('ব্যথাটা কেমন—ছুরি মারার মতো, না যন্ত্রণা-চাপ?'),
        isNotEmpty,
      );
      expect(
        quickRepliesFor('শুরুটা হঠাৎ হয়েছে, না ধীরে ধীরে বেড়েছে?'),
        isNotEmpty,
      );
    });

    test('the seven clinical dimensions each map to their own slot', () {
      expect(
        slotOf('ব্যথাটা কেমন—ছুরি মারার মতো, না যন্ত্রণা-চাপ?'),
        TriageSlot.quality,
      );
      expect(
        slotOf('ব্যথা মাথার কোথায় বেশি—কপালে, না একপাশে?'),
        TriageSlot.location,
      );
      expect(
        slotOf('শুরুটা হঠাৎ হয়েছে, না ধীরে ধীরে বেড়েছে?'),
        TriageSlot.onset,
      );
      expect(
        slotOf('কীসে ব্যথা বাড়ে—মানসিক চাপ, ঘুম কম? কীসে কমে?'),
        TriageSlot.triggers,
      );
      expect(slotOf('উচ্চ রক্তচাপের কোনো ইতিহাস আছে কি?'), TriageSlot.history);
    });
  });

  group('dynamic follow-ups', () {
    test('a hidden red flag triggers an immediate focused probe', () {
      final probe = followUpFor(
        'পাতলা পায়খানা কতদিন থেকে হচ্ছে?',
        'চার দিন, আর পায়খানায় রক্তপাতও হচ্ছে',
      );
      expect(probe, isNotNull);
    });

    test('a dodged answer re-asks the same slot in plainer terms', () {
      expect(isDodging('জানা নাই'), isTrue);
      final probe = followUpFor('জ্বরটা কতদিন ধরে হচ্ছে?', 'মনে নাই');
      expect(probe, isNotNull);
      expect(probe, contains('দিন'));
    });

    test('a plain answer needs no probe', () {
      expect(followUpFor('জ্বরটা কতদিন ধরে হচ্ছে?', 'তিন দিন'), isNull);
    });

    test('an answer naming light/sound trouble deepens into an aura probe', () {
      final probe = followUpFor(
        'সাথে বমিভাব, আলো-শব্দে অস্বস্তি—কী কী আছে?',
        'আলো দেখলে চোখে কষ্ট করে',
      );
      expect(probe, isNotNull);
      expect(probe, contains('ঝাপসা'));
    });

    test('a symptom nothing relieves gets a trajectory question', () {
      final probe = followUpFor(
        'কীসে ব্যথা বাড়ে? কীসে কমে?',
        'কিছুতেই কমে না',
      );
      expect(probe, isNotNull);
      expect(probe, contains('২৪ ঘণ্টা'));
    });

    test('a one-word answer to a descriptive question is not an answer', () {
      expect(isVagueAnswer('জ্বরটা কতদিন ধরে হচ্ছে?', 'হ্যাঁ'), isTrue);
      expect(isVagueAnswer('জ্বরটা কতদিন ধরে হচ্ছে?', 'বেশি'), isTrue);
      expect(isVagueAnswer('জ্বরটা কতদিন ধরে হচ্ছে?', 'তিন দিন ধরে'), isFalse);
      // A chip the question itself offered is a complete answer, however short.
      expect(isVagueAnswer('ব্যথার তীব্রতা ১০-এর মধ্যে কত?', 'হালকা'), isFalse);
      expect(isVagueAnswer('রোগীর বয়স-শ্রেণি কোনটা?', 'শিশু'), isFalse);
      // হ্যাঁ/না genuinely closes a yes/no question.
      expect(isVagueAnswer(_yesNoQ, 'না'), isFalse);
      final probe = followUpFor('জ্বরটা কতদিন ধরে হচ্ছে?', 'হ্যাঁ');
      expect(probe, isNotNull);
      // The clarification still collects the same clinical slot.
      expect(slotOf(probe!), TriageSlot.duration);
      expect(probe, contains('দিন'));
    });

    test('a bare হ্যাঁ to a safety question earns a detail probe', () {
      final probe = followUpFor(_yesNoQ, 'হ্যাঁ');
      expect(probe, isNotNull);
      expect(probe, contains('বুঝি'));
    });

    test('every clarification maps back to its own slot', () {
      for (final question in <String>[
        'এই সমস্যাটা কতদিন থেকে হচ্ছে?',
        'ব্যথার তীব্রতা ১০-এর মধ্যে কত?',
        'সমস্যাটা কেমন—ছুরি মারার মতো, না যন্ত্রণা-চাপ?',
        'শরীরের ঠিক কোন জায়গায় বেশি?',
        'শুরুটা হঠাৎ হয়েছে, না ধীরে ধীরে বেড়েছে?',
        'কীসে সমস্যাটা বাড়ে? কীসে কমে?',
      ]) {
        final clarified = clarifyQuestionFor(question);
        expect(slotOf(clarified), slotOf(question), reason: question);
      }
    });
  });

  group('the doctor proves it read the answer', () {
    test('a reply that only asks on gets the patient’s words echoed', () {
      const question = 'জ্বরটা কতদিন ধরে হচ্ছে?';
      const answer = 'তিন দিন ধরে, রাতে বেশি হয়';
      // The model skipped straight past what the patient typed.
      final repaired = withAnswerAcknowledgement(
        text: 'জ্বর মাপলে কত ডিগ্রি হয়েছে?',
        question: question,
        answer: answer,
      );
      expect(repaired, startsWith('আপনি বলেছেন—“তিন দিন ধরে'));
      expect(repaired, contains('জ্বর মাপলে কত ডিগ্রি হয়েছে?'));
    });

    test('a reply that engages with the answer is left untouched', () {
      final kept = withAnswerAcknowledgement(
        text: 'তিন দিন ধরে জ্বর, রাতে বাড়ে—ডেগ্রি মাপা হয়েছে?',
        question: 'জ্বরটা কতদিন ধরে হচ্ছে?',
        answer: 'তিন দিন ধরে, রাতে বেশি হয়',
      );
      expect(kept, 'তিন দিন ধরে জ্বর, রাতে বাড়ে—ডেগ্রি মাপা হয়েছে?');
    });

    test('a bare বুঝেছি does not count as having listened', () {
      expect(
        readsAnswer('বুঝেছি। পরের প্রশ্ন—ডায়াবেটিস আছে?', 'মাঝে মাঝে বমি ভাব'),
        isFalse,
      );
      expect(
        readsAnswer(
          'আপনি বলছেন মাঝে মাঝে বমি ভাব। বমি হয়েছে?',
          'মাঝে মাঝে বমি ভাব',
        ),
        isTrue,
      );
    });

    test('a paraphrased scripted question counts as asked', () {
      expect(
        asksAbout(
          'আপনি বলছেন তিন দিন ধরে জ্বর। জ্বর কত দিনের?',
          'জ্বরটা কতদিন ধরে হচ্ছে?',
        ),
        isTrue,
      );
      // A different question never stands in for the scripted one.
      expect(
        asksAbout(
          'আপনি বলছেন তিন দিন ধরে জ্বর। প্রস্রাবে জ্বালা আছে?',
          'জ্বরটা কতদিন ধরে হচ্ছে?',
        ),
        isFalse,
      );
    });
  });

  group('structured interview coverage', () {
    test(
      'a headache interview walks through all the diagnostic dimensions',
      () {
        final entry = findEntry('প্রচণ্ড মাথা ব্যথা');
        expect(entry, isNotNull);
        final plan = planFor(entry!, 'প্রচণ্ড মাথা ব্যথা');
        expect(plan, isNotNull);
        final joined = plan!.questions.join('\n');
        for (final cue in <String>[
          'কেমন', // pain type / quality
          'কোথায়', // location
          'হঠাৎ', // onset
          'তীব্রতা', // severity 1-10
          'কীসে', // triggers & relieving factors
          'ইতিহাস', // relevant medical history
          'ওজন', // weight—needed for a confirmed dose
        ]) {
          expect(joined, contains(cue));
        }
        final slots = plan.questions.map(slotOf).toSet();
        expect(
          slots,
          containsAll(const [
            TriageSlot.quality,
            TriageSlot.location,
            TriageSlot.onset,
            TriageSlot.triggers,
            TriageSlot.severity,
            TriageSlot.history,
          ]),
        );
      },
    );
  });

  group('interview completion', () {
    test('a hurried patient cannot finish without the safety slots', () {
      expect(
        isInterviewComplete(
          answered: 4,
          total: 8,
          userRequestedFinish: true,
          answeredSlots: {TriageSlot.duration, TriageSlot.associated},
        ),
        isFalse,
      );
    });

    test('early finish is allowed once urgency/age/risk are on record', () {
      expect(
        isInterviewComplete(
          answered: 4,
          total: 8,
          userRequestedFinish: true,
          answeredSlots: {
            TriageSlot.duration,
            TriageSlot.urgency,
            TriageSlot.age,
            TriageSlot.risk,
          },
        ),
        isTrue,
      );
    });

    test('auto-complete only at full confidence', () {
      expect(
        isInterviewComplete(
          answered: 8,
          total: 8,
          userRequestedFinish: false,
          answeredSlots: {},
        ),
        isTrue,
      );
      expect(
        isInterviewComplete(
          answered: 7,
          total: 8,
          userRequestedFinish: false,
          answeredSlots: {},
        ),
        isFalse,
      );
    });
  });

  group('model panel doctors', () {
    test('the deepest reasoners lead and every model wears a name', () {
      const catalogue = [
        'gemini-3.7-flash',
        'claude-opus-5.5',
        'gpt-5.5',
        'gemma-2-2b',
        'deepseek-v4-flash-0731',
        'claude-sonnet-5',
      ];
      final doctors = rankDoctors(catalogue);
      expect(doctors.first.model, 'claude-opus-5.5');
      expect(doctors.last.model, 'gemma-2-2b');
      // Distinct doctor names — no raw ids shown to the patient.
      expect(doctors.map((d) => d.name).toSet().length, catalogue.length);
      expect(doctors.every((d) => d.name.startsWith('ডা. ')), isTrue);
      // A brand-new model id still arrives as some doctor.
      expect(doctorFor('nova-x-99').name, isNotEmpty);
      expect(rankDoctors(['nova-x-99']).single.score, greaterThan(0));
    });
  });

  group('controller: symptom messages interview before prescribing', () {
    late AppDatabase db;
    late AssistantController controller;

    setUp(() async {
      db = await AppDatabase.openForTesting();
      controller = AssistantController(
        AssistantKnowledge(
          LearningRepository(LearningDao(db)),
          MedicineDao(db, pageSize: 5),
        ),
        _OfflineAssistant(),
        AiDao(db),
      );
      Get.put(controller);
      // Let the async session restore settle before the test drives send().
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });

    tearDown(() async {
      Get.reset();
      await db.close();
    });

    test('unmatched symptoms start a general interview, not an answer', () {
      expect(
        looksLikeSymptoms('চার দিন ধরে পেটের নিচের দিকে অস্বস্তি'),
        isTrue,
      );
    });

    test('a fever complaint asks questions and withholds medicine until the '
        'interview is complete', () async {
      controller.draft.value = 'আমার তিন দিন ধরে জ্বর';
      await controller.send();

      // The doctor greeted + asked the first question instead of answering.
      expect(controller.interviewActive.value, isTrue);
      expect(controller.messages.last.role, 'assistant');
      expect(controller.quickReplies, isNotEmpty);

      // Answer every question the way the screen lets a patient do—tap a chip
      // when the question offers them, otherwise write a real detail—so the
      // interview can honestly claim a complete history.
      var guard = 0;
      while (controller.interviewActive.value && guard++ < 30) {
        final chips = quickRepliesFor(controller.currentQuestion.value);
        controller.draft.value = chips.isNotEmpty
            ? chips.first
            : 'প্রায় প্রতিদিন আছে, খাওয়া-দাওয়ার পরে বাড়ে';
        await controller.send();
      }
      expect(controller.interviewActive.value, isFalse);
      // A closing preamble plus the grounded plan arrived as final bubbles.
      final texts = controller.messages.map((m) => m.text).join('\n');
      expect(texts, contains('ধন্যবাদ'));
      // The offline fallback still delivers the four-part structure:
      // summary, home care, medicines and the when-to-seek-help line.
      final last = controller.messages.last.text;
      expect(last, contains('সারসংক্ষেপ'));
      expect(last, contains('ওজন')); // weight captured for the dose
      expect(last, contains('ঘরোয়া'));
      expect(last, contains('কখন দ্রুত ডাক্তার'));
      expect(controller.messages.last.role, 'assistant');
    });

    test(
      'an English symptom report opens the interview, not a remedy list',
      () async {
        controller.draft.value = 'I have a severe headache since this morning';
        await controller.send();
        expect(controller.interviewActive.value, isTrue);
        // Nothing prescribing has happened yet—only the doctor's questions.
        expect(
          controller.messages
              .where((m) => m.role == 'assistant')
              .every((m) => !m.text.contains('Tablet') && m.medicines.isEmpty),
          isTrue,
        );
      },
    );

    test('images queue as pending attachments and clear on send', () async {
      // Feed the pending list exactly the way the pickers do.
      controller.pending.add(
        PendingAttachment(
          kind: AssistantMediaKind.image,
          name: 'rash.jpg',
          mimeType: 'image/jpeg',
          bytes: Uint8List.fromList(List.filled(64, 7)),
        ),
      );
      controller.draft.value = 'এই ছবিটা দেখুন';
      await controller.send();
      expect(controller.pending, isEmpty);
      final userTurn = controller.messages.firstWhere((m) => m.isUser);
      expect(userTurn.attachments.single.kind, 'image');
    });
  });
}
