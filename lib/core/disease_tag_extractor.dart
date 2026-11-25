import 'package:flutter/material.dart';
import '../models/medicine.dart';

/// Represents a distinct clinical condition or disease that a medicine treats.
class DiseaseTag {
  const DiseaseTag({
    required this.name,
    required this.keywords,
    this.icon,
  });

  /// Bengali display name for the tag (e.g. 'জ্বর', 'মাথাব্যথা', 'গ্যাস্ট্রিক').
  final String name;

  /// Associated search keywords used to find all medicines treating this condition.
  final List<String> keywords;

  /// Optional contextual icon.
  final IconData? icon;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiseaseTag &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

/// Extracts structured, clickable disease tags from medicine indication text.
abstract final class DiseaseTagExtractor {
  /// Well-known medical conditions mapped to search tokens and contextual icons.
  static final List<DiseaseTag> _knownConditions = [
    const DiseaseTag(
      name: 'জ্বর',
      keywords: ['জ্বর', 'fever', 'paracetamol', 'antipyretic', 'তাপমাত্রা'],
      icon: Icons.thermostat_rounded,
    ),
    const DiseaseTag(
      name: 'মাথাব্যথা',
      keywords: ['মাথাব্যথা', 'headache', 'paracetamol', 'মাইগ্রেন', 'ব্যথা'],
      icon: Icons.psychology_rounded,
    ),
    const DiseaseTag(
      name: 'মাইগ্রেন',
      keywords: ['মাইগ্রেন', 'migraine', 'naproxen', 'মাথাব্যথা'],
      icon: Icons.storm_rounded,
    ),
    const DiseaseTag(
      name: 'দাঁতব্যথা',
      keywords: ['দাঁতব্যথা', 'toothache', 'ketorolac', 'aceclofenac', 'দাঁত'],
      icon: Icons.sentiment_very_dissatisfied_rounded,
    ),
    const DiseaseTag(
      name: 'গলাব্যথা',
      keywords: ['গলাব্যথা', 'sore throat', 'ফ্যারিঞ্জাইটিস', 'টনসিলাইটিস', 'গলা'],
      icon: Icons.record_voice_over_rounded,
    ),
    const DiseaseTag(
      name: 'সর্দি-কাশি',
      keywords: ['সর্দি', 'কাশি', 'cold', 'flu', 'হাঁচি', 'fexofenadine', 'paracetamol'],
      icon: Icons.coronavirus_rounded,
    ),
    const DiseaseTag(
      name: 'কাশি',
      keywords: ['কাশি', 'cough', 'ambroxol', 'dextromethorphan', 'শ্লেষ্মা'],
      icon: Icons.masks_rounded,
    ),
    const DiseaseTag(
      name: 'হাঁপানি / অ্যাজমা',
      keywords: ['হাঁপানি', 'অ্যাজমা', 'asthma', 'শ্বাসকষ্ট', 'montelukast', 'salbutamol', 'doxophylline'],
      icon: Icons.air_rounded,
    ),
    const DiseaseTag(
      name: 'শ্বাসকষ্ট',
      keywords: ['শ্বাসকষ্ট', 'dyspnea', 'ব্রঙ্কাইটিস', 'montelukast', 'salbutamol'],
      icon: Icons.air_outlined,
    ),
    const DiseaseTag(
      name: 'ব্রঙ্কাইটিস',
      keywords: ['ব্রঙ্কাইটিস', 'bronchitis', 'ফুসফুস', 'ambroxol', 'azithromycin'],
      icon: Icons.medical_services_rounded,
    ),
    const DiseaseTag(
      name: 'নিউমোনিয়া',
      keywords: ['নিউমোনিয়া', 'pneumonia', 'ceftriaxone', 'azithromycin', 'levofloxacin'],
      icon: Icons.local_hospital_rounded,
    ),
    const DiseaseTag(
      name: 'সাইনুসাইটিস',
      keywords: ['সাইনুসাইটিস', 'sinusitis', 'সাইনুস', 'amoxicillin', 'cefixime', 'levofloxacin'],
      icon: Icons.waves_rounded,
    ),
    const DiseaseTag(
      name: 'টনসিলাইটিস',
      keywords: ['টনসিলাইটিস', 'tonsillitis', 'টনসিল', 'azithromycin', 'cefixime'],
      icon: Icons.sick_rounded,
    ),
    const DiseaseTag(
      name: 'গ্যাস্ট্রিক ও এসিডিটি',
      keywords: ['গ্যাস্ট্রিক', 'এসিডিটি', 'অ্যাসিড', 'acid', 'gastric', 'esomeprazole', 'omeprazole', 'pantoprazole'],
      icon: Icons.local_fire_department_rounded,
    ),
    const DiseaseTag(
      name: 'বুকজ্বালা (GERD)',
      keywords: ['বুকজ্বালা', 'অম্বল', 'heartburn', 'gerd', 'রিফ্লাক্স', 'esomeprazole', 'dexlansoprazole'],
      icon: Icons.whatshot_rounded,
    ),
    const DiseaseTag(
      name: 'পাকস্থলীর আলসার',
      keywords: ['আলসার', 'ulcer', 'peptic', 'ক্ষত', 'esomeprazole', 'omeprazole'],
      icon: Icons.water_drop_rounded,
    ),
    const DiseaseTag(
      name: 'বদহজম',
      keywords: ['বদহজম', 'indigestion', 'dyspepsia', 'পেট ফাঁপা', 'domperidone'],
      icon: Icons.dining_rounded,
    ),
    const DiseaseTag(
      name: 'বমি ও বমি ভাব',
      keywords: ['বমি', 'vomiting', 'nausea', 'বমি ভাব', 'domperidone', 'ondansetron'],
      icon: Icons.mood_bad_rounded,
    ),
    const DiseaseTag(
      name: 'ডায়রিয়া',
      keywords: ['ডায়রিয়া', 'diarrhea', 'পাতলা পায়খানা', 'ors', 'zinc', 'ciprofloxacin'],
      icon: Icons.clean_hands_rounded,
    ),
    const DiseaseTag(
      name: 'আমাশয়',
      keywords: ['আমাশয়', 'amoebiasis', 'dysentery', 'metronidazole'],
      icon: Icons.coronavirus_outlined,
    ),
    const DiseaseTag(
      name: 'পেটব্যথা',
      keywords: ['পেটব্যথা', 'abdominal pain', 'পেটে ব্যথা', 'antispasmodic', 'drotaverine'],
      icon: Icons.healing_rounded,
    ),
    const DiseaseTag(
      name: 'বাতব্যথা ও আর্থ্রাইটিস',
      keywords: ['বাত', 'আর্থ্রাইটিস', 'arthritis', 'osteoarthritis', 'অস্টিওআর্থ্রাইটিস', 'aceclofenac', 'diclofenac'],
      icon: Icons.accessible_rounded,
    ),
    const DiseaseTag(
      name: 'কোমর ও পিঠব্যথা',
      keywords: ['কোমরব্যথা', 'পিঠব্যথা', 'back pain', 'লুম্বাগো', 'aceclofenac', 'naproxen'],
      icon: Icons.airline_seat_recline_extra_rounded,
    ),
    const DiseaseTag(
      name: 'পেশির তীব্র ব্যথা',
      keywords: ['পেশির ব্যথা', 'muscle pain', 'myalgia', 'টান', 'baclofen', 'ibuprofen'],
      icon: Icons.fitness_center_rounded,
    ),
    const DiseaseTag(
      name: 'সায়াটিকা',
      keywords: ['সায়াটিকা', 'sciatica', 'স্নায়ু', 'pregabalin', 'vitamin b'],
      icon: Icons.bolt_rounded,
    ),
    const DiseaseTag(
      name: 'গেঁটেবাত (Gout)',
      keywords: ['গেঁটেবাত', 'gout', 'ইউরিক অ্যাসিড', 'etoricoxib', 'diclofenac'],
      icon: Icons.directions_walk_rounded,
    ),
    const DiseaseTag(
      name: 'মাসিকের ব্যথা',
      keywords: ['মাসিকের ব্যথা', 'dysmenorrhea', 'পিরিয়ড', 'naproxen', 'mefenamic', 'paracetamol'],
      icon: Icons.favorite_border_rounded,
    ),
    const DiseaseTag(
      name: 'অ্যালার্জি',
      keywords: ['অ্যালার্জি', 'allergy', 'হাঁচি', 'fexofenadine', 'cetirizine', 'levocetirizine'],
      icon: Icons.spa_rounded,
    ),
    const DiseaseTag(
      name: 'চুলকানি ও আমবাত',
      keywords: ['চুলকানি', 'আমবাত', 'urticaria', 'itching', 'র‍্যাশ', 'cetirizine', 'fexofenadine'],
      icon: Icons.pan_tool_rounded,
    ),
    const DiseaseTag(
      name: 'দাদ ও ফাঙ্গাস ইনফেকশন',
      keywords: ['দাদ', 'ফাঙ্গাস', 'ছত্রাক', 'fungal', 'ক্যানডিডিয়াসিস', 'fluconazole'],
      icon: Icons.flare_rounded,
    ),
    const DiseaseTag(
      name: 'মূত্রনালীর ইনফেকশন (UTI)',
      keywords: ['মূত্রনালী', 'uti', 'প্রস্রাবে জ্বালা', 'ciprofloxacin', 'cefixime', 'nitrofurantoin'],
      icon: Icons.water_damage_rounded,
    ),
    const DiseaseTag(
      name: 'টাইফয়েড জ্বর',
      keywords: ['টাইফয়েড', 'typhoid', 'cefixime', 'ciprofloxacin', 'azithromycin'],
      icon: Icons.emergency_rounded,
    ),
    const DiseaseTag(
      name: 'উচ্চ রক্তচাপ',
      keywords: ['উচ্চ রক্তচাপ', 'প্রেসার', 'hypertension', 'blood pressure', 'losartan', 'amlodipine', 'bisoprolol'],
      icon: Icons.monitor_heart_rounded,
    ),
    const DiseaseTag(
      name: 'ডায়াবেটিস',
      keywords: ['ডায়াবেটিস', 'রক্তে সুগার', 'diabetes', 'metformin', 'gliclazide', 'glimepiride'],
      icon: Icons.bloodtype_rounded,
    ),
    const DiseaseTag(
      name: 'উচ্চ কোলেস্টেরল',
      keywords: ['কোলেস্টেরল', 'cholesterol', 'লিপিড', 'statin', 'atorvastatin', 'rosuvastatin'],
      icon: Icons.heart_broken_rounded,
    ),
    const DiseaseTag(
      name: 'স্নায়ু ব্যথা ও নিউরোপ্যাথি',
      keywords: ['স্নায়ু', 'নিউরোপ্যাথি', 'হাত-পা অবশ', 'ঝিঁঝিঁ', 'pregabalin', 'vitamin b'],
      icon: Icons.electric_bolt_rounded,
    ),
    const DiseaseTag(
      name: 'কৃমি সংক্রমণ',
      keywords: ['কৃমি', 'worm', 'সুঁতো কৃমি', 'গোলকৃমি', 'albendazole', 'mebendazole'],
      icon: Icons.bug_report_rounded,
    ),
    const DiseaseTag(
      name: 'অনিদ্রা ও অতিরিক্ত উদ্বেগ',
      keywords: ['অনিদ্রা', 'উদ্বেগ', 'ঘুম', 'anxiety', 'insomnia', 'clonazepam', 'alprazolam'],
      icon: Icons.bedtime_rounded,
    ),
    const DiseaseTag(
      name: 'ত্বক ও ক্ষতের ইনফেকশন',
      keywords: ['ত্বক', 'ক্ষত', 'ফোঁড়া', 'সেলুলাইটিস', 'wound', 'flucloxacillin', 'mupirocin'],
      icon: Icons.shield_rounded,
    ),
    const DiseaseTag(
      name: 'অপারেশন পরবর্তী ব্যথা',
      keywords: ['অপারেশন', 'অস্ত্রোপচার', 'সার্জারি', 'post-operative', 'ketorolac', 'diclofenac'],
      icon: Icons.medication_liquid_rounded,
    ),
    const DiseaseTag(
      name: 'ভিটামিন ও পুষ্টিহীনতা',
      keywords: ['ভিটামিন', 'পুষ্টি', 'দুর্বলতা', 'ক্লান্তি', 'calcium', 'vitamin b', 'cholecalciferol'],
      icon: Icons.battery_charging_full_rounded,
    ),
  ];

  /// Extracts relevant disease tags for [medicine] from [indicationText].
  static List<DiseaseTag> extract(Medicine medicine, String? indicationText) {
    final tags = <DiseaseTag>[];
    final seen = <String>{};

    final text = '${indicationText ?? ""} ${medicine.indications ?? ""} ${medicine.therapeuticClass ?? ""}'.toLowerCase();
    final generic = (medicine.genericName ?? '').toLowerCase();

    // 1. Direct matching against known clinical catalog
    for (final condition in _knownConditions) {
      bool matched = false;
      for (final keyword in condition.keywords) {
        if (text.contains(keyword.toLowerCase()) || generic.contains(keyword.toLowerCase())) {
          matched = true;
          break;
        }
      }
      if (matched && seen.add(condition.name)) {
        tags.add(condition);
      }
    }

    // 2. Generic-specific fallbacks if indications text is brief
    if (tags.isEmpty) {
      if (generic.contains('paracetamol')) {
        tags.add(_getByName('জ্বর'));
        tags.add(_getByName('মাথাব্যথা'));
      } else if (generic.contains('prazole')) {
        tags.add(_getByName('গ্যাস্ট্রিক ও এসিডিটি'));
        tags.add(_getByName('বুকজ্বালা (GERD)'));
      } else if (generic.contains('fenac') || generic.contains('ibuprofen')) {
        tags.add(_getByName('বাতব্যথা ও আর্থ্রাইটিস'));
        tags.add(_getByName('পেশির তীব্র ব্যথা'));
      } else if (generic.contains('cillin') || generic.contains('cef') || generic.contains('floxacin')) {
        tags.add(_getByName('টাইফয়েড জ্বর'));
        tags.add(_getByName('মূত্রনালীর ইনফেকশন (UTI)'));
      } else if (generic.contains('fexo') || generic.contains('cetirizine')) {
        tags.add(_getByName('অ্যালার্জি'));
        tags.add(_getByName('সর্দি-কাশি'));
      }
    }

    // 3. Fallback generic tag if still empty
    if (tags.isEmpty) {
      final fallbackName = medicine.genericName != null && medicine.genericName!.isNotEmpty
          ? '${medicine.genericName} সংশ্লিষ্ট রোগ'
          : 'রোগের চিকিৎসা';
      tags.add(DiseaseTag(
        name: fallbackName,
        keywords: [medicine.genericName ?? medicine.brandName, 'চিকিৎসা'],
        icon: Icons.healing_rounded,
      ));
    }

    return tags;
  }

  static DiseaseTag _getByName(String name) {
    return _knownConditions.firstWhere(
      (c) => c.name == name,
      orElse: () => DiseaseTag(
        name: name,
        keywords: [name],
        icon: Icons.healing_rounded,
      ),
    );
  }
}
