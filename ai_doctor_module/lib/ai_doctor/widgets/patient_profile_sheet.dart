import 'package:flutter/material.dart';

import '../db.dart';
import '../localization.dart';
import '../models.dart';

class AiPatientProfileSheet extends StatefulWidget {
  const AiPatientProfileSheet({super.key, required this.patientId});

  final int patientId;

  @override
  State<AiPatientProfileSheet> createState() => _AiPatientProfileSheetState();
}

class _AiPatientProfileSheetState extends State<AiPatientProfileSheet> {
  late Future<({List<AiCondition> conditions, List<AiAllergy> allergies})>
  _future = _load();

  Future<({List<AiCondition> conditions, List<AiAllergy> allergies})>
  _load() async {
    final conditions = await AiDoctorDb.i.conditions(widget.patientId);
    final allergies = await AiDoctorDb.i.allergies(widget.patientId);
    return (conditions: conditions, allergies: allergies);
  }

  void _reload() => setState(() => _future = _load());

  Future<String?> _askName(String title) async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => _AskNameDialog(title: title),
    );
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<void> _addCondition(String type) async {
    final name = await _askName(
      type == 'current'
          ? aiText('বর্তমান রোগ যোগ করুন', 'Add current condition')
          : aiText('পূর্বের রোগের তথ্য যোগ করুন', 'Add medical history'),
    );
    if (name == null || !mounted) return;
    await AiDoctorDb.i.addCondition(
      AiCondition(patientId: widget.patientId, name: name, type: type),
    );
    if (!mounted) return;
    _reload();
  }

  Future<void> _addAllergy() async {
    final name = await _askName(aiText('অ্যালার্জি যোগ করুন', 'Add allergy'));
    if (name == null || !mounted) return;
    await AiDoctorDb.i.addAllergy(
      AiAllergy(patientId: widget.patientId, name: name),
    );
    if (!mounted) return;
    _reload();
  }

  Future<void> _deleteCondition(AiCondition condition) async {
    if (condition.id == null || !mounted) return;
    await AiDoctorDb.i.deleteCondition(condition.id!);
    if (!mounted) return;
    _reload();
  }

  Future<void> _deleteAllergy(AiAllergy allergy) async {
    if (allergy.id == null || !mounted) return;
    await AiDoctorDb.i.deleteAllergy(allergy.id!);
    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    aiText('স্বাস্থ্যতথ্য', 'Health profile'),
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: aiText('বন্ধ করুন', 'Close'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child:
                FutureBuilder<
                  ({List<AiCondition> conditions, List<AiAllergy> allergies})
                >(
                  future: _future,
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
                                  'স্বাস্থ্যতথ্য লোড করা যায়নি।',
                                  'Could not load profile.',
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _reload,
                                child: Text(
                                  aiText('আবার চেষ্টা করুন', 'Try again'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final data = snapshot.data!;
                    return ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      children: [
                        Text(
                          aiText(
                            'আরও প্রাসঙ্গিক এআই উত্তরের জন্য স্বাস্থ্যতথ্য যোগ করুন।',
                            'Add health details for more relevant AI answers.',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _section(
                          title: aiText('বর্তমান রোগ', 'Current conditions'),
                          addLabel: aiText('রোগ যোগ করুন', 'Add condition'),
                          icon: Icons.monitor_heart_outlined,
                          onAdd: () => _addCondition('current'),
                          children: [
                            for (final condition in data.conditions.where(
                              (item) => item.type == 'current',
                            ))
                              _entry(
                                condition.name,
                                onDelete: () => _deleteCondition(condition),
                              ),
                          ],
                        ),
                        _section(
                          title: aiText('আগের রোগের ইতিহাস', 'Medical history'),
                          addLabel: aiText('ইতিহাস যোগ করুন', 'Add history'),
                          icon: Icons.history_rounded,
                          onAdd: () => _addCondition('past'),
                          children: [
                            for (final condition in data.conditions.where(
                              (item) => item.type == 'past',
                            ))
                              _entry(
                                condition.name,
                                onDelete: () => _deleteCondition(condition),
                              ),
                          ],
                        ),
                        _section(
                          title: aiText('অ্যালার্জি', 'Allergies'),
                          addLabel: aiText(
                            'অ্যালার্জি যোগ করুন',
                            'Add allergy',
                          ),
                          icon: Icons.warning_amber_rounded,
                          onAdd: _addAllergy,
                          children: [
                            for (final allergy in data.allergies)
                              _entry(
                                allergy.name,
                                onDelete: () => _deleteAllergy(allergy),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required String addLabel,
    required IconData icon,
    required VoidCallback onAdd,
    required List<Widget> children,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: addLabel,
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    aiText('কোনো তথ্য যোগ করা হয়নি', 'No information added'),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }

  Widget _entry(String name, {required VoidCallback onDelete}) => ListTile(
    dense: true,
    contentPadding: const EdgeInsets.only(left: 8),
    title: Text(name),
    trailing: IconButton(
      tooltip: aiText('সরিয়ে দিন', 'Remove'),
      onPressed: onDelete,
      icon: const Icon(Icons.delete_outline, size: 20),
    ),
  );
}

class _AskNameDialog extends StatefulWidget {
  const _AskNameDialog({required this.title});

  final String title;

  @override
  State<_AskNameDialog> createState() => _AskNameDialogState();
}

class _AskNameDialogState extends State<_AskNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: aiText('নাম', 'Name')),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(aiText('বাতিল', 'Cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(aiText('যোগ করুন', 'Add')),
        ),
      ],
    );
  }
}
