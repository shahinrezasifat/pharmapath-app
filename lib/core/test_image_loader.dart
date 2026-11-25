import 'package:flutter/material.dart';
import 'package:get/get.dart';

import './image_loader.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Image Loader Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ImageLoaderTestPage(),
    );
  }
}

class ImageLoaderTestPage extends StatefulWidget {
  const ImageLoaderTestPage({super.key});

  @override
  State<ImageLoaderTestPage> createState() => _ImageLoaderTestPageState();
}

class _ImageLoaderTestPageState extends State<ImageLoaderTestPage> {
  final _imageUrls = [
    'https://picsum.photos/seed/medicine1/300/200',
    'https://picsum.photos/seed/medicine2/300/200',
    'https://picsum.photos/seed/medicine3/300/200',
    '', // Empty URL to test placeholder
    'https://invalid-url-that-will-fail.com/image.jpg', // Invalid URL to test error
  ];

  final _logoUrls = [
    'https://picsum.photos/seed/logo1/100/100',
    'https://picsum.photos/seed/logo2/100/100',
    '', // Empty URL to test placeholder
    'https://invalid-url-that-will-fail.com/logo.png', // Invalid URL
  ];

  final _companies = [
    'Square Pharmaceuticals Ltd',
    'Beximco Pharmaceuticals',
    'ACI Limited',
    'Drug International',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Loader Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              ImageLoader.clearCache();
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Cache cleared')));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Medicine Images',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Test cases: Valid URLs, Empty URL, Invalid URL',
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
              childAspectRatio: 0.8,
            ),
            itemCount: _imageUrls.length,
            itemBuilder: (context, index) {
              return Column(
                children: [
                  Expanded(
                    child: ImageLoader.medicineImage(
                      imageUrl: _imageUrls[index],
                      medicineName: 'Medicine $index',
                      genericName: index % 2 == 0
                          ? 'Paracetamol'
                          : 'Amoxicillin',
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Case ${index + 1}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 32),
          const Text(
            'Company Logos',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Test cases: Valid logos, Placeholder with initials, Error state',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Company Logos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < _logoUrls.length; i++)
                Column(
                  children: [
                    ImageLoader.companyLogo(
                      logoUrl: _logoUrls[i],
                      companyName: _companies[i % _companies.length],
                      size: 64,
                      backgroundColor: [
                        Colors.blue,
                        Colors.green,
                        Colors.orange,
                        Colors.purple,
                      ][i % 4],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 70,
                      child: Text(
                        _companies[i % _companies.length].split(' ').first,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 32),
          const Text(
            'Advanced Features',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Progressive Loading Example
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Progressive Loading with Shimmer',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ImageLoader.medicineImage(
                    imageUrl: 'https://picsum.photos/seed/progressive/400/300',
                    medicineName: 'Advanced Medicine',
                    genericName: 'Advanced Generic',
                    height: 150,
                    borderRadius: BorderRadius.circular(8),
                    showPlaceholder: true,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Custom Placeholder Example
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Custom Placeholder with Initials',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ImageLoader.medicineImage(
                    imageUrl: '', // Empty URL forces placeholder
                    medicineName: 'Napa Extra',
                    genericName: 'Paracetamol',
                    height: 120,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
          const Center(
            child: Text(
              'ImageLoader implementation complete ✓',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
