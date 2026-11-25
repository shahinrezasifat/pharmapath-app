import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/learning_controller.dart';
import '../core/format.dart';
import '../models/learning.dart';
import '../widgets/feedback.dart';
import '../widgets/glass.dart';

class QuizView extends StatefulWidget {
  const QuizView({super.key, required this.courseId});

  final String courseId;

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  final Map<int, int> _answers = {};
  bool _submitted = false;
  int _score = 0;

  void _reset() {
    setState(() {
      _answers.clear();
      _submitted = false;
      _score = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LearningController>();
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final course = controller.courses.firstWhereOrNull(
        (c) => c.id == widget.courseId,
      );
      if (course == null) {
        return AppBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: const Text('কুইজ')),
            body: const EmptyState(
              title: 'কুইজ পাওয়া যায়নি',
              icon: Icons.quiz_outlined,
            ),
          ),
        );
      }
      final questions = course.quiz;
      final answered = _answers.length;
      final progress = questions.isEmpty ? 0.0 : answered / questions.length;
      final threshold = controller.effectivePassRatio(course);
      final passed =
          questions.isNotEmpty && _score / questions.length >= threshold;
      return AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text('${course.title} · কুইজ'),
            actions: [
              if (_submitted)
                IconButton(
                  tooltip: 'আবার শুরু',
                  onPressed: _reset,
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
              const SizedBox(width: 6),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              if (_submitted)
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  gradient: AppTheme.heroGradient(context),
                  borderColor: Colors.white.withValues(alpha: 0.18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GradientIcon(
                            icon: passed
                                ? Icons.verified_rounded
                                : Icons.replay_rounded,
                            colors: passed
                                ? [scheme.primary, scheme.secondary]
                                : [scheme.secondary, scheme.tertiary],
                            size: 46,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  passed
                                      ? 'অভিনন্দন, আপনি পাস করেছেন!'
                                      : 'আরেকটু চেষ্টা করুন',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                Text(
                                  '${bn(_score)} / ${bn(questions.length)} সঠিক · '
                                  '${bn(questions.isEmpty ? 0 : ((_score / questions.length) * 100).round())}%',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.92,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: questions.isEmpty
                              ? 0
                              : _score / questions.length,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          valueColor: AlwaysStoppedAnimation(
                            passed ? scheme.primary : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        passed
                            ? 'পাসের নিয়ম ${bn((threshold * 100).round())}% · ফলাফল এই ডিভাইসে সংরক্ষিত হয়েছে।'
                            : 'পাসের জন্য ${bn((threshold * 100).round())}% দরকার। নিচের ব্যাখ্যা পড়ে আবার চেষ্টা করুন।',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                )
              else
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GradientIcon(icon: Icons.quiz_rounded, size: 42),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${bn(questions.length)}টি প্রশ্ন',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  'প্রতিটি প্রশ্নের একটি সঠিক উত্তর',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${bn(answered)}/${bn(questions.length)}',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              for (var i = 0; i < questions.length; i++)
                _QuestionCard(
                  index: i,
                  question: questions[i],
                  selected: _answers[i],
                  submitted: _submitted,
                  onSelect: (value) => setState(() => _answers[i] = value),
                ),
              const SizedBox(height: 14),
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: _submitted
                          ? FilledButton.icon(
                              onPressed: _reset,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('আবার চেষ্টা করুন'),
                            )
                          : FilledButton(
                              onPressed: _answers.length == questions.length
                                  ? () => _submit(controller, questions)
                                  : null,
                              child: Text(
                                'জমা দিন (${bn(_answers.length)}/${bn(questions.length)})',
                              ),
                            ),
                    ),
                    if (!_submitted) ...[
                      const SizedBox(height: 8),
                      Text(
                        'সব প্রশ্নের উত্তর দিলে জমা দেওয়ার বোতাম চালু হবে।',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _submit(LearningController controller, List<QuizQuestion> questions) {
    var score = 0;
    for (var i = 0; i < questions.length; i++) {
      if (_answers[i] == questions[i].answer) score++;
    }
    setState(() {
      _score = score;
      _submitted = true;
    });
    controller.saveQuiz(widget.courseId, score, questions.length);
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.selected,
    required this.submitted,
    required this.onSelect,
  });

  final int index;
  final QuizQuestion question;
  final int? selected;
  final bool submitted;
  final ValueChanged<int> onSelect;

  /// Malformed imported quizzes can carry an out-of-range answer index; never
  /// let the explanation row crash the whole quiz because of one bad row.
  String _correctOption(QuizQuestion question) {
    final i = question.answer;
    if (i >= 0 && i < question.options.length) return question.options[i];
    return 'সঠিক উত্তর পাওয়া যায়নি';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  bn(index + 1),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'প্রশ্ন ${bn(index + 1)}',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            question.question,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700, height: 1.5),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < question.options.length; i++)
            _OptionTile(
              text: question.options[i],
              selected: selected == i,
              correct: submitted && i == question.answer,
              wrong: submitted && selected == i && i != question.answer,
              onTap: submitted ? null : () => onSelect(i),
            ),
          if (submitted) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${selected == question.answer ? 'সঠিক।' : 'সঠিক উত্তর: ${_correctOption(question)}।'} ${question.explanation}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(height: 1.55),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.text,
    required this.selected,
    required this.correct,
    required this.wrong,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final bool correct;
  final bool wrong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = correct
        ? scheme.primary
        : wrong
        ? scheme.error
        : selected
        ? scheme.primary
        : scheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: color,
              width: selected || correct || wrong ? 1.5 : 1,
            ),
            color: selected || correct || wrong
                ? color.withValues(alpha: 0.08)
                : scheme.surfaceContainerLow,
          ),
          child: Row(
            children: [
              Icon(
                correct
                    ? Icons.check_circle_rounded
                    : wrong
                    ? Icons.cancel_rounded
                    : selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 19,
                color: color,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
