import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/learning_controller.dart';
import '../core/format.dart';
import '../models/learning.dart';
import '../widgets/glass.dart';
import '../widgets/learning_visuals.dart';
import 'lesson_view.dart';

/// The mini-quiz that gates a single lesson. Passing marks the lesson
/// completed; failing reverts it to incomplete and shows exactly which
/// questions went wrong so the user can re-read and retry.
class LessonQuizView extends StatefulWidget {
  const LessonQuizView({super.key, required this.course, required this.lesson});

  final Course course;
  final Lesson lesson;

  @override
  State<LessonQuizView> createState() => _LessonQuizViewState();
}

class _LessonQuizViewState extends State<LessonQuizView> {
  late final List<int?> _answers = List<int?>.filled(
    widget.lesson.quiz.length,
    null,
  );
  bool _submitted = false;
  bool _saving = false;

  List<QuizQuestion> get _questions => widget.lesson.quiz;

  int get _score {
    var score = 0;
    for (var i = 0; i < _questions.length; i++) {
      if (_answers[i] == _questions[i].answer) score++;
    }
    return score;
  }

  double get _threshold =>
      Get.find<LearningController>().effectivePassRatio(widget.course, widget.lesson);

  bool get _passed =>
      _questions.isNotEmpty && _score / _questions.length >= _threshold;

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _saving = true;
    });
    await Get.find<LearningController>().submitLessonQuiz(
      widget.course,
      widget.lesson,
      _score,
      _questions.length,
    );
    if (!mounted) return;
    setState(() => _saving = false);
  }

  void _retry() {
    setState(() {
      _submitted = false;
      for (var i = 0; i < _answers.length; i++) {
        _answers[i] = null;
      }
    });
  }

  void _openNextLesson() {
    final index = widget.course.lessons.indexWhere(
      (l) => l.id == widget.lesson.id,
    );
    if (index >= 0 && index + 1 < widget.course.lessons.length) {
      Get.off(
        () => LessonView(
          courseId: widget.course.id,
          lessonId: widget.course.lessons[index + 1].id,
        ),
        duration: const Duration(milliseconds: 220),
      );
    } else {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final answered = _answers.where((a) => a != null).length;
    return AppBackground(
      child: Scaffold(
        appBar: AppBar(title: Text('${widget.lesson.title} · কুইজ')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            if (_submitted)
              _ResultBanner(
                passed: _passed,
                score: _score,
                total: _questions.length,
                lessonTitle: widget.lesson.title,
              )
            else
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    GradientIcon(
                      icon: Icons.quiz_rounded,
                      colors: LearningVisuals.colorsFor(
                        widget.course.icon,
                        dark: AppTheme.isDark(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'পাঠ শেষ? এখন যাচাই করুন',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${bn(_questions.length)}টি প্রশ্ন · '
                            'পাস ${bn((_threshold * 100).round())}% · '
                            'পাস করলে পাঠ সম্পূর্ণ হবে',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            for (var i = 0; i < _questions.length; i++)
              _QuizQuestionCard(
                index: i,
                question: _questions[i],
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
                        ? _passed
                              ? FilledButton.icon(
                                  onPressed: () => Get.back(),
                                  icon: const Icon(Icons.check_circle_rounded),
                                  label: const Text('পাঠে ফিরে যান'),
                                )
                              : FilledButton.icon(
                                  onPressed: _retry,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('আবার চেষ্টা করুন'),
                                )
                        : FilledButton(
                            onPressed: answered == _questions.length && !_saving
                                ? _submit
                                : null,
                            child: Text(
                              _saving
                                  ? 'সংরক্ষণ হচ্ছে…'
                                  : 'উত্তর জমা দিন (${bn(answered)}/${bn(_questions.length)})',
                            ),
                          ),
                  ),
                  if (_submitted && _passed) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openNextLesson,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('পরের পাঠে যান'),
                      ),
                    ),
                  ],
                  if (!_submitted && answered < _questions.length) ...[
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
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    required this.passed,
    required this.score,
    required this.total,
    required this.lessonTitle,
  });

  final bool passed;
  final int score;
  final int total;
  final String lessonTitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      gradient: passed ? AppTheme.heroGradient(context) : null,
      color: passed ? null : scheme.errorContainer,
      borderColor: passed
          ? Colors.white.withValues(alpha: 0.18)
          : scheme.error.withValues(alpha: 0.4),
      child: Row(
        children: [
          Icon(
            passed ? Icons.verified_rounded : Icons.replay_rounded,
            size: 30,
            color: passed ? Colors.white : scheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passed
                      ? 'অভিনন্দন! পাঠ সম্পূর্ণ হয়েছে'
                      : 'এখনো সম্পূর্ণ হয়নি — আবার পড়ুন',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: passed ? Colors.white : scheme.onErrorContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$lessonTitle · সঠিক ${bn(score)}/${bn(total)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: passed
                        ? Colors.white.withValues(alpha: 0.9)
                        : scheme.onErrorContainer,
                  ),
                ),
                if (!passed) ...[
                  const SizedBox(height: 2),
                  Text(
                    'নিচে ভুল করা প্রশ্নগুলো দেখে নিন, পাঠ আবার পড়ে '
                    'আবার চেষ্টা করুন।',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: passed
                          ? Colors.white.withValues(alpha: 0.9)
                          : scheme.onErrorContainer,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizQuestionCard extends StatelessWidget {
  const _QuizQuestionCard({
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wrong = submitted && selected != question.answer;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      borderColor: wrong ? scheme.error.withValues(alpha: 0.5) : null,
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
                  color: wrong
                      ? scheme.error.withValues(alpha: 0.12)
                      : scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  bn(index + 1),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: wrong ? scheme.error : scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                wrong ? 'ভুল হয়েছে — আবার পড়ুন' : 'প্রশ্ন ${bn(index + 1)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: wrong ? scheme.error : scheme.onSurfaceVariant,
                  fontWeight: wrong ? FontWeight.w700 : null,
                ),
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
                color: wrong
                    ? scheme.errorContainer.withValues(alpha: 0.45)
                    : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${wrong ? 'সঠিক উত্তর: ${question.options[question.answer]}। ' : 'সঠিক। '}'
                '${question.explanation}',
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
