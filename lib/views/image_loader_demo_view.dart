import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/image_loader.dart';

class ImageLoaderDemoView extends StatelessWidget {
  const ImageLoaderDemoView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ইমেজ লোডিং ডেমো'),
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.image, size: 32, color: Colors.blue),
                  const SizedBox(height: 8),
                  const Text(
                    'টাস্ক ১: ইমেজ লোডিং ইনফ্রাস্ট্রাকচার',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Progresssive loading, caching, placeholder system তৈরি হয়েছে।',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Status: সম্পন্ন ✓',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section 1: Medicine Images
            const Text(
              'ঔষধের ছবি লোডিং',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Valid URL, Empty URL, এবং Invalid URL এর জন্য টেস্ট',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Medicine Images Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: 5,
              itemBuilder: (context, index) {
                final cases = [
                  {
                    'url':
                        'https://picsum.photos/seed/medicine${index + 1}/300/200',
                    'name': 'নাপা ৫০০',
                    'generic': 'Paracetamol',
                    'desc': 'Valid URL - লোড হবে',
                  },
                  {
                    'url': '',
                    'name': 'সেফ্রাডিন',
                    'generic': 'Cefradine',
                    'desc': 'Empty URL - placeholder',
                  },
                  {
                    'url': 'https://picsum.photos/seed/amoxicillin/300/200',
                    'name': 'অ্যামক্সিসিলিন',
                    'generic': 'Amoxicillin',
                    'desc': 'Valid URL - লোড হবে',
                  },
                  {
                    'url': 'https://invalid-url-that-will-fail.com/image.jpg',
                    'name': 'মেটফর্মিন',
                    'generic': 'Metformin',
                    'desc': 'Invalid URL - error state',
                  },
                  {
                    'url': 'https://picsum.photos/seed/insulin/300/200',
                    'name': 'ইনসুলিন',
                    'generic': 'Insulin',
                    'desc': 'Valid URL - লোড হবে',
                  },
                ];

                final caseData = cases[index];

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Expanded(
                          child: ImageLoader.medicineImage(
                            imageUrl: caseData['url'] as String,
                            medicineName: caseData['name'] as String,
                            genericName: caseData['generic'] as String,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          caseData['name'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          caseData['desc'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Section 2: Company Logos
            const Text(
              'কোম্পানি লোগো লোডিং',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Valid Logo, Placeholder with initials, Error state',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Company Logos Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildLogoCard(
                    logoUrl: 'https://picsum.photos/seed/square/100/100',
                    companyName: 'স্কয়ার ফার্মাসিউটিক্যালস',
                    caseDesc: 'Valid Logo',
                    backgroundColor: Colors.blue,
                  ),
                  const SizedBox(width: 16),
                  _buildLogoCard(
                    logoUrl: '',
                    companyName: 'বেক্সিমকো ফার্মা',
                    caseDesc: 'Placeholder (বেক্সিমকো)',
                    backgroundColor: Colors.green,
                  ),
                  const SizedBox(width: 16),
                  _buildLogoCard(
                    logoUrl: 'https://picsum.photos/seed/aci/100/100',
                    companyName: 'এসিআই লিমিটেড',
                    caseDesc: 'Valid Logo',
                    backgroundColor: Colors.orange,
                  ),
                  const SizedBox(width: 16),
                  _buildLogoCard(
                    logoUrl: 'https://invalid-url.com/logo.png',
                    companyName: 'ড্রাগ ইন্টারন্যাশনাল',
                    caseDesc: 'Error State',
                    backgroundColor: Colors.purple,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Section 3: Advanced Features
            const Text(
              'অ্যাডভান্সড ফিচার',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Progressive loading, Shimmer effect, Initials display',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Progressive Loading Example
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.trending_up, size: 20, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'প্রোগ্রেসিভ লোডিং',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ImageLoader.medicineImage(
                      imageUrl:
                          'https://picsum.photos/seed/progressive/400/300',
                      medicineName: 'এডভান্সড মেডিসিন',
                      genericName: 'Advanced Generic',
                      height: 180,
                      borderRadius: BorderRadius.circular(8),
                      showPlaceholder: true,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'ছবি লোড হওয়ার সময় shimmer effect দেখায়, '
                      'তারপর ধীরে ধীরে ফেড ইন করে।',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Placeholder with Initials
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.text_fields, size: 20, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'ইনিশিয়ালস ডিসপ্লে',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ImageLoader.medicineImage(
                      imageUrl: '', // Empty URL forces placeholder
                      medicineName: 'নাপা এক্সট্রা',
                      genericName: 'Paracetamol',
                      height: 140,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'যদি ছবি না থাকে, ঔষধের প্রথম দুই অক্ষর দেখাবে। '
                      'জেনেরিক নাম থাকলে সেটা ব্যবহার করবে।',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Cache Management
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.storage, size: 20, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'ক্যাশ ম্যানেজমেন্ট',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• ঔষধ ছবি: ৩০ দিন ক্যাশে থাকে\n'
                      '• লোগো: ৬০ দিন ক্যাশে থাকে\n'
                      '• ম্যাক্সিমাম ১০০০টি ঔষধ ছবি\n'
                      '• ম্যাক্সিমাম ৫০০টি লোগো',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.delete),
                      label: const Text('ক্যাশ পরিষ্কার করুন'),
                      onPressed: () {
                        ImageLoader.clearCache();
                        Get.snackbar(
                          'ক্যাশ পরিষ্কার',
                          'সকল ইমেজ ক্যাশ পরিষ্কার করা হয়েছে',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Completion Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green.shade50, Colors.green.shade100],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, size: 48, color: Colors.green),
                  const SizedBox(height: 12),
                  const Text(
                    'টাস্ক ১ সম্পূর্ণ!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ইমেজ লোডিং ইনফ্রাস্ট্রাকচার সফলভাবে তৈরি হয়েছে।\n'
                    'এখন ঔষধ মডেল এনহ্যান্সমেন্ট শুরু করা যাবে।',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.green.shade800),
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

  Widget _buildLogoCard({
    required String logoUrl,
    required String companyName,
    required String caseDesc,
    required Color backgroundColor,
  }) {
    return Column(
      children: [
        ImageLoader.companyLogo(
          logoUrl: logoUrl,
          companyName: companyName,
          size: 80,
          backgroundColor: backgroundColor,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 100,
          child: Column(
            children: [
              Text(
                companyName.split(' ').first,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
              const SizedBox(height: 2),
              Text(
                caseDesc,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
