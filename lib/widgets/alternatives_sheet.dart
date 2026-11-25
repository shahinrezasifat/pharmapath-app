import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/medicine_form.dart';
import '../data/medicine_dao.dart';
import '../models/medicine.dart';
import '../views/detail_view.dart';
import 'company_logo.dart';
import 'featured_medicine_tile.dart';
import 'medicine_form_icons.dart';

/// Popup alternative finder. Tapping "বিকল্প ঔষধ" anywhere opens this bottom
/// sheet instead of a full page: the source medicine's generic (and mg) is
/// shown large at the top, and every interchangeable brand — same generic,
/// same strength, other companies — appears as the same product-style square
/// tiles used on the ঔষধ page, two per row. Backing out of the sheet returns
/// to wherever you came from; tapping a tile opens that medicine's profile.
void showAlternativesSheet(BuildContext context, Medicine medicine) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AlternativesSheet(source: medicine),
  );
}

class _AlternativesSheet extends StatefulWidget {
  const _AlternativesSheet({required this.source});

  final Medicine source;

  @override
  State<_AlternativesSheet> createState() => _AlternativesSheetState();
}

class _AlternativesSheetState extends State<_AlternativesSheet> {
  late final Future<List<Medicine>> _future;

  @override
  void initState() {
    super.initState();
    final generic = widget.source.genericName?.trim() ?? '';
    final strength = widget.source.strength?.trim() ?? '';
    _future = Get.find<MedicineDao>().findSimilarByGeneric(
      generic,
      strength: strength.isEmpty ? null : strength,
      excludeId: widget.source.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final generic = widget.source.genericName?.trim() ?? '';
    final strength = widget.source.strength?.trim() ?? '';
    final form = widget.source.form;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // ---- হেডার: মূল ঔষধের জেনেরিক (বড়) ও মাত্রা ----
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: MedicineFormGlyph(form: form, size: 48),
                ),
                const SizedBox(width: 8),
                CompanyLogo(
                  company: widget.source.company,
                  size: 42,
                  radius: 13,
                  padding: 4,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        generic.isEmpty
                            ? widget.source.brandName
                            : (strength.isEmpty
                                  ? generic
                                  : '$generic ($strength)'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          'বিকল্প — ${widget.source.brandName}',
                          if (generic.isNotEmpty) 'একই জেনেরিক ও mg হুবহু',
                          MedicineForm.bnText(widget.source.dosageForm),
                        ].where((e) => e.trim().isNotEmpty).join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(
            child: FutureBuilder<List<Medicine>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        'তালিকা লোড করা যায়নি: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final items = snapshot.data ?? const <Medicine>[];
                if (generic.isEmpty) {
                  return const _BlankHint(
                    text: 'এই ঔষধের জেনেরিক নাম নেই, তাই বিকল্প খোঁজা যায়নি।',
                  );
                }
                if (items.isEmpty) {
                  final label = strength.isEmpty
                      ? '"$generic"'
                      : '"$generic ($strength)"';
                  return _BlankHint(
                    text:
                        '$label মিলে এমন অন্য কোনো ঔষধ ডেটাবেসে নেই। '
                        'ভিন্ন mg বিকল্প হিসেবে দেখানো হয় না।',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (sheetItemContext, index) {
                    final alt = items[index];
                    return FeaturedMedicineTile(
                      medicine: alt,
                      showActions: false,
                      onTap: () {
                        Navigator.of(sheetItemContext).pop();
                        Get.to(
                          () => MedicineDetailView(medicine: alt),
                          preventDuplicates: false,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'ব্র্যান্ড ও জেনেরিক নাম ইংরেজিতে (প্যাকেজিং অনুযায়ী)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlankHint extends StatelessWidget {
  const _BlankHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}
