import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/home_controller.dart';
import '../core/medicine_form.dart';
import '../core/navigation_mode.dart';
import '../data/medicine_dao.dart';
import '../models/medicine.dart';
import '../widgets/medicine_form_icons.dart';

/// Strict "Add Medicine" form. Every field the mandatory checklist names is
/// required (Not Null) except the product image, which is explicitly optional.
/// The bottom bar shows a live completion progress and refuses to submit until
/// all required inputs are valid, so an incomplete entry can never be saved.
class AddMedicineView extends StatefulWidget {
  const AddMedicineView({super.key});

  @override
  State<AddMedicineView> createState() => _AddMedicineViewState();
}

class _AddMedicineViewState extends State<AddMedicineView> {
  final _formKey = GlobalKey<FormState>();
  final _text = <String, TextEditingController>{};
  final _focus = <String, FocusNode>{};

  // Required text fields, grouped for display. Keys double as storage columns.
  static const _general = ['brand_name', 'generic_name', 'company'];
  static const _strength = ['strength'];
  static const _clinical = [
    'indications',
    'composition',
    'pharmacology',
    'dosage_and_administration',
    'contraindications',
    'side_effects',
    'pregnancy_and_lactation',
    'precautions_and_warnings',
    'overdose_effects',
    'therapeutic_class',
  ];
  static const _logistics = [
    'pack_sizes',
    'trade_price',
    'mrp',
    'stock_quantity',
    'batch_number',
    'rack_no',
    'storage_conditions',
  ];
  static const _dates = ['mfg_date', 'expiry_date'];

  MedicineForm? _form;
  DateTime? _mfg;
  DateTime? _expiry;
  bool _attempted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final key in [
      ..._general,
      ..._strength,
      ..._clinical,
      ..._logistics,
      ..._dates,
    ]) {
      final c = TextEditingController();
      c.addListener(_onChanged);
      _text[key] = c;
      _focus[key] = FocusNode();
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged() => setState(() {});

  String _v(String key) => _text[key]!.text.trim();

  /// The set of *required* checks that must all pass before a save is allowed.
  bool get _canSubmit {
    if (_form == null) return false;
    for (final key in [
      ..._general,
      ..._strength,
      ..._clinical,
      ..._logistics,
      ..._dates,
    ]) {
      if (_v(key).isEmpty) return false;
    }
    return true;
  }

  double get _progress {
    final required = [
      ..._general,
      ..._strength,
      ..._clinical,
      ..._logistics,
      ..._dates,
    ];
    final total = required.length + 1; // +1 for the type dropdown
    var done = _form == null ? 0 : 1;
    for (final key in required) {
      if (_v(key).isNotEmpty) done++;
    }
    return done / total;
  }

  int get _remaining {
    var n = _form == null ? 1 : 0;
    for (final key in [
      ..._general,
      ..._strength,
      ..._clinical,
      ..._logistics,
      ..._dates,
    ]) {
      if (_v(key).isEmpty) n++;
    }
    return n;
  }

  Future<void> _pickDate(bool forMfg) async {
    final initial = forMfg ? _mfg : _expiry;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      final key = forMfg ? 'mfg_date' : 'expiry_date';
      final iso = _fmtDate(picked);
      if (forMfg) {
        _mfg = picked;
      } else {
        _expiry = picked;
      }
      _text[key]!.text = iso;
    });
  }

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    setState(() => _attempted = true);
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!_canSubmit || !formValid) {
      Get.snackbar(
        'তথ্য অসম্পূর্ণ',
        'প্রতিটি আবশ্যক ঘর পূরণ করুন। বাকি আছে $_remainingটি।',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final medicine = Medicine(
        id: 0,
        brandName: _v('brand_name'),
        genericName: _v('generic_name'),
        company: _v('company'),
        dosageForm: _form!.label,
        strength: _v('strength'),
        indications: _v('indications'),
        composition: _v('composition'),
        pharmacology: _v('pharmacology'),
        dosageAndAdministration: _v('dosage_and_administration'),
        contraindications: _v('contraindications'),
        sideEffects: _v('side_effects'),
        pregnancyAndLactation: _v('pregnancy_and_lactation'),
        precautionsAndWarnings: _v('precautions_and_warnings'),
        overdoseEffects: _v('overdose_effects'),
        therapeuticClass: _v('therapeutic_class'),
        storageConditions: _v('storage_conditions'),
        packSizes: _v('pack_sizes'),
        tradePrice: _v('trade_price'),
        mrp: _v('mrp'),
        stockQuantity: int.tryParse(_v('stock_quantity')) ?? 0,
        batchNumber: _v('batch_number'),
        rackNo: _v('rack_no'),
        mfgDate: _v('mfg_date'),
        expiryDate: _v('expiry_date'),
        unitPrice: _v('mrp'),
        source: 'manual',
        detailLoaded: true,
      );
      await Get.find<MedicineDao>().addManualMedicine(medicine);
      await Get.find<HomeController>().load();
      if (mounted) Navigator.of(context).pop(true);
      Get.snackbar(
        'সংরক্ষিত',
        '“${medicine.brandName}” ওষুধটি ডেটাবেসে যুক্ত হয়েছে।',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('সংরক্ষণ ব্যর্থ', '$e', snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String key, String label) {
    if (!_attempted) return null;
    return _v(key).isEmpty ? '$label আবশ্যক' : null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('নতুন ওষুধ যুক্ত করুন'),
        actions: [
          IconButton(
            tooltip: 'সংরক্ষণ',
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            _Notice(
              text:
                  'তারকা চিহ্ন (*) লাগানো প্রতিটি ঘর অবশ্যই পূরণ করতে হবে। '
                  'শুধু ওষুধের ছবি (§) ঐচ্ছিক।',
            ),
            _SectionTitle('সাধারণ তথ্য', Icons.info_outline),
            _field(context, 'brand_name', 'ওষুধের নাম (Brand Name)*'),
            _field(context, 'generic_name', 'জেনেরিক নাম (Generic Name)*'),
            _field(context, 'company', 'কোম্পানির নাম (Company)*'),
            _SectionTitle('ধরন ও মাত্রা', Icons.category_outlined),
            _typeDropdown(context),
            _field(
              context,
              'strength',
              'মাত্রা / পাওয়ার (Strength)*',
              hint: 'যেমন: 500mg, 100ml',
            ),
            _SectionTitle(
              'ক্লিনিক্যাল ও মেডিকেল তথ্য',
              Icons.monitor_heart_outlined,
            ),
            _area(context, 'indications', 'রোগের নির্দেশনা (Indications)*'),
            _area(context, 'composition', 'গঠন (Composition)*'),
            _area(context, 'pharmacology', 'ফার্মাকোলজি (Pharmacology)*'),
            _area(
              context,
              'dosage_and_administration',
              'ডোজ ও ব্যবহার বিধি (Dosage & Administration)*',
            ),
            _area(
              context,
              'contraindications',
              'নিষিদ্ধ ব্যবহার (Contraindications)*',
            ),
            _area(
              context,
              'side_effects',
              'পার্শ্বপ্রতিক্রিয়া (Side Effects)*',
            ),
            _area(
              context,
              'pregnancy_and_lactation',
              'গর্ভাবস্থা ও স্তন্যদান (Pregnancy & Lactation)*',
              hint: 'যেমন: Pregnancy Category B',
            ),
            _area(
              context,
              'precautions_and_warnings',
              'সতর্কতা ও সাবধানতা (Precautions & Warnings)*',
            ),
            _area(
              context,
              'overdose_effects',
              'অতিরিক্ত ডোজের প্রভাব (Overdose Effects)*',
            ),
            _field(
              context,
              'therapeutic_class',
              'থেরাপিউটিক শ্রেণি (Therapeutic Class)*',
              hint: 'যেমন: Antibiotic, Analgesic',
            ),
            _SectionTitle(
              'প্যাকেজিং, মূল্য ও স্টক',
              Icons.inventory_2_outlined,
            ),
            _field(
              context,
              'pack_sizes',
              'প্যাকেজিং সাইজ (Unit/Pack)*',
              hint: 'যেমন: 10 x 10 (বক্সে ১০ পাতা, পাতায় ১০ পিস)',
            ),
            _field(
              context,
              'trade_price',
              'ক্রয় মূল্য / Trade Price*',
              numeric: true,
            ),
            _field(
              context,
              'mrp',
              'সর্বোচ্চ খুচরা মূল্য / MRP*',
              numeric: true,
            ),
            _field(
              context,
              'stock_quantity',
              'বর্তমান স্টক (Quantity)*',
              numeric: true,
              intOnly: true,
            ),
            _field(context, 'batch_number', 'ব্যাচ নম্বর (Batch No)*'),
            _field(
              context,
              'rack_no',
              'র্যাক / শেলফ নম্বর (Rack No)*',
              hint: 'যেমন: Rack-A, Shelf-02',
            ),
            _SectionTitle('মেয়াদ ও সংরক্ষণ', Icons.event_available_outlined),
            _dateTile(
              context,
              'mfg_date',
              'উৎপাদন তারিখ (Mfg. Date)*',
              value: _mfg,
              onPick: () => _pickDate(true),
            ),
            _dateTile(
              context,
              'expiry_date',
              'মেয়াদোত্তীর্ণ তারিখ (Expiry Date)*',
              value: _expiry,
              onPick: () => _pickDate(false),
            ),
            _area(
              context,
              'storage_conditions',
              'সংরক্ষণ পদ্ধতি (Storage Conditions)*',
              hint: 'যেমন: আলো থেকে দূরে, অনূর্ধ্ব ৩০°সে',
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(context, scheme),
    );
  }

  Widget _bottomBar(BuildContext context, ColorScheme scheme) {
    final canSubmit = _canSubmit && !_saving;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        GestureNavigation.bottomSpacing(
          context,
          safeMarginAboveGesture: 10,
          fullscreenMargin: 16,
        ),
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _progress >= 1.0 ? 'সব ঘর পূর্ণ' : 'বাকি $_remainingটি',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              // Requirement: incomplete data must never insert. The button is
              // disabled until every required field is valid; tapping is also
              // guarded in _submit, which surfaces per-field errors.
              onPressed: canSubmit
                  ? _submit
                  : () {
                      setState(() => _attempted = true);
                      _formKey.currentState?.validate();
                      _onChanged();
                    },
              style: FilledButton.styleFrom(
                backgroundColor: canSubmit
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                foregroundColor: canSubmit
                    ? scheme.onPrimary
                    : scheme.onSurfaceVariant,
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_task),
              label: Text(_saving ? 'সংরক্ষণ হচ্ছে…' : 'ওষুধ সংরক্ষণ করুন'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeDropdown(BuildContext context) {
    final error = _attempted && _form == null
        ? 'ওষুধের ধরন নির্বাচন করুন'
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'ধরন (Medicine Type)*',
          errorText: error,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<MedicineForm>(
            value: _form,
            isExpanded: true,
            hint: const Text('তালিকা থেকে নির্বাচন করুন'),
            items: [
              for (final f in MedicineForm.selectable)
                DropdownMenuItem(
                  value: f,
                  child: Row(
                    children: [
                      Icon(
                        MedicineFormIcon.of(f),
                        color: MedicineFormIcon.colorOf(f),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(f.label),
                    ],
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _form = value),
          ),
        ),
      ),
    );
  }

  Widget _field(
    BuildContext context,
    String key,
    String label, {
    String? hint,
    bool numeric = false,
    bool intOnly = false,
    bool optional = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: _text[key],
        focusNode: _focus[key],
        keyboardType: numeric
            ? (intOnly
                  ? const TextInputType.numberWithOptions(decimal: false)
                  : const TextInputType.numberWithOptions(decimal: true))
            : TextInputType.text,
        inputFormatters: numeric
            ? [
                FilteringTextInputFormatter.allow(
                  RegExp(intOnly ? r'[0-9]' : r'[0-9.]'),
                ),
              ]
            : null,
        autovalidateMode: _attempted
            ? AutovalidateMode.always
            : AutovalidateMode.disabled,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          helperText: optional ? 'ঐচ্ছিক — না দিলেও চলবে' : null,
        ),
        validator: (_) =>
            optional ? null : _required(key, label.replaceAll('*', '').trim()),
      ),
    );
  }

  Widget _area(BuildContext context, String key, String label, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: _text[key],
        focusNode: _focus[key],
        minLines: 2,
        maxLines: 5,
        autovalidateMode: _attempted
            ? AutovalidateMode.always
            : AutovalidateMode.disabled,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: true,
          border: const OutlineInputBorder(),
        ),
        validator: (_) => _required(key, label.replaceAll('*', '').trim()),
      ),
    );
  }

  Widget _dateTile(
    BuildContext context,
    String key,
    String label, {
    required DateTime? value,
    required VoidCallback onPick,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final missing = _attempted && _v(key).isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            errorText: missing ? 'তারিখ নির্বাচন করুন' : null,
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          ),
          child: Text(
            value == null ? 'নির্বাচন করতে ট্যাপ করুন' : _fmtDate(value),
            style: TextStyle(
              color: value == null ? scheme.onSurfaceVariant : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, this.icon);
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800, color: scheme.primary),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.rule, size: 18, color: scheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
