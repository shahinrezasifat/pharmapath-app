import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

import '../controllers/favorites_controller.dart';
import '../controllers/medicine_detail_controller.dart';
import '../core/app_config.dart';
import '../core/format.dart';
import '../core/navigation_mode.dart';
import '../data/medicine_dao.dart';
import '../models/medicine.dart';
import '../services/ai_learning_tools.dart';
import '../services/sync_service.dart';
import '../widgets/alternatives_sheet.dart';
import '../widgets/company_logo.dart';
import '../widgets/html_content.dart';
import '../widgets/medicine_explain_sheet.dart';
import '../widgets/medicine_form_icons.dart';
import '../widgets/safety_notice.dart';
import '../core/disease_tag_extractor.dart';
import '../core/dosage_age_parser.dart';
import '../core/dosage_calculator.dart';
import '../core/dosage_instruction_formatter.dart';
import 'disease_medicines_sheet.dart';

import 'package:ai_doctor_module/ai_doctor.dart';

class MedicineDetailView extends StatefulWidget {
  const MedicineDetailView({super.key, required this.medicine});

  final Medicine medicine;

  @override
  State<MedicineDetailView> createState() => _MedicineDetailViewState();
}

class _MedicineDetailViewState extends State<MedicineDetailView> {
  late final String _tag;
  late final MedicineDetailController _controller;

  @override
  void initState() {
    super.initState();
    _tag = 'medicine-${identityHashCode(this)}';
    _controller = Get.put(
      MedicineDetailController(
        initial: widget.medicine,
        dao: Get.find<MedicineDao>(),
        sync: Get.find<SyncService>(),
        // The Bangla translation and explanation helper; absent in slim builds,
        // where both actions fall back to their offline notice.
        ai: Get.isRegistered<AiLearningTools>()
            ? Get.find<AiLearningTools>()
            : null,
      ),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    Get.delete<MedicineDetailController>(tag: _tag);
    super.dispose();
  }

  String _sectionText(Medicine medicine, String key) {
    final directValue = switch (key) {
      'dosage_and_administration' => medicine.dosageAndAdministration,
      'pregnancy_and_lactation' => medicine.pregnancyAndLactation,
      _ => null,
    };
    final matchingSection = medicine.sections.entries
        .where((entry) => Medicine.canonicalSectionKey(entry.key) == key)
        .firstOrNull;
    final source = directValue?.trim().isNotEmpty == true
        ? directValue!.trim()
        : matchingSection?.value.trim();
    if (source == null || source.isEmpty) return '';

    final translation = _controller.translations[key]?.trim();
    if (translation?.isNotEmpty == true) return translation!;
    if (matchingSection != null) {
      final aliasTranslation = _controller.translations[matchingSection.key]
          ?.trim();
      if (aliasTranslation?.isNotEmpty == true) return aliasTranslation!;
    }
    return source;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ওষুধের তথ্য',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          Obx(
            () => IconButton(
              tooltip: _controller.favorite.value
                  ? 'ফেভারিট থেকে সরান'
                  : 'ফেভারিটে রাখুন',
              onPressed: () async {
                await _controller.toggleFavorite();
                await Get.find<FavoritesController>().load();
              },
              icon: Icon(
                _controller.favorite.value
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: _controller.favorite.value
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: Obx(() {
        final medicine = _controller.medicine.value;
        final visibleClinicalSections = medicine.clinicalSections
            .where((section) {
              final cKey = Medicine.canonicalSectionKey(section.key);
              if (cKey == 'dosage_and_administration') return false;
              if (section.label == 'ডোজ ও ব্যবহার' ||
                  section.label == 'ডোজ ও ব্যবহারবিধি') {
                return false;
              }
              return true;
            })
            .toList();
        return RefreshIndicator(
          onRefresh: () => _controller.loadDetail(force: true),
          child: ListView(
            padding: EdgeInsets.only(
              bottom: GestureNavigation.pageBottomPadding(
                context,
                additionalBuffer: 24,
              ),
            ),
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _controller.loadingDetail.value
                    ? const _DetailLoadingBanner(key: ValueKey('loading'))
                    : const SizedBox.shrink(key: ValueKey('idle')),
              ),
              if (_controller.detailError.value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.errorContainer.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.cloud_off_outlined,
                        color: scheme.error,
                      ),
                      title: const Text(
                        'অফলাইন তথ্য দেখানো হচ্ছে',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(_controller.detailError.value),
                      trailing: IconButton(
                        tooltip: 'আবার চেষ্টা',
                        onPressed: () => _controller.loadDetail(force: true),
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                  ),
                ),
              _MedicineHero(
                medicine: medicine,
                brandName: _controller.brandName,
                subtitle: _controller.subtitle,
                companyName: _controller.companyName,
                formLabel: _controller.formLabel,
                priceLabel: _controller.priceLabel,
                packLabel: _controller.packLabel,
                translating: _controller.translating.value,
                translateNote: _controller.translateNote.value,
                translatedCount: _controller.translatedCount,
                sectionCount: _controller.translationFieldCount,
                onAskAi: () => Get.to(
                  () => AiDoctorChatPage.forMedicine(
                    medicineName: medicine.brandName,
                    medicineContext: medicine.toAiContext(),
                    initialQuestion: AiDoctorConfig.languageCode == 'bn'
                        ? 'এই ওষুধটির ব্যবহার, উপকারিতা, সতর্কতা এবং সম্ভাব্য পার্শ্বপ্রতিক্রিয়া সম্পর্কে বলুন।'
                        : 'Please explain this medicine’s uses, benefits, precautions, and possible side effects.',
                  ),
                ),
                onAlternatives: medicine.genericName?.trim().isEmpty ?? true
                    ? null
                    : () => showAlternativesSheet(context, medicine),
                onExplain: () =>
                    showMedicineExplanationSheet(context, _controller),
                onShowDosage: () => _showDosageGuidance(
                  context,
                  medicine,
                  dosageText: _sectionText(
                    medicine,
                    'dosage_and_administration',
                  ),
                  pregnancyText: _sectionText(
                    medicine,
                    'pregnancy_and_lactation',
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: SafetyNotice(dense: true),
              ),
              if (visibleClinicalSections.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: .7),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ওষুধের বিস্তারিত তথ্য',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              if (medicine.clinicalSections.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.feed_outlined,
                          size: 40,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          medicine.detailLoaded
                              ? 'বিস্তারিত তথ্য পাওয়া যায়নি'
                              : 'অতিরিক্ত তথ্য প্রয়োজন',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          medicine.detailLoaded
                              ? 'উৎস সার্ভারে এই ওষুধের জন্য ক্লিনিক্যাল তথ্য নেই।'
                              : 'অফলাইন ক্যাটালগে এই ওষুধের সম্পূর্ণ তথ্য নেই। ইন্টারনেট থাকলে বিস্তারিত আনার চেষ্টা করুন।',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                        ),
                        if (!medicine.detailLoaded) ...[
                          const SizedBox(height: 16),
                          FilledButton.tonal(
                            onPressed: () =>
                                _controller.loadDetail(force: true),
                            child: const Text('তথ্য ডাউনলোড করুন'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else ...[
                Builder(
                  builder: (context) {
                    final seen = <String>{};
                    final cards = <Widget>[];
                    for (final section in visibleClinicalSections) {
                      final cKey = Medicine.canonicalSectionKey(section.key);
                      if (!seen.add(cKey)) continue;
                      cards.add(
                        _SectionCard(
                          section: section,
                          text: _controller.fieldText(section),
                          translated: _controller.translations.containsKey(
                            section.key,
                          ),
                          medicine: medicine,
                        ),
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: cards,
                    );
                  },
                ),
              ],
              _InventoryCard(medicine: medicine),
              _Provenance(medicine: medicine),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Text(
                  'তথ্যের উৎস: বাংলাদেশের ওষুধের তথ্যভান্ডার। এই অ্যাপটি অনুমোদিত উৎস থেকে '
                  'সংরক্ষিত তথ্য দেখায়; কোনো তথ্য নিজে থেকে অনুমান বা পরিমার্জন করা হয় না।',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

Future<void> _showDosageGuidance(
  BuildContext context,
  Medicine medicine, {
  required String dosageText,
  required String pregnancyText,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DosageGuidanceSheet(
      medicine: medicine,
      dosageText: dosageText,
      pregnancyText: pregnancyText,
    ),
  );
}

class _DosageGuidanceSheet extends StatefulWidget {
  const _DosageGuidanceSheet({
    required this.medicine,
    required this.dosageText,
    required this.pregnancyText,
  });

  final Medicine medicine;
  final String dosageText;
  final String pregnancyText;

  @override
  State<_DosageGuidanceSheet> createState() => _DosageGuidanceSheetState();
}

class _DosageGuidanceSheetState extends State<_DosageGuidanceSheet> {
  final _ageController = TextEditingController();
  int _step = 1;
  String? _gender;
  bool? _pregnant;
  bool? _breastfeeding;

  int? get _age => int.tryParse(bnToEn(_ageController.text.trim()));

  bool get _validAge => _age != null && _age! >= 0 && _age! <= 130;

  /// Pregnancy / breastfeeding questions apply only to females aged 12+.
  bool get _asksFemaleQuestions => _gender == 'female' && (_age ?? 0) >= 12;

  bool get _canContinue => switch (_step) {
    1 => _validAge && _gender != null,
    2 => _pregnant != null && _breastfeeding != null,
    _ => true,
  };

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  void _setAge(int value) {
    final text = bn(value.clamp(0, 130));
    _ageController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {});
  }

  void _next() {
    if (!_canContinue) return;
    setState(() {
      if (_step == 1) {
        if (_asksFemaleQuestions) {
          _step = 2;
        } else {
          // Clear stale answers when the questions are skipped.
          _pregnant = null;
          _breastfeeding = null;
          _step = 3;
        }
      } else {
        _step = 3;
      }
    });
  }

  void _back() {
    setState(() {
      _step = switch (_step) {
        3 when _asksFemaleQuestions => 2,
        _ => 1,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scheme = Theme.of(context).colorScheme;
    final availableHeight = media.size.height - media.viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: availableHeight * .94,
          ),
          child: Material(
            color: scheme.surface,
            elevation: 24,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  _buildHeader(context),
                  if (_step < 3)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: _step / 3,
                          minHeight: 6,
                          backgroundColor: scheme.surfaceContainerHigh,
                        ),
                      ),
                    ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(.06, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: _buildStep(context),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                    child: _buildActions(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final leading = _step == 1
        ? const SizedBox(width: 44, height: 44)
        : SizedBox(
            width: 44,
            height: 44,
            child: IconButton.filledTonal(
              tooltip: 'পেছনে',
              onPressed: _back,
              style: IconButton.styleFrom(
                backgroundColor: scheme.surfaceContainerLow,
                foregroundColor: scheme.onSurfaceVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'ডোজ ও ব্যবহারবিধি',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton.filledTonal(
              tooltip: 'বন্ধ করুন',
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                minimumSize: Size.zero,
                fixedSize: const Size(36, 36),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: scheme.surfaceContainerLow,
                foregroundColor: scheme.onSurfaceVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context) => switch (_step) {
    1 => _buildPatientStep(context),
    2 => _buildPregnancyStep(context),
    _ => _buildResultStep(context),
  };

  Widget _buildPatientStep(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'রোগীর তথ্য দিন',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'সঠিক নির্দেশনার জন্য বয়স ও লিঙ্গ জানা দরকার',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        Text('বয়স', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              _AgeStepButton(
                icon: Icons.remove_rounded,
                label: 'বয়স কমান',
                onPressed: (_age ?? 0) <= 0
                    ? null
                    : () => _setAge((_age ?? 0) - 1),
              ),
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 3,
                      onChanged: (_) => setState(() {}),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                      decoration: const InputDecoration(
                        hintText: '০',
                        counterText: '',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                    Text(
                      'বছর',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              _AgeStepButton(
                icon: Icons.add_rounded,
                label: 'বয়স বাড়ান',
                onPressed: (_age ?? -1) >= 130
                    ? null
                    : () => _setAge((_age ?? 0) + 1),
              ),
            ],
          ),
        ),
        if (_age != null && !_validAge)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '০ থেকে ১৩০ বছরের মধ্যে বয়স দিন।',
              style: TextStyle(color: scheme.error, fontSize: 12),
            ),
          ),
        const SizedBox(height: 18),
        Text('লিঙ্গ', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _DosageChoiceCard(
                icon: Icons.person_outline_rounded,
                label: 'পুরুষ',
                selected: _gender == 'male',
                onTap: () => setState(() => _gender = 'male'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DosageChoiceCard(
                icon: Icons.person_rounded,
                label: 'মহিলা',
                selected: _gender == 'female',
                onTap: () => setState(() => _gender = 'female'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPregnancyStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'কয়েকটি প্রশ্ন',
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        'মহিলাদের জন্য ওষুধের নির্দেশনা আলাদা হতে পারে',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 18),
      _YesNoQuestion(
        title: 'আপনি কি গর্ভবতী?',
        value: _pregnant,
        onChanged: (value) => setState(() => _pregnant = value),
      ),
      const SizedBox(height: 16),
      _YesNoQuestion(
        title: 'আপনি কি শিশুকে বুকের দুধ খাওয়াচ্ছেন?',
        value: _breastfeeding,
        onChanged: (value) => setState(() => _breastfeeding = value),
      ),
    ],
  );

  Widget _buildResultStep(BuildContext context) {
    final isFemale = _gender == 'female';
    final age = _age ?? 0;
    final isChild = age < 12;
    final needsCaution = _pregnant == true || _breastfeeding == true;
    final scheme = Theme.of(context).colorScheme;
    final doseInstructions = DosageInstructionFormatter.format(
      widget.dosageText,
    );
    // Show only the instructions that apply to this patient's age.
    final visibleInstructions = doseInstructions
        .where(
          (i) => switch (i.kind) {
            DosageInstructionKind.child => age < 18,
            DosageInstructionKind.adult ||
            DosageInstructionKind.maximum => !isChild,
            DosageInstructionKind.general => true,
          },
        )
        .toList();
    final hasChildInfo = doseInstructions.any(
      (i) => i.kind == DosageInstructionKind.child,
    );
    final patientStatus = <String>[
      if (_pregnant == true) 'গর্ভবতী',
      if (_breastfeeding == true) 'স্তন্যদানকারী',
    ].join(' · ');
    final warningBackground = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF33290F)
        : const Color(0xFFFFF3D6);
    final warningForeground = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFFD166)
        : const Color(0xFF9A6400);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: .58),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFemale
                      ? Icons.person_rounded
                      : Icons.person_outline_rounded,
                  color: scheme.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'রোগীর তথ্য',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${bn(age)} বছর · ${isFemale ? 'মহিলা' : 'পুরুষ'}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (patientStatus.isNotEmpty)
                      Text(
                        patientStatus,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.medication_outlined, color: scheme.primary, size: 22),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                widget.medicine.brandName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (doseInstructions.isEmpty)
          const _DosageNotice(
            text:
                'এই ওষুধের ডোজ ও ব্যবহারবিধির নির্ভরযোগ্য তথ্য ডেটাবেসে নেই। '
                'চিকিৎসক বা ফার্মাসিস্টের পরামর্শ ছাড়া ডোজ নির্ধারণ করবেন না।',
          )
        else ...[
          for (final instruction in visibleInstructions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DosageInfoTile(
                instruction: instruction,
                child: Text(instruction.text),
              ),
            ),
          if (isChild && !hasChildInfo)
            const _DosageNotice(
              text:
                  'এই ওষুধের শিশুদের জন্য নির্দিষ্ট ডোজ ডেটাবেসে নেই। '
                  'প্রাপ্তবয়স্কদের ডোজ শিশুকে দেবেন না; চিকিৎসক বা ফার্মাসিস্টের পরামর্শ নিন।',
            ),
        ],
        if (_asksFemaleQuestions && needsCaution) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: warningBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: warningForeground.withValues(alpha: .3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: warningForeground),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'গর্ভাবস্থা ও স্তন্যদান',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: warningForeground,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (widget.pregnancyText.trim().isEmpty)
                        const Text(
                          'এই বিষয়ে নির্দিষ্ট তথ্য ডেটাবেসে নেই। ওষুধ ব্যবহারের আগে চিকিৎসকের পরামর্শ নিন।',
                        )
                      else
                        HtmlContent(widget.pregnancyText),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        _DosageNotice(
          text:
              'এটি ডেটাবেসে থাকা সাধারণ নির্দেশনা, ব্যক্তিগত ডোজ গণনা নয়। '
              'বয়স বা স্বাস্থ্য-অবস্থার ভিত্তিতে ডোজ নিজে থেকে পরিবর্তন করবেন না।',
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    if (_step == 3) {
      return _DosagePrimaryButton(
        label: 'বন্ধ করুন',
        onPressed: () => Navigator.pop(context),
      );
    }
    return _DosagePrimaryButton(
      label: _step == 1 ? 'পরবর্তী' : 'ফলাফল দেখুন',
      onPressed: _canContinue ? _next : null,
    );
  }
}

class _YesNoQuestion extends StatelessWidget {
  const _YesNoQuestion({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _DosageChoiceCard(
              icon: Icons.check_rounded,
              label: 'হ্যাঁ',
              selected: value == true,
              horizontal: true,
              onTap: () => onChanged(true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DosageChoiceCard(
              icon: Icons.close_rounded,
              label: 'না',
              selected: value == false,
              horizontal: true,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    ],
  );
}

class _DosageChoiceCard extends StatelessWidget {
  const _DosageChoiceCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.horizontal = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool horizontal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: .62)
          : scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: BoxConstraints(minHeight: horizontal ? 50 : 92),
          padding: EdgeInsets.symmetric(
            horizontal: horizontal ? 10 : 8,
            vertical: horizontal ? 8 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: horizontal
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 19, color: accent),
                    const SizedBox(width: 7),
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? scheme.primary : scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primary
                            : scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        icon,
                        size: 22,
                        color: selected ? scheme.onPrimary : accent,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? scheme.primary : scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AgeStepButton extends StatelessWidget {
  const _AgeStepButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48,
    height: 48,
    child: IconButton.filledTonal(
      tooltip: label,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      icon: Icon(icon),
    ),
  );
}

class _DosagePrimaryButton extends StatelessWidget {
  const _DosagePrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: onPressed == null ? .42 : 1,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: .25),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(18),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DosageInfoTile extends StatelessWidget {
  const _DosageInfoTile({required this.instruction, required this.child});

  final DosageInstruction instruction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = switch (instruction.kind) {
      DosageInstructionKind.adult => scheme.primary,
      DosageInstructionKind.maximum =>
        dark ? const Color(0xFFFFD166) : const Color(0xFF9A6400),
      DosageInstructionKind.child =>
        dark ? const Color(0xFFFF8D8D) : const Color(0xFFC13434),
      DosageInstructionKind.general => scheme.primary,
    };
    final background = switch (instruction.kind) {
      DosageInstructionKind.adult ||
      DosageInstructionKind.general => scheme.surfaceContainerLow,
      DosageInstructionKind.maximum =>
        dark ? const Color(0xFF33290F) : const Color(0xFFFFF4DC),
      DosageInstructionKind.child =>
        dark ? const Color(0xFF3B1C22) : const Color(0xFFFFECEC),
    };
    final borderColor = switch (instruction.kind) {
      DosageInstructionKind.adult ||
      DosageInstructionKind.general => scheme.outlineVariant,
      DosageInstructionKind.maximum =>
        dark ? const Color(0xFF4D3E17) : const Color(0xFFF6DCA0),
      DosageInstructionKind.child => Colors.transparent,
    };
    final icon = switch (instruction.kind) {
      DosageInstructionKind.adult => Icons.person_outline_rounded,
      DosageInstructionKind.maximum => Icons.schedule_rounded,
      DosageInstructionKind.child => Icons.child_care_rounded,
      DosageInstructionKind.general => Icons.info_outline_rounded,
    };
    final iconBackground =
        instruction.kind == DosageInstructionKind.adult ||
            instruction.kind == DosageInstructionKind.general
        ? scheme.primaryContainer
        : (dark ? scheme.surface : Colors.white);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instruction.title,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: accent, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: instruction.kind == DosageInstructionKind.child
                        ? accent
                        : scheme.onSurface,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DosageNotice extends StatelessWidget {
  const _DosageNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
      ),
    );
  }
}

class _DetailLoadingBanner extends StatelessWidget {
  const _DetailLoadingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Shimmer.fromColors(
              baseColor: scheme.surfaceContainerHighest,
              highlightColor: scheme.surfaceContainerLow,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ওষুধের তথ্য সাজানো হচ্ছে',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'একটু অপেক্ষা করুন…',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const LinearProgressIndicator(minHeight: 3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicineHero extends StatelessWidget {
  const _MedicineHero({
    required this.medicine,
    required this.brandName,
    required this.subtitle,
    required this.companyName,
    required this.formLabel,
    required this.priceLabel,
    required this.packLabel,
    required this.onAskAi,
    required this.onAlternatives,
    required this.onExplain,
    required this.onShowDosage,
    required this.translating,
    required this.translateNote,
    required this.translatedCount,
    required this.sectionCount,
  });

  final Medicine medicine;
  final String brandName;
  final String subtitle;
  final String companyName;
  final String formLabel;
  final String priceLabel;
  final String packLabel;
  final VoidCallback onAskAi;
  final VoidCallback? onAlternatives;
  final VoidCallback onExplain;
  final VoidCallback onShowDosage;
  final bool translating;
  final String translateNote;
  final int translatedCount;
  final int sectionCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = MedicineFormIcon.colorOf(medicine.form);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: .7),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: .04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3, right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                MedicineFormIcon.of(medicine.form),
                                size: 14,
                                color: accent,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                formLabel,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          brandName,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -.3,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (companyName.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              CompanyLogo(company: medicine.company, size: 32),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  companyName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
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
                MedicineFormGlyph(form: medicine.form, size: 72),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: .8),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .55),
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _FactTile(
                        icon: MedicineFormIcon.of(medicine.form),
                        iconColor: accent,
                        label: 'ডোজ ফর্ম',
                        value: formLabel,
                      ),
                    ),
                    _tileDivider(scheme),
                    Expanded(
                      child: _FactTile(
                        icon: Icons.factory_outlined,
                        iconColor: scheme.primary,
                        label: 'প্রস্তুতকারক',
                        value: companyName,
                      ),
                    ),
                    _tileDivider(scheme),
                    Expanded(
                      child: _FactTile(
                        icon: Icons.sell_outlined,
                        iconColor: scheme.tertiary,
                        label: 'মূল্য',
                        value: medicine.hasPrice ? priceLabel : 'নেই',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (packLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _HeroInfoChip(
                  icon: Icons.inventory_2_outlined,
                  label: 'প্যাক',
                  value: packLabel,
                  accent: scheme.tertiary,
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: onExplain,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text(
                  'বিস্তারিত ব্যাখ্যা',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: onShowDosage,
                icon: const Icon(Icons.medication_outlined, size: 18),
                label: const Text(
                  'ডোজ ও ব্যবহারবিধি',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            if (translating || translateNote.isNotEmpty) ...[
              const SizedBox(height: 11),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: .75),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (translating)
                      const Padding(
                        padding: EdgeInsets.only(right: 9),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.translate_rounded,
                          size: 16,
                          color: scheme.primary,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        translating
                            ? sectionCount == 0
                                  ? 'বাংলায় অনুবাদ হচ্ছে…'
                                  : 'বাংলায় অনুবাদ হচ্ছে… '
                                        '(${bn(translatedCount)}/${bn(sectionCount)})'
                            : translateNote,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: onAskAi,
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 17,
                    ),
                    label: const Text(
                      'এআই-কে জিজ্ঞাসা',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: onAlternatives,
                    icon: const Icon(Icons.compare_arrows_rounded, size: 17),
                    label: const Text(
                      'বিকল্প ওষুধ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _tileDivider(ColorScheme scheme) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Container(
      width: 1,
      color: scheme.outlineVariant.withValues(alpha: 0.5),
    ),
  );
}

class _HeroInfoChip extends StatelessWidget {
  const _HeroInfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Provenance extends StatelessWidget {
  const _Provenance({required this.medicine});

  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final updated = medicine.sourceUpdated == null
        ? 'অজানা'
        : bnDateFromIso(medicine.sourceUpdated);
    final source = medicine.isManual
        ? 'ব্যবহারকারীর সংযোজন'
        : 'বাংলাদেশের ওষুধের তথ্যভান্ডার';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 22, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'তথ্যের উৎস: $source',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'যাচাই: ক্লিনিক্যালি যাচাইকৃত নয় (শুধু রেফারেন্সের জন্য)।',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'আপডেট: $updated',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.text,
    this.translated = false,
    this.medicine,
  });

  final MedicineSection section;

  /// The translation or a Bengali-only unavailable notice.
  final String text;

  /// True when [text] is a cached AI translation rather than the source.
  final bool translated;

  /// Current medicine model used for structured age-tier dosage and disease tag extraction.
  final Medicine? medicine;

  IconData _getSectionIcon(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('indication') || lower.contains('নির্দেশনা')) {
      return Icons.check_circle_outline;
    }
    if (lower.contains('overdose') ||
        lower.contains('অতিরিক্ত ডোজ') ||
        lower.contains('অতিরিক্ত মাত্রা')) {
      return Icons.warning_amber_rounded;
    }
    if (lower.contains('dosage') ||
        lower.contains('মাত্রা') ||
        lower.contains('dose')) {
      return Icons.medication_outlined;
    }
    if (lower.contains('side effect') ||
        lower.contains('পার্শ্বপ্রতিক্রিয়া')) {
      return Icons.warning_amber_rounded;
    }
    if (lower.contains('contraindication') ||
        lower.contains('প্রতিনির্দেশনা')) {
      return Icons.do_not_disturb_alt_outlined;
    }
    if (lower.contains('interaction') || lower.contains('মিথস্ক্রিয়া')) {
      return Icons.sync_problem_outlined;
    }
    if (lower.contains('pregnancy') || lower.contains('গর্ভাবস্থা')) {
      return Icons.pregnant_woman_outlined;
    }
    if (lower.contains('precaution') || lower.contains('সতর্কতা')) {
      return Icons.privacy_tip_outlined;
    }
    if (lower.contains('pharmacology')) {
      return Icons.science_outlined;
    }
    return Icons.info_outline;
  }

  @override
  Widget build(BuildContext context) {
    final canonicalKey = Medicine.canonicalSectionKey(section.key);
    if (medicine != null && canonicalKey == 'dosage_and_administration') {
      return _DosageAgeSliderCard(
        medicine: medicine!,
        section: section,
        text: text,
        translated: translated,
      );
    }

    if (medicine != null &&
        (canonicalKey == 'indications' ||
            section.label.contains('নির্দেশনা'))) {
      return _IndicationsCard(
        medicine: medicine!,
        section: section,
        text: text,
        translated: translated,
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: .6),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: .7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getSectionIcon(section.label),
                      size: 19,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      section.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  if (translated)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: .65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.translate_rounded,
                            size: 13,
                            color: scheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'অনূদিত',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: HtmlContent(text, key: ValueKey(text)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive Age Dosage Calculator & Slider Card for Dosage & Administration.
class _DosageAgeSliderCard extends StatefulWidget {
  const _DosageAgeSliderCard({
    required this.medicine,
    required this.section,
    required this.text,
    this.translated = false,
  });

  final Medicine medicine;
  final MedicineSection section;
  final String text;
  final bool translated;

  @override
  State<_DosageAgeSliderCard> createState() => _DosageAgeSliderCardState();
}

class _DosageAgeSliderCardState extends State<_DosageAgeSliderCard> {
  // 0: বাচ্চা, 1: যুবক, 2: বয়স্ক
  int _selectedTierIndex = 1;
  bool _showFullRawText = false;
  late final TextEditingController _ageController;
  bool _isMonths = false;
  late CalculatedDosage _calculatedDosage;

  @override
  void initState() {
    super.initState();
    _ageController = TextEditingController(text: '২৫');
    _calculatedDosage = DosageCalculator.calculate(
      widget.medicine,
      ageYears: 25,
      ageMonths: 0,
    );
  }

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  void _onCategorySelected(int index) {
    setState(() {
      _selectedTierIndex = index;
      _isMonths = false;
      if (index == 0) {
        _ageController.text = '৫';
        _calculatedDosage = DosageCalculator.calculate(
          widget.medicine,
          ageYears: 5,
        );
      } else if (index == 1) {
        _ageController.text = '২৫';
        _calculatedDosage = DosageCalculator.calculate(
          widget.medicine,
          ageYears: 25,
        );
      } else {
        _ageController.text = '৬৫';
        _calculatedDosage = DosageCalculator.calculate(
          widget.medicine,
          ageYears: 65,
        );
      }
    });
  }

  void _calculateAgeDosage() {
    final rawText = _ageController.text.trim();
    final digits = bnToEn(rawText).replaceAll(RegExp(r'[^0-9]'), '');
    final val = int.tryParse(digits) ?? (_isMonths ? 6 : 25);

    int years;
    int months;
    if (_isMonths) {
      years = val ~/ 12;
      months = val % 12;
    } else {
      years = val;
      months = 0;
    }

    final totalMonths = (years * 12) + months;
    int tier;
    if (totalMonths < 12 * 12) {
      tier = 0; // বাচ্চা
    } else if (years < 60) {
      tier = 1; // যুবক
    } else {
      tier = 2; // বয়স্ক
    }

    setState(() {
      _selectedTierIndex = tier;
      _calculatedDosage = DosageCalculator.calculate(
        widget.medicine,
        ageYears: years,
        ageMonths: months,
      );
    });
    FocusScope.of(context).unfocus();
  }

  Widget _buildUnitTab(String text, bool active, VoidCallback onTap) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: active ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: active ? Colors.white : scheme.onSurfaceVariant,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDosageItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
    bool isAlert = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isAlert
            ? accentColor.withValues(alpha: 0.08)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAlert
              ? accentColor.withValues(alpha: 0.35)
              : scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isAlert ? accentColor : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tiers = DosageAgeParser.parse(widget.medicine, widget.text);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: .6),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: .7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.medication_outlined,
                      size: 21,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ডোজ ও ব্যবহারবিধি',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'বয়সভিত্তিক প্রয়োগমাত্রা ও ক্যালকুলেটর',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3-way Category Tabs (বাচ্চা, যুবক, বয়স্ক)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    for (int i = 0; i < tiers.length; i++) ...[
                      Expanded(
                        child: _AgeSliderTab(
                          label: tiers[i].name,
                          icon: tiers[i].icon,
                          selected: _selectedTierIndex == i,
                          accentColor: tiers[i].accentColor,
                          onTap: () => _onCategorySelected(i),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Interactive Age Input Bar ("বয়স দিন ও টিক চিহ্ন/সাবমিট চাপুন")
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_calendar_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                        Text(
                          'রোগীর বয়স:',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        SizedBox(
                          width: 52,
                          height: 36,
                          child: TextField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              filled: true,
                              fillColor: scheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: scheme.outlineVariant,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: scheme.primary,
                                  width: 1.8,
                                ),
                              ),
                            ),
                            onSubmitted: (_) => _calculateAgeDosage(),
                          ),
                        ),
                        Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildUnitTab('বছর', !_isMonths, () {
                                setState(() => _isMonths = false);
                                _calculateAgeDosage();
                              }),
                              _buildUnitTab('মাস', _isMonths, () {
                                setState(() => _isMonths = true);
                                _calculateAgeDosage();
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: _calculateAgeDosage,
                      icon: const Icon(Icons.check_rounded, size: 17),
                      label: const Text('হিসাব করুন'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        visualDensity: VisualDensity.compact,
                        textStyle: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Calculated Structured Result List Card
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: Padding(
                key: ValueKey(
                  '${_calculatedDosage.ageText}_${_calculatedDosage.categoryName}',
                ),
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _calculatedDosage.accentColor.withValues(
                        alpha: 0.35,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Patient Age Bracket Header
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _calculatedDosage.accentColor.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _calculatedDosage.icon,
                                  size: 15,
                                  color: _calculatedDosage.accentColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'বয়স: ${_calculatedDosage.ageText}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: _calculatedDosage.accentColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _calculatedDosage.categoryName,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Item 1: চামচ বা পরিমাপ
                      _buildDosageItem(
                        context,
                        icon: Icons.medication_rounded,
                        label: 'কয় চামচ / মাত্রা:',
                        value: _calculatedDosage.doseAmount,
                        accentColor: _calculatedDosage.accentColor,
                      ),

                      // Item 2: মিলিগ্রাম / শক্তি
                      _buildDosageItem(
                        context,
                        icon: Icons.straighten_rounded,
                        label: 'কত মিলিগ্রাম (শক্তি):',
                        value: _calculatedDosage.milligrams,
                        accentColor: scheme.primary,
                      ),

                      // Item 3: দিনে কয়বার
                      _buildDosageItem(
                        context,
                        icon: Icons.schedule_rounded,
                        label: 'দিনে কয়বার সেব্য:',
                        value: _calculatedDosage.frequency,
                        accentColor: const Color(0xFFE65100),
                      ),

                      // Item 4: খাওয়ার নিয়ম
                      _buildDosageItem(
                        context,
                        icon: Icons.restaurant_rounded,
                        label: 'খাওয়ার নিয়ম ও নির্দেশিকা:',
                        value: _calculatedDosage.howToTake,
                        accentColor: const Color(0xFF00897B),
                      ),

                      // Item 5: দৈনিক সর্বোচ্চ সীমা
                      if (_calculatedDosage.maxDaily != '০')
                        _buildDosageItem(
                          context,
                          icon: Icons.timelapse_rounded,
                          label: 'দৈনিক সর্বোচ্চ মাত্রা:',
                          value: _calculatedDosage.maxDaily,
                          accentColor: const Color(0xFF5E35B1),
                        ),

                      // Item 6: বয়সভিত্তিক সতর্কতা
                      _buildDosageItem(
                        context,
                        icon: Icons.warning_amber_rounded,
                        label: 'বয়সোপযোগী জরুরি সতর্কতা:',
                        value: _calculatedDosage.warnings,
                        accentColor: const Color(0xFFC62828),
                        isAlert: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Toggle full raw text
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () =>
                    setState(() => _showFullRawText = !_showFullRawText),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Text(
                        _showFullRawText
                            ? 'সংক্ষিপ্ত ভিউতে দেখুন'
                            : 'সম্পূর্ণ ক্লিনিক্যাল বিবরণ দেখুন',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(
                        _showFullRawText
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_showFullRawText)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: HtmlContent(widget.text),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AgeSliderTab extends StatelessWidget {
  const _AgeSliderTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? scheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? accentColor : scheme.onSurfaceVariant,
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Interactive Indications Card with Disease Tags / Chips that search on tap.
class _IndicationsCard extends StatefulWidget {
  const _IndicationsCard({
    required this.medicine,
    required this.section,
    required this.text,
    this.translated = false,
  });

  final Medicine medicine;
  final MedicineSection section;
  final String text;
  final bool translated;

  @override
  State<_IndicationsCard> createState() => _IndicationsCardState();
}

class _IndicationsCardState extends State<_IndicationsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tags = DiseaseTagExtractor.extract(widget.medicine, widget.text);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: .6),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: .7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.healing_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'রোগের নির্দেশনা',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'ট্যাগে চাপ দিয়ে এই রোগের সব ওষুধ দেখুন',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Disease Tags Container (Clickable pills)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in tags) ...[
                    Material(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      elevation: 1,
                      shadowColor: scheme.shadow.withValues(alpha: 0.05),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          DiseaseMedicinesSheet.show(
                            context,
                            diseaseName: tag.name,
                            keywords: tag.keywords,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.65,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tag.icon ?? Icons.local_offer_outlined,
                                size: 15,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  tag.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_outward_rounded,
                                size: 13,
                                color: scheme.primary.withValues(alpha: 0.85),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Detailed text overview with expand/collapse
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Only one variant is mounted at a time: keeping both
                    // children of an AnimatedCrossFade alive duplicates the
                    // same text for screen readers and for hit-testing.
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: _expanded
                          ? HtmlContent(
                              widget.text,
                              key: const ValueKey('indications-full'),
                            )
                          : Text(
                              widget.text,
                              key: const ValueKey('indications-short'),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                            ),
                    ),
                    if (widget.text.length > 100) ...[
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => setState(() => _expanded = !_expanded),
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _expanded
                                  ? 'সংক্ষিপ্ত করুন'
                                  : 'সম্পূর্ণ বিবরণ পড়ুন',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Icon(
                              _expanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: scheme.primary,
                            ),
                          ],
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
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.medicine});

  final Medicine medicine;

  bool get _hasAny {
    String? n(String? v) => (v?.trim().isEmpty ?? true) ? null : v!.trim();
    return n(medicine.tradePrice) != null ||
        n(medicine.mrp) != null ||
        medicine.stockQuantity != null ||
        n(medicine.batchNumber) != null ||
        n(medicine.rackNo) != null ||
        n(medicine.mfgDate) != null ||
        n(medicine.expiryDate) != null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAny) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final days = medicine.daysToExpiry;

    Widget? expiryBadge;
    if (medicine.expiryDate != null) {
      if (medicine.isExpired) {
        expiryBadge = _Badge(
          label: 'মেয়াদ শেষ',
          bg: scheme.errorContainer,
          fg: scheme.onErrorContainer,
          icon: Icons.event_busy,
        );
      } else if (days != null && days <= AppConfig.expiringSoonDays) {
        expiryBadge = _Badge(
          label: 'মেয়াদ আসন্ন · ${bn(days)} দিন',
          bg: scheme.tertiaryContainer,
          fg: scheme.onSurface,
          icon: Icons.warning_amber_rounded,
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'ইনভেন্টরি ও মূল্য',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  ?expiryBadge,
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _DetailRow(
                    icon: Icons.payments_outlined,
                    label: 'ক্রয় মূল্য',
                    value: medicine.tradePrice == null
                        ? null
                        : '৳ ${medicine.tradePrice}',
                  ),
                  _DetailRow(
                    icon: Icons.sell_outlined,
                    label: 'সর্বোচ্চ খুচরা মূল্য',
                    value: medicine.mrp == null ? null : '৳ ${medicine.mrp}',
                  ),
                  _DetailRow(
                    icon: Icons.layers_outlined,
                    label: 'বর্তমান স্টক',
                    value: medicine.stockQuantity == null
                        ? null
                        : '${bn(medicine.stockQuantity!)} পিস',
                  ),
                  _DetailRow(
                    icon: Icons.qr_code,
                    label: 'ব্যাচ নম্বর',
                    value: medicine.batchNumber,
                  ),
                  _DetailRow(
                    icon: Icons.shelves,
                    label: 'র্যাক / শেলফ',
                    value: medicine.rackNo,
                  ),
                  _DetailRow(
                    icon: Icons.event_available,
                    label: 'উৎপাদন তারিখ',
                    value: bnDateFromIso(medicine.mfgDate),
                  ),
                  _DetailRow(
                    icon: Icons.event_busy,
                    label: 'মেয়াদোত্তীর্ণ',
                    value: bnDateFromIso(medicine.expiryDate),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, this.value});

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = value?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            v.isEmpty ? '—' : v,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.bg,
    required this.fg,
    required this.icon,
  });

  final String label;
  final Color bg;
  final Color fg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
