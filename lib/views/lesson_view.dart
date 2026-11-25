import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/learning_controller.dart';
import '../controllers/lesson_ai_controller.dart';
import '../core/format.dart';
import '../core/navigation_mode.dart';
import '../models/learning.dart';
import '../services/ai_learning_tools.dart';
import '../widgets/feedback.dart';
import '../widgets/glass.dart';
import '../widgets/html_content.dart';
import '../widgets/learning_visuals.dart';
import '../widgets/lesson_ask_ai_sheet.dart';
import '../widgets/medical_term_dialog.dart';
import '../widgets/safety_notice.dart';
import 'lesson_quiz_view.dart';

class LessonView extends StatefulWidget {
  const LessonView({super.key, required this.courseId, required this.lessonId});

  final String courseId;
  final String lessonId;

  @override
  State<LessonView> createState() => _LessonViewState();
}

class _LessonViewState extends State<LessonView> {
  /// Tag of this page's AI controller, so its summary and chat thread leave
  /// with the lesson instead of leaking into the next one.
  late final String _tag;

  @override
  void initState() {
    super.initState();
    _tag =
        'lesson-ai-${widget.courseId}-${widget.lessonId}-${identityHashCode(this)}';
    // Opening a lesson is what the reading history is built from — and the
    // history drives both the carousel and the easier-first rule.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Get.isRegistered<LearningController>()) {
        Get.find<LearningController>().markRead(
          widget.courseId,
          widget.lessonId,
        );
      }
    });
  }

  @override
  void dispose() {
    if (Get.isRegistered<LessonAiController>(tag: _tag)) {
      Get.delete<LessonAiController>(tag: _tag);
    }
    super.dispose();
  }

  /// Created lazily: the course and lesson objects only resolve once the
  /// catalogue has loaded.
  LessonAiController _ai(Course course, Lesson lesson) {
    if (Get.isRegistered<LessonAiController>(tag: _tag)) {
      return Get.find<LessonAiController>(tag: _tag);
    }
    final tools = Get.isRegistered<AiLearningTools>()
        ? Get.find<AiLearningTools>()
        : null;
    return Get.put(LessonAiController(course, lesson, tools), tag: _tag);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LearningController>();
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final course = controller.courses.firstWhereOrNull(
        (c) => c.id == widget.courseId,
      );
      final lesson = course?.lessons.firstWhereOrNull(
        (l) => l.id == widget.lessonId,
      );
      if (course == null || lesson == null) {
        return AppBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(title: const Text('পাঠ')),
            body: const EmptyState(
              title: 'পাঠটি পাওয়া যায়নি',
              icon: Icons.auto_stories_outlined,
            ),
          ),
        );
      }
      final completed = controller.isCompleted(course.id, lesson.id);
      final bookmarked = controller.isBookmarked(course.id, lesson.id);
      final ai = _ai(course, lesson);
      return AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(course.title, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: bookmarked ? 'বুকমার্ক সরান' : 'বুকমার্ক করুন',
                onPressed: () => controller.toggleBookmark(course, lesson),
                icon: Icon(
                  bookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              GestureNavigation.pageBottomPadding(
                context,
                additionalBuffer: 76,
              ),
            ),
            children: [
              _LessonHero(course: course, lesson: lesson),
              const SizedBox(height: 18),
              _AiSummaryCard(ai: ai),
              _SectionLabel(
                icon: Icons.article_outlined,
                text: 'বিস্তারিত পাঠ',
              ),
              const SizedBox(height: 8),
              if (lesson.hasContentBlocks)
                _StructuredContentBlocks(blocks: lesson.contentBlocks)
              else
                GlassCard(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: HtmlContent(
                    lesson.body,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(height: 1.75, color: scheme.onSurface),
                  ),
                ),
              if (lesson.keyPoints.isNotEmpty) ...[
                const SizedBox(height: 14),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 20,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'মনে রাখুন',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (final point in lesson.keyPoints)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 5),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  point,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(height: 1.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const SafetyNotice(),
              const SizedBox(height: 10),
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    if (lesson.hasQuiz) ...[
                      if (completed)
                        _LessonQuizStatusCard(course: course, lesson: lesson),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => Get.to(
                            () =>
                                LessonQuizView(course: course, lesson: lesson),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: completed
                                ? scheme.surfaceContainerHighest
                                : scheme.primary,
                            foregroundColor: completed
                                ? scheme.onSurfaceVariant
                                : scheme.onPrimary,
                          ),
                          icon: const Icon(Icons.quiz_rounded),
                          label: Text(
                            completed
                                ? 'আবার কুইজ দিয়ে দেখুন'
                                : 'কুইজ দিন ও পাঠ সম্পূর্ণ করুন',
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${bn(lesson.quiz.length)}টি প্রশ্ন · '
                        '${bn((controller.effectivePassRatio(course, lesson) * 100).round())}%+ সঠিক হলে পাঠ সম্পূর্ণ হবে।',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () =>
                              controller.toggleCompleted(course, lesson),
                          style: FilledButton.styleFrom(
                            backgroundColor: completed
                                ? scheme.surfaceContainerHighest
                                : scheme.primary,
                            foregroundColor: completed
                                ? scheme.onSurfaceVariant
                                : scheme.onPrimary,
                          ),
                          icon: Icon(
                            completed
                                ? Icons.check_circle_rounded
                                : Icons.check_circle_outline_rounded,
                          ),
                          label: Text(
                            completed
                                ? 'সম্পূর্ণ হিসেবে চিহ্নিত'
                                : 'পাঠ সম্পূর্ণ করুন',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => showLessonAskAiSheet(context, ai),
                        icon: const Icon(Icons.forum_outlined),
                        label: const Text('AI-এর কাছে এই পাঠ নিয়ে জানুন'),
                      ),
                    ),
                  ],
                ),
              ),
              if (course.lessons.length > 1) ...[
                const SizedBox(height: 10),
                _NextLesson(course: course, lesson: lesson),
              ],
            ],
          ),
          // The lesson question is always one thumb away, however far down
          // the reader has scrolled.
          floatingActionButton: Padding(
            padding: EdgeInsets.only(
              bottom: GestureNavigation.gestureBarHeight(context) + 8,
            ),
            child: FloatingActionButton.extended(
              onPressed: () => showLessonAskAiSheet(context, ai),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('AI-এ জিজ্ঞাসা'),
            ),
          ),
        ),
      );
    });
  }
}

class _LessonHero extends StatelessWidget {
  const _LessonHero({required this.course, required this.lesson});

  final Course course;
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final index = course.lessons.indexWhere((l) => l.id == lesson.id) + 1;
    final completed = Get.find<LearningController>().isCompleted(
      course.id,
      lesson.id,
    );
    return GlassCard(
      padding: const EdgeInsets.all(18),
      gradient: AppTheme.heroGradient(context),
      borderColor: Colors.white.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(
                  LearningVisuals.iconFor(course.icon),
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'পাঠ ${bn(index)} / ${bn(course.lessons.length)} · '
                  '${bn(lesson.minutes)} মিনিট',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (completed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'সম্পন্ন',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            lesson.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            lesson.summary,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// The AI's 3–5 bullet digest of a long lesson, kept above the body so the
/// reader knows where the text is going before wading into it. Rendered only
/// when there is something to show, so a short lesson stays uncluttered.
class _AiSummaryCard extends StatelessWidget {
  const _AiSummaryCard({required this.ai});

  final LessonAiController ai;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Obx(() {
      final bullets = [
        for (final line in ai.summary.value.split('\n'))
          if (line.trim().isNotEmpty)
            line.replaceFirst(RegExp(r'^[•\-]\s*'), ''),
      ];
      if (!ai.isLong) return const SizedBox.shrink();
      if (bullets.isEmpty &&
          !ai.summarizing.value &&
          ai.summaryError.value.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: GlassCard(
          color: scheme.primaryContainer.withValues(alpha: 0.26),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'সংক্ষিপ্ত সারক',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (ai.summaryCached.value)
                    Icon(
                      Icons.offline_bolt_rounded,
                      size: 15,
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (ai.summarizing.value && bullets.isEmpty)
                Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'AI এই পাঠটি পড়ে সারক লিখছে…',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                )
              else if (bullets.isNotEmpty)
                for (final point in bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            point,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ai.summaryError.value,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: ai.loadSummary,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('আবার চেষ্টা'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _LessonQuizStatusCard extends StatelessWidget {
  const _LessonQuizStatusCard({required this.course, required this.lesson});

  final Course course;
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = Get.find<LearningController>();
    final best = controller.lessonBest(course.id, lesson.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'পাঠ সম্পূর্ণ — কুইজে পাস${best == null || best.total == 0 ? '' : ' (${bn(best.score)}/${bn(best.total)})'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextLesson extends StatelessWidget {
  const _NextLesson({required this.course, required this.lesson});

  final Course course;
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final index = course.lessons.indexWhere((l) => l.id == lesson.id);
    final prev = index > 0 ? course.lessons[index - 1] : null;
    final next = index >= 0 && index + 1 < course.lessons.length
        ? course.lessons[index + 1]
        : null;

    if (prev == null && next == null) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          children: [
            if (prev != null)
              Expanded(
                child: GlassCard(
                  onTap: () => Get.off(
                    () => LessonView(courseId: course.id, lessonId: prev.id),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.arrow_back_rounded,
                        size: 16,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'পূর্ববর্তী পাঠ',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                            ),
                            Text(
                              prev.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (prev != null && next != null) const SizedBox(width: 8),
            if (next != null)
              Expanded(
                child: GlassCard(
                  onTap: () => Get.off(
                    () => LessonView(courseId: course.id, lessonId: next.id),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'পরের পাঠ',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                            ),
                            Text(
                              next.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StructuredContentBlocks extends StatelessWidget {
  const _StructuredContentBlocks({required this.blocks});

  final List<ContentBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: switch (block.type) {
              ContentBlockType.heading => Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text(
                  block.title ?? block.content,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ),
              ContentBlockType.paragraph => GlassCard(
                padding: const EdgeInsets.all(16),
                child: Text(
                  block.content,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(height: 1.65, color: scheme.onSurface),
                ),
              ),
              ContentBlockType.bulletList => GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (block.title != null) ...[
                      Text(
                        block.title!,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                    ],
                    for (final item in block.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              ContentBlockType.numberedList => GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (block.title != null) ...[
                      Text(
                        block.title!,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                    ],
                    for (var i = 0; i < block.items.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                bn(i + 1),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: scheme.primary,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                block.items[i],
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              ContentBlockType.medicalTerm =>
                block.term != null
                    ? GlassCard(
                        onTap: () => showMedicalTermSheet(context, block.term!),
                        padding: const EdgeInsets.all(14),
                        borderColor: scheme.primary.withValues(alpha: 0.3),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.spellcheck_rounded,
                                color: scheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          block.term!.termBn,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          '(${block.term!.termEn})',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(color: scheme.primary),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    block.term!.simpleExplanationBn.isNotEmpty
                                        ? block.term!.simpleExplanationBn
                                        : block.term!.definitionBn,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.info_outline_rounded, size: 18),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ContentBlockType.comparisonTable => GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (block.title != null) ...[
                      Text(
                        block.title!,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Table(
                        defaultColumnWidth: const IntrinsicColumnWidth(),
                        border: TableBorder.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        children: [
                          if (block.tableHeaders.isNotEmpty)
                            TableRow(
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHigh,
                              ),
                              children: [
                                for (final h in block.tableHeaders)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      h,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: scheme.onSurface,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          for (final row in block.tableRows)
                            TableRow(
                              children: [
                                for (final cell in row)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      cell,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ContentBlockType.safetyNotice ||
              ContentBlockType.warning => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:
                      (block.severity == 'danger'
                              ? scheme.error
                              : block.severity == 'warning'
                              ? scheme.secondary
                              : scheme.primary)
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                  border: Border.all(
                    color:
                        (block.severity == 'danger'
                                ? scheme.error
                                : block.severity == 'warning'
                                ? scheme.secondary
                                : scheme.primary)
                            .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      block.severity == 'danger'
                          ? Icons.dangerous_outlined
                          : Icons.warning_amber_rounded,
                      color: block.severity == 'danger'
                          ? scheme.error
                          : scheme.secondary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (block.title != null) ...[
                            Text(
                              block.title!,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: block.severity == 'danger'
                                        ? scheme.error
                                        : scheme.secondary,
                                  ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            block.content,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ContentBlockType.clinicalCase => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.medical_information_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          block.title ?? 'ক্লিনিক্যাল সিনারিও',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.primary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      block.content,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(height: 1.6),
                    ),
                  ],
                ),
              ),
              _ => GlassCard(
                padding: const EdgeInsets.all(16),
                child: Text(
                  block.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            },
          ),
      ],
    );
  }
}
