import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/navigation_controller.dart';
import '../controllers/search_controller.dart';
import '../core/format.dart';
import '../data/medicine_dao.dart';
import '../models/medicine.dart';
import '../widgets/medicine_form_icons.dart';
import 'detail_view.dart';

/// Modal bottom sheet listing medicines indicated for a specific disease or condition.
class DiseaseMedicinesSheet extends StatefulWidget {
  const DiseaseMedicinesSheet({
    super.key,
    required this.diseaseName,
    required this.keywords,
  });

  final String diseaseName;
  final List<String> keywords;

  static Future<void> show(
    BuildContext context, {
    required String diseaseName,
    required List<String> keywords,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (_) => DiseaseMedicinesSheet(
        diseaseName: diseaseName,
        keywords: keywords,
      ),
    );
  }

  @override
  State<DiseaseMedicinesSheet> createState() => _DiseaseMedicinesSheetState();
}

class _DiseaseMedicinesSheetState extends State<DiseaseMedicinesSheet> {
  final MedicineDao _dao = Get.find<MedicineDao>();
  late Future<List<Medicine>> _future;

  String _selectedForm = 'সকল';

  @override
  void initState() {
    super.initState();
    _future = _dao.searchByDisease(
      widget.diseaseName,
      keywords: widget.keywords,
      limit: 60,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top drag indicator
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.healing_rounded,
                        color: scheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '‘${widget.diseaseName}’-এর ওষুধসমূহ',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'চিকিৎসায় কার্যকর ও অনুমোদিত ঔষধের তালিকা',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'বন্ধ করুন',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Medicines List
              Expanded(
                child: FutureBuilder<List<Medicine>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: scheme.error,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'ওষুধের তালিকা লোড করা যায়নি',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final allMedicines = snapshot.data ?? [];
                    if (allMedicines.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.medication_outlined,
                                size: 54,
                                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'এই রোগের কোনো ওষুধ সরাসরি পাওয়া যায়নি',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'অনুসন্ধান ট্যাবে গিয়ে সম্পূর্ণ ক্যাটালগে বিকল্প নামে খুঁজে দেখতে পারেন।',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Extract available dosage forms for quick filtering
                    final forms = <String>{'সকল'};
                    for (final m in allMedicines) {
                      final f = (m.dosageForm ?? '').trim();
                      if (f.isNotEmpty) forms.add(f);
                    }

                    final filtered = _selectedForm == 'সকল'
                        ? allMedicines
                        : allMedicines
                            .where((m) => (m.dosageForm ?? '').trim() == _selectedForm)
                            .toList();

                    return Column(
                      children: [
                        // Quick filter chips & count
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: scheme.surfaceContainerLowest,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${bn(filtered.length)}টি ওষুধ',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      for (final form in forms.take(6)) ...[
                                        Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: ChoiceChip(
                                            selected: _selectedForm == form,
                                            label: Text(
                                              form,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: _selectedForm == form
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 6),
                                            onSelected: (_) {
                                              setState(() => _selectedForm = form);
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // List of medicines
                        Expanded(
                          child: ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final formColor = MedicineFormIcon.colorOf(item.form);

                              return Material(
                                color: scheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Get.to(
                                      () => MedicineDetailView(medicine: item),
                                      preventDuplicates: false,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Form icon
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: formColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            MedicineFormIcon.of(item.form),
                                            color: formColor,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Brand, generic, strength, manufacturer
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      item.brandName,
                                                      style: theme.textTheme.titleSmall?.copyWith(
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (item.hasPrice) ...[
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      item.priceLabel,
                                                      style: theme.textTheme.labelMedium?.copyWith(
                                                        color: scheme.primary,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '${item.genericName ?? "জেনেরিক"} · ${item.strength ?? ""} · ${item.dosageForm ?? ""}',
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: scheme.onSurfaceVariant,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if ((item.company ?? '').isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  item.company!,
                                                  style: theme.textTheme.labelSmall?.copyWith(
                                                    color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),

                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Bottom search bar shortcut
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: Text(
                      'সার্চ ট্যাবে ‘${widget.diseaseName}’-এর সকল তথ্য দেখুন',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      if (Get.isRegistered<MedicineSearchController>()) {
                        Get.find<MedicineSearchController>().onQueryChanged(widget.diseaseName);
                      }
                      if (Get.isRegistered<NavigationController>()) {
                        Get.find<NavigationController>().goTo(1);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
