import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/learning_controller.dart';
import '../widgets/glass.dart';
import 'lesson_view.dart';
import 'lesson_quiz_view.dart';

class RevisionView extends StatelessWidget {
  const RevisionView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LearningController>();
    final scheme = Theme.of(context).colorScheme;

    return Obx(() {
      final pending = controller.revisionPendingList;

      return AppBackground(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('কুইজ ও রিভিশন'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // Hero Summary
              GlassCard(
                padding: const EdgeInsets.all(18),
                gradient: AppTheme.heroGradient(context),
                borderColor: Colors.white.withValues(alpha: 0.18),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.history_edu_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'স্মৃতি যাচাই ও রিভিশন',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'যেসব পাঠে পুনরায় অনুশীলন প্রয়োজন বা কুইজ বাকি আছে, সেগুলো এখানে তালিকাভুক্ত থাকে।',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Pending Revision List
              Row(
                children: [
                  Icon(
                    Icons.pending_actions_rounded,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'অসম্পূর্ণ বা রিভিশন অপেক্ষারত পাঠ (${pending.length}টি)',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (pending.isEmpty)
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 40,
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'দারুণ! কোনো অসম্পূর্ণ রিভিশন বাকি নেই।',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'নতুন কোনো কোর্স শুরু করে আপনার জ্ঞান সমৃদ্ধ করুন।',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final item in pending)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      onTap: () => Get.to(
                        () => LessonView(
                          courseId: item.course.id,
                          lessonId: item.lesson.id,
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.menu_book_rounded,
                              color: scheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.lesson.title,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  item.course.title,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              if (item.lesson.hasQuiz) {
                                Get.to(
                                  () => LessonQuizView(
                                    course: item.course,
                                    lesson: item.lesson,
                                  ),
                                );
                              } else {
                                Get.to(
                                  () => LessonView(
                                    courseId: item.course.id,
                                    lessonId: item.lesson.id,
                                  ),
                                );
                              }
                            },
                            child: Text(
                              item.lesson.hasQuiz
                                  ? 'কুইজ দিন'
                                  : 'পুনরায় পড়ুন',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

              const SizedBox(height: 20),

              // All Quizzes performance
              Row(
                children: [
                  Icon(Icons.quiz_outlined, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'কুইজ পারফরম্যান্স রেকর্ড',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (controller.bestResults.isEmpty)
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'এখনো কোনো কুইজ সম্পন্ন করা হয়নি। যেকোনো পাঠ শেষে কুইজ দিয়ে জ্ঞান যাচাই করুন।',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                )
              else
                for (final entry in controller.bestResults.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            (entry.value.score /
                                        (entry.value.total == 0
                                            ? 1
                                            : entry.value.total)) >=
                                    0.8
                                ? Icons.verified_rounded
                                : Icons.replay_rounded,
                            color:
                                (entry.value.score /
                                        (entry.value.total == 0
                                            ? 1
                                            : entry.value.total)) >=
                                    0.8
                                ? scheme.primary
                                : scheme.secondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entry.key.contains('::')
                                  ? 'পাঠ কুইজ: ${entry.key.split('::').last}'
                                  : 'কোর্স ফাইনাল কুইজ: ${entry.key}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            'নম্বর: ${entry.value.score}/${entry.value.total} (${((entry.value.score / (entry.value.total == 0 ? 1 : entry.value.total)) * 100).round()}%)',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      );
    });
  }
}
