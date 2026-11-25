import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/learning_controller.dart';
import '../core/format.dart';
import '../core/navigation_mode.dart';
import '../models/learning.dart';
import '../widgets/feedback.dart';
import '../widgets/glass.dart';
import '../widgets/learning_visuals.dart';
import 'body_system_view.dart';
import 'disease_topic_view.dart';
import 'lesson_view.dart';
import 'subject_detail_view.dart';

/// Minimal course library: search + pharmacy-oriented subjects. Progress,
/// recommendations, glossary/revision shortcuts and the old tabs are gone —
/// their data APIs stay intact for the home page and other callers.
class LearningView extends StatefulWidget {
  const LearningView({super.key});

  @override
  State<LearningView> createState() => _LearningViewState();
}

class _LearningViewState extends State<LearningView> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LearningController>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Obx(() {
        if (controller.loading.value) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingList(count: 4),
          );
        }
        if (controller.error.value.isNotEmpty) {
          return Center(
            child: ErrorState(
              message: controller.error.value,
              onRetry: controller.load,
            ),
          );
        }

        final query = _query.trim().toLowerCase();
        return RefreshIndicator(
          onRefresh: () async => controller.load(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: _searchField(),
                ),
              ),
              if (query.isEmpty) ..._librarySlivers(controller),
              if (query.isNotEmpty) ..._searchSlivers(controller, query),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: GestureNavigation.shellContentBottomPadding(context),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _searchField() {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _search,
      textInputAction: TextInputAction.search,
      onChanged: (value) => setState(() => _query = value),
      decoration: InputDecoration(
        hintText: 'বিষয়, কোর্স বা পাঠ খুঁজুন…',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: 'মুছুন',
                icon: const Icon(Icons.close_rounded),
                onPressed: _clearSearch,
              ),
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  List<Widget> _librarySlivers(LearningController controller) {
    final scheme = Theme.of(context).colorScheme;
    final subjects = controller.subjects;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'কোর্স লাইব্রেরি',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${bn(subjects.length)}টি বিষয় · '
                '${bn(controller.courses.length)}টি কোর্স',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      if (subjects.isEmpty)
        const SliverPadding(
          padding: EdgeInsets.all(24),
          sliver: SliverToBoxAdapter(
            child: EmptyState(
              title: 'লাইব্রেরি লোড করা যায়নি',
              message: 'রিফ্রেশ করে আবার দেখুন।',
              icon: Icons.school_outlined,
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  _SubjectCard(subject: subjects[index], controller: controller),
              childCount: subjects.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.94,
            ),
          ),
        ),
    ];
  }

  List<Widget> _searchSlivers(LearningController controller, String query) {
    final scheme = Theme.of(context).colorScheme;
    final matchedSubjects = controller.subjects.where((s) {
      return s.titleBn.toLowerCase().contains(query) ||
          s.descriptionBn.toLowerCase().contains(query) ||
          s.subtopics.any((t) => t.toLowerCase().contains(query));
    }).toList();
    final matchedSystems = controller.bodySystems.where((s) {
      return s.nameBn.toLowerCase().contains(query) ||
          s.nameEn.toLowerCase().contains(query) ||
          s.descriptionBn.toLowerCase().contains(query);
    }).toList();
    final matchedTopics = controller.diseaseTopics.where((t) {
      return t.titleBn.toLowerCase().contains(query) ||
          t.titleEn.toLowerCase().contains(query) ||
          t.summary.toLowerCase().contains(query) ||
          t.symptoms.any((s) => s.toLowerCase().contains(query));
    }).toList();
    final matchedLessons = <({Course course, Lesson lesson})>[];
    for (final course in controller.courses) {
      for (final lesson in course.lessons) {
        final content = [
          course.title,
          lesson.title,
          lesson.summary,
          ...lesson.keyPoints,
        ].join(' ').toLowerCase();
        if (content.contains(query)) {
          matchedLessons.add((course: course, lesson: lesson));
        }
      }
    }
    final total =
        matchedSubjects.length +
        matchedSystems.length +
        matchedTopics.length +
        matchedLessons.length;

    final slivers = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '"$_query" → ${bn(total)}টি ফলাফল',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ),
              TextButton(onPressed: _clearSearch, child: const Text('মুছুন')),
            ],
          ),
        ),
      ),
    ];

    if (matchedSubjects.isNotEmpty) {
      slivers.add(_sectionTitle('বিষয়'));
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _SubjectCard(
                subject: matchedSubjects[index],
                controller: controller,
              ),
              childCount: matchedSubjects.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.94,
            ),
          ),
        ),
      );
    }
    if (matchedSystems.isNotEmpty) {
      slivers.add(_sectionTitle('অঙ্গতন্ত্র'));
      slivers.add(
        _simpleList(
          count: matchedSystems.length,
          builder: (index) {
            final sys = matchedSystems[index];
            return (
              icon: Icons.healing_outlined,
              title: sys.nameBn,
              subtitle: sys.nameEn,
              onTap: () => Get.to(() => BodySystemView(systemId: sys.id)),
            );
          },
        ),
      );
    }
    if (matchedTopics.isNotEmpty) {
      slivers.add(_sectionTitle('রোগ ও স্বাস্থ্যসমস্যা'));
      slivers.add(
        _simpleList(
          count: matchedTopics.length,
          builder: (index) {
            final topic = matchedTopics[index];
            return (
              icon: Icons.healing_outlined,
              title: topic.titleBn,
              subtitle: topic.titleEn,
              onTap: () => Get.to(() => DiseaseTopicView(topicId: topic.id)),
            );
          },
        ),
      );
    }
    if (matchedLessons.isNotEmpty) {
      slivers.add(_sectionTitle('পাঠ'));
      slivers.add(
        _simpleList(
          count: matchedLessons.length,
          builder: (index) {
            final match = matchedLessons[index];
            return (
              icon: Icons.menu_book_rounded,
              title: match.lesson.title,
              subtitle: match.course.title,
              onTap: () => Get.to(
                () => LessonView(
                  courseId: match.course.id,
                  lessonId: match.lesson.id,
                ),
              ),
            );
          },
        ),
      );
    }
    if (total == 0) {
      slivers.add(
        const SliverPadding(
          padding: EdgeInsets.all(24),
          sliver: SliverToBoxAdapter(
            child: EmptyState(
              title: 'কোনো মিল পাওয়া যায়নি',
              message: 'অন্য বানান বা ইংরেজি শব্দে চেষ্টা করুন।',
              icon: Icons.search_off_rounded,
            ),
          ),
        ),
      );
    }
    return slivers;
  }

  Widget _sectionTitle(String title) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    sliver: SliverToBoxAdapter(
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
  );

  Widget _simpleList({
    required int count,
    required ({IconData icon, String title, String subtitle, VoidCallback onTap})
        Function(int index) builder,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: count,
        itemBuilder: (context, index) {
          final item = builder(index);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              onTap: item.onTap,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(item.icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject, required this.controller});

  final StudySubject subject;
  final LearningController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final courseCount = controller.courses.where(subject.matches).length;
    final tint = switch (subject.accentIndex % 6) {
      0 => scheme.primaryContainer,
      1 => scheme.secondaryContainer,
      2 => scheme.tertiaryContainer,
      3 => scheme.errorContainer.withValues(alpha: .6),
      4 => scheme.surfaceContainerHighest,
      _ => scheme.primaryContainer.withValues(alpha: .6),
    };
    final iconColor = switch (subject.accentIndex % 6) {
      3 => scheme.error,
      4 => scheme.onSurfaceVariant,
      _ => scheme.onPrimaryContainer,
    };

    return GlassCard(
      onTap: () => Get.to(() => SubjectDetailView(subjectId: subject.id)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              LearningVisuals.iconFor(subject.icon),
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subject.titleBn,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              subject.descriptionBn,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${bn(courseCount)}টি কোর্স',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
