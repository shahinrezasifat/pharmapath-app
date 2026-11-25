import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../widgets/html_content.dart';
import '../widgets/safety_notice.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key, required this.kind});

  /// `about`, `privacy`, `safety`.
  final String kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = switch (kind) {
      'privacy' => 'গোপনীয়তা ও ডেটা উৎস',
      'safety' => 'চিকিৎসা সতর্কতা',
      _ => 'ফার্মাপাথ সম্পর্কে',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        children: [
          if (kind == 'safety') ...[
            const SafetyNotice(dense: true),
            const SizedBox(height: 16),
            const HtmlContent(
              '<h3>জরুরি অবস্থায়</h3>'
              '<p>শ্বাসকষ্ট, বুকে ব্যথা, অজ্ঞান হওয়া, তীব্র অ্যালার্জি (মুখ/গলা ফুলে যাওয়া), '
              'খিঁচুনি বা সন্দেহজনক অতিরিক্ত ডোজ হলে দেরি না করে Nearby হাসপাতাল/ইমার্জেন্সিতে যান '
              'অথবা জাতীয় জরুরি সেবায় যোগাযোগ করুন।</p>'
              '<h3>অ্যাপ কীভাবে সাহায্য করে</h3>'
              '<p>অ্যাপটি সংরক্ষিত ওষুধ-তথ্য দেখায়, অফলাইনে সার্চ করতে দেয় এবং শেখার উপকরণ দেয়। '
              'এটি রোগ নির্ণয়, প্রেসক্রিপশন বা ডোজ নির্ধারণ করে না।</p>'
              '<h3>AI সম্পর্কে</h3>'
              '<p>AI-এর উত্তর স্বয়ংক্রিয়ভাবে তৈরি এবং ভুল হতে পারে। AI-এর পরামর্শ চিকিৎসকের '
              'পরামর্শের বিকল্প নয়।</p>',
            ),
          ] else if (kind == 'privacy') ...[
            const HtmlContent(
              '<h3>আপনার ডেটা কোথায় থাকে</h3>'
              '<p>ফেভারিট, সার্চ ইতিহাস, শেখার অগ্রগতি, কুইজ ফলাফল — সব এই ডিভাইসের SQLite '
              'ডেটাবেসে থাকে। কোনো অ্যাকাউন্ট লাগে না এবং আমরা কোনো বিশ্লেষণ (analytics) সংগ্রহ করি না।</p>'
              '<h3>কখন ইন্টারনেট ব্যবহার হয়</h3>'
              '<p>শুধু দুটি ক্ষেত্রে: (১) আপনি ডেটাবেস আপডেট চাইলে আপনার নিজের BD Medicine API '
              'সার্ভার থেকে ওষুধের সারসংক্ষেপ নামে; ওষুধ খুললে তার বিস্তারিত তথ্যও সেই সার্ভার থেকে '
              'আসে। (২) AI সহায়কের অন-ডিভাইস মডেলটি প্রথমবার চালু করতে একবার ইন্টারনেট লাগে; এরপর '
              'আপনার সব প্রশ্ন-উত্তর সম্পূর্ণ অফলাইনে, এই ডিভাইসের ভিতরেই হয়।</p>'
              '<h3>AI কী</h3>'
              '<p>AI সহায়ক আপনার ফোনেই চলা একটি ছোট ভাষা-মডেল, যা আপনার নিজের অ্যাপের ওষুধ ও রোগের '
              'ডেটাবেস থেকে তথ্য খুঁজে সহজ বাংলায় বা ইংরেজিতে উত্তর দেয়। আপনার প্রশ্ন ফোনের বাইরে যায় '
              'না; কোনো API কী বা অ্যাকাউন্ট লাগে না।</p>'
              '<h3>ডেটার উৎস</h3>'
              '<p>ওষুধ-তথ্য ${AppConfig.dataSourceName} প্রকল্প থেকে, যা medex.com.bd থেকে সংগৃহীত। '
              'রিপোজিটরিতে কোনো লাইসেন্স ফাইল নেই; তাই ডেটা পুনর্বিতরণের আগে অনুমতি যাচাই করা '
              'আপনার দায়িত্ব। তথ্য ক্লিনিক্যালি যাচাইকৃত হিসেবে দাবি করা হয় না।</p>',
            ),
          ] else ...[
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset('assets/LOGO.jpg', fit: BoxFit.cover),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConfig.appName,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${AppConfig.appNameLatin} · সংস্করণ ${AppConfig.version}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const HtmlContent(
              '<p>ফার্মাপাথ একটি অফলাইন-ফার্স্ট বাংলাদেশি ওষুধ-তথ্য ও শেখার অ্যাপ। '
              'লগইন, সাবস্ক্রিপশন, বিজ্ঞাপন বা পেওয়াল নেই।</p>'
              '<h3>মূল বৈশিষ্ট্য</h3>'
              '<ul><li>SQLite + পূর্ণ-পাঠ্য সার্চ — ইন্টারনেট ছাড়াই ওষুধ খোঁজা</li>'
              '<li>বিস্তারিত ওষুধ-তথ্য, ফেভারিট ও দেখা-ইতিহাস</li>'
              '<li>বাংলা ভাষার পাঠ, কুইজ ও অগ্রগতি</li>'
              '<li>অন-ডিভাইস AI সহায়ক (বাংলা ও ইংরেজি)</li>'
              '<li>লোকাল ব্যাকআপ ও পুনরুদ্ধার</li></ul>'
              '<h3>সীমাবদ্ধতা</h3>'
              '<p>ওষুধ-তথ্য স্বয়ংক্রিয়ভাবে সংগৃহীত; ভুল বা অসম্পূর্ণ থাকতে পারে। কোনো তথ্য '
              'ক্লিনিক্যালি যাচাইকৃত নয়। শেখার কনটেন্ট নমুনা এবং প্রোডাকশনের আগে বিশেষজ্ঞ '
              'পর্যালোচনা প্রয়োজন।</p>',
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ডেটা উৎস',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const SelectableText(
                      AppConfig.dataSourceUrl,
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ডেটা ব্যবহারের আগে উৎসের লাইসেন্স ও অনুমতি যাচাই করুন। '
                      'এই অ্যাপ MedEx বা কোনো ওষুধ কোম্পানির সঙ্গে সম্পৃক্ত নয়।',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
