import 'package:flutter/material.dart';

import 'ai_service.dart';

String aiText(String bangla, String english) =>
    AiDoctorConfig.languageCode == 'bn' ? bangla : english;

String aiLocalizedNumber(int value) {
  final digits = value.toString();
  if (AiDoctorConfig.languageCode != 'bn') return digits;
  const bengaliDigits = '০১২৩৪৫৬৭৮৯';
  return digits.replaceAllMapped(
    RegExp(r'\d'),
    (match) => bengaliDigits[int.parse(match[0]!)],
  );
}

String aiGenderLabel(String gender) {
  if (AiDoctorConfig.languageCode != 'bn') return gender;
  return switch (gender.toLowerCase()) {
    'female' => 'নারী',
    'male' => 'পুরুষ',
    'other' => 'অন্যান্য',
    _ => gender,
  };
}

String aiRelationLabel(String relation) {
  if (AiDoctorConfig.languageCode != 'bn') return relation;
  return switch (relation.toLowerCase()) {
    'self' => 'নিজে',
    'parent' => 'মা-বাবা',
    'child' => 'সন্তান',
    'spouse' => 'স্বামী/স্ত্রী',
    'sibling' => 'ভাই/বোন',
    'grandparent' => 'দাদা-দাদি/নানা-নানি',
    'grandmother' => 'দাদি/নানি',
    'grandfather' => 'দাদা/নানা',
    'relative' => 'আত্মীয়',
    'demo profile' => 'নমুনা প্রোফাইল',
    _ => relation,
  };
}

String aiMedicationUnit(String unit) {
  if (AiDoctorConfig.languageCode != 'bn') return unit;
  return switch (unit.toLowerCase()) {
    'tablet' => 'টি ট্যাবলেট',
    'capsule' => 'টি ক্যাপসুল',
    'ml' => 'মিলিলিটার',
    'drop' || 'drops' => 'ফোঁটা',
    'puff' || 'puffs' => 'পাফ',
    'spoon' || 'teaspoon' => 'চামচ',
    'application' => 'বার প্রয়োগ',
    'dose' => 'মাত্রা',
    _ => unit,
  };
}

String aiDosageFormLabel(String form) {
  if (AiDoctorConfig.languageCode != 'bn') return form;
  return switch (form.toLowerCase()) {
    'tablet' => 'ট্যাবলেট',
    'capsule' => 'ক্যাপসুল',
    'syrup' => 'সিরাপ',
    'suspension' => 'সাসপেনশন',
    'injection' => 'ইনজেকশন',
    'drop' || 'drops' => 'ড্রপ',
    'cream' => 'ক্রিম',
    'ointment' => 'মলম',
    'inhaler' => 'ইনহেলার',
    'suppository' => 'সাপোজিটরি',
    'cream / ointment' => 'ক্রিম/মলম',
    'other' => 'অন্যান্য',
    _ => form,
  };
}

String aiMedicationSince(DateTime startedAt) {
  final days = DateTime.now().difference(startedAt).inDays;
  if (AiDoctorConfig.languageCode != 'bn') {
    if (days < 1) return 'Started today';
    if (days < 30) return 'Started $days ${days == 1 ? 'day' : 'days'} ago';
    if (days < 365) {
      final months = days ~/ 30;
      return 'Started $months ${months == 1 ? 'month' : 'months'} ago';
    }
    final years = days ~/ 365;
    final months = (days % 365) ~/ 30;
    final yearText = 'Started $years ${years == 1 ? 'year' : 'years'} ago';
    return months == 0
        ? yearText
        : '$yearText, $months ${months == 1 ? 'month' : 'months'}';
  }
  if (days < 1) return 'আজ থেকে';
  if (days < 30) return '${aiLocalizedNumber(days)} দিন আগে শুরু';
  if (days < 365) return '${aiLocalizedNumber(days ~/ 30)} মাস আগে শুরু';
  final years = days ~/ 365;
  final months = (days % 365) ~/ 30;
  return months == 0
      ? '${aiLocalizedNumber(years)} বছর আগে শুরু'
      : '${aiLocalizedNumber(years)} বছর ${aiLocalizedNumber(months)} মাস আগে শুরু';
}

String aiDoctorName(String id, String fallback) {
  if (AiDoctorConfig.languageCode != 'bn') return fallback;
  return switch (id) {
    'aftab' => 'ডা. আফতাব উদ্দিন',
    'ariful' => 'ডা. আরিফুল ইসলাম',
    'mahmuda' => 'ডা. মাহমুদা খাতুন',
    'sajid' => 'ডা. সাজিদ করিম',
    _ => fallback,
  };
}

String aiDoctorRole(String value, {required bool vision, required bool fast}) {
  if (AiDoctorConfig.languageCode != 'bn') {
    return '$value'
        '${vision ? ' · Vision' : ''}'
        '${fast ? ' · Fast' : ''}';
  }
  final role = switch (value) {
    'Lead Consultant' => 'প্রধান পরামর্শক',
    'Senior Consultant' => 'জ্যেষ্ঠ পরামর্শক',
    'Consultant' => 'পরামর্শক',
    _ => value,
  };
  return '$role'
      '${vision ? ' · ছবি বিশ্লেষণ' : ''}'
      '${fast ? ' · দ্রুত উত্তর' : ''}';
}

class AiDoctorLanguageButton extends StatelessWidget {
  const AiDoctorLanguageButton({super.key, required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final bangla = AiDoctorConfig.languageCode == 'bn';
    return IconButton(
      tooltip: bangla ? 'ইংরেজিতে দেখুন' : 'বাংলায় দেখুন',
      onPressed: () {
        AiDoctorConfig.setLanguage(bangla ? 'en' : 'bn');
        onChanged();
      },
      icon: Text(
        bangla ? 'ইং' : 'বাং',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
