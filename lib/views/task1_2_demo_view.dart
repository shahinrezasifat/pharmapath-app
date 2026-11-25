import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/image_loader.dart';
import '../services/image_api_client.dart';

class Task12DemoView extends StatelessWidget {
  const Task12DemoView({super.key});

  @override
  Widget build(BuildContext context) {
    final imageApi = ImageApiClient();

    return Scaffold(
      appBar: AppBar(
        title: const Text('টাস্ক ১ & ২ ডেমো'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.purple.shade50, Colors.indigo.shade50],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.architecture,
                    size: 48,
                    color: Colors.purple,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ফার্মাপাথ UI রিডিজাইন - প্রোগ্রেস',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'টাস্ক ১ & ২: ইমেজ লোডিং ইনফ্রাস্ট্রাকচার এবং API ইন্টিগ্রেশন',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.purple.shade700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Progress Status
            Row(
              children: [
                Expanded(
                  child: _buildProgressCard(
                    title: 'টাস্ক ১',
                    description: 'ইমেজ লোডিং ইনফ্রাস্ট্রাকচার',
                    status: 'সম্পন্ন',
                    icon: Icons.image,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildProgressCard(
                    title: 'টাস্ক ২',
                    description: 'API ক্লায়েন্ট ও মডেল এনহ্যান্সমেন্ট',
                    status: 'সম্পন্ন',
                    icon: Icons.api,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Integrated Demo Section
            const Text(
              'ইন্টিগ্রেটেড ডেমো: ImageLoader + ImageApiClient',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'দুইটি সিস্টেম একসাথে কাজ করে - API থেকে ছবি আনা, ImageLoader দিয়ে ডিসপ্লে করা',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Demo 1: Medicine with API fetched image
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.medical_services, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'ঔষধ: API থেকে ছবি + ImageLoader',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    FutureBuilder<String?>(
                      future: imageApi.getMedicineImageUrl(
                        brandName: 'Napa 500mg',
                        genericName: 'Paracetamol',
                        company: 'Square Pharmaceuticals',
                      ),
                      builder: (context, snapshot) {
                        final imageUrl = snapshot.data;

                        return Column(
                          children: [
                            ImageLoader.medicineImage(
                              imageUrl: imageUrl,
                              medicineName: 'নাপা ৫০০',
                              genericName: 'প্যারাসিটামল',
                              height: 180,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            const SizedBox(height: 12),

                            if (snapshot.connectionState ==
                                ConnectionState.waiting)
                              const Row(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(width: 8),
                                  Text('API থেকে ছবি আনছি...'),
                                ],
                              )
                            else if (imageUrl != null)
                              const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text('ছবি API থেকে পাওয়া গেছে'),
                                ],
                              )
                            else
                              const Row(
                                children: [
                                  Icon(
                                    Icons.warning,
                                    color: Colors.orange,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'API ছবি দিতে পারেনি, placeholder দেখাচ্ছে',
                                  ),
                                ],
                              ),

                            const SizedBox(height: 8),
                            const Text(
                              'প্রক্রিয়া: 1. ImageApiClient → MatEx API\n'
                              '2. ImageLoader → Caching + Progressive loading\n'
                              '3. Fallback → Initials placeholder',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Demo 2: Company logo integration
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.business, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'কোম্পানি লোগো: API + ImageLoader',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    FutureBuilder<String?>(
                      future: imageApi.getCompanyLogoUrl(
                        'Square Pharmaceuticals Ltd',
                      ),
                      builder: (context, snapshot) {
                        final logoUrl = snapshot.data;

                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ImageLoader.companyLogo(
                                  logoUrl: logoUrl,
                                  companyName: 'স্কয়ার ফার্মাসিউটিক্যালস',
                                  size: 100,
                                  backgroundColor: Colors.blue,
                                ),
                                const SizedBox(width: 16),
                                ImageLoader.companyLogo(
                                  logoUrl: null, // Test fallback
                                  companyName: 'বেক্সিমকো ফার্মা',
                                  size: 100,
                                  backgroundColor: Colors.green,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (snapshot.connectionState ==
                                ConnectionState.waiting)
                              const Row(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(width: 8),
                                  Text('লোগো API থেকে আনছি...'),
                                ],
                              )
                            else if (logoUrl != null)
                              const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text('লোগো Clearbit API থেকে পাওয়া গেছে'),
                                ],
                              )
                            else
                              const Row(
                                children: [
                                  Icon(
                                    Icons.warning,
                                    color: Colors.orange,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'API লোগো দিতে পারেনি, initials placeholder দেখাচ্ছে',
                                  ),
                                ],
                              ),

                            const SizedBox(height: 8),
                            const Text(
                              'প্রক্রিয়া: 1. Clearbit/Logo API → Company logo\n'
                              '2. Fallback → UI-Avatars with initials\n'
                              '3. ImageLoader → Caching + Display',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Demo 3: Batch processing
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.batch_prediction, color: Colors.purple),
                        SizedBox(width: 8),
                        Text(
                          'ব্যাচ প্রসেসিং: একাধিক লোগো',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'একসাথে ৪টি কোম্পানির লোগো ফেচ করা হচ্ছে',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    FutureBuilder<Map<String, String?>>(
                      future: imageApi.getCompanyLogoUrls([
                        'Square Pharmaceuticals',
                        'Beximco Pharma',
                        'ACI Limited',
                        'Drug International',
                      ]),
                      builder: (context, snapshot) {
                        final logos = snapshot.data;

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 8),
                                Text('একসাথে ৪টি লোগো আনছি...'),
                              ],
                            ),
                          );
                        }

                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.2,
                          children: (logos?.entries ?? []).map((entry) {
                            return Column(
                              children: [
                                ImageLoader.companyLogo(
                                  logoUrl: entry.value,
                                  companyName: entry.key,
                                  size: 80,
                                  backgroundColor: _getColorForCompany(
                                    entry.key,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  entry.key.split(' ').first,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                ),
                              ],
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Demo 4: Real-time medicine search
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.search, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'রিয়েল-টাইম ঔষধ ছবি সার্চ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'MatEx API দিয়ে ঔষধের জন্য একাধিক ছবি খোঁজা',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    FutureBuilder<List<String>>(
                      future: imageApi.searchMedicineImages(
                        brandName: 'Amoxicillin 500mg',
                        genericName: 'Amoxicillin',
                        company: 'ACI Limited',
                        limit: 3,
                      ),
                      builder: (context, snapshot) {
                        final images = snapshot.data;

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 8),
                                Text('MatEx API থেকে ছবি সার্চ করছি...'),
                              ],
                            ),
                          );
                        }

                        if (images == null || images.isEmpty) {
                          return const Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.image_not_supported,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text('কোন ছবি পাওয়া যায়নি'),
                              ],
                            ),
                          );
                        }

                        return SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            itemBuilder: (context, index) {
                              return Container(
                                width: 180,
                                margin: EdgeInsets.only(
                                  right: index < images.length - 1 ? 12 : 0,
                                ),
                                child: ImageLoader.medicineImage(
                                  imageUrl: images[index],
                                  medicineName: 'অ্যামক্সিসিলিন ৫০০',
                                  genericName: 'Amoxicillin',
                                  height: 100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(Icons.info, size: 16, color: Colors.blue),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'MatEx API বিভিন্ন ধরনের ছবি দেয়: pack shots, molecular structure, medicine in context',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Technical Summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.teal.shade50, Colors.cyan.shade50],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.engineering, color: Colors.teal),
                      SizedBox(width: 8),
                      Text(
                        'টেকনিকাল অ্যাচিভমেন্ট',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AchievementItem(
                        '✓ Progressive image loading with caching',
                      ),
                      _AchievementItem(
                        '✓ Multiple image source integration (MatEx, Clearbit, UI-Avatars)',
                      ),
                      _AchievementItem(
                        '✓ Intelligent fallback system (initials when images unavailable)',
                      ),
                      _AchievementItem(
                        '✓ Batch processing for performance optimization',
                      ),
                      _AchievementItem(
                        '✓ Medicine model enhanced with imageUrl and companyLogoUrl',
                      ),
                      _AchievementItem('✓ Error handling and retry mechanisms'),
                      _AchievementItem(
                        '✓ Material Design 3 compatible components',
                      ),
                      _AchievementItem('✓ Offline-first architecture support'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'পরবর্তী ধাপ:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'টাস্ক ৩: হোম পেজ হেডার রিডিজাইন\n'
                          '• Material Design 3 হিরো সেকশন\n'
                          '• নতুন gradient effects\n'
                          '• Redesigned search bar\n'
                          '• Modern visual hierarchy',
                          style: TextStyle(color: Colors.teal.shade800),
                        ),
                      ],
                    ),
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

  Widget _buildProgressCard({
    required String title,
    required String description,
    required String status,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        color: color.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Color _getColorForCompany(String companyName) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];

    final index = companyName.hashCode.abs() % colors.length;
    return colors[index];
  }
}

class _AchievementItem extends StatelessWidget {
  const _AchievementItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.teal)),
          Expanded(
            child: Text(text, style: TextStyle(color: Colors.teal.shade800)),
          ),
        ],
      ),
    );
  }
}
