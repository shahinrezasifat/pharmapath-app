import 'package:flutter/material.dart';

import '../widgets/progress_charts.dart';

/// Task 7 Demo: Advanced Progress Visualization with Charts
class Task7DemoView extends StatefulWidget {
  const Task7DemoView({super.key});

  @override
  State<Task7DemoView> createState() => _Task7DemoViewState();
}

class _Task7DemoViewState extends State<Task7DemoView> {
  late List<double> _weekData;
  late List<({String name, double score, int lessons})> _courseData;

  @override
  void initState() {
    super.initState();
    // Sample week data (percentage per day)
    _weekData = [65.0, 70.0, 72.0, 78.0, 82.0, 85.0, 88.0];

    // Sample course data
    _courseData = [
      (name: 'শরীর ও রোগ', score: 85.0, lessons: 12),
      (name: 'ওষুধের মূলকথা', score: 78.0, lessons: 10),
      (name: 'ফার্মেসি ও চিকিৎসা', score: 92.0, lessons: 15),
      (name: 'রোগ নির্ণয়', score: 70.0, lessons: 8),
      (name: 'চিকিৎসা নির্দেশিকা', score: 88.0, lessons: 11),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Task 7: উন্নত চার্ট এবং বিশ্লেষণ'),
        centerTitle: true,
      ),
      body: AnalyticsDashboard(
        passed: 12,
        failed: 3,
        pending: 5,
        weekData: _weekData,
        courses: _courseData,
      ),
    );
  }
}

/// Individual chart demo pages (optional - for testing)
class ChartShowcaseView extends StatefulWidget {
  const ChartShowcaseView({super.key});

  @override
  State<ChartShowcaseView> createState() => _ChartShowcaseViewState();
}

class _ChartShowcaseViewState extends State<ChartShowcaseView> {
  int _selectedChart = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('চার্ট প্রদর্শনী'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tab Selector
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('পাই চার্ট'),
                icon: Icon(Icons.pie_chart_rounded),
              ),
              ButtonSegment(
                value: 1,
                label: Text('লাইন চার্ট'),
                icon: Icon(Icons.trending_up_rounded),
              ),
              ButtonSegment(
                value: 2,
                label: Text('বার চার্ট'),
                icon: Icon(Icons.bar_chart_rounded),
              ),
            ],
            selected: {_selectedChart},
            onSelectionChanged: (value) {
              setState(() => _selectedChart = value.first);
            },
          ),
          const SizedBox(height: 24),

          // Chart Display
          if (_selectedChart == 0)
            Column(
              children: [
                QuizPerformancePieChart(passed: 12, failed: 3, pending: 5),
                const SizedBox(height: 24),
                _buildChartInfo(context, 'পাই চার্ট - কুইজ পারফরম্যান্স', [
                  '✓ কুইজ স্ট্যাটাস ভিজ্যুয়ালাইজেশন',
                  '✓ প্রতিটি সেক্টর ইন্টারেক্টিভ',
                  '✓ শতাংশ লেবেল প্রদর্শন',
                  '✓ কাস্টম লেজেন্ড',
                  '✓ টাচ-বন্ধুত্বপূর্ণ ডিজাইন',
                ]),
              ],
            )
          else if (_selectedChart == 1)
            Column(
              children: [
                LearningProgressLineChart(
                  weekData: [65.0, 70.0, 72.0, 78.0, 82.0, 85.0, 88.0],
                ),
                const SizedBox(height: 24),
                _buildChartInfo(context, 'লাইন চার্ট - সাপ্তাহিক অগ্রগতি', [
                  '✓ মসৃণ বক্ররেখা প্রদর্শন',
                  '✓ গ্রেডিয়েন্ট ফিলিং প্রভাব',
                  '✓ দৈনিক পয়েন্ট চিহ্নিত করা',
                  '✓ গ্রিড লাইন সহ পটভূমি',
                  '✓ গতিশীল অক্ষ লেবেল',
                ]),
              ],
            )
          else
            Column(
              children: [
                CoursePerformanceBarChart(
                  courses: [
                    (name: 'শরীর ও রোগ', score: 85.0, lessons: 12),
                    (name: 'ওষুধের মূলকথা', score: 78.0, lessons: 10),
                    (name: 'ফার্মেসি ও চিকিৎসা', score: 92.0, lessons: 15),
                    (name: 'রোগ নির্ণয়', score: 70.0, lessons: 8),
                  ],
                ),
                const SizedBox(height: 24),
                _buildChartInfo(context, 'বার চার্ট - কোর্স পারফরম্যান্স', [
                  '✓ মাল্টি-কোর্স তুলনা',
                  '✓ গ্রেডিয়েন্ট রঙিন বার',
                  '✓ বিস্তারিত তথ্য কার্ড',
                  '✓ স্ক্রোলযোগ্য লেআউট',
                  '✓ দৃষ্টি-বান্ধব ডিজাইন',
                ]),
              ],
            ),

          const SizedBox(height: 32),

          // Feature Cards
          _buildFeatureCard(
            context,
            icon: Icons.insights_rounded,
            title: 'স্মার্ট অন্তর্দৃষ্টি',
            description: 'AI-চালিত পরামর্শ আপনার কর্মক্ষমতা উপর ভিত্তি করে স্বয়ংক্রিয়ভাবে উত্পন্ন হয়।',
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.article_rounded,
            title: 'এক্সপোর্ট সক্ষমতা',
            description:
                'আপনার অগ্রগতি প্রতিবেদন PNG বা PDF হিসাবে রপ্তানি করুন।',
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.trending_up_rounded,
            title: 'লক্ষ্য ট্র্যাকিং',
            description:
                'ব্যক্তিগত শেখার লক্ষ্য সেট করুন এবং অগ্রগতি ট্র্যাক করুন।',
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildChartInfo(
    BuildContext context,
    String title,
    List<String> features,
  ) {
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
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(fontSize: 13, color: scheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withAlpha(100),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withAlpha(50),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withAlpha(30),
            ),
            child: Icon(icon, color: scheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
