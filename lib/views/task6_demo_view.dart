import 'package:flutter/material.dart';

import '../services/tutorial_service.dart';
import '../widgets/redesigned_learning_header.dart';

/// Task 6 Demo: Learning Academy with Interactive Tutorials and Progress Visualization
class Task6DemoView extends StatefulWidget {
  const Task6DemoView({super.key});

  @override
  State<Task6DemoView> createState() => _Task6DemoViewState();
}

class _Task6DemoViewState extends State<Task6DemoView> {
  late final TutorialService _tutorialService;
  int _currentTutorialIndex = 0;
  bool _showTutorials = true;

  @override
  void initState() {
    super.initState();
    _tutorialService = TutorialService();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tutorials = _tutorialService.getTutorials();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Task 6: শিক্ষার একাডেমি'),
        centerTitle: true,
        actions: [
          PopupMenuButton<int>(
            itemBuilder: (context) => [
              const PopupMenuItem<int>(
                value: 1,
                child: Text('টিউটোরিয়াল রিসেট করুন'),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<int>(
                value: 2,
                child: StatefulBuilder(
                  builder: (context, setState) => CheckboxListTile(
                    title: const Text('টিউটোরিয়াল দেখান'),
                    value: _showTutorials,
                    onChanged: (value) {
                      setState(() {
                        _showTutorials = value ?? false;
                      });
                      this.setState(() {
                        _showTutorials = value ?? false;
                      });
                    },
                  ),
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 1) {
                _tutorialService.resetTutorials();
                setState(() {
                  _currentTutorialIndex = 0;
                });
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Redesigned Learning Header with Progress
              RedesignedLearningHeader(
                totalLessons: 45,
                completedLessons: 18,
                passedQuizzes: 12,
                totalQuizzes: 20,
                showStats: true,
                onRefresh: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ডেটা রিফ্রেশ করা হয়েছে')),
                  );
                },
              ),
              const SizedBox(height: 28),

              // 2. Interactive Tutorial Section
              if (_showTutorials) ...[
                Text(
                  'ইন্টারেক্টিভ টিউটোরিয়াল',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'ধাপে ধাপে শিখুন এবং PharmaPath সম্পূর্ণভাবে ব্যবহার করতে শিখুন',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),

                // Tutorial Carousel
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < tutorials.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            right: i < tutorials.length - 1 ? 12 : 0,
                          ),
                          child: _TutorialThumbnail(
                            tutorial: tutorials[i],
                            isSelected: _currentTutorialIndex == i,
                            onTap: () {
                              setState(() => _currentTutorialIndex = i);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Full Tutorial Card
                InteractiveTutorialCard(
                  tutorial: tutorials[_currentTutorialIndex],
                  onComplete: () async {
                    await _tutorialService.completeTutorial(
                      tutorials[_currentTutorialIndex].id,
                    );
                    setState(() {});
                    if (_currentTutorialIndex < tutorials.length - 1) {
                      setState(() => _currentTutorialIndex++);
                    }
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '✓ সম্পন্ন করা হয়েছে: ${tutorials[_currentTutorialIndex].title}',
                        ),
                      ),
                    );
                  },
                  onSkip: () {
                    if (_currentTutorialIndex < tutorials.length - 1) {
                      setState(() => _currentTutorialIndex++);
                    }
                  },
                ),
                const SizedBox(height: 28),

                // Tutorial Progress
                _TutorialProgressBar(tutorials: tutorials),
                const SizedBox(height: 28),
              ],

              // 3. Learning Tracks Section
              Text(
                'শিক্ষার ট্র্যাক',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),

              // Track 1: Body and Disease
              RedesignedLearningTrackCard(
                title: 'শরীর ও রোগ',
                subtitle: 'অঙ্গ-প্রত্যঙ্গভিত্তিক রোগ, লক্ষণ, খাদ্য ও চিকিৎসা',
                icon: Icons.medical_services_outlined,
                colors: [Colors.red, Colors.pink],
                courseCount: 15,
                completedCount: 6,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('শরীর ও রোগ ট্র্যাক খোলা হয়েছে'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Track 2: Medicine Essentials
              RedesignedLearningTrackCard(
                title: 'ওষুধের মূল কথা',
                subtitle: 'নিরাপদ ব্যবহার, অ্যান্টিবায়োটিক ও দীর্ঘমেয়াদি রোগ',
                icon: Icons.medication_outlined,
                colors: [Colors.blue, Colors.cyan],
                courseCount: 12,
                completedCount: 6,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ওষুধের মূল কথা ট্র্যাক খোলা হয়েছে'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Track 3: Pharmacy and Clinical Care
              RedesignedLearningTrackCard(
                title: 'ফার্মেসি ও ক্লিনিক্যাল কেয়ার',
                subtitle: 'ফার্মাকোলজি, বিশেষ রোগী, রিপোর্ট পড়া ও ব্যবস্থাপনা',
                icon: Icons.storefront_outlined,
                colors: [Colors.green, Colors.teal],
                courseCount: 18,
                completedCount: 6,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'ফার্মেসি ও ক্লিনিক্যাল কেয়ার ট্র্যাক খোলা হয়েছে',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),

              // 4. Learning Statistics Panel
              LearningStatsPanel(
                totalLessons: 45,
                completedLessons: 18,
                totalQuizzes: 20,
                passedQuizzes: 12,
                averageScore: 82.5,
              ),
              const SizedBox(height: 28),

              // 5. Achievement Section
              Text(
                'আপনার অর্জন',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _AchievementBadge(
                    icon: Icons.star_rounded,
                    title: 'শুরু করেছেন',
                    description: 'প্রথম পাঠ শুরু',
                    color: Colors.yellow,
                    unlocked: true,
                  ),
                  _AchievementBadge(
                    icon: Icons.check_circle_rounded,
                    title: 'গতি নিয়েছেন',
                    description: '৫টি পাঠ সম্পূর্ণ',
                    color: Colors.blue,
                    unlocked: true,
                  ),
                  _AchievementBadge(
                    icon: Icons.whatshot_rounded,
                    title: 'দ্রুতগামী',
                    description: '১০টি পাঠ সম্পূর্ণ',
                    color: Colors.orange,
                    unlocked: false,
                  ),
                  _AchievementBadge(
                    icon: Icons.verified_rounded,
                    title: 'কুইজ মাস্টার',
                    description: '৫টি কুইজ পাস',
                    color: Colors.purple,
                    unlocked: true,
                  ),
                  _AchievementBadge(
                    icon: Icons.psychology_rounded,
                    title: 'বিশেষজ্ঞ',
                    description: 'সব ট্র্যাক শুরু',
                    color: Colors.indigo,
                    unlocked: false,
                  ),
                  _AchievementBadge(
                    icon: Icons.emoji_events_rounded,
                    title: 'চ্যাম্পিয়ন',
                    description: 'সব কোর্স সম্পূর্ণ',
                    color: Colors.amber,
                    unlocked: false,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 6. Quick Stats Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withAlpha(15),
                      scheme.secondary.withAlpha(15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.primary.withAlpha(30),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'এই সপ্তাহের কার্যকলাপ',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '↑ ৩০%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActivityStat(
                          icon: Icons.menu_book_rounded,
                          value: '5',
                          label: 'পাঠ',
                        ),
                        _buildActivityStat(
                          icon: Icons.quiz_rounded,
                          value: '3',
                          label: 'কুইজ',
                        ),
                        _buildActivityStat(
                          icon: Icons.timer_rounded,
                          value: '2h',
                          label: 'সময়',
                        ),
                        _buildActivityStat(
                          icon: Icons.whatshot_rounded,
                          value: '5',
                          label: 'স্ট্রিক',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Info Card
              _buildInfoCard(
                context,
                icon: Icons.lightbulb_outlined,
                title: 'Task 6 বৈশিষ্ট্য',
                items: [
                  '✓ ইন্টারেক্টিভ ৬-ধাপ টিউটোরিয়াল সিস্টেম',
                  '✓ GetStorage-ভিত্তিক অগ্রগতি সংরক্ষণ',
                  '✓ পুনর্নির্মাণ করা শিক্ষা শীর্ষলেখা উপাদান',
                  '✓ শিক্ষা ট্র্যাক কার্ড এবং গতিবেগ ট্র্যাকিং',
                  '✓ সম্পূর্ণ পরিসংখ্যান এবং অর্জন সিস্টেম',
                  '✓ উন্নত ভিজ্যুয়াল: গ্রেডিয়েন্ট, স্বচ্ছতা, ছায়া',
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primaryContainer.withAlpha(100),
          ),
          child: Icon(icon, color: scheme.primary, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<String> items,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withAlpha(100),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withAlpha(50),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: scheme.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tutorial thumbnail showing completion status
class _TutorialThumbnail extends StatelessWidget {
  const _TutorialThumbnail({
    required this.tutorial,
    required this.isSelected,
    required this.onTap,
  });

  final TutorialStep tutorial;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? scheme.primaryContainer.withAlpha(100)
                : scheme.surfaceContainerHigh.withAlpha(100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? scheme.primary.withAlpha(100)
                  : scheme.outlineVariant.withAlpha(50),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(tutorial.icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              if (tutorial.completed)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                )
              else
                Text(
                  '${_getTutorialNumber(tutorial.id)}/৬',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  int _getTutorialNumber(String id) {
    const stepIds = [
      'welcome',
      'search',
      'medicine_details',
      'learning',
      'favorites',
      'assistant',
    ];
    return stepIds.indexOf(id) + 1;
  }
}

/// Tutorial progress bar showing completion
class _TutorialProgressBar extends StatelessWidget {
  const _TutorialProgressBar({required this.tutorials});

  final List<TutorialStep> tutorials;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final completed = tutorials.where((t) => t.completed).length;
    final progress = tutorials.isNotEmpty ? completed / tutorials.length : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withAlpha(100),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withAlpha(50),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'টিউটোরিয়াল অগ্রগতি',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest.withAlpha(100),
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$completed/${tutorials.length} টিউটোরিয়াল সম্পন্ন',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Achievement badge widget
class _AchievementBadge extends StatelessWidget {
  const _AchievementBadge({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.unlocked,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked
            ? color.withAlpha(20)
            : scheme.surfaceContainerHigh.withAlpha(100),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked
              ? color.withAlpha(50)
              : scheme.outlineVariant.withAlpha(30),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                color: unlocked ? color : scheme.outlineVariant,
                size: 28,
              ),
              if (!unlocked)
                Icon(
                  Icons.lock_outline_rounded,
                  size: 12,
                  color: scheme.outlineVariant,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: unlocked ? color : scheme.outlineVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Interactive tutorial card - standalone display
class InteractiveTutorialCard extends StatelessWidget {
  const InteractiveTutorialCard({
    super.key,
    required this.tutorial,
    required this.onComplete,
    required this.onSkip,
  });

  final TutorialStep tutorial;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  scheme.primaryContainer.withAlpha(100),
                  scheme.secondaryContainer.withAlpha(100),
                ]
              : [scheme.primary.withAlpha(15), scheme.secondary.withAlpha(15)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.primary.withAlpha(30), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon and Title
          Row(
            children: [
              Text(tutorial.icon, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tutorial.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ধাপ ${_getStepNumber(tutorial.id)}/৬',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (tutorial.completed)
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // Description
          Text(
            tutorial.description,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: scheme.onSurface, height: 1.5),
          ),
          const SizedBox(height: 16),
          // Tips
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow.withAlpha(100),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'টিপস:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                for (final tip in tutorial.tips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: scheme.primary)),
                        Expanded(
                          child: Text(
                            tip,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSkip,
                  child: const Text('পরবর্তী'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onComplete,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(tutorial.completed ? 'সম্পন্ন' : 'সম্পন্ন করুন'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _getStepNumber(String id) {
    const stepIds = [
      'welcome',
      'search',
      'medicine_details',
      'learning',
      'favorites',
      'assistant',
    ];
    return stepIds.indexOf(id) + 1;
  }
}
