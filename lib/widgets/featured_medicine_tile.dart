import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/medicine_form.dart';
import '../models/medicine.dart';
import '../views/detail_view.dart';
import 'alternatives_sheet.dart';
import 'company_logo.dart';
import 'medicine_form_icons.dart';

/// List row for a featured medicine, with a form symbol, concise identity,
/// price, company logo and optional quick actions.
class FeaturedMedicineTile extends StatelessWidget {
  const FeaturedMedicineTile({
    super.key,
    required this.medicine,
    required this.onTap,
    this.showActions = true,
  });

  final Medicine medicine;
  final VoidCallback onTap;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final form = medicine.form;
    final generic = medicine.genericName?.trim() ?? '';
    final strength = medicine.strength?.trim() ?? '';
    final genericLine = [
      if (generic.isNotEmpty) generic,
      if (strength.isNotEmpty) strength,
    ].join(' · ');
    final company = medicine.company?.trim() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    MedicineFormGlyph(form: form, size: 48),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medicine.brandName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (genericLine.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              genericLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _FeaturedTag(
                                icon: MedicineFormIcon.of(form),
                                label: form.label,
                                color: MedicineFormIcon.colorOf(form),
                              ),
                              _FeaturedTag(
                                icon: Icons.sell_outlined,
                                label: medicine.hasPrice
                                    ? medicine.priceLabel
                                    : 'দাম নেই',
                                color: medicine.hasPrice
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    CompanyLogo(
                      company: company,
                      size: 40,
                      radius: 11,
                      padding: 2,
                    ),
                  ],
                ),
                if (showActions) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed:
                              medicine.genericName?.trim().isEmpty ?? true
                              ? null
                              : () => showAlternativesSheet(context, medicine),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.swap_horiz_rounded, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'বিকল্প ওষুধ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide(color: scheme.outlineVariant),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () =>
                              showMedicineUsageSheet(context, medicine),
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                          ),
                          label: const Text(
                            'ব্যবহারবিধি',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedTag extends StatelessWidget {
  const _FeaturedTag({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

/// ব্যবহারবিধি bottom sheet: indications and dosage already stored in Bangla
/// (manual or translated rows) are shown directly; English text is labelled as
/// such and the full page stays one tap away. Nothing is ever invented.
void showMedicineUsageSheet(BuildContext context, Medicine medicine) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final indications = medicine.indications?.trim() ?? '';
  final dosage = medicine.dosageAndAdministration?.trim() ?? '';
  final hasInfo = indications.isNotEmpty || dosage.isNotEmpty;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                    MedicineFormIcon.of(medicine.form),
                    size: 22,
                    color: MedicineFormIcon.colorOf(medicine.form),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medicine.brandName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          [
                                medicine.genericName,
                                medicine.strength,
                                MedicineForm.bnText(medicine.dosageForm),
                              ]
                              .where((e) => e != null && e.trim().isNotEmpty)
                              .join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (!hasInfo)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'অফলাইন ক্যাটালগে এই ঔষধের ব্যবহারবিধির তথ্য এখনো যোগ হয়নি। '
                    'বিস্তারিত পাতা থেকে তথ্য আনুন বা নিজে যোগ করুন।',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else ...[
                if (indications.isNotEmpty) ...[
                  _UsageRow(
                    icon: Icons.check_circle_outline,
                    title: 'রোগের নির্দেশনা',
                    body: indications,
                    banglaOnly: _looksBangla(indications),
                  ),
                ],
                if (dosage.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _UsageRow(
                    icon: Icons.schedule_rounded,
                    title: 'সেবনবিধি',
                    body: dosage,
                    banglaOnly: _looksBangla(dosage),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Get.to(
                      () => MedicineDetailView(medicine: medicine),
                      preventDuplicates: false,
                    );
                  },
                  child: const Text('বিস্তারিত পাতা দেখুন'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

bool _looksBangla(String text) => RegExp(r'[\u0980-\u09ff]').hasMatch(text);

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.banglaOnly,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool banglaOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                banglaOnly ? body : '$body\n(ইংরেজি মূল তথ্য)',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
