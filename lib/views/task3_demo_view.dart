import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../widgets/redesigned_header.dart';

class Task3DemoView extends StatefulWidget {
  const Task3DemoView({super.key});

  @override
  State<Task3DemoView> createState() => _Task3DemoViewState();
}

class _Task3DemoViewState extends State<Task3DemoView> {
  int _medicineCount = 245;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('টাস্ক ৩: হোম পেজ হেডার রিডিজাইন'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview Section
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withAlpha(50), blurRadius: 10),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Material(
                  color: scheme.surface,
                  child: RedesignedHeader(
                    medicineCount: _medicineCount,
                    onSettings: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('সেটিংস খোলা হবে')),
                      );
                    },
                    onData: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ডেটা ম্যানেজমেন্ট খোলা হবে'),
                        ),
                      );
                    },
                    onSearch: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('সার্চ খোলা হবে')),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Interactive Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'ইন্টারেক্টিভ নিয়ন্ত্রণ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ঔষধের সংখ্যা পরিবর্তন করুন:'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  value: _medicineCount.toDouble(),
                                  min: 0,
                                  max: 1000,
                                  divisions: 100,
                                  label: '$_medicineCount',
                                  onChanged: (value) {
                                    setState(() {
                                      _medicineCount = value.toInt();
                                    });
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  _medicineCount.toString(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Feature Grid Demo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  const Text(
                    'উন্নত ফিচার গ্রিড',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  RedesignedFeatureGrid(
                    tiles: [
                      RedesignedGridTileData(
                        icon: Icons.add_circle_outline_rounded,
                        label: 'ওষুধ যোগ',
                        subtitle: 'নতুন ওষুধ',
                        backgroundColor: Colors.green,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ওষুধ যোগ করা হবে')),
                          );
                        },
                      ),
                      RedesignedGridTileData(
                        icon: Icons.quiz_rounded,
                        label: 'কুইজ',
                        subtitle: 'পরীক্ষা নিন',
                        backgroundColor: Colors.amber,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('কুইজ শুরু হবে')),
                          );
                        },
                      ),
                      RedesignedGridTileData(
                        icon: Icons.storage_rounded,
                        label: 'ডেটা',
                        subtitle: 'সিঙ্ক করুন',
                        backgroundColor: Colors.cyan,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('ডেটা ম্যানেজমেন্ট খোলা হবে'),
                            ),
                          );
                        },
                      ),
                      RedesignedGridTileData(
                        icon: Icons.tune_rounded,
                        label: 'সেটিংস',
                        subtitle: 'পছন্দ',
                        backgroundColor: Colors.blueGrey,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('সেটিংস খোলা হবে')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Promo Banner Demo
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  const Text(
                    'প্রমো ব্যানার',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  RedesignedPromoBanner(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('AI সহায়ক খোলা হবে')),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Features List
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'নতুন বৈশিষ্ট্যসমূহ',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureCard(
                    icon: Icons.design_services,
                    title: 'Material Design 3',
                    description: 'সর্বশেষ Material ডিজাইন নীতিমালা অনুসরণ',
                    color: Colors.purple,
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureCard(
                    icon: Icons.blur_on,
                    title: 'Glassmorphism',
                    description: 'আধুনিক ফ্রস্টেড গ্লাস ইফেক্ট',
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureCard(
                    icon: Icons.dashboard_customize,
                    title: 'উন্নত লেআউট',
                    description: 'উন্নত ভিজ্যুয়াল হায়ারার্কি এবং স্পেসিং',
                    color: Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureCard(
                    icon: Icons.animation,
                    title: 'মসৃণ ট্রানজিশন',
                    description: 'সব ইন্টারঅ্যাকশনে মসৃণ অ্যানিমেশন',
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureCard(
                    icon: Icons.palette,
                    title: 'ডায়নামিক রঙ',
                    description: 'থিমের সাথে স্বয়ংক্রিয় রঙ সমন্বয়',
                    color: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureCard(
                    icon: Icons.info_outline,
                    title: 'উন্নত তথ্য প্রদর্শন',
                    description: 'স্ট্যাটিস্টিক্স এবং তথ্য সুন্দরভাবে দেখানো',
                    color: Colors.teal,
                  ),
                ],
              ),
            ),

            // Implementation Details
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.primary.withAlpha(100)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.code, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'প্রযুক্তিগত বাস্তবায়ন',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '✓ RedesignedHeader widget - প্রধান হেডার কম্পোনেন্ট\n'
                    '✓ RedesignedFeatureGrid - উন্নত ফিচার গ্রিড\n'
                    '✓ RedesignedPromoBanner - প্রমো ব্যানার\n'
                    '✓ RedesignedSectionTitle - সেকশন শিরোনাম\n'
                    '✓ Glassmorphism effects - ফ্রস্টেড গ্লাস ইফেক্ট\n'
                    '✓ Dynamic color scheme - থিম-সচেতন রঙ\n'
                    '✓ Responsive design - সব ডিভাইসে কাজ করে\n'
                    '✓ Accessibility - অ্যাক্সেসিবিলিটি সমর্থন',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                ],
              ),
            ),

            // Completion Status
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green.shade50, Colors.green.shade100],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Column(
                children: [
                  Icon(Icons.check_circle, size: 48, color: Colors.green),
                  SizedBox(height: 12),
                  Text(
                    'টাস্ক ৩ সম্পূর্ণ!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'হোম পেজ হেডার সফলভাবে রিডিজাইন হয়েছে।\n'
                    'Material Design 3 নীতিমালা অনুসরণ করে তৈরি।\n\n'
                    'পরবর্তী ধাপ: টাস্ক ৪ - কুইক অ্যাকশন এবং ফিচার গ্রিড',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF388E3C), height: 1.5),
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

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha(30),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
