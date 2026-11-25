import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';
import '../controllers/learning_controller.dart';
import '../core/format.dart';
import '../core/navigation_mode.dart';
import '../models/learning.dart';
import '../widgets/feedback.dart';
import '../widgets/glass.dart';
import '../widgets/learning_visuals.dart';
import 'body_system_view.dart';
import 'course_view.dart';
import 'disease_topic_view.dart';
import 'lesson_view.dart';
import 'medical_terms_view.dart';
import 'quiz_view.dart';
import 'revision_view.dart';

/// Redesigned LearningView — drop-in replacement for the original file.
///
/// What changed, and why:
/// * One scroll view only. The old nested ListView inside Expanded caused
///   scroll jank and layout jumps. Everything now lives in a single
///   CustomScrollView, so pull-to-refresh and scrolling feel native.
/// * Search no longer swaps the whole AppBar. It is always visible under
///   the header, so the title never jumps and the keyboard focus is stable.
/// * The crowded AppBar (search toggle + refresh + bookmark + popup menu)
///   is gone. Navigation is one SegmentedButton: কোর্স | অঙ্গতন্ত্র | কুইজ.
///   Terms and Revision are now explicit quick-action buttons, not hidden
///   in a popup menu that duplicated the tabs.
/// * Readability: minimum body text is 12sp, captions are 12sp, touch
///   targets are full-width rows / 48dp chips. The old 9.5–10.5sp labels
///   and the 54dp recommendation rail are removed.
/// * Progress is always visible (no hidden expandable strip) and the
///   recommendation rail is tall enough to actually read.
/// * Same controller, models, routes and Bengali copy — no API changes,
///   so this file can replace learning_view.dart as-is.
class LearningView extends StatefulWidget {
  const LearningView({super.key});

  @override
  State<LearningView> createState() => _LearningViewState();
}

class _LearningViewState extends State<LearningView> {
  final TextEditingController _search = TextEditingController();

  String _query = '';

  /// The shelf the reader picked. Empty = show every shelf.
  String _selectedTrack = '';

  bool _showBookmarks = false;

  /// 0: কোর্সসমূহ, 1: অঙ্গতন্ত্র, 2: কুইজ হাব
  int _viewTab = 0;

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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
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
          onRefresh: () async {
            controller.load();
          },
          child: CustomScrollView(
            slivers: [
              // Search sits directly under the shared top header.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                  child: _searchField(),
                ),
              ),
              if (query.isNotEmpty) ..._searchSlivers(controller, query),
              if (query.isEmpty) ...[
                if (_showBookmarks) ..._bookmarkSlivers(controller),
                if (!_showBookmarks) ...[
                  ..._progressSlivers(controller),
                  _quickActionsSliver(),
                  _tabBarSliver(),
                  if (_viewTab == 0) ..._courseTabSlivers(controller),
                  if (_viewTab == 1) ..._atlasSlivers(controller),
                  if (_viewTab == 2) ..._quizSlivers(controller),
                ],
              ],
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

  // -------------------------------------------------------------------------
  // Header & search
  // -------------------------------------------------------------------------

  Widget _searchField() {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _search,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'অঙ্গ, রোগ, লক্ষণ বা ওষুধ খুঁজুন (উদাঃ গলাব্যথা, Kidney)…',
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
          vertical: 14,
        ),
      ),
      onChanged: (val) => setState(() => _query = val),
    );
  }

  // -------------------------------------------------------------------------
  // Progress, continue, recommendations
  // -------------------------------------------------------------------------

  List<Widget> _progressSlivers(LearningController controller) {
    final scheme = Theme.of(context).colorScheme;
    final progress = controller.overallProgress;
    final pct = (progress * 100).round();
    final totalLessons = controller.courses.fold<int>(
      0,
      (sum, c) => sum + c.lessons.length,
    );
    final resume = controller.continueReading;

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        sliver: SliverToBoxAdapter(
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 18,
            borderColor: scheme.primary.withValues(alpha: 0.25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'সার্বিক অগ্রগতি',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${bn(pct)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${bn(controller.completedLessonCount)}/${bn(totalLessons)} পাঠ সম্পন্ন',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(scheme.primary),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: 'মোট কোর্স',
                        value: bn(controller.totalCourses),
                        sub: '${bn(controller.startedCourseCount)}টি শুরু',
                      ),
                    ),
                    Expanded(
                      child: _Stat(
                        label: 'কুইজ স্কোর',
                        value: '${bn(controller.quizPerformanceAverage)}%',
                        sub: '${bn(controller.passedQuizCount)}টি পাস',
                      ),
                    ),
                    Expanded(
                      child: _Stat(
                        label: 'বুকমার্ক',
                        value: bn(controller.bookmarks.length),
                        sub: '${bn(controller.revisionPendingCount)} রিভিশন',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      if (resume != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          sliver: SliverToBoxAdapter(
            child: _ContinueCard(target: resume, controller: controller),
          ),
        ),
      if (controller.recommendations.isNotEmpty)
        ..._recommendationSlivers(controller),
    ];
  }

  List<Widget> _recommendationSlivers(LearningController controller) {
    final scheme = Theme.of(context).colorScheme;
    final recs = controller.recommendations;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: scheme.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                'সুপারিশকৃত পাঠ',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.secondary,
                ),
              ),
              const Spacer(),
              Text(
                '${bn(recs.length)}টি পাঠ',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = recs[index];
              return SizedBox(
                width: 260,
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  borderRadius: 16,
                  color: scheme.secondaryContainer.withValues(alpha: 0.25),
                  borderColor: scheme.secondary.withValues(alpha: 0.3),
                  onTap: () => Get.to(
                    () => LessonView(
                      courseId: item.course.id,
                      lessonId: item.lesson.id,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.lesson.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: scheme.secondary,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '${item.reason} · ${bn(item.lesson.minutes)} মিনিট',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      const SliverPadding(padding: EdgeInsets.only(bottom: 12)),
    ];
  }

  Widget _quickActionsSliver() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => Get.to(() => const MedicalTermsView()),
                icon: const Icon(Icons.book_outlined, size: 18),
                label: const Text('চিকিৎসা পরিভাষা'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => Get.to(() => const RevisionView()),
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('রিভিশন'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBarSliver() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      sliver: SliverToBoxAdapter(
        child: SegmentedButton<int>(
          segments: [
            // Short labels on purpose: counts live in each tab's header,
            // and long Bengali labels would overflow SegmentedButton on
            // narrow phones.
            const ButtonSegment(
              value: 0,
              icon: Icon(Icons.school_rounded),
              label: Text('কোর্স'),
            ),
            const ButtonSegment(
              value: 1,
              icon: Icon(Icons.accessibility_new_rounded),
              label: Text('অঙ্গতন্ত্র'),
            ),
            const ButtonSegment(
              value: 2,
              icon: Icon(Icons.quiz_rounded),
              label: Text('কুইজ'),
            ),
          ],
          selected: {_viewTab},
          showSelectedIcon: false,
          onSelectionChanged: (sel) => setState(() => _viewTab = sel.first),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Courses tab
  // -------------------------------------------------------------------------

  List<Widget> _courseTabSlivers(LearningController controller) {
    const previewCount = 4;
    final shelves = controller.liveTracks;
    final entries = [
      for (final shelf in shelves)
        (
          id: shelf.id,
          label: shelf.labelBn,
          courses: controller.shelfCourses(shelf.id),
        ),
    ];
    final focus = entries.where((e) => e.id == _selectedTrack).firstOrNull;
    final shown = focus == null ? entries : [focus];
    final lessons = controller.courses.fold<int>(
      0,
      (sum, course) => sum + course.lessons.length,
    );
    final scheme = Theme.of(context).colorScheme;

    final slivers = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'কোর্স লাইব্রেরি',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (focus != null)
                    TextButton(
                      onPressed: () => setState(() => _selectedTrack = ''),
                      child: const Text('সব বিভাগ দেখুন'),
                    ),
                ],
              ),
              Text(
                '${bn(controller.courses.length)}টি কোর্স · ${bn(lessons)}টি পাঠ · '
                '${bn(shelves.length)}টি বিভাগ',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final entry in entries) ...[
                ChoiceChip(
                  label: Text('${entry.label} (${bn(entry.courses.length)})'),
                  selected: entry.id == _selectedTrack,
                  onSelected: (_) => setState(
                    () => _selectedTrack = entry.id == _selectedTrack
                        ? ''
                        : entry.id,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
      const SliverPadding(padding: EdgeInsets.only(bottom: 8)),
      // Featured master course, only on the unfiltered library view.
      if (focus == null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          sliver: SliverToBoxAdapter(child: _FeaturedCard()),
        ),
    ];

    for (final entry in shown) {
      slivers.addAll(
        _shelfSlivers(
          entry: entry,
          controller: controller,
          expanded: focus != null,
          previewCount: previewCount,
        ),
      );
    }

    if (entries.isEmpty) {
      slivers.add(
        const SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: EmptyState(
              title: 'লাইব্রেরিতে এখনো কোনো কোর্স নেই',
              message: 'রিফ্রেশ করে আবার দেখুন।',
              icon: Icons.school_outlined,
            ),
          ),
        ),
      );
    }
    return slivers;
  }

  List<Widget> _shelfSlivers({
    required ({String id, String label, List<Course> courses}) entry,
    required LearningController controller,
    required bool expanded,
    required int previewCount,
  }) {
    final scheme = Theme.of(context).colorScheme;
    if (entry.courses.isEmpty) return const [];
    final lessons = entry.courses.fold<int>(
      0,
      (sum, course) => sum + course.lessons.length,
    );
    final visible = expanded
        ? entry.courses
        : entry.courses.take(previewCount).toList();
    final icon = entry.courses.first.icon;
    final colors = LearningVisuals.colorsFor(
      icon,
      dark: scheme.brightness == Brightness.dark,
    );

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  LearningVisuals.iconFor(icon),
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${bn(entry.courses.length)}টি কোর্স · ${bn(lessons)}টি পাঠ',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (!expanded && entry.courses.length > previewCount)
                TextButton(
                  onPressed: () => setState(() => _selectedTrack = entry.id),
                  child: Text('সব ${bn(entry.courses.length)}টি'),
                ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.builder(
          itemCount: visible.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CourseCard(course: visible[index], controller: controller),
          ),
        ),
      ),
    ];
  }

  List<Widget> _bookmarkSlivers(LearningController controller) {
    final scheme = Theme.of(context).colorScheme;
    final bookmarked = controller.courses
        .where((c) => c.lessons.any((l) => controller.isBookmarked(c.id, l.id)))
        .toList();
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Icon(Icons.bookmark_rounded, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'বুকমার্ক করা পাঠ (${bn(bookmarked.length)}টি)',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _showBookmarks = false),
                child: const Text('বন্ধ করুন'),
              ),
            ],
          ),
        ),
      ),
      if (bookmarked.isEmpty)
        const SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: EmptyState(
              title: 'কোনো বুকমার্ক নেই',
              message: 'পাঠ খোলার সময় বুকমার্ক আইকন চেপে প্রয়োজনীয় পাঠ এখানে রাখুন।',
              icon: Icons.bookmark_border_rounded,
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: bookmarked.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CourseCard(
                course: bookmarked[index],
                controller: controller,
              ),
            ),
          ),
        ),
    ];
  }

  // -------------------------------------------------------------------------
  // Atlas tab
  // -------------------------------------------------------------------------

  List<Widget> _atlasSlivers(LearningController controller) {
    final scheme = Theme.of(context).colorScheme;
    final systems = controller.bodySystems;
    if (systems.isEmpty) {
      return [
        const SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: EmptyState(
              title: 'অঙ্গতন্ত্র পাওয়া যায়নি',
              icon: Icons.accessibility_new_rounded,
            ),
          ),
        ),
      ];
    }

    final groups = <String, List<BodySystem>>{};
    for (final system in systems) {
      groups.putIfAbsent(system.group, () => <BodySystem>[]).add(system);
    }
    final labels = controller.atlasGroupLabels;
    final ordered = [
      for (final key in labels.keys)
        if (groups[key] != null) (label: labels[key]!, rows: groups[key]!),
      if (groups.keys.where((k) => !labels.containsKey(k)).isNotEmpty)
        (
          label: 'অন্যান্য বিভাগ',
          rows: [
            for (final key in groups.keys)
              if (!labels.containsKey(key)) ...groups[key]!,
          ],
        ),
    ];

    final slivers = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'মানবদেহের অঙ্গতন্ত্র ও রোগ-বিভাগ (${bn(systems.length)}টি)',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                'প্রতিটি বিভাগে অংশ, লক্ষণ ও সেখান থেকে খোলা যায় এমন কোর্স।',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    ];

    for (final group in ordered) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ),
                Text(
                  '${bn(group.rows.length)}টি',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemCount: group.rows.length,
            itemBuilder: (context, index) {
              final sys = group.rows[index];
              final guides = sys.relatedCourseIds.length;
              return GlassCard(
                onTap: () => Get.to(() => BodySystemView(systemId: sys.id)),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        LearningVisuals.iconFor(sys.iconKey),
                        color: scheme.primary,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      sys.nameBn,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      guides == 0
                          ? sys.nameEn
                          : '${bn(guides)}টি কোর্স · ${sys.nameEn}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: guides == 0
                            ? scheme.onSurfaceVariant
                            : scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }
    return slivers;
  }

  // -------------------------------------------------------------------------
  // Quiz tab
  // -------------------------------------------------------------------------

  List<Widget> _quizSlivers(LearningController controller) {
    final scheme = Theme.of(context).colorScheme;
    final coursesWithQuiz =
        controller.courses.where((c) => c.quiz.isNotEmpty).toList()
          ..sort((a, b) => a.title.compareTo(b.title));

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        sliver: SliverToBoxAdapter(
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            color: scheme.primaryContainer.withValues(alpha: 0.25),
            child: Row(
              children: [
                Icon(Icons.quiz_rounded, color: scheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'কুইজ ও জ্ঞান যাচাই',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'পাস মার্ক ৮০% · সঠিক উত্তর দিলে পাঠ ও কোর্স সম্পন্ন হবে।',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.builder(
          itemCount: coursesWithQuiz.length,
          itemBuilder: (context, index) {
            final course = coursesWithQuiz[index];
            final passed = controller.isPassed(course.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                onTap: () => Get.to(() => QuizView(courseId: course.id)),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      passed ? Icons.verified_rounded : Icons.quiz_outlined,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${course.title} কুইজ',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${bn(course.quiz.length)}টি প্রশ্ন · পাস মার্ক ৮০%',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: () =>
                          Get.to(() => QuizView(courseId: course.id)),
                      child: Text(passed ? 'আবার দিন' : 'কুইজ শুরু'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  // -------------------------------------------------------------------------
  // Search results
  // -------------------------------------------------------------------------

  List<Widget> _searchSlivers(LearningController controller, String query) {
    final scheme = Theme.of(context).colorScheme;
    final matchedSystems = controller.bodySystems.where((s) {
      return s.nameBn.toLowerCase().contains(query) ||
          s.nameEn.toLowerCase().contains(query) ||
          s.descriptionBn.toLowerCase().contains(query);
    }).toList();
    final matchedTopics = controller.diseaseTopics.where((t) {
      return t.titleBn.toLowerCase().contains(query) ||
          t.titleEn.toLowerCase().contains(query) ||
          t.summary.toLowerCase().contains(query) ||
          t.causes.any((c) => c.toLowerCase().contains(query)) ||
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
    final totalFound =
        matchedSystems.length + matchedTopics.length + matchedLessons.length;

    final slivers = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '"$query" এর জন্য ${bn(totalFound)}টি ফলাফল পাওয়া গেছে',
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

    if (matchedSystems.isNotEmpty) {
      slivers.add(
        _searchSectionTitle('অঙ্গতন্ত্রসমূহ (${bn(matchedSystems.length)})'),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: matchedSystems.length,
            itemBuilder: (context, index) {
              final sys = matchedSystems[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  onTap: () => Get.to(() => BodySystemView(systemId: sys.id)),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        LearningVisuals.iconFor(sys.iconKey),
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${sys.nameBn} (${sys.nameEn})',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    if (matchedTopics.isNotEmpty) {
      slivers.add(
        _searchSectionTitle(
          'রোগ ও স্বাস্থ্যসমস্যা (${bn(matchedTopics.length)})',
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: matchedTopics.length,
            itemBuilder: (context, index) {
              final top = matchedTopics[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  onTap: () => Get.to(() => DiseaseTopicView(topicId: top.id)),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.healing_outlined, color: scheme.secondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              top.titleBn,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              top.titleEn,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
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
        ),
      );
    }

    if (matchedLessons.isNotEmpty) {
      slivers.add(
        _searchSectionTitle('পাঠ ও অধ্যায় (${bn(matchedLessons.length)})'),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: matchedLessons.length,
            itemBuilder: (context, index) {
              final m = matchedLessons[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  onTap: () => Get.to(
                    () => LessonView(
                      courseId: m.course.id,
                      lessonId: m.lesson.id,
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.menu_book_rounded, color: scheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.lesson.title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              m.course.title,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
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
        ),
      );
    }

    if (totalFound == 0) {
      slivers.add(
        const SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: EmptyState(
                title: 'কোনো মিল পাওয়া যায়নি',
                message: 'ইংরেজি বা বাংলায় ভিন্ন বানানে অনুসন্ধান করে দেখুন।',
                icon: Icons.search_off_rounded,
              ),
            ),
          ),
        ),
      );
    }
    return slivers;
  }

  Widget _searchSectionTitle(String title) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
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
  }
}

// ---------------------------------------------------------------------------
// Shared cards
// ---------------------------------------------------------------------------

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.sub});

  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800, color: scheme.primary),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          sub,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.target, required this.controller});

  final ({Course course, Lesson lesson}) target;
  final LearningController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = controller.completedIn(target.course);
    final total = target.course.lessons.length;
    final pct = total == 0 ? 0 : ((done / total) * 100).round();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      color: scheme.primaryContainer.withValues(alpha: 0.25),
      borderColor: scheme.primary.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
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
                      'চলমান পাঠ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      target.lesson.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${target.course.title} · ${bn(pct)}%',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () => Get.to(
                  () => LessonView(
                    courseId: target.course.id,
                    lessonId: target.lesson.id,
                  ),
                ),
                child: const Text('চালিয়ে যান'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = Get.find<LearningController>();
    final course = controller.courses.firstWhereOrNull(
      (c) => c.id == 'sore_throat_master',
    );
    if (course == null) return const SizedBox.shrink();

    final done = controller.completedIn(course);
    final total = course.lessons.length;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      gradient: AppTheme.heroGradient(context),
      borderColor: Colors.white.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'যাচাইকৃত মাস্টার পাঠক্রম (WHO & DGHS)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            course.title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            course.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${bn(total)}টি পাঠ · ${bn(course.quiz.length)}টি কুইজ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () => Get.to(() => CourseView(courseId: course.id)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: scheme.primary,
                ),
                child: Text(
                  done == 0
                      ? 'কোর্স শুরু'
                      : 'চালিয়ে যান (${bn(done)}/${bn(total)})',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.controller});

  final Course course;
  final LearningController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = controller.completedIn(course);
    final total = course.lessons.length;
    final progress = total == 0 ? 0.0 : done / total;
    final isDone = total > 0 && done == total;

    return GlassCard(
      onTap: () => Get.to(() => CourseView(courseId: course.id)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  LearningVisuals.iconFor(course.icon),
                  color: scheme.primary,
                  size: 24,
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
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      course.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${bn(total)}টি পাঠ'
                      '${course.quiz.isNotEmpty ? ' · ${bn(course.quiz.length)}টি কুইজ' : ''}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isDone)
                Icon(
                  Icons.check_circle_rounded,
                  color: scheme.primary,
                  size: 22,
                )
              else
                Text(
                  '${bn((progress * 100).round())}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
