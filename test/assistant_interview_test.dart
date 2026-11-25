import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pharmapath_app/controllers/assistant_controller.dart';
import 'package:pharmapath_app/core/app_config.dart';
import 'package:pharmapath_app/core/assistant_triage.dart';
import 'package:pharmapath_app/data/ai_dao.dart';
import 'package:pharmapath_app/data/app_database.dart';
import 'package:pharmapath_app/data/learning_dao.dart';
import 'package:pharmapath_app/data/learning_repository.dart';
import 'package:pharmapath_app/data/medicine_dao.dart';
import 'package:pharmapath_app/services/assistant_knowledge.dart';
import 'package:pharmapath_app/services/oxion_assistant.dart';

/// One model request, captured so a test can prove exactly what the doctor
/// was allowed to read.
class _Call {
  _Call({
    required this.query,
    required this.context,
    required this.history,
    required this.mode,
    required this.scriptedQuestion,
  });

  final String query;
  final String? context;
  final List<({String role, String text})> history;
  final AssistantReplyMode mode;
  final String? scriptedQuestion;
}

/// A model that always answers, recording every request.
class _RecordingAssistant extends OxionAssistant {
  _RecordingAssistant() : super();

  /// What this model answers with — a test can replace it with a reply that
  /// ignores the patient, to prove the controller repairs the doctor's turn.
  String answer = 'বুঝেছি।';
  final List<_Call> calls = [];

  @override
  bool get ready => true;

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
    calls.add(
      _Call(
        query: query,
        context: context,
        history: history,
        mode: mode,
        scriptedQuestion: scriptedQuestion,
      ),
    );
    return answer;
  }
}

/// An unreachable cloud, so the deterministic interview path is exercised.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('scripted question safety net', () {
    test('a reply that forgot the question gets it appended verbatim', () {
      const question = 'জ্বর মাপলে কত ডিগ্রি (Fahrenheit) হয়েছে?';
      expect(
        AssistantController.withScriptedQuestion('আপনার কথা বুঝেছি।', question),
        'আপনার কথা বুঝেছি।\n\n$question',
      );
      // A reply that already asks it is left alone—never asked twice.
      final already = 'আপনি বলছেন তিন দিন ধরে জ্বর।\n$question';
      expect(
        AssistantController.withScriptedQuestion(already, question),
        already,
      );
      // An empty reply still delivers the question.
      expect(
        AssistantController.withScriptedQuestion('   ', question),
        question,
      );
    });

    test('the offline doctor turn echoes the answer, then asks on', () {
      final turn = acknowledgeAnswer(
        question: 'জ্বরটা কতদিন ধরে হচ্ছে?',
        answer: 'তিন দিন ধরে, রাতে বেশি হয়',
        nextQuestion: 'জ্বর মাপলে কত ডিগ্রি হয়েছে?',
      );
      // The patient's own words come back, so nothing typed is skipped.
      expect(turn, contains('তিন দিন ধরে, রাতে বেশি হয়'));
      expect(turn, contains('সময়কালটা এখন পরিষ্কার হলো'));
      expect(turn.endsWith('জ্বর মাপলে কত ডিগ্রি হয়েছে?'), isTrue);
    });

    test('a dodged answer is acknowledged as unclear', () {
      final turn = acknowledgeAnswer(
        question: 'জ্বরটা কতদিন ধরে হচ্ছে?',
        answer: 'জানা নাই',
        nextQuestion: 'তীব্রতা ১০-এর মধ্যে কত?',
      );
      expect(turn, contains('জানা নাই'));
      expect(turn, contains('অস্পষ্ট'));
    });

    test(
      'the opening line repeats the complaint before the first question',
      () {
        expect(
          openingAcknowledgement('আমার তিন দিন ধরে জ্বর'),
          contains('আমার তিন দিন ধরে জ্বর'),
        );
        expect(openingAcknowledgement('   '), contains('মনোযোগ'));
      },
    );
  });

  group('the doctor reads every answer', () {
    late AppDatabase db;
    late _OfflineAssistant assistant;
    late AssistantController controller;

    setUp(() async {
      db = await AppDatabase.openForTesting();
      assistant = _OfflineAssistant();
      controller = AssistantController(
        AssistantKnowledge(
          LearningRepository(LearningDao(db)),
          MedicineDao(db, pageSize: 5),
        ),
        assistant,
        AiDao(db),
      );
    });

    tearDown(() async => db.close());

    test('the first reply repeats the complaint and asks a question', () async {
      controller.draft.value = 'আমার তিন দিন ধরে জ্বর';
      expect(await controller.send(), isTrue);

      expect(controller.interviewActive.value, isTrue);
      final opening = controller.messages.last;
      expect(opening.role, 'assistant');
      expect(opening.text, contains('আমার তিন দিন ধরে জ্বর'));
      expect(opening.text, contains(controller.currentQuestion.value));
    });

    test('an answer is acknowledged and the interview moves on', () async {
      controller.draft.value = 'আমার তিন দিন ধরে জ্বর';
      await controller.send();
      final first = controller.currentQuestion.value;

      controller.draft.value = 'শরীর ১০১ ডিগ্রি হয়েছে, কাঁপুনি আছে';
      expect(await controller.send(), isTrue);

      final reply = controller.messages.last;
      expect(reply.role, 'assistant');
      // The reply quotes what the patient typed…
      expect(reply.text, contains('১০১ ডিগ্রি'));
      // …and still delivers the next scripted question.
      expect(reply.text, contains(controller.currentQuestion.value));
      expect(controller.currentQuestion.value, isNot(first));
      // Nothing was prescribed mid-interview.
      expect(reply.medicines, isEmpty);
      expect(reply.text, isNot(contains('প্রয়োজনীয় ঔষধ')));
    });

    test(
      'a message typed while the doctor is thinking is not swallowed',
      () async {
        controller.thinking.value = true;
        controller.draft.value = 'আমার আরেকটা লক্ষণ আছে';
        expect(await controller.send(), isFalse);
        expect(controller.draft.value, 'আমার আরেকটা লক্ষণ আছে');
        expect(controller.messages, isEmpty);
      },
    );
  });

  group('model requests carry the accumulated history', () {
    late AppDatabase db;
    late _RecordingAssistant assistant;
    late AssistantController controller;

    setUp(() async {
      db = await AppDatabase.openForTesting();
      assistant = _RecordingAssistant();
      controller = AssistantController(
        AssistantKnowledge(
          LearningRepository(LearningDao(db)),
          MedicineDao(db, pageSize: 5),
        ),
        assistant,
        AiDao(db),
      );
    });

    tearDown(() async => db.close());

    Future<void> answer(String text) async {
      controller.draft.value = text;
      await controller.send();
    }

    test(
      'each turn is an interview request ending on the fresh answer',
      () async {
        await answer('আমার তিন দিন ধরে জ্বর');
        expect(assistant.calls, isEmpty, reason: 'the greeting is local');

        const first = 'শরীর ১০১ ডিগ্রি হয়েছে';
        await answer(first);
        const second = 'সাথে মাথাব্যথাও আছে';
        await answer(second);

        expect(assistant.calls.length, 2);
        final firstCall = assistant.calls.first;
        expect(firstCall.mode, AssistantReplyMode.interview);
        expect(firstCall.query, first);
        expect(firstCall.scriptedQuestion, isNotNull);
        expect(firstCall.context, contains(first));
        // The complaint the patient typed, then the greeting that answered it.
        expect(firstCall.history.map((t) => t.role).toList(), [
          'user',
          'assistant',
        ]);
        expect(firstCall.history.first.text, 'আমার তিন দিন ধরে জ্বর');
        expect(firstCall.history.last.text, contains('আমার তিন দিন ধরে জ্বর'));

        // The second request reads the complaint, the greeting, then the
        // patient's first answer and the doctor's acknowledgement of it.
        final secondCall = assistant.calls.last;
        expect(secondCall.query, second);
        expect(secondCall.history.map((t) => t.role).toList(), [
          'user',
          'assistant',
          'user',
          'assistant',
        ]);
        expect(secondCall.history[2].text, first);
        expect(secondCall.history.last.text, contains('বুঝেছি'));
        // The scripted question is delivered even though the model left it out.
        expect(
          controller.messages.last.text,
          contains(secondCall.scriptedQuestion!),
        );
      },
    );

    test('the treatment plan is generated from the whole transcript', () async {
      await answer('আমার তিন দিন ধরে জ্বর');
      var guard = 0;
      while (controller.interviewActive.value && guard++ < 40) {
        await answer('হালকা, দুদিন ধরে');
      }
      expect(controller.interviewActive.value, isFalse);

      final planCall = assistant.calls.last;
      expect(planCall.mode, AssistantReplyMode.treatmentPlan);
      expect(planCall.query, contains('সাক্ষাৎকার সম্পন্ন হয়েছে'));
      expect(planCall.history.length, greaterThan(4));
      expect(planCall.history.first.text, contains('আমার তিন দিন ধরে জ্বর'));
      expect(planCall.history.last.role, 'user');
      expect(
        assistant.calls
            .where((c) => c.mode == AssistantReplyMode.treatmentPlan)
            .length,
        1,
      );
      // No question-mode call ever asked for a prescription.
      expect(
        assistant.calls
            .where((c) => c.mode == AssistantReplyMode.interview)
            .every((c) => c.scriptedQuestion != null),
        isTrue,
      );
    });
  });

  group('the interview cannot be skipped or short-changed', () {
    late AppDatabase db;
    late _RecordingAssistant assistant;
    late AssistantController controller;

    setUp(() async {
      db = await AppDatabase.openForTesting();
      assistant = _RecordingAssistant();
      controller = AssistantController(
        AssistantKnowledge(
          LearningRepository(LearningDao(db)),
          MedicineDao(db, pageSize: 5),
        ),
        assistant,
        AiDao(db),
      );
    });

    tearDown(() async => db.close());

    Future<void> answer(String text) async {
      controller.draft.value = text;
      await controller.send();
    }

    test(
      'a model that only asks on is made to acknowledge the answer',
      () async {
        assistant.answer = 'জ্বর মাপলে কত ডিগ্রি (Fahrenheit) হয়েছে?';
        await answer('আমার তিন দিন ধরে জ্বর');
        await answer('তিন দিন ধরে, রাতে বেশি হয়');

        final reply = controller.messages.last.text;
        // The patient's own words open the doctor's turn—nothing is skipped.
        expect(reply, startsWith('আপনি বলেছেন—“তিন দিন ধরে'));
        expect(reply, contains('তিন দিন ধরে, রাতে বেশি হয়'));
        // …and the question the patient must answer next is still delivered.
        expect(reply, contains(controller.currentQuestion.value));
      },
    );

    test('the window ends on the doctor’s question and never sends the answer twice', () async {
      await answer('আমার তিন দিন ধরে জ্বর');
      // A thread whose newest bubble is not the doctor's question (a restored
      // chat, a note that arrived in between) still carries the Q→A pair.
      controller.messages.add(
        const ChatTurn(role: 'user', text: 'আর একটা কথা'),
      );
      final asked = controller.currentQuestion.value;

      await answer('তিন দিন ধরে');
      final call = assistant.calls.last;
      expect(call.query, 'তিন দিন ধরে');
      expect(call.history.last.role, 'assistant');
      expect(call.history.last.text, asked);
      expect(
        call.history.where((turn) => turn.text == 'তিন দিন ধরে'),
        isEmpty,
        reason: 'the answer travels as the new message, not as history',
      );
    });

    test('a hurried patient is taken to the safety questions first', () async {
      await answer('আমার তিন দিন ধরে জ্বর');
      await answer('১০১ ডিগ্রি, টানা');
      await answer('সাথে মাথাব্যথা');
      await answer('পরামর্শ দাও');

      // Not finished: the safety basics are now the very next questions.
      expect(controller.interviewActive.value, isTrue);
      expect(
        kSafetyCriticalSlots,
        contains(slotOf(controller.currentQuestion.value)),
      );
      expect(controller.messages.last.text, contains('তাড়াহুড়ো'));
      expect(
        assistant.calls.where(
          (c) => c.mode == AssistantReplyMode.treatmentPlan,
        ),
        isEmpty,
      );
    });

    test('dodged safety answers cannot buy a confident prescription', () async {
      await answer('আমার তিন দিন ধরে জ্বর');
      var guard = 0;
      while (controller.interviewActive.value && guard++ < 60) {
        await answer('জানা নাই');
      }
      expect(controller.interviewActive.value, isFalse);
      expect(assistant.calls.last.mode, AssistantReplyMode.treatmentPlan);
      // Nothing was credited as answered, so the cautious closing is used and
      // the safety questions were put to the patient more than once.
      expect(controller.confidence.value, 0);
      expect(
        controller.messages.map((turn) => turn.text).join('\n'),
        contains('সাবধানী'),
      );
    });

    test('a quick reply keeps the answer already typed', () async {
      await answer('আমার তিন দিন ধরে জ্বর');
      controller.draft.value = 'রাতে বেশি হয়';
      await controller.answerQuickly('তিন দিন');
      expect(assistant.calls.last.query, 'রাতে বেশি হয় তিন দিন');
    });
  });

  group('request assembly', () {
    Future<List<Map<String, dynamic>>> sendAndCapture({
      required List<({String role, String text})> history,
      required AssistantReplyMode mode,
      String? scriptedQuestion,
    }) async {
      final bodies = <Map<String, dynamic>>[];
      final assistant = OxionAssistant(
        apiKey: 'test-key',
        baseUrl: 'https://example.test/v1',
        client: MockClient((request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'ঠিক আছে, বুঝেছি।'},
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final text = await assistant.reply(
        query: 'তিন দিন ধরে জ্বর',
        context: 'চলমান সাক্ষাৎকার',
        history: history,
        mode: mode,
        scriptedQuestion: scriptedQuestion,
      );
      expect(text, 'ঠিক আছে, বুঝেছি।');
      assistant.dispose();
      return (bodies.single['messages'] as List).cast<Map<String, dynamic>>();
    }

    test('system, history then the answer — in that order', () async {
      final messages = await sendAndCapture(
        history: const [
          (role: 'assistant', text: 'প্রশ্ন ১: কতদিন ধরে?'),
          (role: 'user', text: 'গতকাল থেকে'),
        ],
        mode: AssistantReplyMode.interview,
        scriptedQuestion: 'জ্বর মাপলে কত ডিগ্রি?',
      );

      expect(messages.map((m) => m['role']).toList(), [
        'system',
        'assistant',
        'user',
        'user',
      ]);
      expect(messages[1]['content'], 'প্রশ্ন ১: কতদিন ধরে?');
      expect(messages[2]['content'], 'গতকাল থেকে');
      expect(messages.last['content'], 'তিন দিন ধরে জ্বর');
    });

    test(
      'the interview persona must acknowledge, then ask, never prescribe',
      () async {
        final messages = await sendAndCapture(
          history: const [],
          mode: AssistantReplyMode.interview,
          scriptedQuestion: 'জ্বর মাপলে কত ডিগ্রি?',
        );
        final system = messages.first['content'] as String;
        expect(system, contains('শোনার নিয়ম'));
        expect(system, contains('স্বীকার করো'));
        expect(system, contains('জ্বর মাপলে কত ডিগ্রি?'));
        expect(system, contains('কোনো ঔষধের নাম, ডোজ'));
        // The prescribing directive must stay out of the interview turn.
        expect(system, isNot(contains('প্রতিটি ঔষধের পূর্ণ জ্ঞান দাও')));
      },
    );

    test('a long consultation is windowed, keeping the newest turns', () async {
      final history = <({String role, String text})>[
        for (var i = 0; i < 40; i++)
          (role: i.isEven ? 'user' : 'assistant', text: 'বার্তা $i'),
      ];
      final messages = await sendAndCapture(
        history: history,
        mode: AssistantReplyMode.consult,
      );
      expect(messages.length, AppConfig.assistantHistoryTurns + 2);
      expect(messages[1]['content'], 'বার্তা 16');
      expect(messages.last['content'], 'তিন দিন ধরে জ্বর');
    });
  });
}
