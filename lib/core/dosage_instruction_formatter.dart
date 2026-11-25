import 'format.dart';
import 'json_utils.dart';

enum DosageInstructionKind { general, adult, maximum, child }

class DosageInstruction {
  const DosageInstruction({
    required this.kind,
    required this.title,
    required this.text,
  });

  final DosageInstructionKind kind;
  final String title;
  final String text;
}

abstract final class DosageInstructionFormatter {
  static final _sectionMarker = RegExp(
    r'(adult(?:s)?(?:\s+dose)?|maximum(?:\s+daily)?\s+dose|child(?:ren)?(?:\s+dose)?|'
    r'প্রাপ্তবয়স্ক(?:দের)?(?:\s+ডোজ)?|সর্বোচ্চ(?:\s+দৈনিক)?\s+ডোজ|শিশুদের?(?:\s+ডোজ)?)\s*:\s*',
    caseSensitive: false,
  );

  static List<DosageInstruction> format(String source) {
    final text = stripHtml(source)
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
    if (text.isEmpty) return const [];

    final markers = _sectionMarker.allMatches(text).toList();
    if (markers.isEmpty) {
      return [
        DosageInstruction(
          kind: DosageInstructionKind.general,
          title: 'ডোজ ও ব্যবহারবিধি',
          text: _translateBody(text, DosageInstructionKind.general),
        ),
      ];
    }

    final result = <DosageInstruction>[];
    for (var index = 0; index < markers.length; index++) {
      final marker = markers[index];
      final kind = _kindOf(marker.group(1)!);
      final end = index + 1 < markers.length
          ? markers[index + 1].start
          : text.length;
      final body = text
          .substring(marker.end, end)
          .replaceAll(RegExp(r'^[\s.;,]+|[\s.;,]+$'), '')
          .trim();
      if (body.isEmpty) continue;
      result.add(
        DosageInstruction(
          kind: kind,
          title: _titleOf(kind),
          text: _translateBody(body, kind),
        ),
      );
    }

    if (result.isEmpty) {
      return [
        DosageInstruction(
          kind: DosageInstructionKind.general,
          title: 'ডোজ ও ব্যবহারবিধি',
          text: _unavailableTranslation,
        ),
      ];
    }
    return result;
  }

  static DosageInstructionKind _kindOf(String marker) {
    final normalized = marker.toLowerCase();
    if (normalized.startsWith('maximum') || normalized.startsWith('সর্বোচ্চ')) {
      return DosageInstructionKind.maximum;
    }
    if (normalized.startsWith('child') || normalized.startsWith('শিশু')) {
      return DosageInstructionKind.child;
    }
    if (normalized.startsWith('adult') ||
        normalized.startsWith('প্রাপ্তবয়স্ক')) {
      return DosageInstructionKind.adult;
    }
    return DosageInstructionKind.general;
  }

  static String _titleOf(DosageInstructionKind kind) => switch (kind) {
    DosageInstructionKind.adult => 'প্রাপ্তবয়স্কদের ডোজ',
    DosageInstructionKind.maximum => 'সর্বোচ্চ ডোজ',
    DosageInstructionKind.child => 'শিশুদের ডোজ',
    DosageInstructionKind.general => 'ডোজ ও ব্যবহারবিধি',
  };

  static String _translateBody(String body, DosageInstructionKind kind) {
    final childRestriction = RegExp(
      r'not recommended for (?:use in )?children (?:below|under)\s+(\d+)\s+years?(?:\s+of age)?',
      caseSensitive: false,
    ).firstMatch(body);
    if (childRestriction != null) {
      return '${bn(childRestriction.group(1)!)} বছরের কম বয়সী শিশুদের জন্য সুপারিশ করা হয় না।';
    }

    final rangeWithInterval = RegExp(
      r'^(\d+)\s*[-–]\s*(\d+)\s*(tablets?|capsules?|pills?)\s+(?:every|each)\s+(\d+)\s*[-–]\s*(\d+)\s+hours?\.?$',
      caseSensitive: false,
    ).firstMatch(body.trim());
    if (rangeWithInterval != null) {
      final unit = _unitName(rangeWithInterval.group(3)!);
      return 'প্রতি ${bn(rangeWithInterval.group(4)!)}–${bn(rangeWithInterval.group(5)!)} ঘণ্টা পরপর '
          '${bn(rangeWithInterval.group(1)!)}–${bn(rangeWithInterval.group(2)!)}টি $unit।';
    }

    final maximumDaily = RegExp(
      r'^(\d+)\s*(tablets?|capsules?|pills?)\s+(?:daily|per day|a day)\.?$',
      caseSensitive: false,
    ).firstMatch(body.trim());
    if (kind == DosageInstructionKind.maximum && maximumDaily != null) {
      return 'দিনে সর্বোচ্চ ${bn(maximumDaily.group(1)!)}টি ${_unitName(maximumDaily.group(2)!)}।';
    }

    if (!RegExp(r'[A-Za-z]').hasMatch(body)) {
      return bn(body.trim());
    }
    return _unavailableTranslation;
  }

  static String _unitName(String raw) {
    final unit = raw.toLowerCase();
    if (unit.startsWith('capsule')) return 'ক্যাপসুল';
    if (unit.startsWith('pill')) return 'বড়ি';
    return 'ট্যাবলেট';
  }

  static const _unavailableTranslation =
      'এই নির্দেশনার বাংলা অনুবাদ পাওয়া যায়নি। চিকিৎসক বা ফার্মাসিস্টের পরামর্শ নিন।';
}
