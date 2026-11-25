import 'dart:async';

import 'package:flutter/material.dart';

import '../ai_service.dart';
import '../localization.dart';
import '../models.dart';

class AiMedicationFormDialog extends StatefulWidget {
  const AiMedicationFormDialog({
    super.key,
    required this.patientId,
    this.medication,
  });

  final int patientId;
  final AiMedication? medication;

  @override
  State<AiMedicationFormDialog> createState() => _AiMedicationFormDialogState();
}

class _AiMedicationFormDialogState extends State<AiMedicationFormDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.medication?.name ?? '',
  );
  late final TextEditingController _dose = TextEditingController(
    text: widget.medication?.dose ?? '',
  );
  late DateTime _started = widget.medication?.startedAt ?? DateTime.now();
  late int _timesPerDay = widget.medication?.timesPerDay ?? 1;
  late String _unit = widget.medication?.unit ?? 'tablet';
  late String _dosageForm = widget.medication?.dosageForm ?? 'Tablet';
  AiMedicineOption? _selected;
  List<AiMedicineOption> _results = const [];
  Timer? _debounce;
  Object? _searchError;
  bool _searching = false;
  bool _customName = false;

  static const _forms = [
    'Tablet',
    'Capsule',
    'Syrup',
    'Suspension',
    'Drops',
    'Injection',
    'Cream / ointment',
    'Inhaler',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final old = widget.medication;
    if (old != null) {
      _selected = AiMedicineOption(name: old.name, dosageForm: old.dosageForm);
    }
    _customName = AiDoctorConfig.medicineLookup == null;
    _dosageForm = _normalizeForm(_dosageForm);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _dose.dispose();
    super.dispose();
  }

  String _normalizeForm(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('syrup')) return 'Syrup';
    if (lower.contains('suspension')) return 'Suspension';
    if (lower.contains('capsule')) return 'Capsule';
    if (lower.contains('drop')) return 'Drops';
    if (lower.contains('injection') || lower.contains('injectable')) {
      return 'Injection';
    }
    if (lower.contains('cream') || lower.contains('ointment')) {
      return 'Cream / ointment';
    }
    if (lower.contains('inhaler')) return 'Inhaler';
    if (lower.contains('tablet')) return 'Tablet';
    return 'Other';
  }

  String _unitFor(String form) => switch (form) {
    'Tablet' => 'tablet',
    'Capsule' => 'capsule',
    'Syrup' || 'Suspension' => 'ml',
    'Drops' => 'drops',
    'Injection' => 'ml',
    'Cream / ointment' => 'application',
    'Inhaler' => 'puff',
    _ => 'dose',
  };

  void _search(String value) {
    _debounce?.cancel();
    final query = value.trim();
    setState(() {
      _results = const [];
      _searchError = null;
      _searching = query.length >= 2 && AiDoctorConfig.medicineLookup != null;
    });
    if (query.length < 2) return;

    final lookup = AiDoctorConfig.medicineLookup;
    if (lookup == null) return;
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await lookup(query);
        if (!mounted || _name.text.trim() != query) return;
        setState(() {
          _results = results;
          _searching = false;
        });
      } on Exception catch (error) {
        if (!mounted || _name.text.trim() != query) return;
        setState(() {
          _searchError = error;
          _searching = false;
        });
      }
    });
  }

  void _select(AiMedicineOption option) {
    setState(() {
      _selected = option;
      _customName = false;
      _name.text = option.name;
      _results = const [];
      _searchError = null;
      _dosageForm = _normalizeForm(option.dosageForm);
      _unit = _unitFor(_dosageForm);
    });
  }

  void _save() {
    if (_name.text.trim().isEmpty || _dose.text.trim().isEmpty) return;
    if (!_customName && _selected == null) return;
    Navigator.pop(
      context,
      (widget.medication ??
              AiMedication(patientId: widget.patientId, name: _name.text))
          .copyWith(
            name: _name.text.trim(),
            dose: _dose.text.trim(),
            timesPerDay: _timesPerDay,
            unit: _unit,
            dosageForm: _dosageForm,
            startedAt: _started,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lookupAvailable = AiDoctorConfig.medicineLookup != null;

    return AlertDialog(
      title: Text(
        widget.medication == null
            ? aiText('ওষুধ যোগ করুন', 'Add medication')
            : aiText('ওষুধ সম্পাদনা', 'Edit medication'),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: widget.medication == null,
                textCapitalization: TextCapitalization.words,
                onChanged: (value) {
                  if (_selected != null && value != _selected!.name) {
                    setState(() {
                      _selected = null;
                      _customName = false;
                    });
                  }
                  _search(value);
                },
                decoration: InputDecoration(
                  labelText: aiText('ওষুধ', 'Medicine'),
                  hintText: lookupAvailable
                      ? aiText(
                          'ব্র্যান্ড বা জেনেরিক নাম লিখুন',
                          'Type a brand or generic name',
                        )
                      : aiText('ওষুধের নাম লিখুন', 'Enter medicine name'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
              if (_results.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final option = _results[index];
                      return ListTile(
                        dense: true,
                        title: Text(option.name),
                        subtitle: option.subtitle.isEmpty
                            ? null
                            : Text(option.subtitle),
                        onTap: () => _select(option),
                      );
                    },
                  ),
                ),
              if (_searchError != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      aiText(
                        'ওষুধ খোঁজা যায়নি। আবার চেষ্টা করুন।',
                        'Medicine search failed.',
                      ),
                      style: TextStyle(color: colors.error, fontSize: 12),
                    ),
                  ),
                ),
              if (lookupAvailable &&
                  !_searching &&
                  _name.text.trim().length >= 2 &&
                  _results.isEmpty &&
                  _selected == null &&
                  _searchError == null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          aiText(
                            'মিলেছে এমন ওষুধ নেই।',
                            'No matching medicine.',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _customName = true),
                          child: Text(
                            aiText('নিজে নাম লিখুন', 'Use custom name'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_selected != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      aiText(
                        'ওষুধের তথ্যভান্ডার থেকে নির্বাচন করা হয়েছে',
                        'Selected from medicine database',
                      ),
                      style: TextStyle(fontSize: 12, color: colors.primary),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _dose,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: aiText(
                          'প্রতি মাত্রার পরিমাণ',
                          'Amount per dose',
                        ),
                        hintText: aiText('যেমন: ১ বা ৫', 'e.g. 1 or 5'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _dosageForm,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: aiText('ওষুধের ধরন', 'Form'),
                      ),
                      items: [
                        for (final form in _forms)
                          DropdownMenuItem(
                            value: form,
                            child: Text(
                              aiDosageFormLabel(form),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _dosageForm = value;
                          _unit = _unitFor(value);
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: aiText('একক', 'Unit'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'tablet',
                          child: Text(aiMedicationUnit('tablet')),
                        ),
                        DropdownMenuItem(
                          value: 'capsule',
                          child: Text(aiMedicationUnit('capsule')),
                        ),
                        DropdownMenuItem(
                          value: 'ml',
                          child: Text(aiMedicationUnit('ml')),
                        ),
                        DropdownMenuItem(
                          value: 'teaspoon',
                          child: Text(aiMedicationUnit('teaspoon')),
                        ),
                        DropdownMenuItem(
                          value: 'drops',
                          child: Text(aiMedicationUnit('drops')),
                        ),
                        DropdownMenuItem(
                          value: 'puff',
                          child: Text(aiMedicationUnit('puff')),
                        ),
                        DropdownMenuItem(
                          value: 'application',
                          child: Text(aiMedicationUnit('application')),
                        ),
                        DropdownMenuItem(
                          value: 'dose',
                          child: Text(aiMedicationUnit('dose')),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _unit = value ?? _unit),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _timesPerDay,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: aiText('দিনে কতবার', 'Times / day'),
                      ),
                      items: [
                        for (var count = 1; count <= 6; count++)
                          DropdownMenuItem(
                            value: count,
                            child: Text(
                              aiText(
                                '${aiLocalizedNumber(count)} বার',
                                '$count ${count == 1 ? 'time' : 'times'}',
                              ),
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _timesPerDay = value ?? 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(aiText('শুরু করার তারিখ', 'Started taking')),
                subtitle: Text(
                  '${_started.day}/${_started.month}/${_started.year}',
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _started,
                    firstDate: DateTime(1990),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _started = date);
                },
              ),
              Text(
                aiText(
                  'চিকিৎসকের পরামর্শ ছাড়া ওষুধের মাত্রা পরিবর্তন করবেন না।',
                  'Do not change a prescription without consulting a clinician.',
                ),
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(aiText('বাতিল', 'Cancel')),
        ),
        FilledButton(
          onPressed:
              _name.text.trim().isNotEmpty &&
                  _dose.text.trim().isNotEmpty &&
                  (_customName || _selected != null)
              ? _save
              : null,
          child: Text(aiText('ওষুধ সংরক্ষণ', 'Save medication')),
        ),
      ],
    );
  }
}
