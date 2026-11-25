import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/learning_controller.dart';
import '../core/format.dart';
import '../core/navigation_mode.dart';
import '../models/learning.dart';
import '../widgets/course_card.dart';
import '../widgets/feedback.dart';
import '../widgets/glass.dart';
import '../widgets/safety_notice.dart';

/// Clean subject page: subtopics, an educational indication guide (where
/// relevant) and every course filed under this subject.
class SubjectDetailView extends StatelessWidget {
  const SubjectDetailView({super.key, required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LearningController>();
    final subject = controller.subjects.firstWhereOrNull(
      (s) => s.id == subjectId,
    );
    if (subject == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('বিষয়')),
        body: const Center(
          child: EmptyState(
            title: 'বিষয়টি পাওয়া যায়নি',
            icon: Icons.menu_book_outlined,
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final courses = controller.courses.where(subject.matches).toList();

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(subject.titleBn),
        leading: IconButton(
          tooltip: 'ফিরে যান',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: GestureNavigation.shellContentBottomPadding(context),
        ),
        children: [
          Text(
            subject.descriptionBn,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          const SafetyNotice(dense: true),

          if (subject.subtopics.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(
              'উপবিষয়',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final subtopic in subject.subtopics)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      subtopic,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],

          if (subject.indications.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(
              'কোন অবস্থায় কোন গ্রুপ',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'শিক্ষামূলক গাইড — চিকিৎসকের পরামর্শের বিকল্প নয়।',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            for (final indication in subject.indications) ...[
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      indication.condition,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.medication_outlined,
                          size: 16,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            indication.group,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (indication.note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        indication.note,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],

          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'এই বিষয়ের কোর্স',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${bn(courses.length)}টি',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (courses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: EmptyState(
                title: 'এই বিষয়ে এখনো কোর্স নেই',
                icon: Icons.school_outlined,
              ),
            )
          else
            for (final course in courses) ...[
              CourseCard(course: course, controller: controller),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}
