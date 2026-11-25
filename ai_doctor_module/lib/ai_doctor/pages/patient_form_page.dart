import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../localization.dart';
import '../models.dart';

class AiPatientFormPage extends StatefulWidget {
  const AiPatientFormPage({super.key, this.patient});

  final AiPatient? patient;

  @override
  State<AiPatientFormPage> createState() => _AiPatientFormPageState();
}

class _AiPatientFormPageState extends State<AiPatientFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _relation = TextEditingController();
  final _phone = TextEditingController();
  final _imagePicker = ImagePicker();

  XFile? _photo;
  String _gender = '';
  String _bloodGroup = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final patient = widget.patient;
    if (patient == null) return;
    _name.text = patient.name;
    _age.text = patient.age.toString();
    _relation.text = patient.relation;
    _phone.text = patient.phone;
    _gender = patient.gender;
    _bloodGroup = patient.bloodGroup;
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _relation.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 86,
        maxWidth: 1400,
      );
      if (image != null && mounted) setState(() => _photo = image);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              aiText(
                'ছবি নির্বাচন করা যায়নি। আবার চেষ্টা করুন।',
                'Could not select photo. Please try again.',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<String> _savePhoto() async {
    final photo = _photo;
    if (photo == null) return widget.patient?.photoPath ?? '';

    final root = await getApplicationSupportDirectory();
    final folder = Directory(p.join(root.path, 'ai_doctor', 'patients'));
    await folder.create(recursive: true);
    final extension = p.extension(photo.path).toLowerCase();
    final safeExtension = {'.jpg', '.jpeg', '.png', '.webp'}.contains(extension)
        ? extension
        : '.jpg';
    final destination = p.join(
      folder.path,
      'patient_${DateTime.now().microsecondsSinceEpoch}$safeExtension',
    );
    await File(photo.path).copy(destination);
    return destination;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final patient = AiPatient(
        id: widget.patient?.id,
        name: _name.text.trim(),
        age: int.parse(_age.text.trim()),
        relation: _relation.text.trim(),
        gender: _gender,
        bloodGroup: _bloodGroup,
        phone: _phone.text.trim(),
        photoPath: await _savePhoto(),
      );
      if (mounted) Navigator.pop(context, patient);
    } on Exception {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              aiText(
                'রোগীর তথ্য সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।',
                'Could not save patient. Please try again.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.patient == null
              ? aiText('নতুন রোগী', 'New patient')
              : aiText('রোগীর তথ্য সম্পাদনা', 'Edit patient'),
        ),
        actions: [
          AiDoctorLanguageButton(onChanged: () => setState(() {})),
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(aiText('সংরক্ষণ', 'Save')),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Center(
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: cs.primaryContainer,
                        backgroundImage: _photo != null
                            ? FileImage(File(_photo!.path))
                            : widget.patient?.photoPath.isNotEmpty == true &&
                                  File(widget.patient!.photoPath).existsSync()
                            ? FileImage(File(widget.patient!.photoPath))
                            : null,
                        child:
                            _photo == null &&
                                (widget.patient?.photoPath.isEmpty ?? true)
                            ? Icon(
                                Icons.person_outline_rounded,
                                size: 44,
                                color: cs.onPrimaryContainer,
                              )
                            : null,
                      ),
                      Positioned(
                        right: -2,
                        bottom: 0,
                        child: Material(
                          color: cs.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _saving ? null : _pickPhoto,
                            child: Padding(
                              padding: const EdgeInsets.all(9),
                              child: Icon(
                                Icons.camera_alt_outlined,
                                size: 19,
                                color: cs.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _saving ? null : _pickPhoto,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: Text(
                      _photo == null &&
                              (widget.patient?.photoPath.isEmpty ?? true)
                          ? aiText('ছবি যোগ করুন', 'Add photo')
                          : aiText('ছবি পরিবর্তন করুন', 'Change photo'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _sectionTitle(
              context,
              aiText('ব্যক্তিগত তথ্য', 'Personal details'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: _decoration(
                aiText('পুরো নাম', 'Full name'),
                Icons.person_outline,
              ),
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? aiText('রোগীর নাম লিখুন', 'Enter the patient’s name')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _age,
              keyboardType: TextInputType.number,
              decoration: _decoration(
                aiText('বয়স', 'Age'),
                Icons.cake_outlined,
              ).copyWith(suffixText: aiText('বছর', 'years')),
              validator: (value) {
                final age = int.tryParse(value?.trim() ?? '');
                return age == null || age < 0 || age > 130
                    ? aiText('বয়স লিখুন (০–১৩০)', 'Enter age (0–130)')
                    : null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              isExpanded: true,
              decoration: _decoration(
                aiText('লিঙ্গ', 'Gender'),
                Icons.wc_outlined,
              ),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(
                    aiText('উল্লেখ নেই', 'Not specified'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'Female',
                  child: Text(aiText('নারী', 'Female')),
                ),
                DropdownMenuItem(
                  value: 'Male',
                  child: Text(aiText('পুরুষ', 'Male')),
                ),
                DropdownMenuItem(
                  value: 'Other',
                  child: Text(aiText('অন্যান্য', 'Other')),
                ),
              ],
              onChanged: (value) => setState(() => _gender = value ?? ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _relation,
              textCapitalization: TextCapitalization.words,
              decoration:
                  _decoration(
                    aiText('সম্পর্ক', 'Relationship'),
                    Icons.family_restroom_outlined,
                  ).copyWith(
                    hintText: aiText(
                      'যেমন: নিজে, মা-বাবা, সন্তান',
                      'e.g. Self, parent, child',
                    ),
                  ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _bloodGroup,
              isExpanded: true,
              decoration: _decoration(
                aiText('রক্তের গ্রুপ', 'Blood group'),
                Icons.bloodtype_outlined,
              ),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(
                    aiText('উল্লেখ নেই', 'Not specified'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (final group in [
                  'A+',
                  'A-',
                  'B+',
                  'B-',
                  'AB+',
                  'AB-',
                  'O+',
                  'O-',
                ])
                  DropdownMenuItem(value: group, child: Text(group)),
              ],
              onChanged: (value) => setState(() => _bloodGroup = value ?? ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _decoration(
                aiText('ফোন নম্বর', 'Phone number'),
                Icons.phone_outlined,
              ).copyWith(hintText: aiText('ঐচ্ছিক', 'Optional')),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 18, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      aiText(
                        'প্রোফাইলের তথ্য ও ছবি এই ডিভাইসেই থাকে। এআইকে জিজ্ঞেস করলে শুধু প্রাসঙ্গিক স্বাস্থ্যতথ্য শেয়ার করা হয়।',
                        'Profile details and photo stay on this device. '
                            'Only relevant health information is shared when you ask AI.',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(
                _saving
                    ? aiText('সংরক্ষণ হচ্ছে…', 'Saving…')
                    : aiText('রোগীর প্রোফাইল তৈরি করুন', 'Create patient'),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Text(
    title,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w700),
  );

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20),
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary,
        width: 1.5,
      ),
    ),
  );
}
