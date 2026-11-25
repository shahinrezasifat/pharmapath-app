import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../app/theme.dart';
import '../controllers/favorites_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/learning_controller.dart';
import '../controllers/search_controller.dart';
import '../controllers/settings_controller.dart';
import '../core/format.dart';
import '../services/backup_service.dart';
import '../widgets/glass.dart';

/// Single home for every backup action. The old settings screen offered the
/// same export/restore operations in two different places; this page keeps one
/// canonical version of each and explains the trade-off between them.
class BackupSettingsView extends StatefulWidget {
  const BackupSettingsView({super.key});

  @override
  State<BackupSettingsView> createState() => _BackupSettingsViewState();
}

class _BackupSettingsViewState extends State<BackupSettingsView> {
  BackupService get _backup => Get.find<BackupService>();

  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('ব্যাকআপ ও রিস্টোর')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(18),
            gradient: AppTheme.heroGradient(context),
            borderColor: Colors.white.withValues(alpha: 0.18),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'আপনার ডেটা আপনার কাছে',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'কোনো ক্লাউড নয়। ফাইল আপনার ডিভাইস বা SD কার্ডে থাকবে।',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle(
            title: 'পোর্টেবল ZIP',
            subtitle: 'SD কার্ড বা ফাইল ম্যানেজারে রাখার জন্য',
          ),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _exportZip,
                    icon: const Icon(Icons.folder_zip_outlined),
                    label: const Text('সম্পূর্ণ ডেটাসেট ZIP এ সেভ'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _restoreZip,
                    icon: const Icon(Icons.unarchive_outlined),
                    label: const Text('ZIP থেকে রিস্টোর'),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'জিপে পুরো ওষুধ ডেটাবেস, পছন্দ ও শেখার অগ্রগতি থাকে। '
                  'এক ডিভাইস থেকে অন্য ডিভাইসে নেওয়া যায় — ইন্টারনেট ছাড়াই।',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SectionTitle(
            title: 'সম্পূর্ণ ডেটাবেস স্ন্যাপশট',
            subtitle: 'দ্রুত ফিরে পাওয়ার জন্য .db কপি',
          ),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _busy ? null : _exportCatalog,
                    icon: const Icon(Icons.dataset_outlined),
                    label: const Text('ডেটাবেস স্ন্যাপশট তৈরি'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _restoreCatalog,
                    icon: const Icon(Icons.settings_backup_restore_rounded),
                    label: const Text('সর্বশেষ স্ন্যাপশট রিস্টোর'),
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle(
            title: 'ব্যক্তিগত ব্যাকআপ',
            subtitle: 'শুধু পছন্দ, ইতিহাস ও শেখার অগ্রগতি',
          ),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _busy ? null : _exportUserBackup,
                    icon: const Icon(Icons.backup_outlined),
                    label: const Text('ব্যক্তিগত ব্যাকআপ তৈরি'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _restoreLatestUserBackup,
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('সর্বশেষ ব্যাকআপ ফিরিয়ে আনুন'),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'API কী কোনো ব্যাকআপে যায় না।',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 18),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Future<void> _exportZip() async {
    await _run(() async {
      final bundle = await _backup.exportCatalogZip();
      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'ZIP ফাইল সেভ করুন (SD কার্ড বা ফাইল ম্যানেজার)',
        fileName: bundle.fileName,
        mimeType: 'application/zip',
        bytes: Uint8List.fromList(bundle.bytes),
      );
      if (savedUri == null) {
        Get.snackbar('বাতিল', 'সেভ করা হয়নি (বাতিল)।');
        return;
      }
      final path = savedUri.scheme == 'file'
          ? savedUri.toFilePath()
          : savedUri.toString();
      Get.snackbar(
        'সেভ সম্পন্ন',
        'সম্পূর্ণ ডেটাসেট জিপ আকারে সেভ হয়েছে:\n$path',
      );
    });
  }

  Future<void> _restoreZip() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'রিস্টোর করতে ZIP ফাইল বেছে নিন',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (file == null) return;
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      Get.snackbar('ব্যর্থ', 'ফাইলটি পড়া যায়নি।');
      return;
    }
    final confirmed = await _confirm(
      'ডেটা রিস্টোর করবেন?',
      '“${file.name}” জিপ থেকে সব ওষুধ, পছন্দ ও অগ্রগতি বর্তমান ডেটাবেসে বসে যাবে। '
          'আগের লোকাল ডেটা প্রতিস্থাপিত হবে।',
    );
    if (!confirmed) return;
    await _run(() async {
      final manifest = await _backup.restoreCatalogFromZip(bytes);
      await _reloadAll();
      final src = manifest['source_base']?.toString();
      final counts = manifest['counts'] as Map?;
      final medicines = counts?['medicines'];
      Get.snackbar(
        'রিস্টোর সম্পন্ন',
        'ডেটা ফিরে এসেছে · ${bn(medicines ?? 0)}টি ওষুধ'
            '${src == null || src.isEmpty ? '' : '\nউৎস সার্ভার: $src'}',
      );
    });
  }

  Future<void> _exportCatalog() async {
    await _run(() async {
      final info = await _backup.exportCatalog();
      final bytes = await info.file.readAsBytes();
      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'ডেটাবেস স্ন্যাপশট সেভ করুন',
        fileName: p.basename(info.file.path),
        mimeType: 'application/octet-stream',
        bytes: bytes,
      );
      if (savedUri == null) {
        Get.snackbar('বাতিল', 'স্ন্যাপশট সেভ করা হয়নি।');
        return;
      }
      Get.snackbar(
        'স্ন্যাপশট তৈরি',
        '${bn((bytes.length / 1048576).ceil())} MB ডেটাবেস সেভ হয়েছে।',
      );
    });
  }

  Future<void> _restoreCatalog() async {
    final snapshots = await _backup.listCatalogSnapshots();
    if (snapshots.isEmpty) {
      Get.snackbar(
        'ব্যাকআপ নেই',
        'আগে একটি সম্পূর্ণ ডেটাবেস স্ন্যাপশট তৈরি করুন।',
      );
      return;
    }
    final latest = snapshots.first;
    final confirmed = await _confirm(
      'সম্পূর্ণ ডেটাবেস রিস্টোর করবেন?',
      '${bnDate(latest.createdAt)}-এর ${bn((latest.bytes / 1048576).ceil())} MB '
          'স্ন্যাপশট দিয়ে বর্তমান সব ওষুধ, পছন্দ ও অগ্রগতি প্রতিস্থাপিত হবে।',
    );
    if (!confirmed) return;
    await _run(() async {
      await _backup.restoreCatalog(latest.file);
      await _reloadAll();
      Get.snackbar('সম্পন্ন', 'সম্পূর্ণ ডেটাবেস রিস্টোর হয়েছে।');
    });
  }

  Future<void> _exportUserBackup() async {
    await _run(() async {
      final info = await _backup.export();
      final bytes = await info.file.readAsBytes();
      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'ব্যক্তিগত ব্যাকআপ সেভ করুন',
        fileName: p.basename(info.file.path),
        mimeType: 'application/json',
        bytes: bytes,
      );
      if (savedUri == null) {
        Get.snackbar('বাতিল', 'ব্যাকআপ সেভ করা হয়নি।');
        return;
      }
      Get.snackbar(
        'ব্যাকআপ তৈরি',
        '${bn((bytes.length / 1024).ceil())} KB ব্যাকআপ সেভ হয়েছে।',
      );
    });
  }

  Future<void> _restoreLatestUserBackup() async {
    final backups = await _backup.listBackups();
    if (backups.isEmpty) {
      Get.snackbar('ব্যাকআপ নেই', 'আগে একটি ব্যক্তিগত ব্যাকআপ তৈরি করুন।');
      return;
    }
    final latest = backups.first;
    final confirmed = await _confirm(
      'ব্যাকআপ ফিরিয়ে আনবেন?',
      '${bnDate(latest.createdAt)}-এর ব্যাকআপ ব্যবহার করা হবে। বর্তমান পছন্দ, '
          'ইতিহাস ও শেখার অগ্রগতি প্রতিস্থাপিত হবে।',
    );
    if (!confirmed) return;
    await _run(() async {
      await _backup.restore(latest.file);
      await _reloadAll();
      Get.snackbar('সম্পন্ন', 'ব্যক্তিগত ব্যাকআপ ফিরিয়ে আনা হয়েছে।');
    });
  }

  Future<void> _reloadAll() async {
    await Get.find<HomeController>().load();
    await Get.find<FavoritesController>().load();
    await Get.find<LearningController>().load();
    await Get.find<MedicineSearchController>().refreshHistory();
    await Get.find<SettingsController>().refreshStats();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      Get.snackbar('ব্যর্থ', '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('হ্যাঁ'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
