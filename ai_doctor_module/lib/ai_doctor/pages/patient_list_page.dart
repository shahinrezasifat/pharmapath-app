import 'package:flutter/material.dart';

import '../db.dart';
import '../localization.dart';
import '../models.dart';
import 'patient_chat_page.dart';
import 'patient_form_page.dart';
import 'patient_overview_page.dart';
import '../widgets/patient_avatar.dart';

class AiDoctorHomePage extends StatefulWidget {
  const AiDoctorHomePage({
    super.key,
    this.initialQuestion,
    this.isTab,
  });

  final String? initialQuestion;
  final bool? isTab;

  @override
  State<AiDoctorHomePage> createState() => _AiDoctorHomePageState();
}

class _AiDoctorHomePageState extends State<AiDoctorHomePage> {
  late Future<List<AiPatient>> _future = AiDoctorDb.i.patients();
  final _search = TextEditingController();

  void _reload() {
    setState(() {
      _future = AiDoctorDb.i.patients();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _addPatient() async {
    final patient = await Navigator.push<AiPatient>(
      context,
      MaterialPageRoute(builder: (_) => const AiPatientFormPage()),
    );
    if (patient != null) {
      try {
        final id = await AiDoctorDb.i.addPatient(patient);
        if (widget.initialQuestion?.trim().isNotEmpty == true) {
          await _open(
            AiPatient(
              id: id,
              name: patient.name,
              age: patient.age,
              relation: patient.relation,
              gender: patient.gender,
              bloodGroup: patient.bloodGroup,
              phone: patient.phone,
              photoPath: patient.photoPath,
            ),
          );
        } else {
          _reload();
        }
      } on Exception {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                aiText(
                  'রোগীর প্রোফাইল তৈরি করা যায়নি। আবার চেষ্টা করুন।',
                  'Could not create the patient profile. Please try again.',
                ),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _addDemoPatient() async {
    try {
      final patients = await AiDoctorDb.i.patients();
      final existing = patients.where(
        (patient) => patient.relation == 'Demo profile',
      );
      if (existing.isNotEmpty) {
        await _open(existing.first);
        return;
      }

      final demo = AiPatient(
        name: 'Alex Morgan',
        age: 36,
        relation: 'Demo profile',
      );
      final id = await AiDoctorDb.i.addPatient(demo);
      if (!mounted) return;
      await _open(
        AiPatient(
          id: id,
          name: demo.name,
          age: demo.age,
          relation: demo.relation,
        ),
      );
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              aiText(
                'নমুনা প্রোফাইল যোগ করা যায়নি। আবার চেষ্টা করুন।',
                'Could not add the sample profile. Please try again.',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _open(AiPatient p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => widget.initialQuestion?.trim().isNotEmpty == true
            ? AiDoctorChatPage(
                patient: p,
                initialQuestion: widget.initialQuestion,
              )
            : AiPatientOverviewPage(patient: p),
      ),
    );
    _reload();
  }

  Future<void> _deletePatient(AiPatient p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(aiText('রোগী মুছবেন?', 'Delete patient?')),
        content: Text(
          aiText(
            '${p.name} এবং তাঁর প্রোফাইল, ওষুধ, দৈনিক কাজ ও কথোপকথনের ইতিহাস স্থায়ীভাবে মুছে যাবে।',
            'This will permanently delete ${p.name} and their profile, '
                'medications, tasks, and chat history.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(aiText('বাতিল', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(aiText('মুছুন', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed == true && p.id != null) {
      await AiDoctorDb.i.deletePatient(p.id!);
      if (mounted) {
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              aiText(
                '${p.name}-এর প্রোফাইল মুছে ফেলা হয়েছে।',
                '${p.name} deleted',
              ),
            ),
          ),
        );
      }
    }
  }

  double _bottomInset(BuildContext context) {
    try {
      final view = View.of(context);
      final pixelRatio = view.devicePixelRatio;
      if (pixelRatio > 0) {
        final logical = view.viewPadding.bottom / pixelRatio;
        if (logical > 0) return logical;
        final logicalPad = view.padding.bottom / pixelRatio;
        if (logicalPad > 0) return logicalPad;
      }
    } catch (_) {}
    final viewPad = MediaQuery.viewPaddingOf(context).bottom;
    if (viewPad > 0) return viewPad;
    return MediaQuery.paddingOf(context).bottom;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final isShellTab = widget.isTab ?? !canPop;
    final inset = _bottomInset(context);
    final navBarTop = isShellTab ? (80.0 + inset) : 0.0;
    final fabBottom = isShellTab ? (navBarTop + 14.0) : (inset + 14.0);
    final listBottom = isShellTab ? (navBarTop + 84.0) : (inset + 84.0);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          aiText('রোগী', 'Patients'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          AiDoctorLanguageButton(
            onChanged: () {
              if (mounted) setState(() {});
            },
          ),
          PopupMenuButton<String>(
            tooltip: aiText('আরও বিকল্প', 'More options'),
            onSelected: (value) {
              if (value == 'demo') _addDemoPatient();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'demo',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.science_outlined),
                  title: Text(
                    aiText('নমুনা প্রোফাইল যোগ করুন', 'Add sample profile'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<AiPatient>>(
        future: _future,
        builder: (c, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      aiText(
                        'রোগীর তালিকা লোড করা যায়নি।',
                        'Could not load patients.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _reload,
                      child: Text(aiText('আবার চেষ্টা করুন', 'Try again')),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_alt_outlined, size: 52, color: cs.primary),
                  const SizedBox(height: 16),
                  Text(
                    aiText('এখনো কোনো রোগীর প্রোফাইল নেই', 'No patients yet'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    aiText(
                      'স্বাস্থ্যতথ্য ও চিকিৎসকের সঙ্গে কথোপকথন সংরক্ষণে একটি প্রোফাইল তৈরি করুন।',
                      'Create a profile to save health details and consultations.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),
                  TextButton.icon(
                    onPressed: _addDemoPatient,
                    icon: const Icon(Icons.science_outlined, size: 18),
                    label: Text(
                      aiText('নমুনা প্রোফাইল যোগ করুন', 'Add sample profile'),
                    ),
                  ),
                ],
              ),
            );
          }
          final query = _search.text.trim().toLowerCase();
          final filtered = list.where((patient) {
            return query.isEmpty ||
                patient.name.toLowerCase().contains(query) ||
                patient.phone.contains(query);
          }).toList();
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 4, 16, listBottom),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: .18),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -24,
                      top: -34,
                      child: Container(
                        width: 118,
                        height: 118,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: .08),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .16),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  aiText('স্বাস্থ্যসেবা', 'HEALTHCARE'),
                                  style: TextStyle(
                                    color: cs.onPrimary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                aiText(
                                  'পরিবারের স্বাস্থ্যপ্রোফাইল',
                                  'Family health profiles',
                                ),
                                style: TextStyle(
                                  color: cs.onPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                aiText(
                                  '${aiLocalizedNumber(list.length)} জনের তথ্য নিরাপদে রাখুন',
                                  'Keep ${list.length} patient profiles in one place',
                                ),
                                style: TextStyle(
                                  color: cs.onPrimary.withValues(alpha: .86),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.health_and_safety_rounded,
                            size: 26,
                            color: cs.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: aiText(
                    'নাম বা ফোন নম্বর দিয়ে খুঁজুন',
                    'Search by name or phone',
                  ),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: cs.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      aiText('রোগীর তালিকা', 'Patient list'),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    aiText(
                      '${aiLocalizedNumber(filtered.length)} জন',
                      '${filtered.length} ${filtered.length == 1 ? 'person' : 'people'}',
                    ),
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    aiText(
                      'এই নামে কোনো রোগী পাওয়া যায়নি।',
                      'No patients match your search.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                for (final patient in filtered) ...[
                  _PatientListCard(
                    patient: patient,
                    onTap: () => _open(patient),
                    onDelete: () => _deletePatient(patient),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: fabBottom),
        child: FloatingActionButton.extended(
          onPressed: _addPatient,
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: Text(aiText('রোগী যোগ করুন', 'Add patient')),
        ),
      ),
    );
  }
}

class _PatientListCard extends StatelessWidget {
  const _PatientListCard({
    required this.patient,
    required this.onTap,
    required this.onDelete,
  });

  final AiPatient patient;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final details = [
      '${aiLocalizedNumber(patient.age)} ${aiText('বছর', 'years')}',
      if (patient.gender.isNotEmpty) aiGenderLabel(patient.gender),
      if (patient.relation.isNotEmpty) aiRelationLabel(patient.relation),
    ];
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: .8),
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.primary.withValues(alpha: .22),
                    width: 1.5,
                  ),
                ),
                child: AiPatientAvatar(patient: patient, radius: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    if (patient.bloodGroup.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${aiText('রক্তের গ্রুপ', 'Blood group')} · ${patient.bloodGroup}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    FutureBuilder<String>(
                      future: AiDoctorDb.i.currentSummary(patient.id!),
                      builder: (context, snapshot) {
                        final summary = snapshot.data;
                        if (summary == null ||
                            summary == 'No current conditions added') {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colors.error),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: aiText('রোগী মুছুন', 'Delete patient'),
                onPressed: onDelete,
                style: IconButton.styleFrom(
                  backgroundColor: colors.errorContainer.withValues(alpha: .65),
                  visualDensity: VisualDensity.compact,
                ),
                icon: Icon(Icons.delete_outline_rounded, color: colors.error),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
