import 'package:flutter/material.dart';
import 'package:get/get.dart';

import './image_api_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Image API Client Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ImageApiTestPage(),
    );
  }
}

class ImageApiTestPage extends StatefulWidget {
  const ImageApiTestPage({super.key});

  @override
  State<ImageApiTestPage> createState() => _ImageApiTestPageState();
}

class _ImageApiTestPageState extends State<ImageApiTestPage> {
  late final ImageApiClient _imageApi;
  final _testMedicines = [
    {
      'brand': 'Napa 500mg',
      'generic': 'Paracetamol',
      'company': 'Square Pharmaceuticals',
    },
    {
      'brand': 'Seclo 20mg',
      'generic': 'Omeprazole',
      'company': 'Beximco Pharmaceuticals',
    },
    {
      'brand': 'Amoxicillin 500mg',
      'generic': 'Amoxicillin',
      'company': 'ACI Limited',
    },
    {
      'brand': 'Metformin 850mg',
      'generic': 'Metformin',
      'company': 'Drug International',
    },
  ];

  final _testCompanies = [
    'Square Pharmaceuticals Ltd',
    'Beximco Pharmaceuticals',
    'ACI Limited',
    'Drug International',
    'Incepta Pharmaceuticals',
    'Healthcare Pharmaceuticals',
    'Opsonin Pharma Limited',
    'Renata Limited',
  ];

  List<String>? _medicineImages;
  Map<String, String?>? _companyLogos;
  String? _validationResult;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _imageApi = ImageApiClient();
  }

  @override
  void dispose() {
    _imageApi.dispose();
    super.dispose();
  }

  Future<void> _testMedicineImageSearch() async {
    setState(() {
      _isLoading = true;
      _medicineImages = null;
      _error = null;
    });

    try {
      final medicine = _testMedicines.first;
      final images = await _imageApi.searchMedicineImages(
        brandName: medicine['brand']!,
        genericName: medicine['generic'],
        company: medicine['company'],
        limit: 5,
      );

      setState(() {
        _medicineImages = images;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testSingleMedicineImage() async {
    setState(() {
      _isLoading = true;
      _medicineImages = null;
      _error = null;
    });

    try {
      final medicine = _testMedicines[1];
      final imageUrl = await _imageApi.getMedicineImageUrl(
        brandName: medicine['brand']!,
        genericName: medicine['generic'],
        company: medicine['company'],
      );

      setState(() {
        _medicineImages = imageUrl != null ? [imageUrl] : [];
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testCompanyLogos() async {
    setState(() {
      _isLoading = true;
      _companyLogos = null;
      _error = null;
    });

    try {
      final logos = await _imageApi.getCompanyLogoUrls(_testCompanies);

      setState(() {
        _companyLogos = logos;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testSingleCompanyLogo() async {
    setState(() {
      _isLoading = true;
      _companyLogos = null;
      _error = null;
    });

    try {
      final company = _testCompanies.first;
      final logoUrl = await _imageApi.getCompanyLogoUrl(company);

      setState(() {
        _companyLogos = {company: logoUrl};
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testImageValidation() async {
    setState(() {
      _isLoading = true;
      _validationResult = null;
      _error = null;
    });

    try {
      const testUrl = 'https://picsum.photos/seed/test/200/200';
      final validation = await _imageApi.validateImageUrl(testUrl);

      setState(() {
        _validationResult = validation != null
            ? 'Valid: ${validation['valid']}\n'
                  'Content Type: ${validation['contentType']}\n'
                  'Content Length: ${validation['contentLength']}'
            : 'Validation failed';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildTestCard({
    required String title,
    required String description,
    required VoidCallback onTest,
    required IconData icon,
    Color? color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: color ?? Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : onTest,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('টেস্ট করুন'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image API Client Test')),
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
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.api, size: 32, color: Colors.green),
                  const SizedBox(height: 8),
                  const Text(
                    'টাস্ক ২: ঔষধ মডেল এনহ্যান্সমেন্ট এবং API ক্লায়েন্ট',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'MatEx API integration, company logo fetching, এবং image validation system তৈরি হয়েছে।',
                    style: TextStyle(color: Colors.green.shade700),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Error display
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Test Cards
            _buildTestCard(
              title: 'ঔষধের ছবি সার্চ',
              description: 'Brand name, generic name এবং company দিয়ে MatEx API থেকে ছবি খোঁজা',
              onTest: _testMedicineImageSearch,
              icon: Icons.medical_services,
              color: Colors.blue,
            ),

            const SizedBox(height: 12),

            _buildTestCard(
              title: 'একটি ঔষধের ছবি',
              description: 'Single medicine এর জন্য primary image URL পাওয়া',
              onTest: _testSingleMedicineImage,
              icon: Icons.image_search,
              color: Colors.purple,
            ),

            const SizedBox(height: 12),

            _buildTestCard(
              title: 'কোম্পানি লোগো (একটি)',
              description: 'Single company এর জন্য logo URL পাওয়া',
              onTest: _testSingleCompanyLogo,
              icon: Icons.business,
              color: Colors.orange,
            ),

            const SizedBox(height: 12),

            _buildTestCard(
              title: 'কোম্পানি লোগো (ব্যাচ)',
              description: 'Multiple companies এর জন্য batch logo URLs পাওয়া',
              onTest: _testCompanyLogos,
              icon: Icons.business_center,
              color: Colors.teal,
            ),

            const SizedBox(height: 12),

            _buildTestCard(
              title: 'ইমেজ ভ্যালিডেশন',
              description: 'Image URL এর accessibility এবং metadata check করা',
              onTest: _testImageValidation,
              icon: Icons.verified,
              color: Colors.green,
            ),

            const SizedBox(height: 32),

            // Results Section
            if (_medicineImages != null) ...[
              const Text(
                'ঔষধের ছবি রেজাল্ট',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('পাওয়া গেছে: ${_medicineImages!.length}টি ছবি'),
              const SizedBox(height: 12),

              if (_medicineImages!.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _medicineImages!.length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 160,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                                child: Image.network(
                                  _medicineImages![index],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value:
                                                loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                : null,
                                          ),
                                        );
                                      },
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(
                                        Icons.error,
                                        color: Colors.red,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                'ছবি ${index + 1}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
            ],

            if (_companyLogos != null) ...[
              const Text(
                'কোম্পানি লোগো রেজাল্ট',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('পাওয়া গেছে: ${_companyLogos!.length}টি লোগো'),
              const SizedBox(height: 12),

              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _companyLogos!.entries.map((entry) {
                  return Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: entry.value != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  entry.value!,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value:
                                                loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                : null,
                                          ),
                                        );
                                      },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Text(
                                        _getCompanyInitials(entry.key),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Center(
                                child: Text(
                                  _getCompanyInitials(entry.key),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 80,
                        child: Text(
                          entry.key.split(' ').first,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            if (_validationResult != null) ...[
              const Text(
                'ইমেজ ভ্যালিডেশন রেজাল্ট',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _validationResult!,
                  style: const TextStyle(fontFamily: 'Monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, size: 24, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'টাস্ক ২ এর ফিচারসমূহ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '✓ ঔষধ মডেলে imageUrl এবং companyLogoUrl ফিল্ড যোগ করা হয়েছে\n'
                    '✓ MatEx API integration (medicine images)\n'
                    '✓ Company logo fetching service\n'
                    '✓ Batch processing for multiple logos\n'
                    '✓ Image URL validation system\n'
                    '✓ Fallback mechanisms (placeholder, initials)\n'
                    '✓ Error handling and caching support',
                    style: TextStyle(color: Colors.blue.shade800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'পরবর্তী ধাপ: হোম পেজ হেডার রিডিজাইন',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
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

  String _getCompanyInitials(String companyName) {
    final words = companyName.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (companyName.length >= 2) {
      return companyName.substring(0, 2).toUpperCase();
    }
    return companyName.toUpperCase();
  }
}
