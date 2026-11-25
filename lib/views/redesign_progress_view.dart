import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/format.dart';
import 'task3_demo_view.dart';
import 'task6_demo_view.dart';

class RedesignProgressView extends StatelessWidget {
  const RedesignProgressView({super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = [
      {
        'id': 1,
        'title': 'টাস্ক ১: ওষুধের ধরনভিত্তিক প্রতীক',
        'description': 'ছবির বদলে ওষুধের ধরন অনুযায়ী চিহ্ন',
        'status': 'সম্পন্ন',
        'completed': true,
        'demo': null,
      },
      {
        'id': 2,
        'title': 'টাস্ক ২: কোম্পানির লোগো',
        'description': 'ওষুধের তালিকায় কোম্পানির লোগো',
        'status': 'সম্পন্ন',
        'completed': true,
        'demo': null,
      },
      {
        'id': 3,
        'title': 'টাস্ক ৩: হোম পেজ হেডার রিডিজাইন',
        'description': 'Material Design 3 হিরো সেকশন, নতুন search bar',
        'status': 'সম্পন্ন',
        'completed': true,
        'demo': Task3DemoView(),
      },
      {
        'id': 4,
        'title': 'টাস্ক ৪: কুইক অ্যাকশন এবং ফিচার গ্রিড',
        'description': 'Glassmorphic cards, animation effects',
        'status': 'পরিকল্পিত',
        'completed': false,
        'demo': null,
      },
      {
        'id': 5,
        'title': 'টাস্ক ৫: ওষুধের তালিকা',
        'description': 'ছবিহীন তালিকা, ধরনভিত্তিক প্রতীক, লোগো ও দাম',
        'status': 'সম্পন্ন',
        'completed': true,
        'demo': null,
      },
      {
        'id': 6,
        'title': 'টাস্ক ৬: শিক্ষা একাডেমি - ইন্টারেক্টিভ টিউটোরিয়াল',
        'description': 'Tutorial system, progress visualization, achievements',
        'status': 'সম্পন্ন',
        'completed': true,
        'demo': Task6DemoView(),
      },
    ];
    // Every progress number is derived from the same task list, so the chips,
    // bar and caption can never contradict each other.
    final totalTasks = tasks.length;
    final completedTasks = tasks.where((t) => t['completed'] == true).length;
    final progress = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

    return Scaffold(
      appBar: AppBar(title: const Text('ফার্মাপাথ UI রিডিজাইন - অগ্রগতি')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.deepPurple.shade100, Colors.indigo.shade100],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 64,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ফার্মাপাথ UI রিডিজাইন প্রোজেক্ট',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Material Design 3 + মিনিমালিস্টিক + ইমেজ সমৃদ্ধ ইন্টারফেস',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.deepPurple.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Chip(
                        label: Text('${bn(completedTasks)}/${bn(totalTasks)} টাস্ক সম্পন্ন'),
                        backgroundColor: Colors.green,
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                      SizedBox(width: 8),
                      Chip(
                        label: Text('৪৭% ছবি সিস্টেম'),
                        backgroundColor: Colors.blue,
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Progress Overview
            const Text(
              'অগ্রগতি সারসংক্ষেপ',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${bn((progress * 100).round())}% সম্পূর্ণ'),
                Text('${bn(completedTasks)}/${bn(totalTasks)} টাস্ক'),
              ],
            ),

            const SizedBox(height: 32),

            // Tasks List
            const Text(
              'টাস্কসমূহ',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ...tasks.map(
              (task) => _buildTaskCard(
                id: task['id'] as int,
                title: task['title'] as String,
                description: task['description'] as String,
                status: task['status'] as String,
                completed: task['completed'] as bool,
                demo: task['demo'] as Widget?,
              ),
            ),

            const SizedBox(height: 32),

            // Achievements Section
            Container(
              width: double.infinity,
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
                      Icon(Icons.celebration, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'এখন পর্যন্ত অর্জন',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const _AchievementItem(
                    '✓ ওষুধের তালিকা ছবিমুক্ত',
                    'সব ওষুধের জন্য একরকম সহজপাঠ্য তালিকা',
                  ),
                  const _AchievementItem(
                    '✓ ধরন অনুযায়ী ওষুধের প্রতীক',
                    'ট্যাবলেট, ক্যাপসুল, সিরাপ ও অন্যান্য ধরন',
                  ),
                  const _AchievementItem(
                    '✓ কোম্পানি লোগো সিস্টেম তৈরি',
                    'Clearbit + UI-Avatars fallback',
                  ),
                  const _AchievementItem(
                    '✓ কোম্পানির লোগোসহ ওষুধের তালিকা',
                    'ওষুধের ছবি ছাড়াই পরিচিতি ও দাম',
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'পরবর্তী মাইলফলক:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'হোম পেজ হেডার রিডিজাইন সম্পন্ন করা\n'
                          '→ Material Design 3 অনুসরণ\n'
                          '→ নতুন visual hierarchy\n'
                          '→ Improved user experience',
                          style: TextStyle(color: Colors.green.shade800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Text(
                    'ফার্মাপাথ UI রিডিজাইন রোডম্যাপ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'পর্ব ১: ফাউন্ডেশন (টাস্ক ১-৩) - ইমেজ সিস্টেম এবং হোম পেজ\n'
                    'পর্ব ২: শিক্ষা অপশন (টাস্ক ৬-৮) - ইন্টারেক্টিভ টিউটোরিয়াল\n'
                    'পর্ব ৩: এনহ্যান্সমেন্ট (টাস্ক ৯-১২) - পারফরমেন্স এবং টেস্টিং\n'
                    'পর্ব ৪: ডিপ্লয়মেন্ট (টাস্ক ১৩) - ডকুমেন্টেশন এবং রিলিজ',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
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
    required int id,
    required String title,
    required String description,
    required String status,
    required bool completed,
    required Widget? demo,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: completed ? Colors.green : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: completed
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : Text(
                        '$id',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: completed ? Colors.green : Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (demo != null)
                        ElevatedButton(
                          onPressed: () => Get.to(() => demo),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            backgroundColor: Colors.blue.shade50,
                            foregroundColor: Colors.blue,
                          ),
                          child: const Text('ডেমো দেখুন'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'সম্পন্ন':
        return Colors.green;
      case 'পরবর্তী':
        return Colors.orange;
      case 'পরিকল্পিত':
        return Colors.blue;
      case 'চলমান':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

class _AchievementItem extends StatelessWidget {
  const _AchievementItem(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 14, color: Colors.green),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.green.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
