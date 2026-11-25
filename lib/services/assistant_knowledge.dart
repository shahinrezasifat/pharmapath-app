// ignore_for_file: prefer_initializing_formals

import 'package:get/get.dart';

import '../core/assistant_diseases.dart';
import '../core/json_utils.dart';
import '../data/learning_repository.dart';
import '../data/medicine_dao.dart';
import '../models/learning.dart';
import '../models/medicine.dart';

/// Grounding layer for the assistant. It answers *deterministically* from our
/// own data — the 73 condition lessons in শেখা plus the medicine database — and
/// hands the LLM a compact context pack to phrase. The model never invents the
/// medicine list; this class supplies it.
///
/// All methods are safe to call before the LLM model is downloaded, so disease
/// autocomplete and "which medicine for this disease" work fully offline.
class AssistantKnowledge extends GetxService {
  AssistantKnowledge(this._repo, this._dao);

  final LearningRepository _repo;
  final MedicineDao _dao;

  List<Lesson>? _lessons;

  /// Flattened lesson list across every course, loaded once and cached.
  Future<List<Lesson>> _allLessons() async {
    if (_lessons != null) return _lessons!;
    final courses = await _repo.courses();
    _lessons = [for (final course in courses) ...course.lessons];
    return _lessons!;
  }

  /// Disease autocomplete for the input box, in both scripts.
  Future<List<String>> suggestDiseases(String query) async {
    return suggestDiseasesFor(query, await _allLessons());
  }

  /// The best-matching lesson for [query], or null when nothing fits.
  Future<Lesson?> matchLesson(String query) async {
    final lessons = await _allLessons();
    final raw = query.trim();
    if (raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    // Prefer an exact curated-alias hit that also has a lesson.
    final entry = findEntry(query, lessons: lessons);
    if (entry != null) {
      for (final lesson in lessons) {
        if (lesson.id == entry.lessonId) return lesson;
      }
    }
    for (final lesson in lessons) {
      if (lesson.title.contains(raw) ||
          lesson.title.toLowerCase().contains(lower)) {
        return lesson;
      }
    }
    return null;
  }

  /// Real medicines for [query], assembled from every source we have so the
  /// assistant answers whichever way the question is phrased:
  ///  1. the curated generic/brand tokens of the matched condition;
  ///  2. the database's own *indications* text for the condition's English
  ///     names (and the raw query when it is already Latin) — this is the
  ///     "which disease does this medicine cure" knowledge stored per row;
  ///  3. a direct brand/generic name lookup when the query looks like a medicine.
  /// One representative per generic, preferring clinically detailed rows.
  Future<List<Medicine>> medicinesFor(String query, {int cap = 8}) async {
    final entry = findEntry(query, lessons: await _allLessons());
    final genericTokens = <String>[...?entry?.generics];
    final diseaseTerms = <String>{
      ...?entry?.en,
      if (isLatin(query)) query.trim(),
    };

    // Check Bangla medicine aliases
    final cleanQ = query.trim().toLowerCase();
    for (final mapEntry in kBanglaMedicineMap.entries) {
      if (cleanQ.contains(mapEntry.key.toLowerCase())) {
        for (final token in mapEntry.value) {
          if (!genericTokens.contains(token)) {
            genericTokens.add(token);
          }
        }
      }
    }

    final byKey = <String, Medicine>{};
    final ordered = <Medicine>[];
    // Prefer a row with genuinely stored clinical text. `detailLoaded` alone
    // is not enough: every known generic gets curated sections through the
    // local knowledge engine fallback, so it is true even for summary rows.
    int quality(Medicine m) =>
        (m.indications?.trim().isNotEmpty ?? false ? 4 : 0) +
        (m.dosageAndAdministration?.trim().isNotEmpty ?? false ? 2 : 0) +
        (m.detailLoaded ? 1 : 0);
    void offer(Medicine medicine) {
      final generic = (medicine.genericName ?? '').trim().toLowerCase();
      final key = generic.isEmpty ? 'id:${medicine.id}' : generic;
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = medicine;
        ordered.add(medicine);
      } else if (quality(medicine) > quality(existing)) {
        ordered[ordered.indexOf(existing)] = medicine;
        byKey[key] = medicine;
      }
    }

    // 1. Search by generic and brand tokens
    for (final token in genericTokens) {
      if (ordered.length >= cap) break;
      final page = await _dao.search(generic: token, limit: 5);
      for (final medicine in page.items) {
        offer(medicine);
      }
      if (ordered.length < cap) {
        final brandPage = await _dao.search(query: token, limit: 5);
        for (final medicine in brandPage.items) {
          offer(medicine);
        }
      }
    }

    // 2. Search by disease terms
    for (final term in diseaseTerms) {
      if (ordered.length >= cap) break;
      for (final medicine in await _dao.searchByIndication(term, limit: 6)) {
        offer(medicine);
      }
    }

    // 3. Search by raw Latin query
    if (ordered.isEmpty && isLatin(query)) {
      final page = await _dao.search(query: query.trim(), limit: cap);
      for (final medicine in page.items) {
        offer(medicine);
      }
    }

    // 4. Phonetic transliteration search for Bangla words
    if (ordered.isEmpty) {
      final latinized = banglaToLatinPhonetic(query);
      if (latinized.isNotEmpty) {
        final page = await _dao.search(query: latinized, limit: cap);
        for (final medicine in page.items) {
          offer(medicine);
        }
      }
    }

    return ordered.take(cap).toList();
  }

  /// A Bangla/English grounding string for the LLM system prompt. It carries
  /// the matched lesson *and* each retrieved medicine's own clinical sections
  /// (indications, dosage, cautions…), so the model can translate and present
  /// the full per-tablet knowledge in the user's language. Returns null only
  /// when nothing in our data matches.
  Future<String?> buildContext(String query, {int cap = 5}) async {
    final lesson = await matchLesson(query);
    final medicines = await medicinesFor(query, cap: cap);
    if (lesson == null && medicines.isEmpty) return null;
    final buffer = StringBuffer();
    if (lesson != null) {
      buffer.writeln('রোগ: ${lesson.title}');
      final summary = lesson.summary.trim();
      if (summary.isNotEmpty) buffer.writeln('সারসংক্ষেপ: $summary');
      final excerpt = _dosageExcerpt(lesson.body);
      if (excerpt.isNotEmpty) buffer.writeln('ওষুধ ও ডোজ (পাঠ থেকে): $excerpt');
    }
    if (medicines.isNotEmpty) {
      buffer.writeln('ডেটাবেজের ওষুধ (প্রতিটির পূর্ণ তথ্য):');
      for (final medicine in medicines) {
        buffer.write(_medicineDossier(medicine));
      }
    }
    buffer.write(
      'এই তথ্য ব্যবহার করে ডাক্তারের মতো গাইড করো; ইংরেজি অংশ বাংলায় বুঝিয়ে বলো; '
      'তালিকার বাইরে নতুন ঔষধ বা নিশ্চিত না এমন ডোজ আবিষ্কার করো না।',
    );
    return buffer.toString();
  }

  /// A compact dossier for one medicine: identity + its key clinical sections,
  /// each trimmed, so the model has the real per-tablet knowledge to translate.
  static const _dossierKeys = {
    'indications',
    'composition',
    'dosage_and_administration',
    'contraindications',
    'side_effects',
    'pregnancy_and_lactation',
    'precautions_and_warnings',
  };

  String _medicineDossier(Medicine medicine) {
    final generic = (medicine.genericName ?? '').trim();
    final strength = (medicine.strength ?? '').trim();
    final header = <String>[
      medicine.brandName,
      if (generic.isNotEmpty) '($generic)',
      if (strength.isNotEmpty) strength,
    ].join(' ');
    final buffer = StringBuffer('• $header\n');
    var wrote = false;
    for (final section in medicine.clinicalSections) {
      if (!_dossierKeys.contains(section.key)) continue;
      final maxLen = (section.key == 'dosage_and_administration' ||
              section.key == 'indications')
          ? 600
          : 250;
      final value = _clip(stripHtml(section.value), maxLen);
      if (value.isEmpty) continue;
      buffer.writeln('  ${section.label}: $value');
      wrote = true;
    }
    if (!wrote) {
      buffer.writeln(
        '  (বিস্তারিত ক্লিনিক্যাল তথ্য সংরক্ষিত নেই — শুধু পরিচয়)',
      );
    }
    return buffer.toString();
  }

  static String _clip(String text, int max) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.length <= max ? clean : '${clean.substring(0, max)}…';
  }

  /// Pull the "ওষুধ ও ডোজ" slice out of a lesson's HTML body, plain text.
  static String _dosageExcerpt(String body) {
    final text = stripHtml(body);
    final index = text.indexOf('ওষুধ');
    if (index < 0) return '';
    final slice = text.substring(index);
    final trimmed = slice.length <= 400 ? slice : '${slice.substring(0, 400)}…';
    return trimmed.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

/// Alias so the controller can call the top-level [suggestDiseases] helper with
/// a pre-loaded lesson list without a name clash on the instance method.
List<String> suggestDiseasesFor(String query, List<Lesson> lessons) =>
    suggestDiseases(query, lessons);

/// Common Bengali medicine names and their corresponding English brand/generic tokens
const Map<String, List<String>> kBanglaMedicineMap = {
  'নাপা': ['Napa', 'Paracetamol'],
  'এইস': ['Ace', 'Paracetamol'],
  'সিকলো': ['Seclo', 'Omeprazole'],
  'সেক্লো': ['Seclo', 'Omeprazole'],
  'ওমিপ্রাজল': ['Omeprazole'],
  'ম্যাক্সপ্রো': ['Maxpro', 'Esomeprazole'],
  'এসোমিপ্রাজল': ['Esomeprazole'],
  'নেক্সাম': ['Nexum', 'Esomeprazole'],
  'প্যানটোনিক্স': ['Pantonix', 'Pantoprazole'],
  'প্যান্টোপ্রাজল': ['Pantoprazole'],
  'এন্টাসিড': ['Antacid', 'Aluminium Hydroxide'],
  'মোনাস': ['Monas', 'Montelukast'],
  'মন্টেলুকাস্ট': ['Montelukast'],
  'ফেক্সো': ['Fexo', 'Fexofenadine'],
  'ফেক্সোফেনাডিন': ['Fexofenadine'],
  'হিস্টাসিন': ['Histasin', 'Chlorpheniramine'],
  'সিটিরিজিন': ['Cetirizine'],
  'অ্যালাট্রোল': ['Alatrol', 'Cetirizine'],
  'এলার্ট্রল': ['Alatrol', 'Cetirizine'],
  'ফ্ল্যাজিল': ['Flagyl', 'Metronidazole'],
  'ফ্লাজিল': ['Flagyl', 'Metronidazole'],
  'মেট্রোনিডাজল': ['Metronidazole'],
  'মেট্রোজিল': ['Metrogyl', 'Metronidazole'],
  'অ্যাজিথ্রোমাইসিন': ['Azithromycin', 'Azithro'],
  'এজিথ্রো': ['Azithro', 'Azithromycin'],
  'সিপ্রো': ['Ciprocin', 'Ciprofloxacin'],
  'সিপ্রোসিন': ['Ciprocin', 'Ciprofloxacin'],
  'সিপ্রোফ্লক্সাসিন': ['Ciprofloxacin'],
  'অ্যামোক্সিসিলিন': ['Amoxicillin', 'Moxacil'],
  'মক্সাসিল': ['Moxacil', 'Amoxicillin'],
  'সিভিট': ['Ceevit', 'Vitamin C'],
  'জিংক': ['Baby Zinc', 'Zinc'],
  'স্যালাইন': ['ORS', 'Saline'],
  'ডাইক্লোফেনাক': ['Diclofenac'],
  'আইবুপ্রোফেন': ['Ibuprofen'],
  'সালবিউটামল': ['Salbutamol', 'Ventolin'],
  'ভেন্টোলিন': ['Ventolin', 'Salbutamol'],
  'অ্যামব্রোক্সল': ['Ambroxol'],
  'ডমপেরিডন': ['Domperidone'],
  'অনডানসেট্রন': ['Ondansetron'],
  'টুস্কা': ['Tusca'],
  'ক্লোনাজিপাম': ['Clonazepam'],
  'লোনাপাম': ['Lonapam', 'Clonazepam'],
};

/// Transliterates Bengali text phonetically to Latin search tokens
String banglaToLatinPhonetic(String text) {
  final clean = text.trim().toLowerCase();
  if (clean.isEmpty) return '';
  final sb = StringBuffer();
  for (final rune in clean.runes) {
    final ch = String.fromCharCode(rune);
    switch (ch) {
      case 'ক': sb.write('k');
      case 'খ': sb.write('kh');
      case 'গ': sb.write('g');
      case 'ঘ': sb.write('gh');
      case 'চ': case 'ছ': sb.write('ch');
      case 'জ': sb.write('j');
      case 'ঝ': sb.write('jh');
      case 'ট': case 'ত': sb.write('t');
      case 'ঠ': case 'থ': sb.write('th');
      case 'ড': case 'দ': sb.write('d');
      case 'ঢ': case 'ধ': sb.write('dh');
      case 'ন': case 'ণ': sb.write('n');
      case 'প': sb.write('p');
      case 'ফ': sb.write('f');
      case 'ব': sb.write('b');
      case 'ভ': sb.write('v');
      case 'ম': sb.write('m');
      case 'য': sb.write('y');
      case 'র': sb.write('r');
      case 'ল': sb.write('l');
      case 'শ': case 'ষ': case 'স': sb.write('s');
      case 'হ': sb.write('h');
      case 'া': sb.write('a');
      case 'ি': case 'ী': sb.write('i');
      case 'ু': case 'ূ': sb.write('u');
      case 'ে': sb.write('e');
      case 'ো': sb.write('o');
      default:
        if (RegExp(r'[a-zA-Z0-9]').hasMatch(ch)) {
          sb.write(ch);
        }
    }
  }
  return sb.toString();
}
