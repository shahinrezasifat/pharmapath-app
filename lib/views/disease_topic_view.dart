import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/learning_controller.dart';
import '../models/learning.dart';
import '../widgets/feedback.dart';
import '../widgets/glass.dart';
import 'course_view.dart';

class DiseaseTopicView extends StatelessWidget {
  const DiseaseTopicView({super.key, required this.topicId});

  final String topicId;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LearningController>();
    final scheme = Theme.of(context).colorScheme;

    return Obx(() {
      final topic = controller.diseaseTopics.firstWhereOrNull(
        (t) => t.id == topicId,
      );
      if (topic == null) {
        return AppBackground(
          child: Scaffold(
            appBar: AppBar(title: const Text('রোগ ও স্বাস্থ্যসমস্যা')),
            body: const EmptyState(
              title: 'রোগের তথ্য পাওয়া যায়নি',
              icon: Icons.medical_services_outlined,
            ),
          ),
        );
      }

      final associatedCourse = topic.courseId != null
          ? controller.courses.firstWhereOrNull((c) => c.id == topic.courseId)
          : null;

      return AppBackground(
        child: Scaffold(
          appBar: AppBar(
            title: Text(topic.titleBn),
            actions: [
              if (associatedCourse != null)
                TextButton.icon(
                  onPressed: () =>
                      Get.to(() => CourseView(courseId: associatedCourse.id)),
                  icon: const Icon(Icons.school_outlined, size: 18),
                  label: const Text('কোর্সে যান'),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // Hero Banner
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
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.coronavirus_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                topic.titleBn,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              if (topic.titleEn.isNotEmpty)
                                Text(
                                  topic.titleEn,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      topic.summary,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Causes & Symptoms
              if (topic.causes.isNotEmpty) ...[
                _SectionTitle(
                  icon: Icons.biotech_outlined,
                  title: 'সম্ভাব্য কারণ ও ঝুঁকিসমূহ',
                ),
                const SizedBox(height: 8),
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      for (final cause in topic.causes)
                        _BulletItem(
                          text: cause,
                          icon: Icons.circle,
                          iconColor: scheme.primary,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (topic.symptoms.isNotEmpty) ...[
                _SectionTitle(
                  icon: Icons.healing_outlined,
                  title: 'প্রধান লক্ষণসমূহ',
                ),
                const SizedBox(height: 8),
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      for (final symptom in topic.symptoms)
                        _BulletItem(
                          text: symptom,
                          icon: Icons.check_circle_outline,
                          iconColor: scheme.secondary,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Differential Diagnosis
              if (topic.differentialDiagnosis.isNotEmpty) ...[
                _SectionTitle(
                  icon: Icons.compare_arrows_rounded,
                  title:
                      'রোগ শনাক্তকরণ ও সম্ভাব্য মিল (Differential Diagnosis)',
                ),
                const SizedBox(height: 8),
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'একই ধরনের লক্ষণ অন্যান্য রোগেও দেখা যেতে পারে, তাই শুধু লক্ষণ দেখে নিশ্চিত সিদ্ধান্তে পৌঁছানো সম্ভব নয়:',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      for (final diff in topic.differentialDiagnosis)
                        _BulletItem(
                          text: diff,
                          icon: Icons.arrow_right_rounded,
                          iconColor: scheme.primary,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Safe Home Care
              if (topic.homeCare.isNotEmpty) ...[
                _SectionTitle(
                  icon: Icons.home_repair_service_outlined,
                  title: 'নিরাপদ ঘরোয়া যত্ন',
                ),
                const SizedBox(height: 8),
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      for (final care in topic.homeCare)
                        _BulletItem(
                          text: care,
                          icon: Icons.spa_outlined,
                          iconColor: Colors.teal,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // What To Do and What Not To Do
              if (topic.whatToDo.isNotEmpty ||
                  topic.whatNotToDo.isNotEmpty) ...[
                _SectionTitle(
                  icon: Icons.rule_rounded,
                  title: 'করণীয় ও বর্জনীয়',
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (topic.whatToDo.isNotEmpty)
                      Expanded(
                        child: GlassCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'কী করবেন',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              for (final item in topic.whatToDo)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '• $item',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (topic.whatToDo.isNotEmpty &&
                        topic.whatNotToDo.isNotEmpty)
                      const SizedBox(width: 10),
                    if (topic.whatNotToDo.isNotEmpty)
                      Expanded(
                        child: GlassCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.cancel_rounded,
                                    color: scheme.error,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'কী করবেন না',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: scheme.error,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              for (final item in topic.whatNotToDo)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '• $item',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 3-Tier Red Flags (Section 7.11)
              if (topic.redFlags.isNotEmpty) ...[
                _SectionTitle(
                  icon: Icons.warning_amber_rounded,
                  title: 'জরুরি সতর্কসংকেত (Red Flags)',
                ),
                const SizedBox(height: 8),
                for (final flag in topic.redFlags) _RedFlagCard(flag: flag),
                const SizedBox(height: 16),
              ],

              // Related Medicines
              if (topic.relatedMedicines.isNotEmpty) ...[
                _SectionTitle(
                  icon: Icons.medication_outlined,
                  title: 'সংশ্লিষ্ট ওষুধের সাধারণ ধারণা ও নিরাপত্তা',
                ),
                const SizedBox(height: 8),
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final med in topic.relatedMedicines)
                        _BulletItem(
                          text: med,
                          icon: Icons.medication_liquid_outlined,
                          iconColor: scheme.primary,
                        ),
                      const SizedBox(height: 8),
                      Text(
                        '* ওষুধ সেবনের আগে অবশ্যই অনুমোদিত স্বাস্থ্যকর্মীর নির্দেশনা নিন। অ্যান্টিবায়োটিক কখনোই নিজের সিদ্ধান্তে সেবন করবেন না।',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // References
              if (topic.references.isNotEmpty) ...[
                _SectionTitle(
                  icon: Icons.verified_user_outlined,
                  title: 'যাচাইকৃত রেফারেন্স ও নির্দেশিকা',
                ),
                const SizedBox(height: 8),
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      for (final ref in topic.references)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.link_rounded,
                                size: 16,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${ref.sourceName}: ${ref.sourceTitle}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (ref.evidenceNote != null)
                                      Text(
                                        ref.evidenceNote!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
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
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Action CTA
              if (associatedCourse != null)
                FilledButton.icon(
                  onPressed: () =>
                      Get.to(() => CourseView(courseId: associatedCourse.id)),
                  icon: const Icon(Icons.play_lesson_rounded),
                  label: const Text(
                    'এই বিষয়ের বিস্তারিত পাঠ ও কুইজ শুরু করুন',
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface),
        ),
      ],
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem({
    required this.text,
    required this.icon,
    required this.iconColor,
  });

  final String text;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _RedFlagCard extends StatelessWidget {
  const _RedFlagCard({required this.flag});

  final RedFlagItem flag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (badgeColor, badgeText, badgeIcon) = switch (flag.level) {
      RedFlagLevel.observation => (
        scheme.primary,
        'স্তর ১: সাধারণ যত্ন ও পর্যবেক্ষণ',
        Icons.visibility_outlined,
      ),
      RedFlagLevel.doctor => (
        scheme.primary,
        'স্তর ২: চিকিৎসকের পরামর্শ',
        Icons.medical_services_outlined,
      ),
      RedFlagLevel.emergency => (
        scheme.error,
        'স্তর ৩: জরুরি চিকিৎসা / হাসপাতাল',
        Icons.emergency_rounded,
      ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.smallRadius),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(badgeIcon, size: 16, color: badgeColor),
              const SizedBox(width: 6),
              Text(
                badgeText,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(fontWeight: FontWeight.w700, color: badgeColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            flag.title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            flag.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
          ),
          if (flag.action.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'পদক্ষেপ: ${flag.action}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700, color: badgeColor),
            ),
          ],
        ],
      ),
    );
  }
}
