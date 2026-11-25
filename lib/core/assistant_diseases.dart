/// Deterministic disease knowledge for the on-device assistant.
///
/// This is *our* curated map from what a user types (Bangla or English, full
/// word or prefix) to a condition lesson in the শেখা library and to the English
/// generic/brand tokens we look up in the medicine database. Nothing here is
/// invented by the model — the LLM only ever re-phrases what this layer
/// retrieves. Keyed by lesson `id` (see `assets/learning/conditions_*.json`).
library;

import '../models/learning.dart';

/// Script detection shared by the assistant UI and the medicine tile. Bangla
/// lives in U+0980–U+09FF; anything Latin uses the ASCII letter range.
bool isBangla(String text) => RegExp(r'[\u0980-\u09ff]').hasMatch(text);

bool isLatin(String text) => RegExp(r'[A-Za-z]').hasMatch(text);

/// One condition: its lesson id, Bangla aliases, English aliases, and the
/// English generic/brand tokens used to pull real medicines from the database.
class ConditionEntry {
  const ConditionEntry({
    required this.lessonId,
    this.bn = const [],
    this.en = const [],
    this.generics = const [],
  });

  final String lessonId;
  final List<String> bn;
  final List<String> en;
  final List<String> generics;
}

/// Curated index over the common condition lessons. Every `en` token is a
/// Latin search term; every `generics` token is an English DB generic/brand
/// name we expect the catalogue to contain.
const List<ConditionEntry> kConditionIndex = [
  ConditionEntry(
    lessonId: 'fever',
    bn: ['জ্বর', 'গা গরম', 'জ্বরে', 'তাপ', 'শরীর গরম'],
    en: ['fever', 'temperature'],
    generics: ['Paracetamol', 'Ibuprofen'],
  ),
  ConditionEntry(
    lessonId: 'cold-cough',
    bn: ['সর্দি', 'কাশি', 'সর্দি-কাশি', 'গলা', 'ঠান্ডা'],
    en: ['cold', 'cough', 'flu', 'sore throat'],
    generics: ['Cetirizine', 'Diphenhydramine', 'Paracetamol'],
  ),
  ConditionEntry(
    lessonId: 'diarrhea',
    bn: ['ডায়রিয়া', 'পাতলা পায়খানা', 'পানিশূন্যতা', 'বমি'],
    en: ['diarrhea', 'loose motion', 'dehydration', 'vomit'],
    generics: ['Oraline', 'Zinc', 'Metronidazole'],
  ),
  ConditionEntry(
    lessonId: 'anemia',
    bn: ['রক্তশূন্যতা', 'অ্যানিমিয়া', 'রক্ত স্বল্পতা'],
    en: ['anemia', 'anaemia'],
    generics: ['Ferrous Sulphate', 'Folic Acid'],
  ),
  ConditionEntry(
    lessonId: 'vitamin-d',
    bn: ['ভিটামিন ডি', 'হাড়ের ব্যথা', 'কমজোরি'],
    en: ['vitamin d', 'vit d', 'bone pain'],
    generics: ['Cholecalciferol'],
  ),
  ConditionEntry(
    lessonId: 'allergy-hives',
    bn: ['অ্যালার্জি', 'চুলকানি', 'ফোলা', 'ঘাসের ফোলা'],
    en: ['allergy', 'hives', 'urticaria', 'itch'],
    generics: ['Cetirizine', 'Loratadine', 'Fexofenadine'],
  ),
  ConditionEntry(
    lessonId: 'heart-attack',
    bn: ['হার্ট অ্যাটাক', 'বুকে ব্যথা', 'বুক ব্যথা'],
    en: ['heart attack'],
    generics: ['Aspirin', 'Atorvastatin', 'Clopidogrel'],
  ),
  ConditionEntry(
    lessonId: 'stroke',
    bn: ['স্ট্রোক', 'পক্ষাঘাত'],
    en: ['stroke'],
    generics: ['Aspirin'],
  ),
  ConditionEntry(
    lessonId: 'anaphylaxis',
    bn: ['তীব্র অ্যালার্জি', 'অ্যানাফাইল্যাক্সিস'],
    en: ['anaphylaxis'],
    generics: ['Epinephrine', 'Adrenaline'],
  ),
  ConditionEntry(
    lessonId: 'hypertension',
    bn: ['উচ্চ রক্তচাপ', 'হাই ব্লাড প্রেসার', 'রক্তচাপ'],
    en: ['hypertension', 'high blood pressure', 'bp'],
    generics: ['Amlodipine', 'Losartan', 'Telmisartan'],
  ),
  ConditionEntry(
    lessonId: 'heart-failure',
    bn: ['হার্ট ফেইলিওর', 'হৃৎস্পন্দন'],
    en: ['heart failure'],
    generics: ['Furosemide', 'Bisoprolol'],
  ),
  ConditionEntry(
    lessonId: 'cholesterol',
    bn: ['কোলেস্টেরল', 'চর্বি'],
    en: ['cholesterol', 'lipid'],
    generics: ['Atorvastatin', 'Rosuvastatin'],
  ),
  ConditionEntry(
    lessonId: 'angina',
    bn: ['এনজাইনা', 'বুকে চাপ'],
    en: ['angina', 'chest pain'],
    generics: ['Glyceryl Trinitrate'],
  ),
  ConditionEntry(
    lessonId: 'asthma',
    bn: ['অ্যাজমা', 'শ্বাসকষ্ট'],
    en: ['asthma', 'wheezing'],
    generics: ['Salbutamol', 'Budesonide', 'Montelukast'],
  ),
  ConditionEntry(
    lessonId: 'copd',
    bn: ['সিওপিডি', 'দীর্ঘ শ্বাসকষ্ট'],
    en: ['copd'],
    generics: ['Salbutamol', 'Ipratropium'],
  ),
  ConditionEntry(
    lessonId: 'pneumonia',
    bn: ['নিউমোনিয়া', 'ফুসফুসের সংক্রমণ'],
    en: ['pneumonia'],
    generics: ['Amoxicillin', 'Azithromycin', 'Ceftriaxone'],
  ),
  ConditionEntry(
    lessonId: 'tuberculosis',
    bn: ['যক্ষ্মা', 'টিবি'],
    en: ['tuberculosis', 'tb'],
    generics: ['Isoniazid', 'Rifampicin'],
  ),
  ConditionEntry(
    lessonId: 'allergic-rhinitis',
    bn: ['নাক পাতলা', 'অ্যালার্জিক রাইনাইটিস', 'বারবার হাঁচি'],
    en: ['rhinitis', 'sneezing', 'runny nose'],
    generics: ['Cetirizine', 'Loratadine'],
  ),
  ConditionEntry(
    lessonId: 'dengue',
    bn: ['ডেঙ্গু', 'ডেঙ্গু জ্বর'],
    en: ['dengue'],
    generics: ['Paracetamol'],
  ),
  ConditionEntry(
    lessonId: 'typhoid',
    bn: ['টাইফয়েড', 'টাইফয়েড জ্বর'],
    en: ['typhoid'],
    generics: ['Ceftriaxone', 'Azithromycin'],
  ),
  ConditionEntry(
    lessonId: 'malaria',
    bn: ['ম্যালেরিয়া', 'জ্বরে কাঁপা'],
    en: ['malaria'],
    generics: ['Artemether', 'Lumefantrine'],
  ),
  ConditionEntry(
    lessonId: 'hepatitis',
    bn: ['হেপাটাইটিস', 'লিভের রোগ', 'জন্ডিস'],
    en: ['hepatitis', 'jaundice'],
    generics: ['Ursodeoxycholic Acid'],
  ),
  ConditionEntry(
    lessonId: 'type2-diabetes',
    bn: ['ডায়াবেটিস', 'শর্করা', 'প্রস্রাবে চিনি'],
    en: ['diabetes', 'sugar', 'blood sugar'],
    generics: ['Metformin', 'Glimepiride'],
  ),
  ConditionEntry(
    lessonId: 'hypothyroidism',
    bn: ['হাইপোথাইরয়েড', 'থাইরয়েড'],
    en: ['hypothyroidism', 'thyroid'],
    generics: ['Thyroxine', 'Levothyroxine'],
  ),
  ConditionEntry(
    lessonId: 'pcos',
    bn: ['পিসিওএস', 'বন্ধ হওয়া মাসিক', 'ডিম্বাশয়ের গ্রন্থি'],
    en: ['pcos', 'pcod'],
    generics: ['Metformin'],
  ),
  ConditionEntry(
    lessonId: 'obesity',
    bn: ['স্থূলতা', 'ওজন', 'মেদ'],
    en: ['obesity', 'weight', 'fat'],
    generics: ['Orlistat'],
  ),
  ConditionEntry(
    lessonId: 'uti',
    bn: ['ইউটিআই', 'মূত্রনালির সংক্রমণ', 'প্রস্রাবে জ্বালা'],
    en: ['uti', 'urinary infection', 'burning urine'],
    generics: ['Nitrofurantoin', 'Ciprofloxacin'],
  ),
  ConditionEntry(
    lessonId: 'kidney-stones',
    bn: ['কিডনিতে পাথর', 'পাথর'],
    en: ['kidney stone', 'stones'],
    generics: ['Tamsulosin'],
  ),
  ConditionEntry(
    lessonId: 'gerd',
    bn: [
      'গ্যাস্ট্রিক',
      'রিফ্লাক্স',
      'পেটে জ্বালা',
      'অ্যাসিডিটি',
      'বুক জ্বালা',
      'বুকে জ্বালা',
      'গলা জ্বালা',
      'টক ঢেকুর',
      'টক ঢেঁকুর',
      'ঢেকুর',
      'ঢেঁকুর',
      'জ্বালাপোড়া',
      'গ্যাস',
      'পেটে গ্যাস',
      'পেট ফাঁপা',
    ],
    en: [
      'gerd',
      'reflux',
      'acidity',
      'heartburn',
      'acid reflux',
      'sour belch',
      'belching',
    ],
    generics: ['Omeprazole', 'Esomeprazole'],
  ),
  ConditionEntry(
    lessonId: 'peptic-ulcer',
    bn: ['আলসার', 'পেপটিক আলসার'],
    en: ['ulcer', 'peptic ulcer'],
    generics: ['Omeprazole', 'Ranitidine'],
  ),
  ConditionEntry(
    lessonId: 'ibs',
    bn: ['আইবিএস', 'অন্ত্রের সমস্যা'],
    en: ['ibs', 'irritable bowel'],
    generics: ['Racecadotril'],
  ),
  ConditionEntry(
    lessonId: 'constipation',
    bn: ['কোষ্ঠকাঠিন্য', 'দেয় না', 'খাচা'],
    en: ['constipation'],
    generics: ['Lactulose', 'Bisacodyl'],
  ),
  ConditionEntry(
    lessonId: 'fatty-liver',
    bn: ['ফ্যাটি লিভার', 'লিভারে চর্বি'],
    en: ['fatty liver'],
    generics: ['Ursodeoxycholic Acid'],
  ),
  ConditionEntry(
    lessonId: 'piles',
    bn: ['পাইলস', 'হেমোরয়েড', 'গুদবেথনা'],
    en: ['piles', 'hemorrhoid'],
    generics: ['Diosmin'],
  ),
  ConditionEntry(
    lessonId: 'migraine',
    bn: ['মাইগ্রেন', 'মাথা ব্যথা', 'অর্ধমাথা ব্যথা'],
    en: ['migraine', 'headache'],
    generics: ['Naproxen', 'Sumatriptan', 'Paracetamol'],
  ),
  ConditionEntry(
    lessonId: 'epilepsy',
    bn: ['মৃগী', 'খিঁচুনি', 'আপিলেপসি'],
    en: ['epilepsy', 'seizure', 'fits'],
    generics: ['Sodium Valproate', 'Carbamazepine'],
  ),
  ConditionEntry(
    lessonId: 'neuropathy',
    bn: ['নিউরোপ্যাথি', 'স্নায়ুর ব্যথা', 'হাত-পা অবশ'],
    en: ['neuropathy', 'numbness', 'tingling'],
    generics: ['Pregabalin', 'Gabapentin', 'Methylcobalamin'],
  ),
  ConditionEntry(
    lessonId: 'insomnia',
    bn: ['অনিদ্রা', 'ঘুমের সমস্যা', 'ঘুম হয় না'],
    en: ['insomnia', 'sleep'],
    generics: ['Diazepam', 'Melatonin'],
  ),
  ConditionEntry(
    lessonId: 'anxiety',
    bn: ['দুশ্চিন্তা', 'অ্যানজাইটি', 'ভয়'],
    en: ['anxiety', 'stress'],
    generics: ['Diazepam', 'Sertraline'],
  ),
  ConditionEntry(
    lessonId: 'depression',
    bn: ['বিষণ্নতা', 'ডিপ্রেশন', 'খারাপ লাগা'],
    en: ['depression'],
    generics: ['Fluoxetine', 'Sertraline', 'Amitriptyline'],
  ),
  ConditionEntry(
    lessonId: 'osteoarthritis',
    bn: ['অস্টিওআর্থ্রাইটিস', 'গাঁটের ব্যথা', 'হাড়ের জোড়া'],
    en: ['osteoarthritis', 'joint pain', 'arthritis'],
    generics: ['Diclofenac', 'Glucosamine', 'Celecoxib'],
  ),
  ConditionEntry(
    lessonId: 'rheumatoid-arthritis',
    bn: ['রিউমাটয়েড আর্থ্রাইটিস', 'বাত'],
    en: ['rheumatoid', 'ra'],
    generics: ['Methotrexate', 'Diclofenac'],
  ),
  ConditionEntry(
    lessonId: 'gout',
    bn: ['গাউট', 'ইউরিক অ্যাসিড', 'বাতের ব্যথা'],
    en: ['gout', 'uric acid'],
    generics: ['Allopurinol', 'Colchicine'],
  ),
  ConditionEntry(
    lessonId: 'osteoporosis',
    bn: ['অস্টিওপোরোসিস', 'হাড় ক্ষয়', 'হাড় ভাঙা'],
    en: ['osteoporosis', 'brittle bone'],
    generics: ['Calcium Carbonate', 'Cholecalciferol'],
  ),
  ConditionEntry(
    lessonId: 'low-back-pain',
    bn: ['কোমর ব্যথা', 'পিঠের ব্যথা', 'কোমর'],
    en: ['back pain', 'lower back', 'lumbago'],
    generics: ['Diclofenac', 'Thiocolchicoside'],
  ),
  ConditionEntry(
    lessonId: 'eczema',
    bn: ['একজিমা', 'ত্বকের চুলকানি'],
    en: ['eczema', 'dermatitis'],
    generics: ['Hydrocortisone', 'Cetirizine'],
  ),
  ConditionEntry(
    lessonId: 'acne',
    bn: ['ব্রণ', 'মুখের ব্রণ'],
    en: ['acne', 'pimple'],
    generics: ['Benzoyl Peroxide', 'Clindamycin'],
  ),
  ConditionEntry(
    lessonId: 'psoriasis',
    bn: ['সোরিয়াসিস', 'ত্বকের রশি'],
    en: ['psoriasis'],
    generics: ['Clobetasol'],
  ),
  ConditionEntry(
    lessonId: 'fungal-infection',
    bn: ['ফাঙ্গাল', 'দাদ', 'ছত্রাক', 'চুলকানি দাদ'],
    en: ['fungal', 'ringworm', 'dad'],
    generics: ['Fluconazole', 'Terbinafine', 'Ketoconazole'],
  ),
  ConditionEntry(
    lessonId: 'scabies',
    bn: ['স্ক্যাবিস', 'খোসপাঁচড়া'],
    en: ['scabies'],
    generics: ['Permethrin'],
  ),
  ConditionEntry(
    lessonId: 'conjunctivitis',
    bn: ['চোখ ওঠা', 'কনজাংটিভাইটিস', 'চোখ লাল'],
    en: ['conjunctivitis', 'eye infection', 'red eye'],
    generics: ['Chloramphenicol', 'Ciprofloxacin'],
  ),
  ConditionEntry(
    lessonId: 'dry-eye',
    bn: ['শুষ্ক চোখ', 'চোখ শুকনো'],
    en: ['dry eye'],
    generics: ['Carboxymethylcellulose'],
  ),
  ConditionEntry(
    lessonId: 'ear-infection',
    bn: ['কানের সংক্রমণ', 'কান ব্যথা', 'কান পাকা'],
    en: ['ear infection', 'ear pain'],
    generics: ['Ciprofloxacin'],
  ),
  ConditionEntry(
    lessonId: 'sinusitis',
    bn: ['সাইনুসাইটিস', 'সাইনাস', 'নাক বন্ধ'],
    en: ['sinusitis', 'sinus'],
    generics: ['Amoxicillin', 'Cetirizine'],
  ),
  ConditionEntry(
    lessonId: 'dental-health',
    bn: ['দাঁতের ব্যথা', 'দাঁত', 'মাড়ি'],
    en: ['toothache', 'dental', 'teeth'],
    generics: ['Ibuprofen', 'Metronidazole'],
  ),
  ConditionEntry(
    lessonId: 'period-pain',
    bn: ['পিরিয়ড ব্যথা', 'মাসিক', 'ডিসমেনোরিয়া'],
    en: ['period pain', 'menstrual', 'dysmenorrhea'],
    generics: ['Mefenamic Acid', 'Ibuprofen'],
  ),
  ConditionEntry(
    lessonId: 'worms',
    bn: ['কৃমি', 'পেটের কৃমি'],
    en: ['worms', 'worm', 'helminth'],
    generics: ['Albendazole', 'Mebendazole'],
  ),
];

/// Look up the curated entry for a free-text query, matching either script.
/// A query can contain several aliases (e.g. “প্রস্রাবে জ্বালা” hits both
/// “জ্বালা”-style entries and UTI); the *most specific* (longest) alias wins,
/// so symptom phrasings land on the right condition. Falls back to resolving a
/// lesson title to its entry when [lessons] is given.
ConditionEntry? findEntry(String query, {List<Lesson>? lessons}) {
  final raw = query.trim();
  if (raw.isEmpty) return null;
  final lower = raw.toLowerCase();
  ConditionEntry? best;
  var bestLen = 0;
  for (final entry in kConditionIndex) {
    for (final alias in entry.bn) {
      if (alias.length > bestLen && _hits(alias, raw)) {
        best = entry;
        bestLen = alias.length;
      }
    }
    for (final alias in entry.en) {
      final x = alias.toLowerCase();
      if (x.length > bestLen && _hits(x, lower)) {
        best = entry;
        bestLen = x.length;
      }
    }
  }
  if (best != null) return best;
  if (lessons != null) {
    for (final lesson in lessons) {
      if (lesson.title.contains(raw) ||
          lesson.title.toLowerCase().contains(lower)) {
        for (final entry in kConditionIndex) {
          if (entry.lessonId == lesson.id) return entry;
        }
      }
    }
  }
  return null;
}

/// Either the query contains the alias or the alias contains the query
/// (prefix/substring hits both ways), matching the original alias behaviour.
bool _hits(String alias, String value) =>
    alias.contains(value) || value.contains(alias);

/// The entry whose lesson id matches, if any.
ConditionEntry? entryForLesson(String lessonId) {
  for (final entry in kConditionIndex) {
    if (entry.lessonId == lessonId) return entry;
  }
  return null;
}

/// Disease autocomplete: the lesson titles a typed prefix could mean, both
/// scripts, deduped and ranked (exact/prefix matches first).
List<String> suggestDiseases(String query, List<Lesson> lessons) {
  final raw = query.trim();
  if (raw.isEmpty) return const [];
  final lower = raw.toLowerCase();
  final byId = {for (final l in lessons) l.id: l};
  final ranked = <String>[];
  final seen = <String>{};

  void add(String? title) {
    if (title == null || title.isEmpty) return;
    if (seen.add(title)) ranked.add(title);
  }

  // Curated aliases first, prefix-weighted.
  for (final entry in kConditionIndex) {
    final prefix =
        entry.bn.any((a) => a.startsWith(raw)) ||
        entry.en.any((a) => a.toLowerCase().startsWith(lower));
    final contains =
        _matchesAnyBn(entry.bn, raw) || _matchesAnyEn(entry.en, lower);
    if (prefix || contains) {
      add(byId[entry.lessonId]?.title);
      if (prefix) {
        // Pull prefix hits to the front by re-inserting at index 0.
        final t = byId[entry.lessonId]?.title;
        if (t != null && ranked.last == t && ranked.length > 1) {
          ranked.remove(t);
          ranked.insert(0, t);
        }
      }
    }
  }
  // Direct lesson-title substring match.
  for (final lesson in lessons) {
    if (lesson.title.contains(raw) ||
        lesson.title.toLowerCase().contains(lower)) {
      add(lesson.title);
    }
  }
  return ranked;
}

bool _matchesAnyBn(List<String> aliases, String raw) =>
    aliases.any((a) => a.contains(raw) || raw.contains(a));

bool _matchesAnyEn(List<String> aliases, String lower) => aliases.any((a) {
  final x = a.toLowerCase();
  return x.startsWith(lower) || x.contains(lower);
});
