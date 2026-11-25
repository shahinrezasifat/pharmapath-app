/// Canonical medicine dosage-form categories and a classifier that maps the
/// messy free-text `dosage_form` strings the API returns (119 distinct values
/// like "Tablet (Extended Release)", "IM/IV Injection", "Ophthalmic Solution")
/// onto a small, stable set that each owns a distinct icon in the UI.
///
/// Kept deliberately free of any Flutter import so the pure [Medicine] model
/// can expose `Medicine.form` without dragging the widget layer in. Icon data
/// lives in `widgets/medicine_form_icons.dart`.
enum MedicineForm {
  tablet,
  capsule,
  syrup,
  suspension,
  suppository,
  injection,
  ointment,
  cream,
  gel,
  drop,
  inhaler,
  saline,
  spray,
  powder,
  lotion,
  other;

  /// Bengla label shown in dropdowns and chips.
  String get label => switch (this) {
    MedicineForm.tablet => 'ট্যাবলেট',
    MedicineForm.capsule => 'ক্যাপসুল',
    MedicineForm.syrup => 'সিরাপ',
    MedicineForm.suspension => 'সাসপেনশন',
    MedicineForm.suppository => 'সাপোজিটরি',
    MedicineForm.injection => 'ইনজেকশন',
    MedicineForm.ointment => 'অয়েন্টমেন্ট',
    MedicineForm.cream => 'ক্রিম',
    MedicineForm.gel => 'জেল',
    MedicineForm.drop => 'ড্রপ',
    MedicineForm.inhaler => 'ইনহেলার',
    MedicineForm.saline => 'স্যালাইন',
    MedicineForm.spray => 'স্প্রে',
    MedicineForm.powder => 'পাউডার',
    MedicineForm.lotion => 'লোশন',
    MedicineForm.other => 'অন্যান্য',
  };

  /// Stable ascii key stored for manually-added medicines' `dosage_form`.
  String get key => name;

  /// Every category in display order, used to build the type dropdown.
  static const List<MedicineForm> selectable = [
    tablet,
    capsule,
    syrup,
    suspension,
    suppository,
    injection,
    ointment,
    cream,
    gel,
    drop,
    inhaler,
    saline,
    spray,
    powder,
    lotion,
  ];

  /// Resolve a canonical form from raw source text. Rules are ordered so the
  /// most specific signal wins first: an "Ophthalmic Solution" is a drop, a
  /// "Powder for Suspension" is a suspension, a "Dry Powder Inhalation
  /// Capsule" is an inhaler — even though each also mentions another form.
  static MedicineForm classify(String? raw) {
    final s = (raw ?? '').toLowerCase();
    if (s.isEmpty) return MedicineForm.other;
    bool has(List<String> keys) => keys.any((k) => s.contains(k));

    // Devices / hygiene that aren't a drug dosage form.
    if (has([
      'glucometer',
      'bp monitor',
      'test strip',
      'strip ',
      'hand rub',
      'mouthwash',
      'shampoo',
      'medicated bar',
      'soap',
      'device',
      'kit',
    ])) {
      return MedicineForm.other;
    }
    // Inhalation devices before any "capsule"/"solution" they mention.
    if (has([
      'inhalat',
      'inhaler',
      'nebulis',
      ' mdi',
      'dpi',
      'dry powder inhal',
    ])) {
      return MedicineForm.inhaler;
    }
    // Eye/ear/nose preparations → drop, even when labelled solution/spray is
    // reserved for nasal spray which is caught below.
    if (has([
      'ophthalmic',
      'ocular',
      'ear drop',
      'auricular',
      'nasal drop',
      'eye drop',
      'drops',
    ])) {
      if (s.contains('spray')) return MedicineForm.spray;
      if (has(['ointment'])) return MedicineForm.ointment;
      if (has(['gel'])) return MedicineForm.gel;
      return MedicineForm.drop;
    }
    if (has(['spray'])) return MedicineForm.spray;
    if (has(['suppositor', 'ovule', 'vaginal'])) {
      return MedicineForm.suppository;
    }
    // IV fluids / saline before generic injection.
    if (has([
      'saline',
      'ringer',
      'iv infusion',
      'infusion',
      'iv fluid',
      'dextrose',
      'dns',
      'normal saline',
    ])) {
      return MedicineForm.saline;
    }
    if (has([
      'injection',
      'injectable',
      ' iv',
      ' im',
      ' sc ',
      's/c',
      'i/v',
      'i.m',
      'syringe',
      'ampoule',
      'vial',
    ])) {
      return MedicineForm.injection;
    }
    // Suspension before powder (so "Powder for Suspension" is a suspension).
    if (has(['suspension'])) return MedicineForm.suspension;
    if (has(['powder', 'granule'])) return MedicineForm.powder;
    if (has(['syrup', 'elixir', 'oral solution', 'solution'])) {
      return MedicineForm.syrup;
    }
    // Topical semi-solids: order ointment → cream → gel → lotion. A "softgel
    // capsule" mentions gel but is an oral capsule, so gel excludes capsules.
    if (has(['ointment'])) return MedicineForm.ointment;
    if (has(['cream'])) return MedicineForm.cream;
    if (has(['gel']) && !has(['capsule'])) return MedicineForm.gel;
    if (has(['lotion'])) return MedicineForm.lotion;
    if (has(['tablet', 'lozenge', 'troche', 'mups'])) {
      return MedicineForm.tablet;
    }
    if (has(['capsule'])) return MedicineForm.capsule;
    return MedicineForm.other;
  }

  /// Reverse lookup for manually-created rows whose `dosage_form` may be a
  /// stored key, a Bengali label, or English category name.
  static MedicineForm fromStored(String? raw) {
    final s = (raw ?? '').trim();
    for (final f in MedicineForm.values) {
      if (f.key == s || f.label == s) return f;
    }
    return classify(s);
  }

  /// Exact Bengali display names for every raw `dosage_form` string the
  /// catalogue ships (110 distinct values). Keys are compared case-
  /// insensitively. International release/route abbreviations (ER, IV, DPI…)
  /// stay as on packaging, mirroring the brand/generic-name exception.
  static const Map<String, String> _bnForms = {
    'bp monitor device': 'বিপি মনিটর ডিভাইস',
    'capsule': 'ক্যাপসুল',
    'capsule (controlled release)': 'ক্যাপসুল (নিয়ন্ত্রিত নিঃসরণ)',
    'capsule (delayed release)': 'ক্যাপসুল (বিলম্বিত নিঃসরণ)',
    'capsule (enteric coated)': 'ক্যাপসুল (আন্ত্রিক-আবৃত)',
    'capsule (extended release)': 'ক্যাপসুল (ধীর-নিঃসরণ)',
    'capsule (modified release)': 'ক্যাপসুল (পরিমিত নিঃসরণ)',
    'capsule (sustained release)': 'ক্যাপসুল (সতত নিঃসরণ)',
    'capsule (timed release)': 'ক্যাপসুল (সময়নিয়ন্ত্রিত নিঃসরণ)',
    'chewable tablet': 'চিবানো ট্যাবলেট',
    'cream': 'ক্রিম',
    'dialysis solution': 'ডায়ালাইসিস দ্রবণ',
    'dispersible tablet': 'ডিসপারসিবল ট্যাবলেট (ছড়ানো)',
    'dry powder inhalation capsule (dpi)':
        'শুষ্ক-পাউডার ইনহেলেশন ক্যাপসুল (DPI)',
    'ear drop': 'কানের ড্রপ',
    'effervescent granules': 'গ্যাসযুক্ত গ্রানুল',
    'effervescent powder': 'গ্যাসযুক্ত পাউডার',
    'effervescent tablet': 'গ্যাসযুক্ত ট্যাবলেট',
    'emulsion': 'ইমালশন',
    'emulsion for infusion': 'ইনফিউশন ইমালশন',
    'extend release suspension': 'ধীর-নিঃসরণ সাসপেনশন',
    'flash tablet': 'ফ্ল্যাশ ট্যাবলেট (মুখে গলে)',
    'gel': 'জেল',
    'hand rub': 'হ্যান্ড রুব (স্যানিটাইজার)',
    'im injection': 'পেশিতে ইনজেকশন (IM)',
    'im/ia injection': 'ইনজেকশন (IM/IA)',
    'im/iv injection': 'ইনজেকশন (IM/IV)',
    'im/sc injection': 'ইনজেকশন (IM/SC)',
    'iv infusion': 'শিরায় ইনফিউশন (IV)',
    'iv injection': 'শিরায় ইনজেকশন (IV)',
    'iv injection or infusion': 'ইনজেকশন/ইনফিউশন (IV)',
    'iv/sc injection': 'ইনজেকশন (IV/SC)',
    'injectable solution (oral & im)': 'ইনজেক্টেবল দ্রবণ (মৌখিক ও IM)',
    'injection': 'ইনজেকশন',
    'intra-articular injection': 'সন্ধিতে ইনজেকশন',
    'intracameral injection': 'চোখে ইনজেকশন (ইন্ট্রাক্যামেরাল)',
    'intraocular injection': 'চোখের ভিতরে ইনজেকশন',
    'intraspinal injection': 'মেরুদণ্ডে ইনজেকশন',
    'intratracheal suspension': 'শ্বাসনালীতে সাসপেনশন',
    'intravitreal injection': 'চোখে ইনজেকশন (ইন্ট্রাভিট্রিয়াল)',
    'irrigation solution': 'ইরিগেশন দ্রবণ (ধৌঁখান)',
    'lancet needle': 'ল্যানসেট সুঁচ',
    'liquid': 'তরল',
    'long acting tablet': 'দীর্ঘ-ক্রিয়াশীল ট্যাবলেট',
    'lotion': 'লোশন',
    'medicated bar': 'ঔষধি সাবান',
    'metered-dose inhaler (mdi)': 'মিটারেড-ডোজ ইনহেলার (MDI)',
    'microgranules': 'মাইক্রোগ্রানুল',
    'mouthwash': 'মাউথওয়াশ',
    'multidose dry powder inhaler (mdpi)': 'মাল্টিডোজ পাউডার ইনহেলার (MDPI)',
    'nail lacquer': 'নখের লাকার',
    'nasal drop': 'নাকের ড্রপ',
    'nasal inhaler': 'নাকের ইনহেলার',
    'nasal spray': 'নাকের স্প্রে',
    'nebuliser solution': 'নেবুলাইজার দ্রবণ',
    'nebuliser suspension': 'নেবুলাইজার সাসপেনশন',
    'oros tablet': 'ওরোস ট্যাবলেট (OROS)',
    'ointment': 'মলম (অয়েন্টমেন্ট)',
    'ophthalmic emulsion': 'চোখের ইমালশন',
    'ophthalmic gel': 'চোখের জেল',
    'ophthalmic ointment': 'চোখের মলম',
    'ophthalmic solution': 'চোখের দ্রবণ (ড্রপ)',
    'ophthalmic suspension': 'চোখের সাসপেনশন',
    'oral gel': 'মৌখিক জেল',
    'oral granules': 'মৌখিক গ্রানুল',
    'oral paste': 'মৌখিক পেস্ট',
    'oral powder': 'মৌখিক পাউডার',
    'oral soluble film': 'মৌখিক গলনশীল ফিল্ম',
    'oral solution': 'মৌখিক দ্রবণ',
    'oral suspension': 'মৌখিক সাসপেনশন',
    'pediatric drops': 'শিশুদের ড্রপ',
    'pen needle': 'পেন সূচ (নিডল)',
    'powder for injection': 'ইনজেকশন পাউডার (লায়োফিলাইজড)',
    'powder for solution': 'দ্রবণ তৈরির পাউডার',
    'powder for suspension': 'সাসপেনশন তৈরির পাউডার',
    'rectal ointment': 'মলদ্বারের মলম',
    'rectal saline': 'মলদ্বারের স্যালাইন',
    'retard tablet': 'রিটার্ড ট্যাবলেট (ধীর-নিঃসরণ)',
    'sc injection': 'ত্বকের নিচে ইনজেকশন (SC)',
    'scalp lotion': 'মাথার ত্বকের লোশন',
    'scalp ointment': 'মাথার ত্বকের মলম',
    'scalp solution': 'মাথার ত্বকের দ্রবণ',
    'shampoo': 'শ্যাম্পু',
    'solution': 'দ্রবণ',
    'sprinkle capsule': 'স্প্রিংকল ক্যাপসুল (ছড়ানো)',
    'sublingual tablet': 'জিভের নিচের ট্যাবলেট',
    'suppository': 'সাপোজিটরি (মলদ্বার)',
    'surgical scrub': 'সার্জিক্যাল স্ক্রাব',
    'syrup': 'সিরাপ',
    'tablet': 'ট্যাবলেট',
    'tablet (controlled release)': 'ট্যাবলেট (নিয়ন্ত্রিত নিঃসরণ)',
    'tablet (delayed release)': 'ট্যাবলেট (বিলম্বিত নিঃসরণ)',
    'tablet (enteric coated)': 'ট্যাবলেট (আন্ত্রিক-আবৃত)',
    'tablet (extended release)': 'ট্যাবলেট (ধীর-নিঃসরণ)',
    'tablet (modified release)': 'ট্যাবলেট (পরিমিত নিঃসরণ)',
    'tablet (prolonged release)': 'ট্যাবলেট (দীর্ঘ-নিঃসরণ)',
    'tablet (sustained release)': 'ট্যাবলেট (সতত নিঃসরণ)',
    'topical gel': 'ত্বকের জেল',
    'topical powder': 'ত্বকের পাউডার',
    'topical solution': 'ত্বকের দ্রবণ',
    'topical spray': 'ত্বকের স্প্রে',
    'topical suspension': 'ত্বকের সাসপেনশন',
    'transdermal patch': 'ত্বকের প্যাচ (ট্রান্সডারমাল)',
    'vaginal cream': 'যোনির ক্রিম',
    'vaginal gel': 'যোনির জেল',
    'vaginal pessary': 'যোনির পেসারি',
    'vaginal tablet': 'যোনির ট্যাবলেট',
    'viscoelastic solution': 'ভিসকোইলাস্টিক দ্রবণ',
    'viscous eye drop': 'ঘন চোখের ড্রপ',
    'mups tablet': 'এমইউপিএস ট্যাবলেট (MUPS)',
  };

  /// Bengali display text for a raw API dosage form. Falls back to the
  /// classified category label, so unknown or hand-typed strings still render
  /// in Bangla; returns the original only when nothing matches at all.
  static String bnText(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return '';
    final exact = _bnForms[s.toLowerCase()];
    if (exact != null) return exact;
    // Manual rows store the Bengali label or the ascii key; show the label.
    for (final f in MedicineForm.values) {
      if (f.key == s || f.label == s) return f.label;
    }
    final category = classify(s);
    return category == MedicineForm.other ? s : category.label;
  }
}
