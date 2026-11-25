import 'package:flutter_test/flutter_test.dart';
import 'package:pharmapath_app/core/dosage_calculator.dart';
import 'package:pharmapath_app/core/dosage_instruction_formatter.dart';
import 'package:pharmapath_app/models/medicine.dart';

void main() {
  group('Medicine Section Deduplication', () {
    test('strictly prevents duplicate dosage and administration sections', () {
      final med = Medicine(
        id: 1,
        brandName: 'Napa 500mg',
        genericName: 'Paracetamol',
        dosageAndAdministration: 'Adults: 1-2 tablets every 4 to 6 hours.',
        sections: const {
          'dosage': 'Adults: 500mg - 1000mg',
          'administration': 'Take with water after meals.',
        },
      );

      final sections = med.clinicalSections;
      final dosageSections = sections.where(
        (s) =>
            s.key == 'dosage_and_administration' ||
            s.key == 'dosage' ||
            s.key == 'administration' ||
            s.label.contains('ডোজ'),
      );

      expect(
        dosageSections.length,
        equals(1),
        reason: 'Duplicate dosage sections must be deduplicated into a single entry',
      );
    });

    test('deduplicates alias keys like pregnancy_cat and precautions', () {
      final med = Medicine(
        id: 2,
        brandName: 'Test Med',
        genericName: 'Test',
        pregnancyAndLactation: 'Category B',
        precautionsAndWarnings: 'Monitor liver enzymes',
        sections: const {
          'pregnancy_cat': 'Category B in animals',
          'precautions': 'Check renal function',
        },
      );

      final sections = med.clinicalSections;
      final pregSections = sections.where(
        (s) => s.key == 'pregnancy_and_lactation',
      );
      final precSections = sections.where(
        (s) => s.key == 'precautions_and_warnings',
      );

      expect(pregSections.length, equals(1));
      expect(precSections.length, equals(1));
    });
  });

  group('DosageInstructionFormatter', () {
    test(
      'splits and translates the adult, maximum, and child dose example',
      () {
        final result = DosageInstructionFormatter.format(
          'Adult dose: 1-2 tablets every 4-6 hours. '
          'Maximum dose: 8 tablets daily. '
          'Child dose: Not recommended for children below 12 years.',
        );

        expect(result.map((item) => item.title).toList(), [
          'প্রাপ্তবয়স্কদের ডোজ',
          'সর্বোচ্চ ডোজ',
          'শিশুদের ডোজ',
        ]);
        expect(result[0].text, 'প্রতি ৪–৬ ঘণ্টা পরপর ১–২টি ট্যাবলেট।');
        expect(result[1].text, 'দিনে সর্বোচ্চ ৮টি ট্যাবলেট।');
        expect(
          result[2].text,
          '১২ বছরের কম বয়সী শিশুদের জন্য সুপারিশ করা হয় না।',
        );
        expect(
          result.map((item) => item.text).join(' '),
          isNot(matches(RegExp(r'[A-Za-z]'))),
        );
      },
    );

    test('keeps already-Bengali instructions and localizes their digits', () {
      final result = DosageInstructionFormatter.format(
        'প্রাপ্তবয়স্কদের ডোজ: 1-2টি ট্যাবলেট প্রতি 4-6 ঘণ্টা পরপর।',
      );

      expect(result.single.title, 'প্রাপ্তবয়স্কদের ডোজ');
      expect(result.single.text, '১-২টি ট্যাবলেট প্রতি ৪-৬ ঘণ্টা পরপর।');
    });

    test('does not show an unsupported English dose as Bengali', () {
      final result = DosageInstructionFormatter.format(
        'Take with plenty of water after meals.',
      );

      expect(result.single.title, 'ডোজ ও ব্যবহারবিধি');
      expect(result.single.text, contains('বাংলা অনুবাদ পাওয়া যায়নি'));
      expect(result.single.text, isNot(matches(RegExp(r'[A-Za-z]'))));
    });
  });

  group('DosageCalculator Age-Specific Calculations', () {
    final paracetamolTab = Medicine(
      id: 10,
      brandName: 'Napa Tablet',
      genericName: 'Paracetamol',
      dosageForm: 'Tablet',
      strength: '500 mg',
    );

    final paracetamolSyrup = Medicine(
      id: 11,
      brandName: 'Napa Syrup',
      genericName: 'Paracetamol',
      dosageForm: 'Syrup',
      strength: '120 mg/5 ml',
    );

    test('calculates correct infant dose (< 2 years / in months)', () {
      final result = DosageCalculator.calculate(
        paracetamolSyrup,
        ageYears: 0,
        ageMonths: 8,
      );

      expect(result.ageText, equals('৮ মাস'));
      expect(result.categoryName, contains('বাচ্চা'));
      expect(result.doseAmount, contains('চা চামচ'));
      expect(result.frequency, contains('দিনে ৩ থেকে ৪ বার'));
      expect(result.milligrams, contains('মি.গ্রা.'));
    });

    test('calculates correct child dose (2 - 11 years)', () {
      final result = DosageCalculator.calculate(
        paracetamolSyrup,
        ageYears: 5,
        ageMonths: 0,
      );

      expect(result.ageText, equals('৫ বছর'));
      expect(result.categoryName, contains('বাচ্চা'));
      expect(result.doseAmount, contains('১ চা চামচ'));
      expect(result.milligrams, contains('১২০ - ২৫০ মি.গ্রা.'));
      expect(result.frequency, contains('দিনে ৩ থেকে ৪ বার'));
    });

    test('calculates correct youth/adult dose (12 - 59 years)', () {
      final result = DosageCalculator.calculate(
        paracetamolTab,
        ageYears: 25,
        ageMonths: 0,
      );

      expect(result.ageText, equals('২৫ বছর'));
      expect(result.categoryName, contains('যুবক'));
      expect(result.doseAmount, contains('ট্যাবলেট'));
      expect(result.milligrams, contains('৫০০ মি.গ্রা.'));
      expect(result.frequency, contains('প্রতি ৪ থেকে ৬ ঘণ্টা'));
      expect(result.maxDaily, contains('৪০০০ মি.গ্রা.'));
    });

    test('calculates correct senior/elderly dose (60+ years)', () {
      final result = DosageCalculator.calculate(
        paracetamolTab,
        ageYears: 68,
        ageMonths: 0,
      );

      expect(result.ageText, equals('৬৮ বছর'));
      expect(result.categoryName, contains('বয়স্ক'));
      expect(result.warnings, contains('লিভার ও কিডনি'));
    });

    test('PPI gastro medication provides breakfast timing guidance', () {
      final esomeprazole = Medicine(
        id: 20,
        brandName: 'Sergel 20',
        genericName: 'Esomeprazole',
        dosageForm: 'Capsule',
        strength: '20 mg',
      );

      final result = DosageCalculator.calculate(esomeprazole, ageYears: 30);

      expect(result.howToTake, contains('খালি পেটে'));
      expect(result.frequency, contains('দিনে ১ বার'));
    });
  });
}
