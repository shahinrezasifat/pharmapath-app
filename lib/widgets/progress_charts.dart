import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Quiz Performance Pie Chart
class QuizPerformancePieChart extends StatelessWidget {
  const QuizPerformancePieChart({
    super.key,
    required this.passed,
    required this.failed,
    required this.pending,
  });

  final int passed;
  final int failed;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = passed + failed + pending;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withAlpha(100),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withAlpha(50),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'কুইজ পারফরম্যান্স',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: passed.toDouble(),
                    title: '$passed',
                    color: scheme.primary,
                    radius: 60,
                    titleStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: failed.toDouble(),
                    title: '$failed',
                    color: scheme.secondary,
                    radius: 60,
                    titleStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: pending.toDouble(),
                    title: '$pending',
                    color: scheme.tertiary,
                    radius: 60,
                    titleStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
                pieTouchData: PieTouchData(enabled: true),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem(
                label: 'পাস করা',
                color: scheme.primary,
                value: '${((passed / total) * 100).toStringAsFixed(1)}%',
              ),
              _buildLegendItem(
                label: 'ব্যর্থ',
                color: scheme.secondary,
                value: '${((failed / total) * 100).toStringAsFixed(1)}%',
              ),
              _buildLegendItem(
                label: 'বাকি',
                color: scheme.tertiary,
                value: '${((pending / total) * 100).toStringAsFixed(1)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required String label,
    required Color color,
    required String value,
  }) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Learning Progress Line Chart
class LearningProgressLineChart extends StatelessWidget {
  const LearningProgressLineChart({super.key, required this.weekData});

  final List<double> weekData; // 7 days of data

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withAlpha(100),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withAlpha(50),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'এই সপ্তাহের অগ্রগতি',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      weekData.length,
                      (index) => FlSpot(index.toDouble(), weekData[index]),
                    ),
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.secondary],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 4,
                            color: scheme.primary,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary.withAlpha(50),
                          scheme.secondary.withAlpha(50),
                        ],
                      ),
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}%',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        _getDayName(value.toInt()),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: scheme.outlineVariant.withAlpha(30),
                    strokeWidth: 0.8,
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: 100,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDayName(int index) {
    const days = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহ', 'শুক্র', 'শনি', 'রবি'];
    return days[index.clamp(0, days.length - 1)];
  }
}

/// Course Performance Bar Chart
class CoursePerformanceBarChart extends StatelessWidget {
  const CoursePerformanceBarChart({super.key, required this.courses});

  final List<({String name, double score, int lessons})> courses;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withAlpha(100),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withAlpha(50),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'কোর্স পারফরম্যান্স',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                barGroups: List.generate(
                  courses.length,
                  (index) => BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: courses[index].score,
                        gradient: LinearGradient(
                          colors: _getGradientColors(index),
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                        ),
                        width: 20,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}%',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          value.toInt() >= 0 && value.toInt() < courses.length
                              ? courses[value.toInt()].name
                              : '',
                          style: const TextStyle(fontSize: 10),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: scheme.outlineVariant.withAlpha(30),
                    strokeWidth: 0.8,
                  ),
                ),
                borderData: FlBorderData(show: false),
                maxY: 100,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                courses.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildCourseInfo(
                    context,
                    courses[index].name,
                    courses[index].score,
                    courses[index].lessons,
                    _getGradientColors(index).first,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseInfo(
    BuildContext context,
    String name,
    double score,
    int lessons,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50), width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${score.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$lessons পাঠ',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  List<Color> _getGradientColors(int index) {
    final colors = [
      [Color(0xFF93C5FD), Color(0xFF2563EB)],
      [Color(0xFFBFDBFE), Color(0xFF1D4ED8)],
      [Color(0xFF60A5FA), Color(0xFF1E40AF)],
      [Color(0xFFDBEAFE), Color(0xFF3B82F6)],
      [Color(0xFF7DD3FC), Color(0xFF0284C7)],
    ];
    return colors[index % colors.length].map((c) => c).toList();
  }
}

/// Combined Analytics Dashboard
class AnalyticsDashboard extends StatelessWidget {
  const AnalyticsDashboard({
    super.key,
    required this.passed,
    required this.failed,
    required this.pending,
    required this.weekData,
    required this.courses,
  });

  final int passed;
  final int failed;
  final int pending;
  final List<double> weekData;
  final List<({String name, double score, int lessons})> courses;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dashboard Header
            Text(
              'শেখার বিশ্লেষণ',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'আপনার শেখার অগ্রগতি এবং কর্মক্ষমতা ট্র্যাক করুন',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // Quick Stats
            _buildQuickStats(context),
            const SizedBox(height: 24),

            // Quiz Performance Pie Chart
            QuizPerformancePieChart(
              passed: passed,
              failed: failed,
              pending: pending,
            ),
            const SizedBox(height: 24),

            // Learning Progress Line Chart
            LearningProgressLineChart(weekData: weekData),
            const SizedBox(height: 24),

            // Course Performance Bar Chart
            CoursePerformanceBarChart(courses: courses),
            const SizedBox(height: 24),

            // Insights Section
            _buildInsightsCard(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final passRate = (passed / (passed + failed + pending) * 100);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _buildStatCard(
          icon: Icons.quiz_rounded,
          label: 'মোট কুইজ',
          value: '${passed + failed + pending}',
          color: scheme.primary,
        ),
        _buildStatCard(
          icon: Icons.verified_rounded,
          label: 'পাস হার',
          value: '${passRate.toStringAsFixed(0)}%',
          color: scheme.secondary,
        ),
        _buildStatCard(
          icon: Icons.trending_up_rounded,
          label: 'এই সপ্তাহে',
          value: weekData.isEmpty ? '—' : '${weekData.last.toStringAsFixed(0)}%',
          color: scheme.tertiary,
        ),
        _buildStatCard(
          icon: Icons.check_circle_rounded,
          label: 'পাস করা',
          value: '$passed',
          color: scheme.primary,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(20), color.withAlpha(10)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withAlpha(50), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: scheme.primary),
              const SizedBox(width: 12),
              Text(
                'অন্তর্দৃষ্টি',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _generateInsight(),
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _generateInsight() {
    final total = passed + failed + pending;
    final passRate = total == 0 ? 0.0 : (passed / total * 100);
    final avgWeeklyProgress = weekData.isEmpty
        ? 0.0
        : weekData.reduce((a, b) => a + b) / weekData.length;

    if (passRate > 80) {
      return '🎉 দুর্দান্ত! আপনি সব কুইজে ৮০% এর উপরে স্কোর করছেন। এই গতি বজায় রাখুন!';
    } else if (avgWeeklyProgress > 70) {
      return '📈 ভালো অগ্রগতি! এই সপ্তাহে আপনার উপস্থিতি উল্লেখযোগ্য। আরও কিছু পাঠ শেষ করুন।';
    } else if (failed > 3) {
      return '💪 কিছু চ্যালেঞ্জিং বিষয় রয়েছে। এই বিষয়গুলিতে বেশি ফোকাস করুন এবং আবার চেষ্টা করুন।';
    } else {
      return '🚀 আপনি একটি ভাল শুরু করেছেন! নিয়মিত শিখতে থাকুন এবং আপনার লক্ষ্য অর্জন করুন।';
    }
  }
}
