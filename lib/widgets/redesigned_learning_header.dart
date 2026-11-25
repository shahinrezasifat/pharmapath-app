import 'package:flutter/material.dart';

/// Redesigned learning academy header with interactive features
class RedesignedLearningHeader extends StatelessWidget {
  const RedesignedLearningHeader({
    super.key,
    required this.totalLessons,
    required this.completedLessons,
    required this.passedQuizzes,
    required this.totalQuizzes,
    this.onRefresh,
    this.showStats = true,
  });

  final int totalLessons;
  final int completedLessons;
  final int passedQuizzes;
  final int totalQuizzes;
  final VoidCallback? onRefresh;
  final bool showStats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = totalLessons > 0 ? completedLessons / totalLessons : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [scheme.primaryContainer, scheme.tertiaryContainer]
              : [scheme.primary.withAlpha(15), scheme.tertiary.withAlpha(15)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top + 16,
          20,
          24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Title and Refresh Button
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withAlpha(40),
                    border: Border.all(
                      color: scheme.primary.withAlpha(80),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.auto_stories_outlined,
                    color: scheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'স্বাস্থ্য শেখার একাডেমি',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                              letterSpacing: -0.3,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'সম্পূর্ণ অফলাইন শিক্ষার প্ল্যাটফর্ম',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (onRefresh != null)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surfaceContainerHigh.withAlpha(180),
                      border: Border.all(
                        color: scheme.outlineVariant.withAlpha(80),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.refresh_rounded, size: 20),
                      color: scheme.onSurface,
                      onPressed: onRefresh,
                      tooltip: 'রিফ্রেশ করুন',
                      padding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),

            if (showStats) ...[
              const SizedBox(height: 24),
              // Progress Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow.withAlpha(150),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.outlineVariant.withAlpha(80),
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
                          'আপনার অগ্রগতি',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${(progress * 100).round()}%',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: scheme.surfaceContainerHighest
                            .withAlpha(100),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Stats Row
                    Row(
                      children: [
                        _buildProgressStat(
                          icon: Icons.menu_book_rounded,
                          value: '$completedLessons/$totalLessons',
                          label: 'পাঠ সম্পূর্ণ',
                          scheme: scheme,
                        ),
                        const SizedBox(width: 16),
                        _buildProgressStat(
                          icon: Icons.quiz_rounded,
                          value: '$passedQuizzes/$totalQuizzes',
                          label: 'কুইজ পাস',
                          scheme: scheme,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStat({
    required IconData icon,
    required String value,
    required String label,
    required ColorScheme scheme,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer.withAlpha(100),
            ),
            child: Icon(icon, size: 18, color: scheme.primary),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
          ),
        ],
      ),
    );
  }
}

/// Learning track card with improved design
class RedesignedLearningTrackCard extends StatelessWidget {
  const RedesignedLearningTrackCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.courseCount,
    required this.completedCount,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final int courseCount;
  final int completedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = courseCount > 0 ? completedCount / courseCount : 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: colors[0].withAlpha(isDark ? 40 : 15),
            border: Border.all(
              color: colors[0].withAlpha(isDark ? 80 : 30),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withAlpha(isDark ? 30 : 10),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: colors),
                    ),
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest.withAlpha(
                    100,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(colors[0]),
                ),
              ),
              const SizedBox(height: 10),
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$completedCount/$courseCount কোর্স',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 14, color: colors[0]),
                      const SizedBox(width: 4),
                      Text(
                        '${(progress * 100).round()}%',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors[0],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Learning statistics widget
class LearningStatsPanel extends StatelessWidget {
  const LearningStatsPanel({
    super.key,
    required this.totalLessons,
    required this.completedLessons,
    required this.totalQuizzes,
    required this.passedQuizzes,
    required this.averageScore,
  });

  final int totalLessons;
  final int completedLessons;
  final int totalQuizzes;
  final int passedQuizzes;
  final double averageScore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withAlpha(150),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withAlpha(80),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'আপনার পরিসংখ্যান',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: [
              _buildStatCard(
                icon: Icons.menu_book,
                title: 'মোট পাঠ',
                value: totalLessons.toString(),
                color: Colors.blue,
                scheme: scheme,
              ),
              _buildStatCard(
                icon: Icons.check_circle,
                title: 'সম্পন্ন',
                value: completedLessons.toString(),
                color: scheme.secondary,
                scheme: scheme,
              ),
              _buildStatCard(
                icon: Icons.quiz,
                title: 'মোট কুইজ',
                value: totalQuizzes.toString(),
                color: scheme.tertiary,
                scheme: scheme,
              ),
              _buildStatCard(
                icon: Icons.verified,
                title: 'পাস করা',
                value: passedQuizzes.toString(),
                color: scheme.primary,
                scheme: scheme,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Average Score
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.grade_rounded, color: scheme.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('গড় স্কোর', style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        '${averageScore.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withAlpha(30),
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(
                            value: averageScore / 100,
                            strokeWidth: 2,
                            backgroundColor: scheme.outlineVariant.withAlpha(
                              50,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              scheme.primary,
                            ),
                          ),
                        ),
                        Text(
                          averageScore.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required ColorScheme scheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
