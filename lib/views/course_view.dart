import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/learning_controller.dart';
import '../core/format.dart';
import '../models/learning.dart';
import '../widgets/feedback.dart';
import '../widgets/glass.dart';
import '../widgets/learning_visuals.dart';
import 'lesson_view.dart';
import 'quiz_view.dart';

class CourseView extends StatelessWidget {
  const CourseView({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LearningController>();
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final course = controller.courses.firstWhereOrNull(
        (c) => c.id == courseId,
      );
      if (course == null) {
        return AppBackground(
          child: Scaffold(
            appBar: AppBar(title: const Text('কোর্স')),
            body: const EmptyState(
              title: 'কোর্সটি পাওয়া যায়নি',
              icon: Icons.auto_stories_outlined,
            ),
          ),
        );
      }
      final done = controller.completedIn(course);
      final total = course.lessons.length;
      final progress = total == 0 ? 0.0 : done / total;
      final best = controller.bestResults[course.id];
      final passed = controller.isPassed(course.id);
      return AppBackground(
        child: Scaffold(
          appBar: AppBar(title: Text(course.title)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              GlassCard(
                padding: const EdgeInsets.all(18),
                gradient: AppTheme.heroGradient(context),
                borderColor: Colors.white.withValues(alpha: 0.18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Icon(
                            LearningVisuals.iconFor(course.icon),
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course.subtitle,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.92,
                                      ),
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${bn(total)}টি পাঠ · ${bn(course.quiz.length)}টি কুইজ',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Text(
                          '${bn(done)}/${bn(total)} সম্পূর্ণ',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const Spacer(),
                        Text(
                          '${bn((progress * 100).round())}%',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_outlined, size: 18),
                    const SizedBox(width: 7),
                    Text(
                      'পাঠসমূহ',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    Text(
                      'অগ্রগতি ডিভাইসে সংরক্ষিত',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < course.lessons.length; i++)
                _LessonTile(
                  course: course,
                  lesson: course.lessons[i],
                  index: i + 1,
                  controller: controller,
                ),
              if (course.quiz.isNotEmpty) ...[
                const SectionTitle(
                  title: 'অনুশীলন কুইজ',
                  padding: EdgeInsets.fromLTRB(4, 20, 4, 8),
                ),
                GlassCard(
                  onTap: () => Get.to(() => QuizView(courseId: course.id)),
                  padding: const EdgeInsets.all(16),
                  color: AppTheme.isDark(context)
                      ? scheme.surfaceContainerHigh
                      : scheme.primaryContainer,
                  child: Row(
                    children: [
                      GradientIcon(
                        icon: Icons.quiz_rounded,
                        colors: LearningVisuals.colorsFor('science'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              passed
                                  ? 'কুইজে পাস করেছেন'
                                  : '${bn(course.quiz.length)}টি প্রশ্নে নিজেকে যাচাই করুন',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              best == null || best.total == 0
                                  ? 'শুরু করুন · পাসের জন্য ${bn((LearningController.passRatio * 100).round())}% দরকার'
                                  : 'সেরা ফল: ${bn(best.score)}/${bn(best.total)}'
                                        '${passed ? ' · পাস' : ' · আবার চেষ্টা করুন'}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.course,
    required this.lesson,
    required this.index,
    required this.controller,
  });

  final Course course;
  final Lesson lesson;
  final int index;
  final LearningController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final completed = controller.isCompleted(course.id, lesson.id);
    final bookmarked = controller.isBookmarked(course.id, lesson.id);
    final best = controller.lessonBest(course.id, lesson.id);
    final quizLabel = best == null || best.total == 0
        ? (lesson.hasQuiz ? ' · কুইজ বাকি' : '')
        : completed
        ? ' · কুইজ ${bn(best.score)}/${bn(best.total)} ✓'
        : ' · কুইজ ${bn(best.score)}/${bn(best.total)} — আবার দিন';
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      onTap: () =>
          Get.to(() => LessonView(courseId: course.id, lessonId: lesson.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: completed
                    ? LinearGradient(
                        colors: [
                          scheme.primary,
                          scheme.primary.withValues(alpha: 0.75),
                        ],
                      )
                    : null,
                color: completed ? null : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(13),
              ),
              child: completed
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 20,
                    )
                  : Center(
                      child: Text(
                        bn(index),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: completed ? scheme.onSurface : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${bn(lesson.minutes)} মিনিট$quizLabel'
                    '${bookmarked ? ' · বুকমার্ক' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: completed
                          ? scheme.onSurfaceVariant
                          : best != null && best.total > 0 && !completed
                          ? scheme.tertiary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              bookmarked ? Icons.bookmark_rounded : Icons.chevron_right_rounded,
              size: 20,
              color: bookmarked ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
