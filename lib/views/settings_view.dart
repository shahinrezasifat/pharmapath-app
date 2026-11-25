import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/settings_controller.dart';
import '../core/navigation_mode.dart';
import '../services/app_update_service.dart';
import '../widgets/glass.dart';
import 'about_view.dart';
import 'appearance_settings_view.dart';

import 'package:ai_doctor_module/ai_doctor.dart';

import 'backup_settings_view.dart';
import 'data_management_view.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable – settings kept in case a sub-widget needs it
    final settings = Get.find<SettingsController>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          GestureNavigation.shellContentBottomPadding(context),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 10),
            child: Text(
              'অ্যাপ, ডেটা ও নিরাপত্তা',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SectionTitle(title: 'ব্যক্তিগতকরণ'),
          SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.palette_outlined,
                title: 'চেহারা ও থিম',
                subtitle: 'হালকা, গাঢ় অথবা সিস্টেম অনুযায়ী',
                onTap: () => Get.to(() => const AppearanceSettingsView()),
              ),
              if (kReleaseMode)
                SettingsTile(
                  icon: Icons.system_update_alt_rounded,
                  title: 'আপডেট খুঁজুন',
                subtitle: 'GitHub Releases থেকে নতুন সংস্করণ দেখুন',
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final updater = Get.find<AppUpdateService>();
                  if (!updater.isConfigured) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'এই অ্যাপের GitHub repository কনফিগার করা নেই।',
                        ),
                      ),
                    );
                    return;
                  }
                  try {
                    final release = await updater.checkForUpdate();
                    if (release == null) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('আপনি সর্বশেষ সংস্করণ ব্যবহার করছেন।'),
                        ),
                      );
                    } else if (context.mounted) {
                      await showDialog<void>(
                        context: context,
                        builder: (_) => _SettingsUpdateDialog(
                          updater: updater,
                          release: release,
                        ),
                      );
                    }
                  } catch (error) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('আপডেট খোঁজা যায়নি: $error')),
                    );
                  }
                },
              ),
            ],
          ),
          const SectionTitle(title: 'ডেটা'),
          SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.cloud_download_outlined,
                title: 'অফলাইন ডেটা',
                subtitle: 'ডাউনলোড, সিঙ্ক, সার্ভার ও ডেটাবেসের অবস্থা',
                onTap: () => Get.to(() => const DataManagementView()),
              ),
              SettingsTile(
                icon: Icons.inventory_2_outlined,
                title: 'ব্যাকআপ ও রিস্টোর',
                subtitle: 'ZIP, সম্পূর্ণ ডেটাবেস ও ব্যক্তিগত অগ্রগতির ব্যাকআপ',
                onTap: () => Get.to(() => const BackupSettingsView()),
              ),
            ],
          ),
          const SectionTitle(title: 'সহায়ক'),
          SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.people_alt_outlined,
                title: 'রোগী',
                subtitle: 'রোগীর প্রোফাইল, ওষুধ ও পরামর্শ',
                onTap: () => Get.to(() => const AiDoctorHomePage()),
              ),
            ],
          ),
          const SectionTitle(title: 'তথ্য ও নিরাপত্তা'),
          SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.health_and_safety_outlined,
                title: 'চিকিৎসা সতর্কতা',
                subtitle: 'কখন দ্রুত চিকিৎসা নিতে হবে',
                onTap: () => Get.to(() => const AboutView(kind: 'safety')),
              ),
              SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'গোপনীয়তা ও ডেটা উৎস',
                subtitle: 'ডেটা কোথায় থাকে এবং কখন ইন্টারনেট লাগে',
                onTap: () => Get.to(() => const AboutView(kind: 'privacy')),
              ),
              SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'ফার্মাপাথ সম্পর্কে',
                subtitle: 'সংস্করণ · লাইসেন্স ও সীমাবদ্ধতা',
                onTap: () => Get.to(() => const AboutView(kind: 'about')),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 22, 6, 0),
            child: Text(
              'এই অ্যাপ স্বাধীনভাবে তৈরি; কোনো ওষুধ কোম্পানির সঙ্গে সম্পৃক্ত নয়। '
              'ওষুধ-তথ্য ও শেখার কনটেন্ট শিক্ষামূলক; চিকিৎসকের পরামর্শের বিকল্প নয়।',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsUpdateDialog extends StatelessWidget {
  const _SettingsUpdateDialog({required this.updater, required this.release});

  final AppUpdateService updater;
  final AppRelease release;

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.system_update_alt_rounded),
    title: const Text('নতুন আপডেট এসেছে'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PharmaPath ${release.version}'),
          if (release.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(release.notes),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('বন্ধ করুন'),
      ),
      FilledButton(
        onPressed: updater.openReleasePage,
        child: const Text('GitHub Release খুলুন'),
      ),
    ],
  );
}
