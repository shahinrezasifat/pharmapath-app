import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../app/theme.dart';
import '../controllers/home_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/settings_controller.dart';
import '../core/medicine_form.dart';
import '../core/navigation_mode.dart';
import '../models/medicine.dart';
import '../widgets/glass.dart';
import '../widgets/learning_visuals.dart';
import '../widgets/medicine_card.dart';
import '../widgets/safety_notice.dart';
import 'add_medicine_view.dart';
import 'course_view.dart';
import 'detail_view.dart';
import 'medical_terms_view.dart';
import 'revision_view.dart';
import 'prescription_analysis_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  Future<void> _scanPrescription(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ছবি কোথা থেকে নেবেন?',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  'বিশ্লেষণের জন্য ছবিটি OpenRouter AI-তে পাঠানো হবে। ব্যক্তিগত তথ্য থাকলে আগে ঢেকে দিন।',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('ক্যামেরা'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('গ্যালারি'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 100,
      );
      if (image == null || !context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PrescriptionAnalysisView(image: image),
        ),
      );
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ছবি নেওয়া যায়নি: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = Get.find<HomeController>();
    final nav = Get.find<NavigationController>();
    final settings = Get.find<SettingsController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Obx(() {
        final stats = home.stats;
        final count = (stats['medicines'] as int?) ?? 0;
        return RefreshIndicator(
          onRefresh: () async {
            await home.load();
            await settings.refreshStats();
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              GestureNavigation.shellContentBottomPadding(context),
            ),
            children: [
              _HomeIntro(onScanPrescription: () => _scanPrescription(context)),
              const SizedBox(height: 12),
              _QuickTools(
                syncing: home.syncing.value,
                syncProgress: home.syncProgress.value,
                syncMessage: home.syncMessage.value,
                onQuiz: () => Get.to(() => const RevisionView()),
                onAddMedicine: () => Get.to(() => const AddMedicineView()),
                onTerms: () => Get.to(() => const MedicalTermsView()),
              ),
              if (count == 0) ...[
                const SizedBox(height: 12),
                _Hint(
                  'আপনার ওষুধের তালিকা তৈরি করতে নতুন ওষুধ যোগ করুন অথবা ওষুধ খুঁজুন।',
                  icon: Icons.medication_outlined,
                  onTap: () => Get.to(() => const AddMedicineView()),
                ),
              ],
              if (home.loadError.value.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Hint(home.loadError.value, icon: Icons.error_outline_rounded),
              ],
              if (home.continueCourse.value != null &&
                  home.continueLesson.value != null) ...[
                const SectionTitle(
                  title: 'শেখা চালিয়ে যান',
                  padding: EdgeInsets.fromLTRB(2, 26, 2, 10),
                ),
                _ContinueLearning(home: home),
              ],
              SectionTitle(
                title: 'সম্প্রতি দেখা',
                action: 'সব',
                onAction: () => nav.goTo(1),
                padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
              ),
              if (home.recent.isEmpty)
                const _Hint(
                  'আপনি যে ওষুধগুলো খুলে দেখবেন, সেগুলো এখানে থাকবে।',
                  icon: Icons.history_rounded,
                )
              else
                _RecentMedicineSection(
                  recent: home.recent,
                  favorites: home.favorites,
                  favoriteIds: home.favoriteIds.toSet(),
                  onToggleFavorite: home.toggleFavorite,
                ),
              const SizedBox(height: 20),
              // ── Mandatory Medical Disclaimer ────────────────────────────
              const SafetyNotice(),
              const SizedBox(height: 10),
              Text(
                'PharmaPath · সম্পূর্ণ অফলাইন · '
                'ইন্টারনেট শুধু ডেটা আপডেট ও AI মডেলের প্রথম ডাউনলোডে',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

/// Gradient hero header with logo, greeting, and search launcher.
class _HomeIntro extends StatelessWidget {
  const _HomeIntro({required this.onScanPrescription});

  final VoidCallback onScanPrescription;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .65)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset('assets/LOGO.jpg', fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'আজ কী জানতে চান?',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurface,
                                  letterSpacing: -0.3,
                                  height: 1.1,
                                ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'বাংলাদেশি ওষুধের তথ্য, সহজে ও অফলাইনে',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  letterSpacing: 0.1,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.storage_rounded,
                            size: 13,
                            color: scheme.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'স্থানীয় ডেটা',
                            style: TextStyle(
                              color: scheme.onPrimaryContainer,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SearchPill(
                  onTap: () => Get.find<NavigationController>().goTo(1),
                  onScanPrescription: onScanPrescription,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.onTap, required this.onScanPrescription});

  final VoidCallback onTap;
  final VoidCallback onScanPrescription;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: scheme.onSurfaceVariant.withValues(alpha: .8),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'ঔষধ বা জেনেরিক বা কোম্পানি',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFF7B8694)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: 'প্রেসক্রিপশন স্ক্যান করুন',
          child: Semantics(
            button: true,
            label: 'প্রেসক্রিপশন স্ক্যান করুন',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onScanPrescription,
                borderRadius: BorderRadius.circular(18),
                child: Ink(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Icon(
                    Icons.document_scanner_rounded,
                    color: scheme.onPrimaryContainer,
                    size: 23,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick tools
// ─────────────────────────────────────────────────────────────────────────────

/// Shortcuts for useful tools that are not already available in the main navigation.
class _QuickTools extends StatelessWidget {
  const _QuickTools({
    required this.syncing,
    required this.syncProgress,
    required this.syncMessage,
    required this.onQuiz,
    required this.onAddMedicine,
    required this.onTerms,
  });

  final bool syncing;
  final double syncProgress;
  final String syncMessage;
  final VoidCallback onQuiz;
  final VoidCallback onAddMedicine;
  final VoidCallback onTerms;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (syncing) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: syncProgress > 0 ? syncProgress : null,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            syncMessage.isEmpty ? 'ডেটা আপডেট হচ্ছে…' : syncMessage,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            _QuickAction(
              icon: Icons.quiz_outlined,
              label: 'কুইজ',
              tint: scheme.primary,
              onTap: onQuiz,
            ),
            _QuickAction(
              icon: Icons.add_circle_outline_rounded,
              label: 'ওষুধ যোগ',
              tint: scheme.secondary,
              onTap: onAddMedicine,
            ),
            _QuickAction(
              icon: Icons.menu_book_outlined,
              label: 'শব্দকোষ',
              tint: scheme.tertiary,
              onTap: onTerms,
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = AppTheme.isDark(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: scheme.surfaceContainerLow,
          elevation: 1.5,
          shadowColor: scheme.primary.withValues(alpha: 0.10),
          surfaceTintColor: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 88,
              decoration: BoxDecoration(
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .75),
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: dark ? 0.22 : 0.11),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 22, color: tint),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Learning cards
// ─────────────────────────────────────────────────────────────────────────────

class _ContinueLearning extends StatelessWidget {
  const _ContinueLearning({required this.home});

  final HomeController home;

  @override
  Widget build(BuildContext context) {
    final course = home.continueCourse.value!;
    final lesson = home.continueLesson.value!;
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      onTap: () => Get.to(() => CourseView(courseId: course.id)),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          GradientIcon(
            icon: LearningVisuals.iconFor(course.icon),
            colors: LearningVisuals.colorsFor(
              course.icon,
              dark: Theme.of(context).brightness == Brightness.dark,
            ),
            size: 44,
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
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  lesson.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: scheme.primary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Medicine Rail
// ─────────────────────────────────────────────────────────────────────────────

/// Compact vertical medicine list shared by recent and favorite sections.
class _MedicineRail extends StatelessWidget {
  const _MedicineRail({
    required this.items,
    required this.favoriteIds,
    required this.onToggleFavorite,
  });

  final List<Medicine> items;
  final Set<int> favoriteIds;
  final ValueChanged<int> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final medicine in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MedicineCard(
              medicine: medicine,
              onTap: () => Get.to(() => MedicineDetailView(medicine: medicine)),
              trailing: IconButton(
                tooltip: favoriteIds.contains(medicine.id)
                    ? 'প্রিয় থেকে সরান'
                    : 'প্রিয়তে যোগ করুন',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 34,
                  height: 40,
                ),
                onPressed: () => onToggleFavorite(medicine.id),
                icon: Icon(
                  favoriteIds.contains(medicine.id)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 20,
                  color: favoriteIds.contains(medicine.id)
                      ? const Color(0xFFEF476F)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecentMedicineSection extends StatefulWidget {
  const _RecentMedicineSection({
    required this.recent,
    required this.favorites,
    required this.favoriteIds,
    required this.onToggleFavorite,
  });

  final List<Medicine> recent;
  final List<Medicine> favorites;
  final Set<int> favoriteIds;
  final ValueChanged<int> onToggleFavorite;

  @override
  State<_RecentMedicineSection> createState() => _RecentMedicineSectionState();
}

class _RecentMedicineSectionState extends State<_RecentMedicineSection> {
  static const _filters = ['সব', 'ট্যাবলেট', 'সিরাপ', 'প্রিয়'];
  String _selected = 'সব';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final source = _selected == 'প্রিয়' ? widget.favorites : widget.recent;
    final filtered = source.where((medicine) {
      return switch (_selected) {
        'ট্যাবলেট' => medicine.form == MedicineForm.tablet,
        'সিরাপ' =>
          medicine.form == MedicineForm.syrup ||
              medicine.form == MedicineForm.suspension,
        _ => true,
      };
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final label = _filters[index];
              final selected = _selected == label;
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => setState(() => _selected = label),
                backgroundColor: scheme.surface,
                selectedColor: scheme.primary,
                side: BorderSide(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                ),
                labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? Colors.white : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                shape: const StadiumBorder(),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Center(
              child: Text(
                _selected == 'প্রিয়'
                    ? 'এখনো কোনো প্রিয় ওষুধ নেই।'
                    : 'এই ধরনের সাম্প্রতিক ওষুধ নেই।',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          )
        else
          _MedicineRail(
            items: filtered,
            favoriteIds: widget.favoriteIds,
            onToggleFavorite: widget.onToggleFavorite,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hint
// ─────────────────────────────────────────────────────────────────────────────

class _Hint extends StatelessWidget {
  const _Hint(this.text, {this.onTap, this.icon = Icons.info_outline_rounded});

  final String text;
  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Icon(icon, size: 19, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}
