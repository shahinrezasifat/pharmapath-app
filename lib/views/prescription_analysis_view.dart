import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';

import '../services/oxion_assistant.dart';
import '../services/prescription_analyzer.dart';

class PrescriptionAnalysisView extends StatefulWidget {
  const PrescriptionAnalysisView({super.key, required this.image});

  final XFile image;

  @override
  State<PrescriptionAnalysisView> createState() =>
      _PrescriptionAnalysisViewState();
}

class _PrescriptionAnalysisViewState extends State<PrescriptionAnalysisView> {
  late final PrescriptionAnalyzer _analyzer;
  List<PrescriptionMedicine> _medicines = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _analyzer = PrescriptionAnalyzer(assistant: Get.find<OxionAssistant>());
    _analyze();
  }

  Future<void> _analyze() async {
    setState(() {
      _loading = true;
      _error = null;
      _medicines = const [];
    });
    try {
      final result = await _analyzer.analyze(widget.image.path);
      if (!mounted) return;
      setState(() {
        _medicines = result;
        _loading = false;
      });
    } on PrescriptionOfflineException {
      _setError('ইন্টারনেট সংযোগ নেই। সংযোগ দিয়ে আবার চেষ্টা করুন।');
    } on PrescriptionUnreadableException {
      _setError('ছবিটি অস্পষ্ট। দয়া করে পর্যাপ্ত আলোতে পুনরায় ছবি তুলুন।');
    } on FormatException {
      _setError(
        'ছবিটি বিশ্লেষণ করা যায়নি। পরিষ্কার ছবি দিয়ে আবার চেষ্টা করুন।',
      );
    } on Exception catch (error) {
      _setError('বিশ্লেষণ করা যায়নি: $error');
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'প্রেসক্রিপশন বিশ্লেষণ',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.file(
              File(widget.image.path),
              height: 210,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 120,
                color: colors.surfaceContainerHighest,
                child: const Icon(Icons.receipt_long_outlined, size: 40),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (_loading) ...[
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'প্রেসক্রিপশন স্ক্যান করা হচ্ছে…',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _PrescriptionLoadingCards(),
          ] else if (_error != null)
            _AnalysisError(message: _error!, onRetry: _analyze)
          else if (_medicines.isEmpty)
            _NoMedicinesFound()
          else ...[
            Text(
              'প্রেসক্রিপশনে পাওয়া ওষুধ',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              itemCount: _medicines.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final medicine = _medicines[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  color: colors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: colors.primaryContainer,
                          foregroundColor: colors.onPrimaryContainer,
                          child: const Icon(Icons.medication_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                medicine.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                medicine.dosageRules,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      height: 1.5,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            const _VerificationNotice(),
          ],
        ],
      ),
    );
  }
}

class _PrescriptionLoadingCards extends StatelessWidget {
  const _PrescriptionLoadingCards();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colors.surfaceContainerHighest,
      highlightColor: colors.surface,
      child: Column(
        children: List.generate(
          3,
          (_) => Container(
            height: 88,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalysisError extends StatelessWidget {
  const _AnalysisError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onErrorContainer),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('আবার চেষ্টা করুন'),
          ),
        ],
      ),
    );
  }
}

class _NoMedicinesFound extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: colors.primary, size: 32),
          const SizedBox(height: 8),
          const Text(
            'কোনো ওষুধের নাম শনাক্ত হয়নি। ছবিটি পরিষ্কার কি না যাচাই করুন।',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _VerificationNotice extends StatelessWidget {
  const _VerificationNotice();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'এআই প্রেসক্রিপশনের লেখা ভুল পড়তে পারে। ওষুধ খাওয়ার আগে প্রেসক্রিপশনের সঙ্গে নাম ও নিয়ম মিলিয়ে নিন; সন্দেহ হলে চিকিৎসক বা ফার্মাসিস্টকে জিজ্ঞেস করুন।',
        style: TextStyle(color: colors.onTertiaryContainer, height: 1.45),
      ),
    );
  }
}
