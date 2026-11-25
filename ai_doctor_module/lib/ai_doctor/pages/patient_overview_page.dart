import 'package:flutter/material.dart';

import '../db.dart';
import '../localization.dart';
import '../models.dart';
import '../widgets/medicine_sheet.dart';
import '../widgets/patient_avatar.dart';
import '../widgets/patient_profile_sheet.dart';
import 'patient_chat_page.dart';
import 'patient_form_page.dart';

class AiPatientOverviewPage extends StatefulWidget {
  const AiPatientOverviewPage({
    super.key,
    required this.patient,
    this.initialQuestion,
  });

  final AiPatient patient;
  final String? initialQuestion;

  @override
  State<AiPatientOverviewPage> createState() => _AiPatientOverviewPageState();
}

class _AiPatientOverviewPageState extends State<AiPatientOverviewPage> {
  late AiPatient _patient = widget.patient;
  // A deep-linked question is consumed once. Keeping it in the immutable
  // widget would re-send the same question on every later consultation tap.
  late String? _pendingQuestion;
  late Future<({List<AiMedication> medications, List<AiDailyTask> tasks})>
  _data = _load();

  @override
  void initState() {
    super.initState();
    _pendingQuestion = widget.initialQuestion;
  }

  Future<({List<AiMedication> medications, List<AiDailyTask> tasks})>
  _load() async {
    final pid = _patient.id;
    if (pid == null) {
      return (medications: <AiMedication>[], tasks: <AiDailyTask>[]);
    }
    final existing = await AiDoctorDb.i.patient(pid);
    if (existing == null) {
      if (mounted) Navigator.pop(context, true);
      return (medications: <AiMedication>[], tasks: <AiDailyTask>[]);
    }
    final medications = await AiDoctorDb.i.meds(pid);
    final tasks = await AiDoctorDb.i.dailyTasks(pid);
    return (medications: medications, tasks: tasks);
  }

  void _reload() {
    setState(() {
      _data = _load();
    });
  }

  Future<void> _openChat({String? question}) async {
    final asked = question ?? _pendingQuestion;
    _pendingQuestion = null;
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AiDoctorChatPage(
          patient: _patient,
          initialQuestion: asked,
        ),
      ),
    );
    if (!mounted) return;
    if (deleted == true) {
      Navigator.pop(context, true);
      return;
    }
    _reload();
  }

  Future<void> _editPatient() async {
    final patient = await Navigator.push<AiPatient>(
      context,
      MaterialPageRoute(builder: (_) => AiPatientFormPage(patient: _patient)),
    );
    if (patient == null || !mounted) return;
    await AiDoctorDb.i.updatePatient(patient);
    if (!mounted) return;
    setState(() {
      _patient = patient;
      _data = _load();
    });
  }

  Future<void> _openHealthProfile() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      builder: (_) => AiPatientProfileSheet(patientId: _patient.id!),
    );
  }

  Future<void> _manageMedications() async {
    String? question;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      builder: (sheetContext) => AiMedicineSheet(
        patientId: _patient.id!,
        onNote: (_) => _reload(),
        onAsk: (value) {
          question = value;
          Navigator.pop(sheetContext);
        },
      ),
    );
    if (!mounted) return;
    _reload();
    if (question != null) await _openChat(question: question);
  }

  Future<void> _addTask() async {
    final taskData = await showDialog<({String title, String time})>(
      context: context,
      builder: (_) => const _AddTaskDialog(),
    );
    if (taskData == null || !mounted) return;
    await AiDoctorDb.i.addDailyTask(
      AiDailyTask(
        patientId: _patient.id!,
        title: taskData.title,
        time: taskData.time,
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _toggleTask(AiDailyTask task) async {
    if (task.id == null) return;
    final today = _todayKey();
    await AiDoctorDb.i.updateDailyTask(
      task.copyWith(doneOn: task.isDoneToday ? '' : today),
    );
    if (mounted) _reload();
  }

  Future<void> _deleteTask(AiDailyTask task) async {
    if (task.id == null) return;
    await AiDoctorDb.i.deleteDailyTask(task.id!);
    if (mounted) _reload();
  }

  String _todayKey() {
    final date = DateTime.now();
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(aiText('রোগীর সারাংশ', 'Patient overview')),
        actions: [
          AiDoctorLanguageButton(onChanged: () => setState(() {})),
          IconButton(
            tooltip: aiText('রোগীর তথ্য সম্পাদনা', 'Edit patient'),
            onPressed: _editPatient,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: FutureBuilder<({List<AiMedication> medications, List<AiDailyTask> tasks})>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      aiText(
                        'রোগীর তথ্য লোড করা যায়নি।',
                        'Could not load patient details.',
                      ),
                    ),
                    TextButton(
                      onPressed: _reload,
                      child: Text(aiText('আবার চেষ্টা করুন', 'Try again')),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final medications = snapshot.data!.medications;
          final tasks = snapshot.data!.tasks;
          final completed = tasks.where((task) => task.isDoneToday).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _PatientHero(patient: _patient),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.health_and_safety_outlined,
                      label: aiText('স্বাস্থ্যতথ্য', 'Health profile'),
                      onTap: _openHealthProfile,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.medication_outlined,
                      label: aiText('ওষুধ', 'Medications'),
                      count: medications.length,
                      onTap: _manageMedications,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      aiText('দৈনিক যত্ন', 'Daily care'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    aiText(
                      '${aiLocalizedNumber(completed)}/${aiLocalizedNumber(tasks.length)}টি সম্পন্ন',
                      '$completed/${tasks.length} done',
                    ),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: aiText(
                      'দৈনিক কাজ যোগ করুন',
                      'Add daily care task',
                    ),
                    onPressed: _addTask,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              Text(
                aiText(
                  'প্রতিদিনের যত্নের কাজের তালিকা। কোনো অনুস্মারক পাঠানো হয় না।',
                  'A simple daily checklist. No reminders are sent.',
                ),
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              if (tasks.isEmpty)
                _EmptyCard(
                  icon: Icons.checklist_rounded,
                  text: aiText(
                    'প্রতিদিনের যত্নের কাজগুলো এখানে যোগ করুন।',
                    'Add care steps to track each day.',
                  ),
                  actionLabel: aiText('কাজ যোগ করুন', 'Add a task'),
                  onTap: _addTask,
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final task in tasks)
                        ListTile(
                          leading: Checkbox(
                            value: task.isDoneToday,
                            onChanged: (_) => _toggleTask(task),
                          ),
                          title: Text(
                            task.title,
                            style: TextStyle(
                              decoration: task.isDoneToday
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isDoneToday
                                  ? colors.onSurfaceVariant
                                  : null,
                            ),
                          ),
                          subtitle: task.time.isEmpty ? null : Text(task.time),
                          trailing: IconButton(
                            tooltip: aiText('কাজ মুছুন', 'Delete task'),
                            onPressed: () => _deleteTask(task),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      aiText('চলমান ওষুধ', 'Current medications'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _manageMedications,
                    child: Text(aiText('পরিচালনা', 'Manage')),
                  ),
                ],
              ),
              if (medications.isEmpty)
                _EmptyCard(
                  icon: Icons.medication_outlined,
                  text: aiText(
                    'এখনো কোনো চলমান ওষুধ যোগ করা হয়নি।',
                    'No active medications added.',
                  ),
                  actionLabel: aiText('ওষুধ যোগ করুন', 'Add medication'),
                  onTap: _manageMedications,
                )
              else
                for (final medication in medications)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.onPrimaryContainer,
                        child: const Icon(Icons.medication_outlined),
                      ),
                      title: Text(medication.name),
                      subtitle: Text(
                        '${medication.dose} ${aiMedicationUnit(medication.unit)} · '
                        '${aiLocalizedNumber(medication.timesPerDay)} ${aiText('বার/দিন', 'times/day')} · '
                        '${aiDosageFormLabel(medication.dosageForm)}',
                      ),
                      trailing: Text(aiMedicationSince(medication.startedAt)),
                    ),
                  ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _openChat(),
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(
                  aiText(
                    'এআই চিকিৎসকের সঙ্গে কথা বলুন',
                    'Open AI consultation',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PatientHero extends StatelessWidget {
  const _PatientHero({required this.patient});

  final AiPatient patient;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AiPatientAvatar(patient: patient, radius: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        '${aiLocalizedNumber(patient.age)} ${aiText('বছর', 'years')}',
                        if (patient.gender.isNotEmpty)
                          aiGenderLabel(patient.gender),
                        if (patient.relation.isNotEmpty)
                          aiRelationLabel(patient.relation),
                      ].join(' · '),
                      style: TextStyle(
                        color: colors.onPrimary.withValues(alpha: .88),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (patient.bloodGroup.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.onPrimary.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bloodtype_outlined,
                    color: colors.onPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '${aiText('রক্তের গ্রুপ', 'Blood group')} · ${patient.bloodGroup}',
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colors.primary, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (count != null)
                Text(
                  aiLocalizedNumber(count!),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
            TextButton(onPressed: onTap, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog();

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  late final TextEditingController _titleController;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final time = _selectedTime;
    Navigator.of(context).pop((
      title: title,
      time: time == null
          ? ''
          : '${time.hour.toString().padLeft(2, '0')}:'
                '${time.minute.toString().padLeft(2, '0')}',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        aiText('দৈনিক যত্নের কাজ যোগ করুন', 'Add daily care task'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: aiText('কাজের নাম', 'Task'),
                hintText: aiText(
                  'যেমন: রক্তচাপ মাপা',
                  'e.g. Record blood pressure',
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime:
                        _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
                  );
                  if (time != null && mounted) {
                    setState(() => _selectedTime = time);
                  }
                },
                icon: const Icon(Icons.schedule_outlined),
                label: Text(
                  _selectedTime?.format(context) ??
                      aiText('সময় দিন (ঐচ্ছিক)', 'Add a time (optional)'),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(aiText('বাতিল', 'Cancel')),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _titleController,
          builder: (context, value, _) => FilledButton(
            // Disabled instead of silently doing nothing on an empty title.
            onPressed: value.text.trim().isEmpty ? null : _submit,
            child: Text(aiText('যোগ করুন', 'Add task')),
          ),
        ),
      ],
    );
  }
}

