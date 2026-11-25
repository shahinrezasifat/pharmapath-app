import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/learning_controller.dart';
import '../models/learning.dart';
import '../widgets/feedback.dart';
import '../widgets/glass.dart';
import '../widgets/learning_visuals.dart';
import 'course_view.dart';
import 'disease_topic_view.dart';

class BodySystemView extends StatelessWidget {
  const BodySystemView({super.key, required this.systemId});

  final String systemId;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LearningController>();
    final scheme = Theme.of(context).colorScheme;

    return Obx(() {
      final system = controller.bodySystems.firstWhereOrNull(
        (s) => s.id == systemId,
      );
      if (system == null) {
        return AppBackground(
          child: Scaffold(
            appBar: AppBar(title: const Text('অঙ্গতন্ত্র')),
            body: const EmptyState(
              title: 'অঙ্গতন্ত্রের তথ্য পাওয়া যায়নি',
              icon: Icons.accessibility_new_outlined,
            ),
          ),
        );
      }

      // The catalogue declares which guides open this region, organ or
      // condition class; the old keyword guess used to mix unrelated courses in.
      final relatedCourses = system.relatedCourseIds
          .map((id) => controller.courses.firstWhereOrNull((c) => c.id == id))
          .whereType<Course>()
          .toList();

      final relatedTopics = controller.diseaseTopics
          .where((t) => t.bodySystemId == system.id)
          .toList();

      return AppBackground(
        child: Scaffold(
          appBar: AppBar(title: Text(system.nameBn)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // Hero
              GlassCard(
                padding: const EdgeInsets.all(18),
                gradient: AppTheme.heroGradient(context),
                borderColor: Colors.white.withValues(alpha: 0.18),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        LearningVisuals.iconFor(system.iconKey),
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
                            system.nameBn,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            system.nameEn,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            system.descriptionBn,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Body Parts
              if (system.bodyParts.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.hub_outlined, size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'সংশ্লিষ্ট অঙ্গসমূহ (Body Parts)',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final part in system.bodyParts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.circle_outlined,
                              size: 16,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  part.nameBn,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  '${part.nameEn} — ${part.description}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
              ],

              // Disease Topics
              if (relatedTopics.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.healing_outlined,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'রোগ ও ক্লিনিক্যাল টপিক',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final topic in relatedTopics)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      onTap: () =>
                          Get.to(() => DiseaseTopicView(topicId: topic.id)),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.medical_information_outlined,
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
                                  topic.titleBn,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  topic.titleEn,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
              ],

              // Associated Courses
              Row(
                children: [
                  Icon(Icons.school_outlined, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'প্রাসঙ্গিক শিক্ষামূলক কোর্স',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (relatedCourses.isEmpty)
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'এই অঙ্গতন্ত্রের জন্য শীঘ্রই আরও বিস্তারিত কোর্স সংযুক্ত করা হচ্ছে।',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                )
              else
                for (final course in relatedCourses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      onTap: () =>
                          Get.to(() => CourseView(courseId: course.id)),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
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
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  '${course.lessons.length}টি পাঠ · ${course.subtitle}',
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
                          const Icon(Icons.chevron_right_rounded),
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
