import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/learning_controller.dart';
import '../core/format.dart';
import '../models/learning.dart';
import '../views/course_view.dart';
import 'glass.dart';
import 'learning_visuals.dart';

/// A clean, minimal course row used by the course library and subject detail.
/// No progress bar — only an unobtrusive completion check.
class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course, required this.controller});

  final Course course;
  final LearningController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = controller.completedIn(course);
    final lessons = course.lessons.length;
    final isDone = lessons > 0 && done >= lessons;

    return GlassCard(
      onTap: () => Get.to(() => CourseView(courseId: course.id)),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: .7),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              LearningVisuals.iconFor(course.icon),
              color: scheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  course.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${bn(lessons)}টি পাঠ'
                  '${course.quiz.isNotEmpty ? ' · ${bn(course.quiz.length)}টি কুইজ' : ''}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isDone)
            Icon(
              Icons.check_circle_rounded,
              color: scheme.primary,
              size: 20,
            )
          else
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant,
              size: 20,
            ),
        ],
      ),
    );
  }
}
