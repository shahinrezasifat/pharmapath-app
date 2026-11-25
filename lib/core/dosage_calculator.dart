import 'package:flutter/material.dart';
import '../core/format.dart';
import '../models/medicine.dart';

/// Detailed result of calculating medicine dosage for a specific patient age.
class CalculatedDosage {
  const CalculatedDosage({
    required this.ageText,
    required this.categoryName,
    required this.doseAmount,
    required this.milligrams,
    required this.frequency,
    required this.howToTake,
    required this.maxDaily,
    required this.warnings,
    required this.icon,
    required this.accentColor,
  });

  /// The input age in friendly Bengali (e.g. '৪ বছর', '৬ মাস', '৬৮ বছর').
  final String ageText;

  /// The category bracket ('বাচ্চা / শিশু', 'যুবক / প্রাপ্তবয়স্ক', 'বয়স্ক / প্রবীণ').
  final String categoryName;

  /// How much to take in physical units (e.g. '১ চা চামচ (৫ মি.লি.)', '১টি ট্যাবলেট', '২ ফোঁটা').
  final String doseAmount;

  /// Equivalent strength / milligrams (e.g. '১২০ মি.গ্রা.', '৫০০ মি.গ্রা.').
  final String milligrams;

  /// Daily frequency (e.g. 'দিনে ৩ বার (প্রতি ৮ ঘণ্টা পর পর)').
  final String frequency;

  /// Clear administration guidelines (e.g. 'খাবারের পর এক গ্লাস পানিসহ সেব্য').
  final String howToTake;

  /// Maximum permissible intake in 24 hours.
  final String maxDaily;

  /// Specific medical safety precautions for this age.
  final String warnings;

  /// Visual icon for the age group.
  final IconData icon;

  /// Visual accent color.
  final Color accentColor;
}

/// Clinical dosage calculator engine tailored for Bangladesh pharmaceutical catalogue.
abstract final class DosageCalculator {
  /// Calculates structured dosage guidance for [medicine] at [ageYears] and [ageMonths].
  static CalculatedDosage calculate(
    Medicine medicine, {
    required int ageYears,
    int ageMonths = 0,
    double? weightKg,
  }) {
    final totalMonths = (ageYears * 12) + ageMonths;
    final generic = (medicine.genericName ?? '').toLowerCase();
    final form = (medicine.dosageForm ?? '').toLowerCase();
    final strength = (medicine.strength ?? '').trim();

    final isSyrup = form.contains('syrup') || form.contains('suspension');
    final isDrop = form.contains('drop');
    final isTopical = form.contains('cream') || form.contains('ointment') || form.contains('gel');
    final isInjection = form.contains('injection') || form.contains('infusion');

    String ageText;
    if (ageYears == 0) {
      ageText = '${bn(ageMonths)} মাস';
    } else if (ageMonths > 0) {
      ageText = '${bn(ageYears)} বছর ${bn(ageMonths)} মাস';
    } else {
      ageText = '${bn(ageYears)} বছর';
    }

    // ─────────────────────────────────────────────────────────────────────────
    // BRACKET A: INFANT & TODDLER (০ - ২ বছর)
    // ─────────────────────────────────────────────────────────────────────────
    if (totalMonths < 24) {
      if (generic.contains('paracetamol')) {
        final drop = isDrop ? '০.৫ মি.লি. থেকে ১ মি.লি. (ড্রপ)' : 'আধা চা চামচ (২.৫ মি.লি.) সিরাপ';
        return CalculatedDosage(
          ageText: ageText,
          categoryName: 'বাচ্চা (শিশুদের ডোজ)',
          doseAmount: drop,
          milligrams: '৬০ - ১২০ মি.গ্রা. (ওজন অনুযায়ী ১০-১৫ মি.গ্রা./কেজি)',
          frequency: 'দিনে ৩ থেকে ৪ বার (প্রতি ৬ ঘণ্টা পর পর)',
          howToTake: 'পরিমাপক ড্রপার বা চামচ দিয়ে মাপুন। দুধ বা খাবারের পর খাওয়ানো ভালো।',
          maxDaily: '২৪ ঘণ্টায় সর্বোচ্চ ৪ বার; জ্বর কমলে বন্ধ করুন।',
          warnings: 'একই সাথে প্যারাসিটামলযুক্ত অন্য কোনো ঠান্ডা বা কাশির সিরাপ খাওয়াবেন না।',
          icon: Icons.baby_changing_station_rounded,
          accentColor: const Color(0xFF00897B),
        );
      }

      if (generic.contains('cefixime') || generic.contains('amoxicillin')) {
        return CalculatedDosage(
          ageText: ageText,
          categoryName: 'বাচ্চা (শিশুদের ডোজ)',
          doseAmount: 'আধা চা চামচ (২.৫ মি.লি.) পেডিয়াট্রিক সাসপেনশন',
          milligrams: '৫০ - ১০০ মি.গ্রা. (ওজন অনুযায়ী ৮ মি.গ্রা./কেজি)',
          frequency: 'দিনে ২ বার (প্রতি ১২ ঘণ্টা পর পর)',
          howToTake: 'বোতল ভালো করে ঝাঁকিয়ে তৈরি সাসপেনশন খাওয়ান। খাবারের সাথে বা পর পর।',
          maxDaily: 'টানা ৭ থেকে ১০ দিন; কোর্স সম্পূর্ণ করা আবশ্যক।',
          warnings: 'জ্বর কমলেও অ্যান্টিবায়োটিক বন্ধ করবেন না। ডাক্তারের পরামর্শের বাইরে খাওয়াবেন না।',
          icon: Icons.child_care_rounded,
          accentColor: const Color(0xFF00897B),
        );
      }

      if (generic.contains('ciprofloxacin') || generic.contains('levofloxacin') || generic.contains('aceclofenac')) {
        return CalculatedDosage(
          ageText: ageText,
          categoryName: 'বাচ্চা (বিশেষ সতর্কতা)',
          doseAmount: 'শিশুদের জন্য এই ওষুধটি সাধারণত নিষিদ্ধ',
          milligrams: 'শুধুমাত্র বিশেষজ্ঞ চিকিৎসকের লিখিত ব্যবস্থাপত্রে বিশেষ ক্ষেত্রে',
          frequency: 'নিজে থেকে সেবন সম্পূর্ণ নিষেধ',
          howToTake: 'এই বয়সের শিশুদের জন্য এই ওষুধ সরাসরি প্রযোজ্য নয়।',
          maxDaily: '০',
          warnings: 'শিশুদের তরুণাস্থি ও অঙ্গপ্রত্যঙ্গের সুরক্ষায় রেজিস্টার্ড শিশু বিশেষজ্ঞের পরামর্শ নিন।',
          icon: Icons.warning_amber_rounded,
          accentColor: const Color(0xFFD32F2F),
        );
      }

      return CalculatedDosage(
        ageText: ageText,
        categoryName: 'বাচ্চা (শিশুদের ডোজ)',
        doseAmount: isDrop ? '১-২ ফোঁটা' : (isSyrup ? 'আধা চা চামচ (২.৫ মি.লি.)' : 'পেডিয়াট্রিক ড্রপ/সিরাপ'),
        milligrams: 'ওজন ও বয়স অনুপাতে সুনির্দিষ্ট মাত্রা',
        frequency: 'দিনে ২ থেকে ৩ বার (চিকিৎসকের পরামর্শে)',
        howToTake: 'পরিমাপক ড্রপার দিয়ে মেপে তরল আকারে সেব্য।',
        maxDaily: '২৪ ঘণ্টায় চিকিৎসকের নির্দেশিত সর্বোচ্চ সীমা',
        warnings: 'প্রাপ্তবয়স্কদের ট্যাবলেট ভেঙে বাচ্চাদের খাওয়াবেন না।',
        icon: Icons.child_care_rounded,
        accentColor: const Color(0xFF00897B),
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // BRACKET B: CHILD (২ - ১১ বছর)
    // ─────────────────────────────────────────────────────────────────────────
    if (ageYears < 12) {
      if (generic.contains('paracetamol')) {
        final amount = ageYears < 6 ? '১ চা চামচ (৫ মি.লি.) সিরাপ' : '১.৫ থেকে ২ চা চামচ (৭.৫-১০ মি.লি.) বা আধা ট্যাবলেট';
        final mg = ageYears < 6 ? '১২০ - ২৫০ মি.গ্রা.' : '২৫০ - ৫০০ মি.গ্রা.';
        return CalculatedDosage(
          ageText: ageText,
          categoryName: 'বাচ্চা (শিশুদের ডোজ)',
          doseAmount: amount,
          milligrams: mg,
          frequency: 'দিনে ৩ থেকে ৪ বার (প্রতি ৪-৬ ঘণ্টা পর পর)',
          howToTake: 'পরিমাপক কাপ দিয়ে মেপে দিন। পর্যাপ্ত পানিসহ খাবারের আগে বা পরে।',
          maxDaily: '২৪ ঘণ্টায় সর্বোচ্চ ৪ বারের বেশি দেওয়া যাবে না।',
          warnings: 'একটানা ৩ দিনের বেশি জ্বর থাকলে রক্ত পরীক্ষা ও ডাক্তারের পরামর্শ নিন।',
          icon: Icons.child_care_rounded,
          accentColor: const Color(0xFF00897B),
        );
      }

      if (generic.contains('montelukast')) {
        final dose = ageYears <= 5 ? '৪ মি.গ্রা. চিউয়েবল ট্যাবলেট' : '৫ মি.গ্রা. চিউয়েবল ট্যাবলেট';
        return CalculatedDosage(
          ageText: ageText,
          categoryName: 'বাচ্চা (শিশুদের ডোজ)',
          doseAmount: '১টি $dose',
          milligrams: ageYears <= 5 ? '৪ মি.গ্রা.' : '৫ মি.গ্রা.',
          frequency: 'দিনে মাত্র ১ বার (রাতে ঘুমানোর পূর্বে)',
          howToTake: 'চিবিয়ে খাওয়ার ট্যাবলেট দাঁত দিয়ে ভালো করে চিবিয়ে খেতে হবে।',
          maxDaily: '২৪ ঘণ্টায় মাত্র ১টি ট্যাবলেট।',
          warnings: 'হঠাৎ শ্বাসকষ্টের তীব্র আক্রমণে রেসকিউ ইনহেলার ব্যবহার করতে হবে।',
          icon: Icons.child_care_rounded,
          accentColor: const Color(0xFF00897B),
        );
      }

      if (generic.contains('fexofenadine') || generic.contains('cetirizine')) {
        return CalculatedDosage(
          ageText: ageText,
          categoryName: 'বাচ্চা (শিশুদের ডোজ)',
          doseAmount: '১ চা চামচ (৫ মি.লি.) সিরাপ',
          milligrams: generic.contains('fexo') ? '৩০ মি.গ্রা.' : '৫ মি.গ্রা.',
          frequency: 'দিনে ১ থেকে ২ বার',
          howToTake: 'খাবারের সাথে বা খালি পেটে সাধারণ পানিসহ সেব্য।',
          maxDaily: '২৪ ঘণ্টায় সর্বোচ্চ নির্দেশিত মাত্রা।',
          warnings: 'ফলের জুস (কমলা/আঙুরের রস)-এর সাথে খাওয়াবেন না।',
          icon: Icons.child_care_rounded,
          accentColor: const Color(0xFF00897B),
        );
      }

      if (generic.contains('ciprofloxacin') || generic.contains('levofloxacin')) {
        return CalculatedDosage(
          ageText: ageText,
          categoryName: 'বাচ্চা (সতর্কতা)',
          doseAmount: 'সাধারণত এই ওষুধটি শিশুদের জন্য নির্দেশিত নয়',
          milligrams: 'চিকিৎসকের বিশেষ বিবেচনা ব্যতীত নিষেধ',
          frequency: 'চিকিৎসকের পরামর্শ ছাড়া সেবন নিষেধ',
          howToTake: 'বিকল্প শিশু-বান্ধব অ্যান্টিবায়োটিক গ্রহণ শ্রেয়।',
          maxDaily: '০',
          warnings: 'শিশুর অস্থিসন্ধির তরুণাস্থি সুরক্ষায় নিজ থেকে সেবন করাবেন না।',
          icon: Icons.warning_amber_rounded,
          accentColor: const Color(0xFFD32F2F),
        );
      }

      return CalculatedDosage(
        ageText: ageText,
        categoryName: 'বাচ্চা (শিশুদের ডোজ)',
        doseAmount: isSyrup ? '১ চা চামচ (৫ মি.লি.)' : (isTopical ? 'পাতলা স্তর' : 'আধা ট্যাবলেট বা শিশু ফর্মুলেশন'),
        milligrams: 'ওজন ও বয়স অনুযায়ী অনুমোদিত পেডিয়াট্রিক মাত্রা',
        frequency: 'দিনে ২ থেকে ৩ বার',
        howToTake: 'খাবারের পর পর্যাপ্ত পানিসহ সেবন করান।',
        maxDaily: '২৪ ঘণ্টায় চিকিৎসকের নির্দেশিত মাত্রা',
        warnings: 'শিশুদের নাগালের বাইরে রাখুন ও পরিমাপক চামচ ব্যবহার করুন।',
        icon: Icons.child_care_rounded,
        accentColor: const Color(0xFF00897B),
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // BRACKET C: ADULT & YOUTH (১২ - ৫৯ বছর)
    // ─────────────────────────────────────────────────────────────────────────
    if (ageYears < 60) {
      if (generic.contains('paracetamol')) {
        return CalculatedDosage(
          ageText: ageText,
          categoryName: 'যুবক / প্রাপ্তবয়স্ক',
          doseAmount: '১টি থেকে ২টি ট্যাবলেট',
          milligrams: '৫০০ মি.গ্রা. থেকে ১০০০ মি.গ্রা.',
          frequency: 'প্রতি ৪ থেকে ৬ ঘণ্টা পর পর (দিনে সর্বোচ্চ ৪ বার)',
          howToTake: 'এক গ্লাস পানিসহ সেব্য। খালি পেটে বা খাবারের পর খাওয়া যায়।',
          maxDaily: '২৪ ঘণ্টায় সর্বোচ্চ ৪০০০ মি.গ্রা. (৮টি ট্যাবলেট)।',
          warnings: 'অ্যালকোহল পরিহার করুন; একসাথে প্যারাসিটামলযুক্ত অন্য ওষুধ খাবেন না।',
          icon: Icons.person_rounded,
          accentColor: const Color(0xFF1E88E5),
        );
      }

      if (generic.contains('prazole')) {
        final amount = strength.isNotEmpty ? strength : '২০/৪০ মি.গ্রা.';
        return CalculatedDosage(
          ageText: ageText,
          categoryName: 'যুবক / প্রাপ্তবয়স্ক',
          doseAmount: '১টি ক্যাপসুল বা ট্যাবলেট',
          milligrams: amount,
          frequency: 'দিনে ১ বার (তীব্র উপসর্গে সকালে ও রাতে ২ বার)',
          howToTake: 'সকালে নাস্তার অন্তত ৩০ থেকে ৬০ মিনিট পূর্বে খালি পেটে পানিসহ।',
          maxDaily: '২৪ ঘণ্টায় সর্বোচ্চ নির্দেশিত ক্যাপসুল।',
          warnings: 'ক্যাপসুল না ভেঙে বা না চিবিয়ে সম্পূর্ণ গিলে খান।',
          icon: Icons.person_rounded,
          accentColor: const Color(0xFF1E88E5),
        );
      }

      if (generic.contains('fenac') || generic.contains('ibuprofen') || generic.contains('naproxen') || generic.contains('ketorolac')) {
        return CalculatedDosage(
          ageText: ageText,
          categoryName: 'যুবক / প্রাপ্তবয়স্ক',
          doseAmount: '১টি ট্যাবলেট',
          milligrams: strength.isNotEmpty ? strength : 'ব্যথানাশক স্বাভাবিক মাত্রা',
          frequency: 'দিনে ২ বার (সকালে ও রাতে)',
          howToTake: 'অবশ্যই ভারী খাবার বা নাস্তার পর এক গ্লাস পানিসহ।',
          maxDaily: '২৪ ঘণ্টায় সর্বোচ্চ ২টি ট্যাবলেট; একটানা বেশি দিন নয়।',
          warnings: 'খালি পেটে খাবেন না। গ্যাস্ট্রিক সুরক্ষায় সাথে পিপিআই সেবন করুন।',
          icon: Icons.person_rounded,
          accentColor: const Color(0xFF1E88E5),
        );
      }

      if (generic.contains('cillin') || generic.contains('cef') || generic.contains('floxacin') || generic.contains('azithromycin')) {
        return CalculatedDosage(
          ageText: ageText,
          categoryName: 'যুবক / প্রাপ্তবয়স্ক',
          doseAmount: '১টি ট্যাবলেট বা ক্যাপসুল',
          milligrams: strength.isNotEmpty ? strength : 'পূর্ণাঙ্গ থেরাপিউটিক ডোজ',
          frequency: generic.contains('azithromycin') ? 'দিনে মাত্র ১ বার' : 'দিনে ২ বার (প্রতি ১২ ঘণ্টা পর পর)',
          howToTake: 'প্রতিদিন নির্দিষ্ট সময়ে সাধারণ পানিসহ সেব্য।',
          maxDaily: 'সম্পূর্ণ নির্ধারিত কোর্স (৩ থেকে ১৪ দিন) শেষ করা বাধ্যতামূলক।',
          warnings: 'কোর্স অসম্পূর্ণ রাখবেন না; লক্ষণ ভালো হলেও পূর্ণ মেয়াদ গ্রহণ করুন।',
          icon: Icons.person_rounded,
          accentColor: const Color(0xFF1E88E5),
        );
      }

      return CalculatedDosage(
        ageText: ageText,
        categoryName: 'যুবক / প্রাপ্তবয়স্ক',
        doseAmount: isTopical
            ? 'হালকা স্তর'
            : (isInjection
                ? '১টি ভায়াল / অ্যাম্পুল'
                : '১টি ট্যাবলেট / ক্যাপসুল'),
        milligrams: strength.isNotEmpty ? strength : 'স্বাভাবিক প্রাপ্তবয়স্ক মাত্রা',
        frequency: 'দিনে ২ থেকে ৩ বার (চিকিৎসকের পরামর্শ অনুযায়ী)',
        howToTake: isInjection
            ? 'রেজিস্টার্ড চিকিৎসক বা নার্স দ্বারা আইভি/আইএম ইনজেকশন হিসেবে প্রয়োগযোগ্য।'
            : 'পর্যাপ্ত বিশুদ্ধ পানিসহ নিয়মিত সময়ে সেব্য। না চিবিয়ে সম্পূর্ণ গিলে খান।',
        maxDaily: 'চিকিৎসকের প্রেসক্রিপশন অনুযায়ী দৈনিক সর্বোচ্চ সীমা',
        warnings: 'ডোজ ভুলে গেলে পরবর্তী সময়ে ডাবল ডোজ খাবেন না।',
        icon: Icons.person_rounded,
        accentColor: const Color(0xFF1E88E5),
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // BRACKET D: ELDERLY / SENIOR (৬০+ বছর)
    // ─────────────────────────────────────────────────────────────────────────
    if (generic.contains('fenac') || generic.contains('ibuprofen') || generic.contains('ketorolac')) {
      return CalculatedDosage(
        ageText: ageText,
        categoryName: 'বয়স্ক / প্রবীণ (সিনিয়র)',
        doseAmount: '১টি ট্যাবলেট (সর্বনিম্ন কার্যকর মাত্রা)',
        milligrams: 'কম শক্তিসম্পন্ন সর্বনিম্ন ডোজ',
        frequency: 'দিনে ১ থেকে ২ বার (স্বল্পতম মেয়াদের জন্য)',
        howToTake: 'ভারী খাবারের পর গ্যাস্ট্রিক প্রোটেক্টরসহ প্রচুর পানিসহ।',
        maxDaily: 'চিকিৎসকের নির্দেশিত সর্বনিম্ন মাত্রা; দীর্ঘমেয়াদী নয়।',
        warnings: 'কিডনি ও হৃদরোগের ঝুঁকি এড়াতে অহেতুক ব্যথানাশক সেবন পরিহার করুন।',
        icon: Icons.elderly_rounded,
        accentColor: const Color(0xFF8E24AA),
      );
    }

    if (generic.contains('metformin') || generic.contains('gliclazide')) {
      return CalculatedDosage(
        ageText: ageText,
        categoryName: 'বয়স্ক / প্রবীণ (সিনিয়র)',
        doseAmount: '১টি ট্যাবলেট (নিয়ন্ত্রিত মাত্রা)',
        milligrams: strength.isNotEmpty ? strength : 'ডাক্তারের নির্ধারিত সমন্বিত ডোজ',
        frequency: 'দিনে ১ বার প্রধান খাবারের সাথে',
        howToTake: 'খাবারের শুরুতে বা ঠিক পরপরই সেব্য। না খেয়ে ওষুধ খাওয়া নিষেধ।',
        maxDaily: 'প্রেসক্রিপশন অনুযায়ী নিয়মিত সুগার পরিমাপ সাপেক্ষে।',
        warnings: 'রক্তে সুগার কমে যাওয়া (হাইপো) প্রতিরোধে সাথে সবসময় মিষ্টি রাখুন।',
        icon: Icons.elderly_rounded,
        accentColor: const Color(0xFF8E24AA),
      );
    }

    if (generic.contains('clonazepam') || generic.contains('alprazolam') || generic.contains('pregabalin')) {
      return CalculatedDosage(
        ageText: ageText,
        categoryName: 'বয়স্ক / প্রবীণ (সিনিয়র)',
        doseAmount: 'অর্ধেক বা সর্বনিম্ন ট্যাবলেট',
        milligrams: 'স্বাভাবিক প্রাপ্তবয়স্ক মাত্রার অর্ধেক',
        frequency: 'দিনে ১ বার (রাতে ঘুমানোর পূর্বে)',
        howToTake: 'রাতের খাবারের পর শোবার আগে সেব্য।',
        maxDaily: 'সর্বনিম্ন কার্যকর মাত্রা।',
        warnings: 'মাথা ঘোরা ও পড়ে যাওয়ার ঝুঁকিতে শোয়া বা বসা থেকে ধীরে উঠুন।',
        icon: Icons.elderly_rounded,
        accentColor: const Color(0xFF8E24AA),
      );
    }

    return CalculatedDosage(
      ageText: ageText,
      categoryName: 'বয়স্ক / প্রবীণ (সিনিয়র)',
      doseAmount: isTopical
          ? 'পাতলা স্তর'
          : (isInjection
              ? '১টি ভায়াল / নিয়ন্ত্রিত ইনফিউশন'
              : '১টি ট্যাবলেট (নিয়ন্ত্রিত মাত্রা)'),
      milligrams: strength.isNotEmpty ? strength : 'বয়সোপযোগী সর্বনিম্ন মাত্রা',
      frequency: 'দিনে ১ থেকে ২ বার',
      howToTake: isInjection
          ? 'হাসপাতাল বা ক্লিনিকে স্বাস্থ্যকর্মীর সরাসরি তত্ত্বাবধানে প্রয়োগ করতে হবে।'
          : 'খাবার গ্রহণের পর পর্যাপ্ত পানিসহ নিয়মিত সময়ে সেব্য।',
      maxDaily: 'প্রেসক্রিপশন অনুযায়ী সর্বনিম্ন কার্যকর মাত্রা।',
      warnings: 'লিভার ও কিডনির ধীর কার্যকারিতা বিবেচনায় উচ্চমাত্রা সম্পূর্ণ পরিহার্য। অন্যান্য ওষুধের সাথে ব্যবধান রাখুন।',
      icon: Icons.elderly_rounded,
      accentColor: const Color(0xFF8E24AA),
    );
  }
}
