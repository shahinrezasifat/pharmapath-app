import 'package:flutter_test/flutter_test.dart';
import 'package:pharmapath_app/core/clinical_knowledge_engine.dart';
import 'package:pharmapath_app/core/disease_tag_extractor.dart';
import 'package:pharmapath_app/core/dosage_age_parser.dart';
import 'package:pharmapath_app/models/medicine.dart';

void main() {
  group('ClinicalKnowledgeEngine & Medicine Bengali Monograph Tests', () {
    test('Verifies that empty medicines are populated with rich Bengali clinical sections', () {
      const emptyMed = Medicine(
        id: 99999,
        brandName: 'Napa Extra',
        genericName: 'Paracetamol + Caffeine',
        dosageForm: 'Tablet',
        strength: '500 mg + 65 mg',
        company: 'Beximco Pharmaceuticals Ltd.',
        unitPrice: '2.50',
      );

      // Identity fields must remain in English
      expect(emptyMed.brandName, 'Napa Extra');
      expect(emptyMed.genericName, 'Paracetamol + Caffeine');
      expect(emptyMed.dosageForm, 'Tablet');
      expect(emptyMed.company, 'Beximco Pharmaceuticals Ltd.');
      expect(emptyMed.unitPrice, '2.50');

      // Clinical sections must be populated with rich Bengali content
      final sections = emptyMed.clinicalSections;
      expect(sections.isNotEmpty, isTrue);
      expect(sections.length, greaterThanOrEqualTo(10));

      final keys = sections.map((s) => s.key).toSet();
      expect(keys.contains('indications'), isTrue);
      expect(keys.contains('dosage_and_administration'), isTrue);
      expect(keys.contains('side_effects'), isTrue);
      expect(keys.contains('precautions_and_warnings'), isTrue);
      expect(keys.contains('pregnancy_and_lactation'), isTrue);

      final indications = sections.firstWhere((s) => s.key == 'indications');
      expect(indications.label, 'রোগের নির্দেশনা');
      // Must contain Bengali characters
      expect(RegExp(r'[\u0980-\u09FF]').hasMatch(indications.value), isTrue);
      expect(indications.value.contains('Napa Extra'), isTrue);

      final dosage = sections.firstWhere((s) => s.key == 'dosage_and_administration');
      expect(dosage.label, 'ডোজ ও ব্যবহার');
      expect(RegExp(r'[\u0980-\u09FF]').hasMatch(dosage.value), isTrue);
    });

    test('Verifies that engine produces rich Bengali clinical monograph for English DB meds', () {
      const englishMed = Medicine(
        id: 88888,
        brandName: 'Flexi',
        genericName: 'Aceclofenac',
        dosageForm: 'Film Coated Tablet',
        strength: '100 mg',
        company: 'Square Pharmaceuticals Ltd.',
        unitPrice: '4.00',
        indications: 'Flexi is indicated for the relief of pain and inflammation in osteoarthritis...',
      );

      final monograph = ClinicalKnowledgeEngine.getClinicalSections(englishMed);
      expect(monograph.isNotEmpty, isTrue);
      final indications = monograph['indications']!;

      // Monograph is pure rich Bengali
      expect(RegExp(r'[\u0980-\u09FF]').hasMatch(indications), isTrue);
      expect(indications.contains('অস্টিওআর্থ্রাইটিস'), isTrue);
      expect(indications.contains('Flexi'), isTrue);
    });

    test('Verifies universal fallback works for arbitrary unknown generics', () {
      const unknownMed = Medicine(
        id: 77777,
        brandName: 'UnknownCure',
        genericName: 'RareCompoundXYZ',
        dosageForm: 'Eye Drop',
        strength: '0.5%',
        company: 'HealthCare Pharma',
        unitPrice: '120.00',
      );

      final sections = unknownMed.clinicalSections;
      expect(sections.isNotEmpty, isTrue);

      final dosage = sections.firstWhere((s) => s.key == 'dosage_and_administration');
      expect(dosage.value.contains('ড্রপ'), isTrue);
      expect(RegExp(r'[\u0980-\u09FF]').hasMatch(dosage.value), isTrue);
    });

    test('Verifies newly added classes (Levofloxacin, Vitamin B, Ondansetron, Albendazole, etc.)', () {
      const levo = Medicine(
        id: 66661,
        brandName: 'Levomax',
        genericName: 'Levofloxacin Hemihydrate',
        dosageForm: 'Tablet',
        strength: '500 mg',
        company: 'Square Pharmaceuticals Ltd.',
      );
      expect(levo.clinicalSections.firstWhere((s) => s.key == 'indications').value.contains('সাইনুসাইটিস'), isTrue);

      const vitB = Medicine(
        id: 66662,
        brandName: 'Neuro-B',
        genericName: 'Vitamin B1, B6 & B12',
        dosageForm: 'Tablet',
        strength: '',
        company: 'Square Pharmaceuticals Ltd.',
      );
      expect(vitB.clinicalSections.firstWhere((s) => s.key == 'indications').value.contains('নিউরোপ্যাথি'), isTrue);

      const emetic = Medicine(
        id: 66663,
        brandName: 'Emistat',
        genericName: 'Ondansetron',
        dosageForm: 'Tablet',
        strength: '8 mg',
        company: 'Beximco Pharmaceuticals Ltd.',
      );
      expect(emetic.clinicalSections.firstWhere((s) => s.key == 'indications').value.contains('বমি'), isTrue);
    });
  });

  group('DosageAgeParser 3-Tier Tests (বাচ্চা, যুবক, বয়স্ক)', () {
    test('Splits dosage into 3 structured age tiers with specific guidance', () {
      const napa = Medicine(
        id: 11111,
        brandName: 'Napa',
        genericName: 'Paracetamol',
        dosageForm: 'Tablet',
        strength: '500 mg',
        company: 'Beximco',
      );

      final rawDosage = napa.clinicalSections.firstWhere((s) => s.key == 'dosage_and_administration').value;
      final tiers = DosageAgeParser.parse(napa, rawDosage);

      expect(tiers.length, 3);

      final child = tiers[0];
      expect(child.name, 'বাচ্চা');
      expect(child.category, 'child');
      expect(child.dose.isNotEmpty, isTrue);
      expect(child.dose.contains('১০ থেকে ১৫ মি.গ্রা.') || child.dose.contains('ওজন'), isTrue);
      expect(child.ageRange.contains('১১ বছর'), isTrue);

      final adult = tiers[1];
      expect(adult.name, 'যুবক');
      expect(adult.category, 'adult');
      expect(adult.dose.isNotEmpty, isTrue);
      expect(adult.howToTake.isNotEmpty, isTrue);

      final elderly = tiers[2];
      expect(elderly.name, 'বয়স্ক');
      expect(elderly.category, 'elderly');
      expect(elderly.dose.isNotEmpty, isTrue);
      expect(elderly.ageRange.contains('৬০+ বছর'), isTrue);
      expect(elderly.warnings.contains('সতর্কতা') || elderly.warnings.contains('প্রেসক্রিপশন'), isTrue);
    });
  });

  group('DiseaseTagExtractor Tests', () {
    test('Extracts clickable disease tags from indication text', () {
      const med = Medicine(
        id: 22222,
        brandName: 'Napa Extra',
        genericName: 'Paracetamol + Caffeine',
        dosageForm: 'Tablet',
        strength: '500 mg + 65 mg',
        company: 'Beximco',
        indications: 'জ্বর, সর্দি-কাশি জনিত অস্বস্তি, মাথাব্যথা, মাইগ্রেন এবং দাঁতব্যথা নিরাময়ে নির্দেশিত।',
      );

      final tags = DiseaseTagExtractor.extract(med, med.indications);
      expect(tags.isNotEmpty, isTrue);

      final tagNames = tags.map((t) => t.name).toList();
      expect(tagNames.contains('জ্বর'), isTrue);
      expect(tagNames.contains('মাথাব্যথা'), isTrue);
      expect(tagNames.contains('মাইগ্রেন'), isTrue);

      final feverTag = tags.firstWhere((t) => t.name == 'জ্বর');
      expect(feverTag.keywords.contains('fever'), isTrue);
      expect(feverTag.keywords.contains('paracetamol'), isTrue);
    });

    test('Extracts gastric and GERD tags for proton pump inhibitors', () {
      const seclo = Medicine(
        id: 33333,
        brandName: 'Seclo',
        genericName: 'Omeprazole',
        dosageForm: 'Capsule',
        strength: '20 mg',
        company: 'Square',
        indications: 'গ্যাস্ট্রিক আলসার, বুকজ্বালা এবং রিফ্লাক্স ইসোফ্যাগাইটিস নিরাময়ে নির্দেশিত।',
      );

      final tags = DiseaseTagExtractor.extract(seclo, seclo.indications);
      expect(tags.isNotEmpty, isTrue);

      final tagNames = tags.map((t) => t.name).toList();
      expect(tagNames.any((n) => n.contains('গ্যাস্ট্রিক') || n.contains('আলসার') || n.contains('বুকজ্বালা')), isTrue);
    });
  });
}
