const _banglaDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

String bn(Object value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    if (rune >= 0x30 && rune <= 0x39) {
      buffer.write(_banglaDigits[rune - 0x30]);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

String bnDate(DateTime? value) {
  if (value == null) return 'কখনো নয়';
  const months = [
    'জানুয়ারি',
    'ফেব্রুয়ারি',
    'মার্চ',
    'এপ্রিল',
    'মে',
    'জুন',
    'জুলাই',
    'আগস্ট',
    'সেপ্টেম্বর',
    'অক্টোবর',
    'নভেম্বর',
    'ডিসেম্বর',
  ];
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour < 12 ? 'পূর্বাহ্ণ' : 'অপরাহ্ণ';
  return '${bn(value.day)} ${months[value.month - 1]} ${bn(value.year)}, ${bn(hour)}:${bn(minute)} $period';
}

String bnDateFromIso(String? iso) {
  if (iso == null || iso.isEmpty) return 'কখনো নয়';
  final parsed = DateTime.tryParse(iso);
  return parsed == null ? iso : bnDate(parsed.toLocal());
}

String relativeTime(DateTime? value) {
  if (value == null) return 'কখনো নয়';
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'এইমাত্র';
  if (diff.inMinutes < 60) return '${bn(diff.inMinutes)} মিনিট আগে';
  if (diff.inHours < 24) return '${bn(diff.inHours)} ঘণ্টা আগে';
  if (diff.inDays < 30) return '${bn(diff.inDays)} দিন আগে';
  return bnDate(value);
}

/// Converts Bengali numerals ('০'..'৯') in [text] to English ASCII digits ('0'..'9').
String bnToEn(String text) {
  var s = text;
  const bengali = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
  for (int i = 0; i < bengali.length; i++) {
    s = s.replaceAll(bengali[i], '$i');
  }
  return s;
}

