import 'dart:convert';

import '../core/clinical_knowledge_engine.dart';
import '../core/format.dart';
import '../core/json_utils.dart';
import '../core/medicine_form.dart';

/// One medicine record. Listing rows are summaries; clinical sections arrive
/// from `/medicines/{id}` and are cached locally.
class Medicine {
  const Medicine({
    required this.id,
    required this.brandName,
    this.slug,
    this.url,
    this.dosageForm,
    this.strength,
    this.genericName,
    this.genericId,
    this.company,
    this.companyId,
    this.unitPrice,
    this.priceText,
    this.packSizes,
    this.indications,
    this.composition,
    this.pharmacology,
    this.dosageAndAdministration,
    this.interaction,
    this.contraindications,
    this.sideEffects,
    this.pregnancyAndLactation,
    this.precautionsAndWarnings,
    this.overdoseEffects,
    this.therapeuticClass,
    this.storageConditions,
    this.commonQuestions,
    this.sections = const <String, String>{},
    this.detailLoaded = false,
    this.source = 'Bangladeshi-Medicine-API',
    this.sourceUpdated,
    this.firstSeen,
    this.lastUpdated,
    this.tradePrice,
    this.mrp,
    this.stockQuantity,
    this.batchNumber,
    this.rackNo,
    this.mfgDate,
    this.expiryDate,
    this.companyLogoUrl,
  });

  final int id;
  final String brandName;
  final String? slug;
  final String? url;
  final String? dosageForm;
  final String? strength;
  final String? genericName;
  final int? genericId;
  final String? company;
  final int? companyId;
  final String? unitPrice;
  final String? priceText;
  final String? packSizes;
  final String? indications;
  final String? composition;
  final String? pharmacology;
  final String? dosageAndAdministration;
  final String? interaction;
  final String? contraindications;
  final String? sideEffects;
  final String? pregnancyAndLactation;
  final String? precautionsAndWarnings;
  final String? overdoseEffects;
  final String? therapeuticClass;
  final String? storageConditions;
  final String? commonQuestions;
  final Map<String, String> sections;
  final bool detailLoaded;
  final String source;
  final String? sourceUpdated;
  final int? firstSeen;
  final int? lastUpdated;

  /// Shop-specific inventory & visual data. The reference API never supplies
  /// these; they are captured only through the manual "Add Medicine" form, so
  /// every synced/seeded row keeps them null. Dates are stored as ISO `yyyy-MM-dd`.
  final String? tradePrice; // Trade Price / purchase cost
  final String? mrp; // Maximum Retail Price
  final int? stockQuantity;
  final String? batchNumber;
  final String? rackNo;
  final String? mfgDate;
  final String? expiryDate;
  final String? companyLogoUrl;

  /// True for rows a pharmacist entered by hand (never touched by sync/seed).
  bool get isManual => source == 'manual';

  /// Canonical dosage form, classified from the raw [dosageForm] text so both
  /// API and manual rows resolve to one of the iconned categories.
  MedicineForm get form => MedicineForm.fromStored(dosageForm);

  DateTime? get expiry =>
      expiryDate == null ? null : DateTime.tryParse(expiryDate!);
  DateTime? get manufactured =>
      mfgDate == null ? null : DateTime.tryParse(mfgDate!);

  bool get isExpired {
    final e = expiry;
    return e != null && e.isBefore(DateTime.now());
  }

  /// Days until expiry (negative when already expired), null when unknown.
  int? get daysToExpiry {
    final e = expiry;
    if (e == null) return null;
    return e.difference(DateTime.now()).inDays;
  }

  String get subtitle {
    final parts = [
      genericName,
      strength,
      MedicineForm.bnText(dosageForm),
    ].whereType<String>().where((e) => e.trim().isNotEmpty);
    return parts.join(' · ');
  }

  /// True when the catalogue or the shop carries any price for this row.
  bool get hasPrice =>
      (unitPrice?.trim().isNotEmpty ?? false) ||
      (priceText?.trim().isNotEmpty ?? false) ||
      (mrp?.trim().isNotEmpty ?? false);

  String get priceLabel {
    final unit = unitPrice?.trim();
    if (unit != null && unit.isNotEmpty) return '৳ ${bn(unit)}';
    final text = priceText?.trim();
    if (text != null && text.isNotEmpty) return _bnPriceText(text);
    return 'মূল্য পাওয়া যায়নি';
  }

  /// Bengali display for the raw pack string ("5 x 10: ৳ 200.50",
  /// "100's pack: ৳ 400.00"), e.g. “প্যাক: ৫×১০ · ৳২০০.৫০”.
  String get packLabel {
    final p = packSizes?.trim();
    if (p == null || p.isEmpty) return '';
    var s = p
        .replaceAllMapped(
          RegExp(r"(\d+)\s*'s\s*pack", caseSensitive: false),
          (m) => '${m[1]}টি',
        )
        .replaceAllMapped(
          RegExp(r'\s*\bpack\b\s*', caseSensitive: false),
          (m) => ' ',
        )
        .replaceAll(RegExp(r'\s*x\s*', caseSensitive: false), '×')
        .replaceAll(RegExp(r'\s*:\s*'), ' · ');
    s = bn(s.trim());
    return 'প্যাক: $s';
  }

  /// Source text shown on the medicine detail page, keyed for translation.
  Map<String, String> get translationFields {
    final result = <String, String>{};
    for (final section in clinicalSections) {
      result[section.key] = section.value;
    }
    return result;
  }

  static String _bnPriceText(String t) {
    var s = t
        .replaceAll(
          RegExp(r'unit\s*price\s*:', caseSensitive: false),
          'একক মূল্য:',
        )
        .replaceAll(
          RegExp(r'strip\s*price\s*:', caseSensitive: false),
          'স্ট্রিপ:',
        )
        .replaceAll(RegExp(r'box\s*price\s*:', caseSensitive: false), 'বক্স:')
        .replaceAllMapped(
          RegExp(r"(\d+)\s*'s\s*pack", caseSensitive: false),
          (m) => '${m[1]}টি প্যাক',
        )
        .replaceAll(RegExp(r'\s*x\s*', caseSensitive: false), '×');
    return bn(s);
  }

  /// Canonicalizes alternative upstream section keys (e.g. 'dosage', 'administration')
  /// to their standard clinical section key to strictly avoid duplicate sections in UI.
  static String canonicalSectionKey(String key) {
    switch (key.trim().toLowerCase()) {
      case 'dosage':
      case 'administration':
      case 'dosage_and_administration':
        return 'dosage_and_administration';
      case 'pregnancy_cat':
      case 'pregnancy_and_lactation':
        return 'pregnancy_and_lactation';
      case 'precautions':
      case 'precautions_and_warnings':
        return 'precautions_and_warnings';
      case 'drug_classes':
      case 'therapeutic_class':
        return 'therapeutic_class';
      case 'commonly_asked_questions':
      case 'common_questions':
        return 'common_questions';
      default:
        return key.trim();
    }
  }

  /// Clinical sections that actually contain text, in display order. Each
  /// carries a stable [MedicineSection.key] so a per-field translation can be
  /// cached and re-validated against the source text independently of the
  /// Bengali display label.
  List<MedicineSection> get clinicalSections {
    final result = <MedicineSection>[];
    final seenText = <String>{};
    final seenKeys = <String>{};

    void add(String key, String label, String? value) {
      if (seenKeys.contains(key)) return;
      final text = value?.trim();
      if (text == null || text.isEmpty) return;
      // The same paragraph can arrive both as a mapped column and inside
      // sections_json under an alias key; show it once.
      if (!seenText.add(text.replaceAll(RegExp(r'\s+'), ' ').toLowerCase())) {
        return;
      }
      seenKeys.add(key);
      result.add(MedicineSection(key, label, text));
    }

    add('indications', 'রোগের নির্দেশনা', indications);
    add('composition', 'গঠন', composition);
    add('pharmacology', 'ফার্মাকোলজি', pharmacology);
    add('dosage_and_administration', 'ডোজ ও ব্যবহার', dosageAndAdministration);
    add('interaction', 'অন্যান্য ওষুধের সাথে ক্রিয়া', interaction);
    add(
      'contraindications',
      'যেসব ক্ষেত্রে ব্যবহার নিষিদ্ধ',
      contraindications,
    );
    add('side_effects', 'পার্শ্বপ্রতিক্রিয়া', sideEffects);
    add(
      'pregnancy_and_lactation',
      'গর্ভাবস্থা ও স্তন্যদান',
      pregnancyAndLactation,
    );
    add(
      'precautions_and_warnings',
      'সতর্কতা ও সাবধানতা',
      precautionsAndWarnings,
    );
    add('overdose_effects', 'অতিরিক্ত ডোজের প্রভাব', overdoseEffects);
    add('therapeutic_class', 'থেরাপিউটিক শ্রেণি', therapeuticClass);
    add('storage_conditions', 'সংরক্ষণ পদ্ধতি', storageConditions);
    add('common_questions', 'সাধারণ প্রশ্ন', commonQuestions);

    // Preserve any source section not mapped above, always under a Bangla
    // label. Raw API section keys (mode_of_action, pediatric_uses…) never
    // leak into the UI as English headings.
    const known = {
      'indications',
      'composition',
      'pharmacology',
      'dosage_and_administration',
      'interaction',
      'contraindications',
      'side_effects',
      'pregnancy_and_lactation',
      'precautions_and_warnings',
      'overdose_effects',
      'therapeutic_class',
      'storage_conditions',
      'common_questions',
    };
    sections.forEach((key, value) {
      if (known.contains(key)) return;
      // If dosage was already set, avoid duplicate dosage alias sections
      if ((key == 'dosage' || key == 'administration') &&
          seenKeys.contains('dosage_and_administration')) {
        return;
      }
      add(key, bnSectionLabel(key), value);
    });

    // When the catalog row has no stored clinical text, populate from our
    // verified clinical engine so no medicine is presented blank to the user.
    if (result.isEmpty &&
        genericName != null &&
        genericName!.trim().isNotEmpty) {
      final engineData = ClinicalKnowledgeEngine.getClinicalSections(this);
      for (final entry in engineData.entries) {
        if (seenKeys.contains(entry.key)) continue;
        add(entry.key, bnSectionLabel(entry.key), entry.value);
      }
    }
    return result;
  }

  static String bnSectionLabel(String key) =>
      _bnSectionLabels[key] ??
      (const {
            'indications': 'রোগের নির্দেশনা',
            'composition': 'গঠন',
            'pharmacology': 'ফার্মাকোলজি',
            'dosage_and_administration': 'ডোজ ও ব্যবহার',
            'interaction': 'অন্যান্য ওষুধের সাথে ক্রিয়া',
            'contraindications': 'যেসব ক্ষেত্রে ব্যবহার নিষিদ্ধ',
            'side_effects': 'পার্শ্বপ্রতিক্রিয়া',
            'pregnancy_and_lactation': 'গর্ভাবস্থা ও স্তন্যদান',
            'precautions_and_warnings': 'সতর্কতা ও সাবধানতা',
            'overdose_effects': 'অতিরিক্ত ডোজের প্রভাব',
            'therapeutic_class': 'থেরাপিউটিক শ্রেণি',
            'storage_conditions': 'সংরক্ষণ পদ্ধতি',
            'common_questions': 'সাধারণ প্রশ্ন',
          }[key] ??
          'ক্লিনিক্যাল তথ্য');

  /// Bengali headings for every section key the upstream scraper produces.
  static const Map<String, String> _bnSectionLabels = {
    'mode_of_action': 'কাজের ধরন',
    'dosage': 'ডোজ ও ব্যবহার',
    'pregnancy_cat': 'গর্ভাবস্থা ও স্তন্যদান',
    'precautions': 'সতর্কতা ও সাবধানতা',
    'pediatric_uses': 'শিশুদের প্রয়োগ',
    'drug_classes': 'থেরাপিউটিক শ্রেণি',
    'reconstitution': 'গোলানো ও প্রস্তুতির নিয়ম',
    'administration': 'প্রয়োগ পদ্ধতি',
    'duration_of_treatment': 'চিকিৎসার মেয়াদ',
    'description': 'পরিচিতি',
    'compound_summary': 'সারসংক্ষেপ',
    'commonly_asked_questions': 'সাধারণ প্রশ্ন',
  };

  bool get hasClinicalData => clinicalSections.isNotEmpty;

  /// Field-by-field comparison of the *listing* (summary) attributes only.
  /// Used by the incremental sync to decide whether a known medicine changed
  /// upstream (price, strength, manufacturer…) without downloading its detail.
  /// Null and empty/whitespace are treated as equal.
  bool sameSummaryAs(Medicine other) {
    bool eq(String? a, String? b) =>
        (a?.trim().isEmpty ?? true) == (b?.trim().isEmpty ?? true)
        ? (a?.trim() ?? '') == (b?.trim() ?? '')
        : false;
    return eq(brandName, other.brandName) &&
        eq(slug, other.slug) &&
        eq(url, other.url) &&
        eq(dosageForm, other.dosageForm) &&
        eq(strength, other.strength) &&
        eq(genericName, other.genericName) &&
        genericId == other.genericId &&
        eq(company, other.company) &&
        companyId == other.companyId &&
        eq(unitPrice, other.unitPrice) &&
        eq(priceText, other.priceText) &&
        eq(packSizes, other.packSizes);
  }

  /// The minimum complete identity the catalog will accept: brand, generic,
  /// company, dosage form and strength all present. API rows missing any of
  /// these are skipped on import ("incomplete" records are never inserted).
  bool get hasCoreIdentity =>
      _notEmpty(brandName) &&
      _notEmpty(genericName) &&
      _notEmpty(company) &&
      _notEmpty(dosageForm) &&
      _notEmpty(strength);

  static bool _notEmpty(String? v) => v != null && v.trim().isNotEmpty;

  factory Medicine.fromApi(Map<String, dynamic> map) {
    final sectionsRaw = map['sections'];
    final sections = <String, String>{};
    if (sectionsRaw is Map) {
      sectionsRaw.forEach((key, value) {
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) sections[key.toString()] = text;
      });
    } else {
      final sectionsJson = pickString(map, const ['sections_json']);
      if (sectionsJson != null) {
        try {
          final decoded = jsonDecode(sectionsJson);
          if (decoded is Map) {
            decoded.forEach((key, value) {
              final text = value?.toString().trim() ?? '';
              if (text.isNotEmpty) sections[key.toString()] = text;
            });
          }
        } on FormatException {
          // Ignore malformed cache; columns below still carry the data.
        }
      }
    }

    String? pick(List<String> keys) {
      final direct = pickString(map, keys);
      if (direct != null) return direct;
      // The detail route also returns the same text inside `sections`.
      for (final key in keys) {
        final fromSections = sections[key];
        if (fromSections != null && fromSections.isNotEmpty) {
          return fromSections;
        }
      }
      return null;
    }

    int? pickI(List<String> keys) => pickInt(map, keys);

    return Medicine(
      id: pickI(const ['id']) ?? 0,
      brandName:
          pick(const ['brand_name', 'brandName', 'name']) ?? 'নামহীন ওষুধ',
      slug: pick(const ['slug']),
      url: pick(const ['url']),
      dosageForm: pick(const ['dosage_form', 'dosageForm']),
      strength: pick(const ['strength']),
      genericName: pick(const ['generic_name', 'genericName']),
      genericId: pickI(const ['generic_id', 'genericId']),
      company: pick(const ['company', 'company_name', 'manufacturer']),
      companyId: pickI(const ['company_id', 'companyId']),
      unitPrice: pick(const ['unit_price', 'unitPrice', 'price']),
      priceText: pick(const ['price_text', 'priceText']),
      packSizes: pick(const ['pack_sizes', 'packSizes', 'pack_size']),
      indications: pick(const ['indications']),
      composition: pick(const ['composition']),
      pharmacology: pick(const ['pharmacology']),
      dosageAndAdministration: pick(const [
        'dosage_and_administration',
        'dosageAndAdministration',
      ]),
      interaction: pick(const ['interaction', 'interactions']),
      contraindications: pick(const ['contraindications']),
      sideEffects: pick(const ['side_effects', 'sideEffects']),
      pregnancyAndLactation: pick(const [
        'pregnancy_and_lactation',
        'pregnancyAndLactation',
      ]),
      precautionsAndWarnings: pick(const [
        'precautions_and_warnings',
        'precautionsAndWarnings',
      ]),
      overdoseEffects: pick(const ['overdose_effects', 'overdoseEffects']),
      therapeuticClass: pick(const ['therapeutic_class', 'therapeuticClass']),
      storageConditions: pick(const [
        'storage_conditions',
        'storageConditions',
      ]),
      commonQuestions: pick(const ['common_questions', 'commonQuestions']),
      sections: sections,
      detailLoaded: map['detail_loaded'] == 1 || sections.isNotEmpty,
      source: pick(const ['source']) ?? 'Bangladeshi-Medicine-API',
      sourceUpdated: pick(const [
        'source_updated',
        'last_updated',
        'lastUpdated',
      ]),
      firstSeen: pickI(const ['first_seen', 'firstSeen']),
      lastUpdated: pickI(const ['last_updated', 'lastUpdated']),
      companyLogoUrl: pick(const ['company_logo_url', 'companyLogoUrl']),
    );
  }

  factory Medicine.fromDb(Map<String, Object?> row) {
    String? s(String key) {
      final value = row[key]?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }

    int? i(String key) {
      final value = row[key];
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '');
    }

    final sections = <String, String>{};
    final sectionsJson = s('sections_json');
    if (sectionsJson != null) {
      try {
        final decoded = jsonDecode(sectionsJson);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            final text = value?.toString().trim() ?? '';
            if (text.isNotEmpty) sections[key.toString()] = text;
          });
        }
      } on FormatException {
        // keep empty; columns are authoritative
      }
    }

    final stored = s('source') ?? 'Bangladeshi-Medicine-API';
    return Medicine(
      id: i('id') ?? 0,
      brandName: s('brand_name') ?? 'নামহীন ওষুধ',
      slug: s('slug'),
      url: s('url'),
      dosageForm: s('dosage_form'),
      strength: s('strength'),
      genericName: s('generic_name'),
      genericId: i('generic_id'),
      company: s('company'),
      companyId: i('company_id'),
      unitPrice: s('unit_price'),
      priceText: s('price_text'),
      packSizes: s('pack_sizes'),
      indications: s('indications'),
      composition: s('composition'),
      pharmacology: s('pharmacology'),
      dosageAndAdministration: s('dosage_and_administration'),
      interaction: s('interaction'),
      contraindications: s('contraindications'),
      sideEffects: s('side_effects'),
      pregnancyAndLactation: s('pregnancy_and_lactation'),
      precautionsAndWarnings: s('precautions_and_warnings'),
      overdoseEffects: s('overdose_effects'),
      therapeuticClass: s('therapeutic_class'),
      storageConditions: s('storage_conditions'),
      commonQuestions: s('common_questions'),
      sections: sections,
      detailLoaded: (i('detail_loaded') ?? 0) == 1,
      source: stored,
      sourceUpdated: s('source_updated'),
      firstSeen: i('first_seen'),
      lastUpdated: i('last_updated'),
      tradePrice: s('trade_price'),
      mrp: s('mrp'),
      stockQuantity: i('stock_quantity'),
      batchNumber: s('batch_number'),
      rackNo: s('rack_no'),
      mfgDate: s('mfg_date'),
      expiryDate: s('expiry_date'),
      companyLogoUrl: s('company_logo_url'),
    );
  }

  Map<String, Object?> toDbMap() => {
    'id': id,
    'slug': slug,
    'url': url,
    'brand_name': brandName,
    'dosage_form': dosageForm,
    'strength': strength,
    'generic_name': genericName,
    'generic_id': genericId,
    'company': company,
    'company_id': companyId,
    'unit_price': unitPrice,
    'price_text': priceText,
    'pack_sizes': packSizes,
    'indications': indications,
    'composition': composition,
    'pharmacology': pharmacology,
    'dosage_and_administration': dosageAndAdministration,
    'interaction': interaction,
    'contraindications': contraindications,
    'side_effects': sideEffects,
    'pregnancy_and_lactation': pregnancyAndLactation,
    'precautions_and_warnings': precautionsAndWarnings,
    'overdose_effects': overdoseEffects,
    'therapeutic_class': therapeuticClass,
    'storage_conditions': storageConditions,
    'common_questions': commonQuestions,
    'sections_json': sections.isEmpty ? null : jsonEncode(sections),
    'detail_loaded': detailLoaded ? 1 : 0,
    'source': source,
    'source_updated': sourceUpdated,
    'first_seen': firstSeen,
    'last_updated': lastUpdated,
    'trade_price': tradePrice,
    'mrp': mrp,
    'stock_quantity': stockQuantity,
    'batch_number': batchNumber,
    'rack_no': rackNo,
    'mfg_date': mfgDate,
    'expiry_date': expiryDate,
    'company_logo_url': companyLogoUrl,
  };

  /// Compact context for AI prompts; never includes contact or personal data.
  String toAiContext() {
    final buffer = StringBuffer()
      ..writeln('ব্র্যান্ড: $brandName')
      ..writeln('জেনেরিক: ${genericName ?? "অজানা"}')
      ..writeln('শক্তি: ${strength ?? "অজানা"}')
      ..writeln('ডোজ ফর্ম: ${dosageForm ?? "অজানা"}')
      ..writeln('প্রস্তুতকারক: ${company ?? "অজানা"}')
      ..writeln('মূল্য: $priceLabel');
    for (final section in clinicalSections) {
      buffer.writeln('${section.label}: ${stripHtml(section.value)}');
    }
    if (!hasClinicalData) {
      buffer.writeln('বিস্তারিত ক্লিনিক্যাল তথ্য এখনো ডাউনলোড হয়নি।');
    }
    return buffer.toString();
  }
}

class MedicineSection {
  const MedicineSection(this.key, this.label, this.value);

  /// Stable identifier for the underlying field (e.g. `indications`), used to
  /// key cached translations. Not shown to the user.
  final String key;
  final String label;
  final String value;
}

class MedicinePage {
  const MedicinePage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<Medicine> items;
  final int page;
  final int totalPages;
  final int total;

  bool get hasMore => page < totalPages;
}
