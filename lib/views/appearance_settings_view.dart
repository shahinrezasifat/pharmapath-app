import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/settings_controller.dart';
import '../core/navigation_mode.dart';
import '../widgets/glass.dart';

class AppearanceSettingsView extends StatelessWidget {
  const AppearanceSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsController>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('চেহারা ও থিম')),
      body: Obx(() {
        final mode = settings.themeMode.value;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            GestureNavigation.pageBottomPadding(context, additionalBuffer: 24),
          ),
          children: [
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'পরিষ্কার ও ফ্ল্যাট ডিজাইন',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ফার্মাপাথের পৃষ্ঠাগুলো এখন সাদামাটা সারফেস, হালকা বর্ডার '
                    'ও একটিমাত্র নীল অ্যাকসেন্ট ব্যবহার করে। কোনো কাঁচের '
                    'ঝাপসা প্রভাব বা ভারী ছায়া নেই — চোখে আরামদায়ক থাকে।',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SectionTitle(title: 'থিম বেছে নিন'),
            _ThemeOption(
              title: 'সিস্টেম অনুযায়ী',
              subtitle: 'ফোনের সেটিংস অনুযায়ী হালকা বা গাঢ় হবে',
              icon: Icons.brightness_auto_rounded,
              value: 'system',
              selected: mode == 'system',
              onTap: () => settings.setThemeMode('system'),
            ),
            _ThemeOption(
              title: 'হালকা',
              subtitle: 'উজ্জ্বল, পরিষ্কার সারফেস — দিনের আলোর জন্য',
              icon: Icons.light_mode_rounded,
              value: 'light',
              selected: mode == 'light',
              onTap: () => settings.setThemeMode('light'),
            ),
            _ThemeOption(
              title: 'গাঢ়',
              subtitle: 'গাঢ় ও শান্ত সারফেস, রাতে চোখের আরামের জন্য',
              icon: Icons.dark_mode_rounded,
              value: 'dark',
              selected: mode == 'dark',
              onTap: () => settings.setThemeMode('dark'),
            ),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'থিম পরিবর্তন সঙ্গে সঙ্গে পুরো অ্যাপে প্রয়োগ হবে এবং '
                      'এই ডিভাইসে সংরক্ষিত থাকবে।',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SectionTitle(title: 'স্ক্রিন ও নেভিগেশন মোড'),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.fullscreen_rounded,
                        color: scheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ফুল-স্ক্রিন মোড',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'সিস্টেম নেভিগেশন ও জেসচার বোতাম লুকিয়ে পূর্ণ স্ক্রিনে অ্যাপ চালান।',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: settings.fullscreenMode.value,
                        onChanged: settings.setFullscreenMode,
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Icon(
                        GestureNavigation.hasGestureNavigation(context)
                            ? Icons.swipe_up_rounded
                            : Icons.aspect_ratio_rounded,
                        size: 16,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          GestureNavigation.hasGestureNavigation(context)
                              ? 'স্বয়ংক্রিয় শনাক্তকরণ: জেসচার নেভিগেশন সক্রিয় (নিরাপদ মার্জিন নিশ্চিত)'
                              : 'স্বয়ংক্রিয় শনাক্তকরণ: ফুল-স্ক্রিন মোড সক্রিয়',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      onTap: onTap,
      borderColor: selected ? scheme.primary.withValues(alpha: 0.55) : null,
      color: selected ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
      child: Row(
        children: [
          GradientIcon(icon: icon, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? scheme.primary : Colors.transparent,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: 1.6,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }
}
