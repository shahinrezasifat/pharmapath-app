import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'task3_demo_view.dart';

class Task3SummaryView extends StatelessWidget {
  const Task3SummaryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('টাস্ক ১-৩: ফাউন্ডেশন সম্পন্ন')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade100, Colors.indigo.shade100],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                children: [
                  Icon(Icons.build, size: 48, color: Colors.blue),
                  SizedBox(height: 12),
                  Text(
                    'ফাউন্ডেশন সম্পূর্ণ!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'টাস্ক ১, ২, এবং ৩ সফলভাবে সম্পন্ন হয়েছে',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF1976D2)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Progress Overview
            const Text(
              'অগ্রগতি সারাংশ',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'সম্পন্ন হয়েছে',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '৩/১৩ টাস্ক',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: 3 / 13,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '২৩% সম্পূর্ণ',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Task Completion Cards
            const Text(
              'সম্পন্ন টাস্কসমূহ',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _buildTaskCard(
              number: 1,
              title: 'ইমেজ লোডিং ইনফ্রাস্ট্রাকচার',
              items: [
                'Progressive image loading',
                'Caching system',
                'Placeholder with initials',
                'Error handling',
                'Shimmer effects',
              ],
              color: Colors.green,
            ),

            const SizedBox(height: 12),

            _buildTaskCard(
              number: 2,
              title: 'ঔষধ মডেল এনহ্যান্সমেন্ট',
              items: [
                'MatEx API integration',
                'Company logo system',
                'Batch processing',
                'Image validation',
                'Fallback mechanisms',
              ],
              color: Colors.blue,
            ),

            const SizedBox(height: 12),

            _buildTaskCard(
              number: 3,
              title: 'হোম পেজ হেডার রিডিজাইন',
              items: [
                'Material Design 3',
                'Glassmorphism effects',
                'Dynamic color scheme',
                'Improved layout',
                'Better visual hierarchy',
              ],
              color: Colors.purple,
            ),

            const SizedBox(height: 32),

            // Next Steps
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.trending_up, color: Colors.amber),
                      SizedBox(width: 8),
                      Text(
                        'পরবর্তী ধাপ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF57F17),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'টাস্ক ৪: কুইক অ্যাকশন এবং ফিচার গ্রিড রিডিজাইন\n\n'
                    '• Glassmorphic cards\n'
                    '• Animation effects\n'
                    '• New icon set\n'
                    '• Improved interactions',
                    style: TextStyle(color: Color(0xFFEF6C00), height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('টাস্ক ৩ ডেমো দেখুন'),
                    onPressed: () => Get.to(() => const Task3DemoView()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Technical Achievement
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.engineering, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'প্রযুক্তিগত অর্জন',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AchievementItem('✓ Progressive image loading system'),
                      _AchievementItem('✓ Multi-source image API integration'),
                      _AchievementItem('✓ Material Design 3 implementation'),
                      _AchievementItem('✓ Glassmorphism effects'),
                      _AchievementItem('✓ Dynamic color adaptation'),
                      _AchievementItem('✓ Responsive layout system'),
                      _AchievementItem('✓ Error handling & fallback'),
                      _AchievementItem('✓ Performance optimized'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard({
    required int number,
    required String title,
    required List<String> items,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(100)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withAlpha(30),
                    ),
                    child: Center(
                      child: Text(
                        '$number',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withAlpha(30),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'সম্পূর্ণ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle, color: color, size: 24),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items
                    .map(
                      (item) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withAlpha(50)),
                        ),
                        child: Text(
                          item,
                          style: TextStyle(fontSize: 11, color: color),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementItem extends StatelessWidget {
  const _AchievementItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF388E3C),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
