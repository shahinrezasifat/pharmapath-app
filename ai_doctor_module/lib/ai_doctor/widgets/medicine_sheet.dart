import 'package:flutter/material.dart';

import '../db.dart';
import '../localization.dart';
import '../models.dart';
import 'medication_form_dialog.dart';

/// Optional local medicine description integration.
class AiDrugInfo {
  static String Function(String name)? lookupOverride;

  static const _local = {
    'অ্যামলোডিপিন': 'Lowers blood pressure. Follow the schedule prescribed by your clinician.',
    'অ্যাসপিরিন': 'Can reduce blood clotting. Follow the instructions on your prescription.',
  };

  static String lookup(String name) {
    final override = lookupOverride?.call(name);
    if (override != null) return override;
    if (_local.containsKey(name)) {
      return aiText(
        'এই ওষুধটি চিকিৎসকের নির্দেশ অনুযায়ী ব্যবহার করুন।',
        _local[name]!,
      );
    }
    return aiText(
      'নির্দিষ্ট ওষুধ সম্পর্কে জানতে চিকিৎসক বা ফার্মাসিস্টের পরামর্শ নিন।',
      'For medication-specific guidance, ask a clinician or pharmacist.',
    );
  }
}

class AiMedicineSheet extends StatefulWidget {
  const AiMedicineSheet({
    super.key,
    required this.patientId,
    required this.onNote,
    required this.onAsk,
  });

  final int patientId;
  final void Function(String note) onNote;
  final void Function(String question) onAsk;

  @override
  State<AiMedicineSheet> createState() => _AiMedicineSheetState();
}

class _AiMedicineSheetState extends State<AiMedicineSheet> {
  List<AiMedication> _meds = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final meds = await AiDoctorDb.i.meds(widget.patientId);
    if (mounted) setState(() => _meds = meds);
  }

  Future<AiMedication?> _form(AiMedication? medication) => showDialog(
    context: context,
    builder: (_) => AiMedicationFormDialog(
      patientId: widget.patientId,
      medication: medication,
    ),
  );

  Future<void> _add() async {
    final medication = await _form(null);
    if (medication == null) return;
    await AiDoctorDb.i.addMed(medication);
    widget.onNote(
      aiText(
        'ওষুধ যোগ করা হয়েছে: ${medication.name}, ${medication.dose} '
            '${aiMedicationUnit(medication.unit)}, ${aiLocalizedNumber(medication.timesPerDay)} বার/দিন',
        'Medication added: ${medication.name}, ${medication.dose} '
            '${medication.unit}, ${medication.timesPerDay} times/day',
      ),
    );
    await _load();
  }

  Future<void> _edit(AiMedication old) async {
    final medication = await _form(old);
    if (medication == null) return;
    await AiDoctorDb.i.updateMed(medication);
    widget.onNote(
      aiText(
        'ওষুধের তথ্য হালনাগাদ হয়েছে: ${medication.name}, ${medication.dose} '
            '${aiMedicationUnit(medication.unit)}, ${aiLocalizedNumber(medication.timesPerDay)} বার/দিন',
        'Medication updated: ${medication.name}, ${medication.dose} '
            '${medication.unit}, ${medication.timesPerDay} times/day',
      ),
    );
    await _load();
  }

  Future<void> _stop(AiMedication medication) async {
    await AiDoctorDb.i.stopMed(medication);
    widget.onNote(
      aiText(
        '${medication.name} ওষুধটি বন্ধ করা হয়েছে।',
        'Medication stopped: ${medication.name}',
      ),
    );
    await _load();
  }

  void _ask(AiMedication medication, String question) => widget.onAsk(
    aiText(
      '${medication.name}: প্রতি মাত্রায় ${medication.dose} ${aiMedicationUnit(medication.unit)}, '
          'দিনে ${aiLocalizedNumber(medication.timesPerDay)} বার। $question',
      '${medication.name}: ${medication.dose} ${medication.unit} per dose, '
          '${medication.timesPerDay} times daily. $question',
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    aiText('ওষুধ', 'Medications'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(aiText('যোগ করুন', 'Add')),
                ),
              ],
            ),
          ),
          Flexible(
            child: _meds.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      aiText(
                        'এখনো কোনো চলমান ওষুধ নেই।',
                        'No active medications',
                      ),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final medication in _meds)
                        ExpansionTile(
                          leading: CircleAvatar(
                            radius: 15,
                            backgroundColor: colors.primaryContainer,
                            child: Icon(
                              Icons.medication_outlined,
                              size: 17,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                          title: Text(
                            medication.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            '${medication.dose} ${aiMedicationUnit(medication.unit)} · '
                            '${aiLocalizedNumber(medication.timesPerDay)} ${aiText('বার/দিন', 'times/day')} · '
                            '${aiDosageFormLabel(medication.dosageForm)} · '
                            '${aiMedicationSince(medication.startedAt)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            20,
                            0,
                            20,
                            12,
                          ),
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AiDrugInfo.lookup(medication.name),
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              aiText(
                                'চিকিৎসককে জিজ্ঞেস করুন',
                                'Ask your doctor',
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.outline,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ActionChip(
                                  label: Text(
                                    aiText(
                                      'আমার উপসর্গ কি কমছে?',
                                      'Are my symptoms improving?',
                                    ),
                                  ),
                                  onPressed: () => _ask(
                                    medication,
                                    aiText(
                                      'আমার উপসর্গ কি কমছে?',
                                      'Are my symptoms improving?',
                                    ),
                                  ),
                                ),
                                ActionChip(
                                  label: Text(
                                    aiText(
                                      'মাত্রা কি পরিবর্তন করা উচিত?',
                                      'Should I change the dose?',
                                    ),
                                  ),
                                  onPressed: () => _ask(
                                    medication,
                                    aiText(
                                      'মাত্রা কি পরিবর্তন করা উচিত?',
                                      'Should I change the dose?',
                                    ),
                                  ),
                                ),
                                ActionChip(
                                  label: Text(
                                    aiText(
                                      'কত দিন এটি খেতে হবে?',
                                      'How long should I take it?',
                                    ),
                                  ),
                                  onPressed: () => _ask(
                                    medication,
                                    aiText(
                                      'কত দিন এটি খেতে হবে?',
                                      'How long should I take it?',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _edit(medication),
                                  child: Text(aiText('সম্পাদনা', 'Edit')),
                                ),
                                OutlinedButton(
                                  onPressed: () => _stop(medication),
                                  child: Text(aiText('বন্ধ করুন', 'Stop')),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              aiText(
                'চিকিৎসকের পরামর্শ ছাড়া ওষুধের মাত্রা পরিবর্তন করবেন না।',
                'Do not change a prescription without consulting a clinician.',
              ),
              style: TextStyle(fontSize: 11, color: colors.outline),
            ),
          ),
        ],
      ),
    );
  }
}
