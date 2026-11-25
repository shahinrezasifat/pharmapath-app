import 'dart:async';

import 'package:get/get.dart';

import '../core/app_config.dart';
import '../core/json_utils.dart' show stripHtml;
import '../models/learning.dart';
import '../services/ai_learning_tools.dart';

/// One line inside the lesson mini-chat: whose turn it was and what was said.
typedef LessonChatTurn = ({String role, String text});

/// Per-lesson AI state: the smart summary above the body, and the short
/// question-and-answer thread opened by "AI-এ জিজ্ঞাসা করুন".
///
/// A controller exists for the lifetime of one lesson page (tagged by
/// `course::lesson`), so its thread and cached summary are dropped when the
/// reader moves to another lesson instead of accumulating for the session.
class LessonAiController extends GetxController {
  LessonAiController(this.course, this.lesson, [this._tools]);

  final Course course;
  final Lesson lesson;
  final AiLearningTools? _tools;

  final RxString summary = ''.obs;
  final RxBool summarizing = false.obs;

  /// True when [summary] came from the local cache rather than the cloud.
  final RxBool summaryCached = false.obs;

  /// Bangla notice shown in place of the summary when it could not be made.
  final RxString summaryError = ''.obs;

  final RxList<LessonChatTurn> chat = <LessonChatTurn>[].obs;
  final RxBool answering = false.obs;
  final RxString chatError = ''.obs;

  /// Only long lessons earn a summary — a short one's own intro already is
  /// one, and asking the model would just burn tokens repeating it.
  bool get isLong =>
      stripHtml(lesson.body).trim().length >= AppConfig.learningSummaryMinChars;

  bool get hasChat => chat.isNotEmpty;

  /// False on slim builds or tests where no AI helper was injected, so the
  /// mini-chat can say so instead of silently swallowing the question.
  bool get hasAssistant => _tools != null;

  @override
  void onInit() {
    super.onInit();
    unawaited(
      Future.microtask(
        () => loadSummary().catchError((Object error) {
          summaryError.value = 'সারাংশ আনা যায়নি। আবার চেষ্টা করুন।';
        }),
      ),
    );
  }

  /// Fill [summary] from the cache first, so reopening a lesson is instant and
  /// works without a network.
  Future<void> loadSummary() async {
    final tools = _tools;
    if (tools == null || !isLong) return;
    summarizing.value = true;
    try {
      final answer = await tools.summarizeLesson(course, lesson);
      summary.value = answer.text;
      summaryCached.value = answer.cached;
      summaryError.value = answer.ok ? '' : answer.error;
    } finally {
      summarizing.value = false;
    }
  }

  /// Asks the lesson tutor and appends both sides of the exchange. A failure
  /// keeps the question visible with a Bangla notice, so the reader can retry.
  Future<void> ask(String question) async {
    final text = question.trim();
    if (text.isEmpty || answering.value) return;
    chat.add((role: 'user', text: text));
    chatError.value = '';
    final tools = _tools;
    if (tools == null) {
      chatError.value = AiLearningTools.offlineNotice;
      return;
    }
    answering.value = true;
    try {
      final answer = await tools.askAboutLesson(
        course: course,
        lesson: lesson,
        question: text,
        history: chat.toList(),
      );
      if (answer.ok) {
        chat.add((role: 'ai', text: answer.text));
      } else {
        chatError.value = answer.error.isEmpty
            ? AiLearningTools.offlineNotice
            : answer.error;
      }
    } finally {
      answering.value = false;
    }
  }

  void clearChat() {
    chat.clear();
    chatError.value = '';
  }
}
