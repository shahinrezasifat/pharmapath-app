import 'package:flutter/material.dart';

import '../app/theme.dart';

/// A stable visual identity for every manufacturer in the catalogue.
///
/// Companies whose official artwork is bundled with the app resolve to a
/// real logo asset. Every other manufacturer still gets a distinct, consistent
/// brand seal built from its initials and a colour derived from its name, so
/// two different companies can never look alike in a medicine list.
class CompanyBrand {
  const CompanyBrand({
    required this.name,
    required this.initials,
    required this.primary,
    required this.secondary,
    this.logoAsset,
  });

  final String name;
  final String initials;
  final Color primary;
  final Color secondary;
  final String? logoAsset;

  bool get hasOfficialLogo => logoAsset != null;

  /// Normalised key used by [CompanyBrands].
  String get key => CompanyBrands.normalise(name);
}

abstract final class CompanyBrands {
  /// Colour pair + optional bundled logo for the manufacturers that account
  /// for most of the catalogue. Colours mirror each company's own identity
  /// (Square navy, Incepta purple, Opsonin green, …).
  static const Map<String, (Color, Color, String?)> _known = {
    // Official artwork bundled with the app (verified against the brand).
    'aci': (
      Color(0xFF0B7A3B),
      Color(0xFF34D399),
      'assets/companies/aci-limited.png',
    ),
    'acme': (
      Color(0xFF0E7490),
      Color(0xFF22D3EE),
      'assets/companies/acme-laboratories-ltd.png',
    ),
    'albion': (
      Color(0xFF1D4ED8),
      Color(0xFF93C5FD),
      'assets/companies/albion-laboratories-limited.png',
    ),
    'ambee': (
      Color(0xFF1D4ED8),
      Color(0xFF93C5FD),
      'assets/companies/ambee-pharmaceuticals-ltd.png',
    ),
    'amico': (
      Color(0xFF1D4ED8),
      Color(0xFF60A5FA),
      'assets/companies/amico-laboratories-ltd.png',
    ),
    'apex': (
      Color(0xFFC2410C),
      Color(0xFFFB923C),
      'assets/companies/apex-pharma-ltd.png',
    ),
    'aristopharma': (
      Color(0xFF1D4ED8),
      Color(0xFF60A5FA),
      'assets/companies/aristopharma-ltd.png',
    ),
    'asiatic': (
      Color(0xFF0369A1),
      Color(0xFF7DD3FC),
      'assets/companies/asiatic-laboratories-ltd.png',
    ),
    'astrabiopharmaceuticals': (
      Color(0xFF0D9488),
      Color(0xFF99F6E4),
      'assets/companies/astra-biopharmaceuticals-ltd.png',
    ),
    'bwellswiss': (
      Color(0xFFB91C1C),
      Color(0xFFFCA5A5),
      'assets/companies/b-well-swiss.png',
    ),
    'biopharma': (
      Color(0xFF0369A1),
      Color(0xFF7DD3FC),
      'assets/companies/biopharma-limited.png',
    ),
    'delta': (
      Color(0xFF2563EB),
      Color(0xFF93C5FD),
      'assets/companies/delta-pharma-ltd.png',
    ),
    'general': (
      Color(0xFF4F46E5),
      Color(0xFFA5B4FC),
      'assets/companies/general-pharmaceuticals-ltd.png',
    ),
    'glaxosmithkline': (
      Color(0xFFF97316),
      Color(0xFFFDBA74),
      'assets/companies/glaxosmithkline-pharmaceuticals.png',
    ),
    'globe': (
      Color(0xFF0284C7),
      Color(0xFF7DD3FC),
      'assets/companies/globe-pharmaceuticals-ltd.png',
    ),
    'grifolsbiologicals': (
      Color(0xFF0369A1),
      Color(0xFF7DD3FC),
      'assets/companies/grifols-biologicals-llc.png',
    ),
    'hudson': (
      Color(0xFF0891B2),
      Color(0xFF67E8F9),
      'assets/companies/hudson-pharmaceuticals-ltd.png',
    ),
    'jenphar': (
      Color(0xFF0E7490),
      Color(0xFF67E8F9),
      'assets/companies/jenphar-bangladesh-ltd.png',
    ),
    'kemiko': (
      Color(0xFF0E7490),
      Color(0xFF67E8F9),
      'assets/companies/kemiko-pharmaceuticals-ltd.png',
    ),
    'medimet': (
      Color(0xFF1E3A8A),
      Color(0xFF60A5FA),
      'assets/companies/medimet-pharmaceuticals-ltd.png',
    ),
    'monicopharma': (
      Color(0xFF1D4ED8),
      Color(0xFF60A5FA),
      'assets/companies/monicopharma-ltd.png',
    ),
    'mundipharma': (
      Color(0xFF1D4ED8),
      Color(0xFF60A5FA),
      'assets/companies/mundipharma-bd-pvt-ltd.png',
    ),
    'navana': (
      Color(0xFF0891B2),
      Color(0xFF67E8F9),
      'assets/companies/navana-pharmaceuticals-ltd.png',
    ),
    'nipponkayaku': (
      Color(0xFFBE123C),
      Color(0xFFFDA4AF),
      'assets/companies/nippon-kayaku-ltd.png',
    ),
    'opsonin': (
      Color(0xFF15803D),
      Color(0xFF4ADE80),
      'assets/companies/opsonin-pharma-ltd.png',
    ),
    'radiant': (
      Color(0xFFEA580C),
      Color(0xFFFDBA74),
      'assets/companies/radiant-pharmaceuticals-ltd.png',
    ),
    'reckittbenckiser': (
      Color(0xFFDB2777),
      Color(0xFFF9A8D4),
      'assets/companies/reckitt-benckiser-ltd.png',
    ),
    'renata': (
      Color(0xFFEA580C),
      Color(0xFFFDBA74),
      'assets/companies/renata-plc.png',
    ),
    'roche': (
      Color(0xFF0369A1),
      Color(0xFF7DD3FC),
      'assets/companies/roche-bangladesh-ltd.png',
    ),
    'salton': (
      Color(0xFF15803D),
      Color(0xFF86EFAC),
      'assets/companies/salton-pharmaceuticals-ltd.png',
    ),
    'servier': (
      Color(0xFF1D4ED8),
      Color(0xFF93C5FD),
      'assets/companies/servier-bangladesh-operation.png',
    ),
    'sharif': (
      Color(0xFF0369A1),
      Color(0xFF7DD3FC),
      'assets/companies/sharif-pharmaceuticals-ltd.png',
    ),
    'silco': (
      Color(0xFF1D4ED8),
      Color(0xFF93C5FD),
      'assets/companies/silco-pharmaceutical-ltd.png',
    ),
    'silva': (
      Color(0xFF0369A1),
      Color(0xFF7DD3FC),
      'assets/companies/silva-pharmaceuticals-ltd.png',
    ),
    'square': (
      Color(0xFF1B3A6B),
      Color(0xFF3B82F6),
      'assets/companies/square-pharmaceuticals-plc.png',
    ),
    'technodrugs': (
      Color(0xFF0369A1),
      Color(0xFF7DD3FC),
      'assets/companies/techno-drugs-ltd.png',
    ),
    'whitehorse': (
      Color(0xFF4F46E5),
      Color(0xFFA5B4FC),
      'assets/companies/the-white-horse-pharmaceuticals-ltd.png',
    ),
    'unimedunihealth': (
      Color(0xFFBE123C),
      Color(0xFFFDA4AF),
      'assets/companies/unimed-unihealth-pharmaceuticals-ltd.png',
    ),
    'ziska': (
      Color(0xFF1E3A8A),
      Color(0xFF60A5FA),
      'assets/companies/ziska-pharmaceuticals-ltd.png',
    ),
    'abbott': (
      Color(0xFF1E40AF),
      Color(0xFF93C5FD),
      'assets/companies/abbott-laboratories.png',
    ),

    // Larger manufacturers where the official artwork is not bundled: the seal
    // carries the company's own brand colour so the list still reads at a glance.
    'incepta': (
      Color(0xFF7E22CE),
      Color(0xFFC084FC),
      'assets/companies/incepta-pharmaceuticals-ltd.png',
    ),
    'beximco': (
      Color(0xFF0F766E),
      Color(0xFF2DD4BF),
      'assets/companies/beximco-pharmaceuticals-ltd.png',
    ),
    'eskayef': (
      Color(0xFF0E7490),
      Color(0xFF67E8F9),
      'assets/companies/eskayef-pharmaceuticals-ltd.png',
    ),
    'healthcare': (
      Color(0xFF0D9488),
      Color(0xFF5EEAD4),
      'assets/companies/healthcare-pharmaceuticals-ltd.png',
    ),
    'druginternational': (
      Color(0xFF1D4ED8),
      Color(0xFF60A5FA),
      'assets/companies/drug-international-ltd.png',
    ),
    'popular': (
      Color(0xFF7C3AED),
      Color(0xFFC4B5FD),
      'assets/companies/popular-pharmaceuticals-ltd.png',
    ),
    'pacific': (Color(0xFF0891B2), Color(0xFF67E8F9), null),
    'orion': (
      Color(0xFFB45309),
      Color(0xFFFCD34D),
      'assets/companies/orion-pharma-ltd.png',
    ),
    'euro': (Color(0xFF0F766E), Color(0xFF5EEAD4), null),
    'nuvista': (Color(0xFF9333EA), Color(0xFFD8B4FE), null),
    'synovia': (Color(0xFF4338CA), Color(0xFFA5B4FC), null),
    'veritas': (Color(0xFF047857), Color(0xFF6EE7B7), null),
    'smcenterprise': (Color(0xFF1D4ED8), Color(0xFF60A5FA), null),
    'labaid': (Color(0xFFDC2626), Color(0xFFFCA5A5), null),
    'ibnsina': (
      Color(0xFF059669),
      Color(0xFF6EE7B7),
      'assets/companies/ibn-sina-pharmaceuticals-ltd.png',
    ),
    'gonoshasthaya': (Color(0xFF15803D), Color(0xFF4ADE80), null),
    'beacon': (
      Color(0xFFC2410C),
      Color(0xFFFB923C),
      'assets/companies/beacon-pharmaceuticals-plc.png',
    ),
    'jayson': (Color(0xFFBE123C), Color(0xFFFDA4AF), null),
    'naafco': (Color(0xFF0F766E), Color(0xFF5EEAD4), null),
    'novohealthcare': (Color(0xFF0D9488), Color(0xFF99F6E4), null),
    'nipro': (
      Color(0xFF1D4ED8),
      Color(0xFF93C5FD),
      'assets/companies/nipro-jmi-pharma-ltd.png',
    ),
    'niprojmi': (
      Color(0xFF1D4ED8),
      Color(0xFF93C5FD),
      'assets/companies/nipro-jmi-pharma-ltd.png',
    ),
    'alco': (Color(0xFFB91C1C), Color(0xFFFCA5A5), null),
    'concord': (Color(0xFF4F46E5), Color(0xFFA5B4FC), null),
    'cosmic': (Color(0xFF0891B2), Color(0xFF67E8F9), null),
    'desh': (Color(0xFF15803D), Color(0xFF86EFAC), null),
    'edruc': (Color(0xFFB45309), Color(0xFFFCD34D), null),
    'ethical': (Color(0xFF0F766E), Color(0xFF5EEAD4), null),
    'everest': (Color(0xFF0369A1), Color(0xFF7DD3FC), null),
    'guardianhealthcare': (Color(0xFF4338CA), Color(0xFFA5B4FC), null),
    'hallmark': (Color(0xFFBE123C), Color(0xFFFDA4AF), null),
    'kumudini': (Color(0xFF0D9488), Color(0xFF99F6E4), null),
    'medicon': (Color(0xFF15803D), Color(0xFF86EFAC), null),
    'millat': (Color(0xFF7C3AED), Color(0xFFC4B5FD), null),
    'modern': (Color(0xFF0369A1), Color(0xFF7DD3FC), null),
    'onepharma': (Color(0xFFEA580C), Color(0xFFFDBA74), null),
    'pharmasia': (Color(0xFF15803D), Color(0xFF86EFAC), null),
    'pharmik': (Color(0xFFBE123C), Color(0xFFFDA4AF), null),
    'rephco': (Color(0xFF0E7490), Color(0xFF67E8F9), null),
    'seema': (Color(0xFF7C3AED), Color(0xFFC4B5FD), null),
    'somatec': (Color(0xFF0F766E), Color(0xFF5EEAD4), null),
    'sun': (Color(0xFFB91C1C), Color(0xFFFCA5A5), null),
    'supreme': (Color(0xFF1D4ED8), Color(0xFF93C5FD), null),
    'virgo': (Color(0xFFBE123C), Color(0xFFFDA4AF), null),
    'sandozanovartis': (Color(0xFF0EA5E9), Color(0xFF7DD3FC), null),
    'elililly': (Color(0xFFB91C1C), Color(0xFFFCA5A5), null),
    'johnsonjohnson': (Color(0xFFB91C1C), Color(0xFFFCA5A5), null),
    'bristolmyerssquibb': (Color(0xFF1E3A8A), Color(0xFF60A5FA), null),
    'novonordisk': (Color(0xFF0EA5E9), Color(0xFF7DD3FC), null),
    'lundbeck': (Color(0xFF0D9488), Color(0xFF99F6E4), null),
    'cipla': (Color(0xFF0369A1), Color(0xFF7DD3FC), null),
    'beurer': (Color(0xFFB91C1C), Color(0xFFFCA5A5), null),
    'omron': (Color(0xFF1D4ED8), Color(0xFF93C5FD), null),
  };

  static const List<(Color, Color)> _palette = [
    (Color(0xFFB91C1C), Color(0xFFF87171)),
    (Color(0xFF1E3A8A), Color(0xFF60A5FA)),
    (Color(0xFF0F766E), Color(0xFF2DD4BF)),
    (Color(0xFF7C3AED), Color(0xFFC4B5FD)),
    (Color(0xFFC2410C), Color(0xFFFDBA74)),
    (Color(0xFF0369A1), Color(0xFF7DD3FC)),
    (Color(0xFF15803D), Color(0xFF86EFAC)),
    (Color(0xFFBE123C), Color(0xFFFDA4AF)),
    (Color(0xFF4F46E5), Color(0xFFA5B4FC)),
    (Color(0xFF0D9488), Color(0xFF99F6E4)),
  ];

  static String normalise(String name) {
    final lower = name.toLowerCase();
    // Drop common corporate suffixes and punctuation so
    // "Square Pharmaceuticals PLC" and "Square Pharma Ltd." collide. Words
    // such as "healthcare" are part of some brand names, so they stay.
    final cleaned = lower
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(
          RegExp(
            r'\b(limited|ltd|plc|pvt|private|pharmaceuticals|pharmaceutical|pharma|'
            r'laboratories|laboratory|lab|labs|company|co|corporation|corp|the|'
            r'bangladesh|bd|operations?|division|llc|inc|gmbh|and|of|for|group)\b',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final key = cleaned.replaceAll(' ', '');
    if (key.isNotEmpty) return key;
    // Every word was a generic suffix — fall back to the raw name so the
    // company still gets its own stable identity.
    return lower.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static CompanyBrand of(String? company) {
    final name = (company ?? '').trim();
    if (name.isEmpty) {
      return const CompanyBrand(
        name: 'অজানা প্রস্তুতকারক',
        initials: '?',
        primary: Color(0xFF6B7280),
        secondary: Color(0xFF9CA3AF),
      );
    }
    final key = normalise(name);
    final known = _known[key];
    if (known != null) {
      return CompanyBrand(
        name: name,
        initials: initialsOf(name),
        primary: known.$1,
        secondary: known.$2,
        logoAsset: known.$3,
      );
    }
    // Foreign / smaller manufacturers: derive a stable, distinct palette from
    // the name itself. FNV-1a keeps the colour identical across runs.
    var hash = 0x811c9dc5;
    for (final unit in name.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final pair = _palette[hash % _palette.length];
    return CompanyBrand(
      name: name,
      initials: initialsOf(name),
      primary: pair.$1,
      secondary: pair.$2,
    );
  }

  static String initialsOf(String name) {
    const stop = {
      'the',
      'ltd',
      'limited',
      'plc',
      'pvt',
      'private',
      'pharmaceuticals',
      'pharmaceutical',
      'pharma',
      'laboratories',
      'laboratory',
      'labs',
      'company',
      'co',
      'corporation',
      'corp',
      'and',
      'of',
      'bd',
      'bangladesh',
      'healthcare',
      'health',
      'care',
      'division',
    };
    final words = name
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .where((w) => w.isNotEmpty && !stop.contains(w.toLowerCase()))
        .toList();
    if (words.isEmpty) {
      final raw = name
          .split(RegExp(r'[^A-Za-z0-9]+'))
          .where((w) => w.isNotEmpty)
          .toList();
      if (raw.isEmpty) return '?';
      return raw.first.substring(0, 1).toUpperCase();
    }
    if (words.length == 1) {
      final word = words.first;
      return word.length <= 3
          ? word.toUpperCase()
          : word.substring(0, 2).toUpperCase();
    }
    final first = words.first;
    // Acronym brands such as "ACI" or "SMC" stay whole.
    if (first.length <= 3 && first == first.toUpperCase()) {
      return first.toUpperCase();
    }
    return (first.substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }
}

/// Logo badge for a manufacturer. Uses the bundled official artwork when it is
/// available and falls back to a designed monogram seal otherwise.
class CompanyLogo extends StatelessWidget {
  const CompanyLogo({
    super.key,
    required this.company,
    this.size = 40,
    this.radius,
    this.showBorder = true,
    this.padding = 4,
  });

  final String? company;
  final double size;
  final double? radius;
  final bool showBorder;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final brand = CompanyBrands.of(company);
    final scheme = Theme.of(context).colorScheme;
    final resolvedRadius = radius ?? size * 0.28;
    final fallback = _Monogram(
      brand: brand,
      size: size,
      radius: resolvedRadius,
    );
    final logo = brand.logoAsset;
    final child = logo == null
        ? fallback
        : Container(
            padding: EdgeInsets.all(padding),
            alignment: Alignment.center,
            child: Image.asset(
              logo,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => fallback,
            ),
          );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(resolvedRadius),
        border: showBorder
            ? Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.85),
                width: 0.8,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(
              alpha: AppTheme.isDark(context) ? 0.20 : 0.05,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: -3,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({
    required this.brand,
    required this.size,
    required this.radius,
  });

  final CompanyBrand brand;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brand.primary, brand.secondary],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -size * 0.22,
            top: -size * 0.28,
            child: Container(
              width: size * 0.72,
              height: size * 0.72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
          ),
          Center(
            child: Text(
              brand.initials,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: size * (brand.initials.length >= 3 ? 0.28 : 0.34),
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
