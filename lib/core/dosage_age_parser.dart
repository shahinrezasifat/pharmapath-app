import 'package:flutter/material.dart';
import '../models/medicine.dart';

/// Structured dosage details for a specific age group.
class DosageAgeTier {
  const DosageAgeTier({
    required this.category,
    required this.name,
    required this.ageRange,
    required this.badge,
    required this.dose,
    required this.howToTake,
    required this.warnings,
    required this.icon,
    required this.accentColor,
  });

  /// Category identifier: 'child', 'adult', 'elderly'
  final String category;

  /// Bengali display name ('বাচ্চা', 'যুবক', 'বয়স্ক')
  final String name;

  /// Detailed age span ('০ মাস - ১১ বছর', '১২ - ৫৯ বছর', '৬০+ বছর')
  final String ageRange;

  /// Badge label for UI chips
  final String badge;

  /// Specific dosage instructions
  final String dose;

  /// Consumption guidelines (food, water, timing)
  final String howToTake;

  /// Precautions and safety advice
  final String warnings;

  /// Icon representing the age tier
  final IconData icon;

  /// Distinct theme accent color
  final Color accentColor;
}

/// Parses or synthesizes accurate, age-stratified dosage guidance for any medicine.
abstract final class DosageAgeParser {
  /// Extracts or generates 3 distinct tiers: [বাচ্চা], [যুবক], [বয়স্ক].
  static List<DosageAgeTier> parse(Medicine medicine, String rawDosageText) {
    final lowerGeneric = (medicine.genericName ?? '').toLowerCase();
    final lowerForm = (medicine.dosageForm ?? '').toLowerCase();
    final isSyrup = lowerForm.contains('syrup') || lowerForm.contains('suspension') || lowerForm.contains('drop');
    final isDrop = lowerForm.contains('drop');
    final isInjection = lowerForm.contains('injection') || lowerForm.contains('infusion');
    final isTopical = lowerForm.contains('cream') || lowerForm.contains('ointment') || lowerForm.contains('gel');

    // ─────────────────────────────────────────────────────────────────────────
    // 1. CHILD TIER (বাচ্চা: ০ মাস - ১১ বছর)
    // ─────────────────────────────────────────────────────────────────────────
    String childDose;
    String childHowToTake;
    String childWarning;

    if (lowerGeneric.contains('paracetamol')) {
      childDose = 'শরীরের প্রতি কেজি ওজনের জন্য ১০ থেকে ১৫ মি.গ্রা. হিসেবে দিনে সর্বোচ্চ ৪ বার (প্রতি ৪-৬ ঘণ্টা পর পর)। ৩ দিনের বেশি অবিরাম নয়।';
      childHowToTake = 'পরিমাপক চামচ বা ড্রপার দিয়ে মাপুন। খালি বা ভরা পেটে খাওয়ানো যায়।';
      childWarning = 'একই সাথে প্যারাসিটামলযুক্ত অন্য কোনো ঠান্ডা বা কাশির সিরাপ খাওয়াবেন না।';
    } else if (lowerGeneric.contains('cefixime') || lowerGeneric.contains('amoxicillin')) {
      childDose = 'শরীরের ওজনের ভিত্তিতে প্রতি কেজি ওজনে ৮-১৫ মি.গ্রা. দৈনিক ২টি বিভক্ত মাত্রায় (প্রতি ১২ ঘণ্টা পর পর)। টানা ৭-১০ দিন।';
      childHowToTake = 'বোতল ভালো করে ঝাঁকিয়ে সমপরিমাণ ফুটিয়ে ঠান্ডা করা পানিতে তৈরি করুন। খাবারের সাথে বা পরে দিন।';
      childWarning = 'অ্যান্টিবায়োটিকের পূর্ণাঙ্গ কোর্স শেষ করুন, জ্বর কমলেও কোর্স অসম্পূর্ণ রাখবেন না।';
    } else if (lowerGeneric.contains('montelukast')) {
      childDose = '৬ মাস - ৫ বছর: ৪ মি.গ্রা. চিউয়েবল ট্যাবলেট বা গ্র্যানুলস দিনে ১ বার। ৬-১৪ বছর: ৫ মি.গ্রা. চিউয়েবল ট্যাবলেট দিনে ১ বার সন্ধ্যায়।';
      childHowToTake = 'চিবিয়ে খাওয়ার ট্যাবলেট দাঁত দিয়ে চিবিয়ে খেতে হবে। রাতে ঘুমানোর পূর্বে খাওয়ানো শ্রেয়।';
      childWarning = 'হঠাৎ শ্বাসকষ্টের তীব্র আক্রমণে রেসকিউ ইনহেলার ব্যবহার করতে হবে।';
    } else if (lowerGeneric.contains('ciprofloxacin') || lowerGeneric.contains('levofloxacin')) {
      childDose = '১৮ বছরের নিচের শিশুদের জন্য ফ্লুরোকুইনোলন সাধারণত অনুমোদিত নয়; কেবল চিকিৎসকের অতি জরুরি ব্যবস্থাপত্রে সীমিত।';
      childHowToTake = 'শুধুমাত্র পেডিয়াট্রিক বিশেষজ্ঞ চিকিৎসকের পরামর্শ অনুযায়ী সুনির্দিষ্ট মাত্রায়।';
      childWarning = 'শিশুদের অস্থিসন্ধির তরুণাস্থি সুরক্ষায় নিজ থেকে শিশুদের সেবন করানো সম্পূর্ণ নিষিদ্ধ।';
    } else if (lowerGeneric.contains('esomeprazole') || lowerGeneric.contains('omeprazole')) {
      childDose = '১ বছরের ঊর্ধ্ব শিশুদের জন্য ওজনের ভিত্তিতে ১০-২০ মি.গ্রা. দিনে একবার সকালে খালি পেটে।';
      childHowToTake = 'পাউডার বা স্যাচেট হলে পানিতে গুলিয়ে, ক্যাপসুল হলে না চিবিয়ে পানির সাথে গিলতে হবে।';
      childWarning = 'শিশুর তীব্র পেটব্যথা বা বমি থাকলে চিকিৎসকের পরীক্ষা ব্যতীত গ্যাস্ট্রিকের ওষুধ খাওয়াবেন না।';
    } else if (lowerGeneric.contains('domperidone')) {
      childDose = '০.২ থেকে ০.৪ মি.গ্রা./কেজি শরীরের ওজন প্রতি ৮ ঘণ্টা পর পর (দিনে ৩ বার)। ড্রপস বা সিরাপ।';
      childHowToTake = 'খাবার বা দুধ খাওয়ানোর ১৫ থেকে ৩০ মিনিট পূর্বে খালি পেটে দিতে হবে।';
      childWarning = 'নির্দিষ্ট বয়সের ড্রপার দিয়ে সঠিক ড্রপ মেপে দিন। অতিরিক্ত মাত্রা দেওয়া যাবে না।';
    } else if (isDrop) {
      childDose = '১ থেকে ২ ফোঁটা আক্রান্ত চোখ বা কানে দিনে ২ থেকে ৩ বার।';
      childHowToTake = 'ড্রপারের মুখ চোখ বা কানে স্পর্শ করবেন না। ড্রপ দেওয়ার পর কিছুক্ষণ চোখ বন্ধ রাখতে বলুন।';
      childWarning = 'শিশুকে স্থির রেখে সাবধানে ড্রপ দিন যাতে চোখের মণিতে আঘাত না লাগে।';
    } else if (isTopical) {
      childDose = 'আক্রান্ত স্থানে দিনে ১-২ বার পাতলা স্তরে হালকাভাবে মেখে দিন।';
      childHowToTake = 'স্থানটি পরিষ্কার ও শুকনা করে লাগান। ব্যবহারের পূর্বে ও পরে হাত ধুয়ে নিন।';
      childWarning = 'শিশুর চোখ বা মুখের সংস্পর্শ থেকে সাবধানে রাখুন।';
    } else if (isSyrup) {
      childDose = 'চিকিৎসকের পরামর্শ অনুযায়ী বয়স ও ওজনের ভিত্তিতে আধা চামচ থেকে এক চামচ দিনে ২-৩ বার।';
      childHowToTake = 'বোতল ব্যবহারের পূর্বে ভালোভাবে ঝাঁকিয়ে পরিমাপক চামচ দিয়ে সেবন করান।';
      childWarning = 'পরিমাপের জন্য সাধারণ গৃহস্থালি চামচ নয়, বোতলের সাথে থাকা দাগাঙ্কিত কাপ ব্যবহার করুন।';
    } else {
      childDose = 'শিশুদের জন্য এই প্রাপ্তবয়স্ক ট্যাবলেট ফর্মুলেশন সরাসরি প্রযোজ্য নয়। চিকিৎসকের পরামর্শে পেডিয়াট্রিক ড্রপ বা সিরাপ ব্যবহার্য।';
      childHowToTake = 'শিশুর ওজন ও বয়স অনুযায়ী পেডিয়াট্রিক চিকিৎসকের নির্দেশনা অনুযায়ী দিন।';
      childWarning = 'প্রাপ্তবয়স্কদের ট্যাবলেট ভেঙে শিশুদের খাওয়াবেন না; উপযুক্ত পেডিয়াট্রিক ফর্মুলেশন সংগ্রহ করুন।';
    }

    final childTier = DosageAgeTier(
      category: 'child',
      name: 'বাচ্চা',
      ageRange: '০ মাস - ১১ বছর',
      badge: 'শিশু ও কিশোর (বাচ্চাদের ডোজ)',
      dose: childDose,
      howToTake: childHowToTake,
      warnings: childWarning,
      icon: Icons.child_care_rounded,
      accentColor: const Color(0xFF00897B), // Teal
    );

    // ─────────────────────────────────────────────────────────────────────────
    // 2. ADULT TIER (যুবক: ১২ - ৬০ বছর)
    // ─────────────────────────────────────────────────────────────────────────
    String adultDose;
    String adultHowToTake;
    String adultWarning;

    if (rawDosageText.isNotEmpty) {
      final adultMatch = RegExp(r'প্রাপ্তবয়স্ক[^:]*:\s*([^শিশুদের]+)', caseSensitive: false).firstMatch(rawDosageText);
      if (adultMatch != null && adultMatch.group(1)!.trim().length > 10) {
        adultDose = adultMatch.group(1)!.trim();
      } else {
        adultDose = rawDosageText.split('শিশুদের')[0].trim();
      }
    } else {
      adultDose = 'চিকিৎসকের ব্যবস্থাপত্র অনুযায়ী নির্ধারিত শক্তি ও সময়সূচিতে নিয়মিত সেবন করুন।';
    }

    if (lowerGeneric.contains('prazole')) {
      adultHowToTake = 'প্রতিদিন সকালে প্রধান খাবার বা নাস্তার অন্তত ৩০ থেকে ৬০ মিনিট পূর্বে খালি পেটে প্রচুর পানিসহ।';
      adultWarning = 'ট্যাবলেট বা ক্যাপসুল চিবিয়ে বা গুঁড়ো করবেন না; সম্পূর্ণ গিলে সেবন করুন।';
    } else if (lowerGeneric.contains('fenac') || lowerGeneric.contains('ibuprofen') || lowerGeneric.contains('naproxen') || lowerGeneric.contains('ketorolac')) {
      adultHowToTake = 'গ্যাস্ট্রিকের জ্বালাপোড়া এড়াতে অবশ্যই ভারী খাবারের পর এক গ্লাস পানিসহ সেব্য।';
      adultWarning = 'খালি পেটে খাবেন না। চিকিৎসকের পরামর্শে সাথে পিপিআই (যেমন এসোমিপ্রাজল) গ্রহণ করুন।';
    } else if (lowerGeneric.contains('cillin') || lowerGeneric.contains('cef') || lowerGeneric.contains('floxacin') || lowerGeneric.contains('azithromycin')) {
      adultHowToTake = 'প্রতিদিন ঘড়ির কাঁটা ধরে নির্দিষ্ট বিরতিতে (৮/১২ ঘণ্টা পর পর) নিয়মিত সময়ে সেবন করুন।';
      adultWarning = 'অ্যান্টিবায়োটিকের সম্পূর্ণ কোর্স শেষ করুন। কোর্স অসম্পূর্ণ রাখলে জীবাণু প্রতিরোধী হয়ে পড়ে।';
    } else if (isTopical) {
      adultHowToTake = 'আক্রান্ত ত্বকে হালকা স্তরে দিনে ২-৩ বার ম্যাসাজ করে প্রয়োগ করুন।';
      adultWarning = 'চোখ, নাক ও মুখের সংস্পর্শ এড়িয়ে চলুন। ক্ষতস্থান পরিষ্কার রাখুন।';
    } else if (isInjection) {
      adultHowToTake = 'শিরায় (IV) বা মাংসপেশিতে (IM) শুধুমাত্র নিবন্ধিত স্বাস্থ্যকর্মীর তত্ত্বাবধানে প্রয়োগযোগ্য।';
      adultWarning = 'ইনজেকশন প্রস্তুত করার পর দ্রুত প্রয়োগ করতে হবে। নিজে বাসায় প্রয়োগ করবেন না।';
    } else {
      adultHowToTake = 'নিয়মিত সময়ে এক গ্লাস বিশুদ্ধ পানিসহ সেবন করুন। না চিবিয়ে সম্পূর্ণ গিলে খান।';
      adultWarning = 'ডোজ ভুলে গেলে মনে পড়ার সাথে সাথে নিন, তবে পরবর্তী ডোজের সময় কাছাকাছি হলে ডাবল ডোজ খাবেন না।';
    }

    final adultTier = DosageAgeTier(
      category: 'adult',
      name: 'যুবক',
      ageRange: '১২ - ৬০ বছর',
      badge: 'প্রাপ্তবয়স্ক ও যুবক (পূর্ণবয়স্কদের ডোজ)',
      dose: adultDose,
      howToTake: adultHowToTake,
      warnings: adultWarning,
      icon: Icons.person_rounded,
      accentColor: const Color(0xFF1E88E5), // Blue
    );

    // ─────────────────────────────────────────────────────────────────────────
    // 3. ELDERLY TIER (বয়স্ক: ৬০+ বছর)
    // ─────────────────────────────────────────────────────────────────────────
    String elderlyDose;
    String elderlyHowToTake;
    String elderlyWarning;

    if (lowerGeneric.contains('fenac') || lowerGeneric.contains('ibuprofen') || lowerGeneric.contains('ketorolac')) {
      elderlyDose = 'বয়োজ্যেষ্ঠদের ক্ষেত্রে ন্যূনতম কার্যকর মাত্রা (Lowest effective dose) দিয়ে চিকিৎসা শুরু করতে হবে। স্বল্পতম মেয়াদের জন্য ব্যবহার্য।';
      elderlyHowToTake = 'অবশ্যই ভারী খাবারের পর গ্যাস্ট্রিক প্রোটেক্টরসহ (যেমন এসোমিপ্রাজল) পর্যাপ্ত পানিসহ সেবনীয়।';
      elderlyWarning = 'কিডনি ও হার্টের রোগে বিশেষ সতর্কতা প্রয়োজন। একটানা দীর্ঘমেয়াদী ব্যথানাশক সেবন পরিহার করুন।';
    } else if (lowerGeneric.contains('metformin') || lowerGeneric.contains('gliclazide')) {
      elderlyDose = 'কিডনির ফিল্ট্রেশন রেট (eGFR) এবং রক্তে সুগারের মাত্রা নিয়মিত পরীক্ষা সাপেক্ষে নিয়ন্ত্রিত মাত্রায় সেবনীয়।';
      elderlyHowToTake = 'প্রধান খাবারের সাথে বা খাবারের পর পর সেব্য। কখনোই না খেয়ে খালি পেটে ডায়াবেটিসের ওষুধ খাবেন না।';
      elderlyWarning = 'সুগার কমে যাওয়ার (হাইপোগ্লাইসেমিয়া) ঝুঁকিতে সবসময় সাথে ক্যান্ডি বা গ্লুকোজ রাখুন।';
    } else if (lowerGeneric.contains('clonazepam') || lowerGeneric.contains('alprazolam') || lowerGeneric.contains('pregabalin')) {
      elderlyDose = 'স্বাভাবিক প্রাপ্তবয়স্ক মাত্রার অর্ধেক (০.২৫-০.৫ মি.গ্রা. বা ২৫-৫০ মি.গ্রা.) দিয়ে রাতে ঘুমানোর পূর্বে শুরু করা উত্তম।';
      elderlyHowToTake = 'রাতের খাবারের পর ঘুমানোর পূর্বে সেবন করুন।';
      elderlyWarning = 'মাথা ঘোরা ও ভারসাম্যহীনতায় পড়ে যাওয়ার (Fall risk) ঝুঁকি থাকে; বিছানা থেকে ওঠার সময় সতর্ক থাকুন।';
    } else if (lowerGeneric.contains('ciprofloxacin') || lowerGeneric.contains('levofloxacin')) {
      elderlyDose = 'কিডনি ক্লিয়ারেন্স অনুযায়ী মাত্রা সমন্বয় প্রয়োজন। চিকিৎসকের ব্যবস্থাপত্র অনুযায়ী সেব্য।';
      elderlyHowToTake = 'প্রচুর বিশুদ্ধ পানি পান করুন যাতে প্রস্রাবে ইউরিক অ্যাসিড বা ড্রাগ ক্রিস্টাল না জমে।';
      elderlyWarning = 'বয়স্কদের ক্ষেত্রে টেন্ডন বা পেশির ব্যথার বিষয়ে বিশেষ সতর্কতা অবলম্বন করুন।';
    } else {
      elderlyDose = 'বয়োবৃদ্ধির কারণে লিভার ও কিডনির ধীর বিপাক প্রক্রিয়া বিবেচনা করে চিকিৎসকের পরামর্শে সর্বনিম্ন কার্যকর মাত্রায় শুরু করুন।';
      elderlyHowToTake = 'নিয়মিত নির্দিষ্ট সময়ে পর্যাপ্ত পানিসহ সেবন করুন। গ্যাস্ট্রিক সংবেদনশীলতা থাকলে খাবার পর গ্রহণ করুন।';
      elderlyWarning = 'অন্যান্য নিয়মিত প্রেসক্রিপশন ওষুধের সাথে সময়ের পর্যাপ্ত ব্যবধান রাখুন এবং নিয়মিত রক্তচাপ ও স্বাস্থ্য পরীক্ষা করুন।';
    }

    final elderlyTier = DosageAgeTier(
      category: 'elderly',
      name: 'বয়স্ক',
      ageRange: '৬০+ বছর',
      badge: 'বয়োজ্যেষ্ঠ ও প্রবীণ (সিনিয়র ডোজ)',
      dose: elderlyDose,
      howToTake: elderlyHowToTake,
      warnings: elderlyWarning,
      icon: Icons.elderly_rounded,
      accentColor: const Color(0xFF8E24AA), // Purple
    );

    return [childTier, adultTier, elderlyTier];
  }
}

