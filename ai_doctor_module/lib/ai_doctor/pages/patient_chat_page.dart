import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';

import '../ai_service.dart';
import '../db.dart';
import '../localization.dart';
import '../models.dart';
import '../widgets/medicine_sheet.dart';
import '../widgets/patient_profile_sheet.dart';

class AiDoctorChatPage extends StatefulWidget {
  final AiPatient patient;
  final String? initialQuestion;
  final String medicineContext;
  final String medicineName;
  final bool standalone;

  const AiDoctorChatPage({
    super.key,
    required this.patient,
    this.initialQuestion,
  }) : medicineContext = '',
       medicineName = '',
       standalone = false;

  AiDoctorChatPage.forMedicine({
    super.key,
    required this.medicineName,
    required this.medicineContext,
    this.initialQuestion,
  }) : patient = AiPatient(name: medicineName, age: 0),
       standalone = true;

  @override
  State<AiDoctorChatPage> createState() => _AiDoctorChatPageState();
}

class _AiDoctorChatPageState extends State<AiDoctorChatPage> {
  final _ai = AiDoctorService();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _imagePicker = ImagePicker();

  AiDoctor _doctor = aiDoctors.first;
  List<AiChatMessage> _msgs = [];
  int _medCount = 0;
  bool _busy = false;
  String? _pendingImagePath;

  int? get _pid => widget.patient.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!widget.standalone) {
      final current = await AiDoctorDb.i.patient(_pid!);
      if (current == null) {
        if (mounted) Navigator.pop(context, true);
        return;
      }
      final messages = await AiDoctorDb.i.messages(_pid!);
      final meds = await AiDoctorDb.i.meds(_pid!);
      if (!mounted) return;
      setState(() {
        _msgs = messages;
        _medCount = meds.length;
      });
    }
    if (!mounted) return;
    _toEnd();
    final question = widget.initialQuestion?.trim() ?? '';
    if (question.isNotEmpty) await _send(question);
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> _add(String role, String text, {String imagePath = ''}) async {
    final m = AiChatMessage(
      patientId: _pid ?? 0,
      doctorId: _doctor.id,
      role: role,
      text: text,
      imagePath: imagePath,
    );
    if (_pid != null) await AiDoctorDb.i.addMessage(m);
    if (!mounted) return;
    setState(() => _msgs = [..._msgs, m]);
    _toEnd();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final selected = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (selected == null) return;
      final directory = await getApplicationSupportDirectory();
      final imageDirectory = Directory(
        p.join(directory.path, 'ai_doctor', 'chat_images'),
      );
      await imageDirectory.create(recursive: true);
      final extension = p.extension(selected.path).toLowerCase();
      const supportedTypes = {'.jpg', '.jpeg', '.png', '.webp'};
      if (!supportedTypes.contains(extension)) {
        throw FormatException(
          aiText(
            'জেপিইজি, পিএনজি অথবা ওয়েবপি ছবি বেছে নিন।',
            'Choose a JPEG, PNG, or WebP image.',
          ),
        );
      }
      final savedExtension = extension == '.jpeg' ? '.jpg' : extension;
      final destination = p.join(
        imageDirectory.path,
        'chat_${DateTime.now().microsecondsSinceEpoch}$savedExtension',
      );
      final stored = await File(selected.path).copy(destination);
      if (await stored.length() > 5 * 1024 * 1024) {
        await stored.delete();
        throw const FormatException('ছবিটি অনেক বড়। ছোট ছবি বেছে নিন।');
      }
      if (mounted) setState(() => _pendingImagePath = stored.path);
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            aiText(
              'ছবি সংযুক্ত করা যায়নি। আবার চেষ্টা করুন।',
              'Could not attach photo: $error',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _chooseImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(aiText('গ্যালারি থেকে নিন', 'Choose from gallery')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(aiText('ছবি তুলুন', 'Take a photo')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  Future<void> _send(String text, {String? imagePath}) async {
    text = text.trim();
    final attachedImage = imagePath ?? _pendingImagePath;
    if ((text.isEmpty && attachedImage == null) || _busy) return;
    final current = widget.standalone
        ? null
        : await AiDoctorDb.i.patient(_pid!);
    if (!widget.standalone && current == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              aiText(
                'রোগীর প্রোফাইলটি আর পাওয়া যাচ্ছে না।',
                'Patient profile is no longer available.',
              ),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
      return;
    }
    if (text.isEmpty) {
      text = aiText(
        'ছবিতে যা দেখা যাচ্ছে তা বর্ণনা করুন এবং নিরাপদ পরবর্তী পদক্ষেপ জানান।',
        'Describe the visible features in this image and suggest safe next steps.',
      );
    }
    if (attachedImage != null && !_doctor.vision) {
      _doctor = aiDoctors.firstWhere((doctor) => doctor.vision);
    }
    _ctrl.clear();
    if (mounted) setState(() => _pendingImagePath = null);
    final historyBefore = List<AiChatMessage>.from(_msgs);
    await _add('user', text, imagePath: attachedImage ?? '');
    if (aiIsEmergency(text)) {
      await _add(
        'note',
        aiText(
          'এটি জরুরি অবস্থা হতে পারে। এখনই নিকটস্থ হাসপাতালে যান বা স্থানীয় জরুরি সেবায় যোগাযোগ করুন।',
          aiEmergencyNote,
        ),
      );
    }

    setState(() => _busy = true);
    try {
      final conds = widget.standalone
          ? <AiCondition>[]
          : await AiDoctorDb.i.conditions(_pid!);
      final meds = widget.standalone
          ? <AiMedication>[]
          : await AiDoctorDb.i.meds(_pid!);
      final alg = widget.standalone
          ? <AiAllergy>[]
          : await AiDoctorDb.i.allergies(_pid!);
      final system = aiBuildSystemPrompt(
        p: widget.patient,
        doc: _doctor,
        conditions: conds,
        meds: meds,
        allergies: alg,
        medicineContext: widget.medicineContext,
        languageCode: AiDoctorConfig.languageCode,
      );

      final image = attachedImage == null ? null : File(attachedImage);
      final reply = await _ai.reply(
        doc: _doctor,
        system: system,
        history: historyBefore,
        userText: text,
        imageBytes: image == null ? null : await image.readAsBytes(),
        imageMimeType: switch (p.extension(attachedImage ?? '').toLowerCase()) {
          '.png' => 'image/png',
          '.webp' => 'image/webp',
          _ => 'image/jpeg',
        },
      );
      await _add('assistant', reply);

      final hit = aiAllergyHit(reply, alg);
      if (hit != null) {
        await _add(
          'note',
          aiText(
            'নিরাপত্তা: “$hit” রোগীর অ্যালার্জির তালিকায় রয়েছে।',
            'Safety note: "$hit" is listed as a patient allergy.',
          ),
        );
      }
    } on Exception catch (error) {
      await _add(
        'note',
        aiText(
          'উত্তর পাওয়া যায়নি। আবার চেষ্টা করুন।',
          'Could not get a response: $error',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMeds() async {
    final patientId = _pid;
    if (patientId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      builder: (_) => AiMedicineSheet(
        patientId: patientId,
        onNote: (t) => _add('note', t),
        onAsk: (t) {
          Navigator.pop(context);
          _send(t);
        },
      ),
    );
    final meds = await AiDoctorDb.i.meds(patientId);
    if (mounted) setState(() => _medCount = meds.length);
  }

  Future<void> _chooseDoctor() async {
    final doctor = await showModalBottomSheet<AiDoctor>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    aiText('এআই চিকিৎসক বেছে নিন', 'Choose an AI doctor'),
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final doctor in aiDoctors)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: doctor.id == _doctor.id
                                ? colors.primaryContainer.withValues(alpha: .55)
                                : colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => Navigator.pop(context, doctor),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: colors.primaryContainer,
                                      foregroundColor:
                                          colors.onPrimaryContainer,
                                      child: Text(
                                        doctor.initial,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            aiDoctorName(
                                              doctor.id,
                                              doctor.name,
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            aiDoctorRole(
                                              doctor.role,
                                              vision: doctor.vision,
                                              fast: doctor.fast,
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (doctor.id == _doctor.id)
                                      Icon(
                                        Icons.check_circle,
                                        color: colors.primary,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (doctor != null && mounted) setState(() => _doctor = doctor);
  }

  Future<void> _confirmDeletePatient() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(aiText('রোগী মুছবেন?', 'Delete patient?')),
        content: Text(
          aiText(
            '${widget.patient.name} এবং তাঁর স্বাস্থ্যতথ্য, ওষুধ, কাজ ও কথোপকথনের ইতিহাস স্থায়ীভাবে মুছে যাবে।',
            'This will permanently delete ${widget.patient.name} and their '
                'health profile, medications, tasks, and chat history.',
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
    if (confirmed == true && widget.patient.id != null) {
      await AiDoctorDb.i.deletePatient(widget.patient.id!);
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _openProfile() {
    final patientId = _pid;
    if (patientId == null) return Future<void>.value();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      builder: (_) => AiPatientProfileSheet(patientId: patientId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = widget.patient;
    final doctorName = aiDoctorName(_doctor.id, _doctor.name);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.standalone
              ? aiText('ওষুধ নিয়ে এআই-এর সাথে কথা বলুন', 'Medicine AI chat')
              : aiText('এআই স্বাস্থ্য সহায়ক', 'AI health assistant'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          AiDoctorLanguageButton(onChanged: () => setState(() {})),
          if (!widget.standalone)
            PopupMenuButton<String>(
              tooltip: aiText('আরও বিকল্প', 'More options'),
              onSelected: (_) => _confirmDeletePatient(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    aiText('রোগী মুছুন', 'Delete patient'),
                    style: TextStyle(color: cs.error),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: _chooseDoctor,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFFDBE8FC),
                          foregroundColor: const Color(0xFF0C1830),
                          child: Text(
                            _doctor.initial,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 19,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doctorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                aiDoctorRole(
                                  _doctor.role,
                                  vision: _doctor.vision,
                                  fast: _doctor.fast,
                                ),
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: aiText('স্বাস্থ্যতথ্য ও নিরাপত্তা', 'Health profile'),
                          onPressed: _openProfile,
                          icon: Icon(
                            Icons.health_and_safety_outlined,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        IconButton(
                          tooltip: aiText('ওষুধ ও প্রেসক্রিপশন', 'Medications'),
                          onPressed: _openMeds,
                          icon: Badge.count(
                            count: _medCount,
                            isLabelVisible: _medCount > 0,
                            child: Icon(
                              Icons.medication_outlined,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (widget.standalone)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.medication_outlined,
                      size: 16,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.medicineName,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _msgs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 40,
                              color: cs.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.standalone
                                  ? aiText(
                                      '${widget.medicineName} সম্পর্কে কী জানতে চান?',
                                      'What would you like to know about ${widget.medicineName}?',
                                    )
                                  : aiText(
                                      '$p.name সম্পর্কে $doctorName-কে প্রশ্ন করুন',
                                      'Ask $doctorName a question about ${p.name}',
                                    ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _msgs.length + (_busy ? 1 : 0),
                      itemBuilder: (c, i) {
                        if (i == _msgs.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  aiText('উত্তর তৈরি হচ্ছে…', 'Thinking…'),
                                  style: TextStyle(color: cs.outline),
                                ),
                              ],
                            ),
                          );
                        }
                        return TweenAnimationBuilder<double>(
                          key: ValueKey(_msgs[i].id ?? _msgs[i].createdAt),
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          builder: (context, progress, child) => Opacity(
                            opacity: progress,
                            child: Transform.translate(
                              offset: Offset(0, 8 * (1 - progress)),
                              child: child,
                            ),
                          ),
                          child: _MessageView(m: _msgs[i]),
                        );
                      },
                    ),
            ),
            _Composer(
              ctrl: _ctrl,
              busy: _busy,
              imagePath: _pendingImagePath,
              onPickImage: _chooseImage,
              onRemoveImage: () => setState(() => _pendingImagePath = null),
              onSend: () => _send(_ctrl.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  final AiChatMessage m;
  const _MessageView({required this.m});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (m.role == 'note') {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            m.text,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (m.role == 'user') {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFFDBE8FC),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (m.imagePath.isNotEmpty && File(m.imagePath).existsSync())
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      File(m.imagePath),
                      width: 220,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Text(
                m.text,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF0C1830),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final doc = aiDoctors.firstWhere(
      (d) => d.id == m.doctorId,
      orElse: () => aiDoctors.first,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: const Color(0xFFDBE8FC),
                child: Text(
                  doc.initial,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0C1830),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                aiDoctorName(doc.id, doc.name),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: SelectableText(
              m.text,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController ctrl;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final String? imagePath;
  const _Composer({
    required this.ctrl,
    required this.busy,
    required this.onSend,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imagePath != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(imagePath!),
                          width: 88,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: IconButton.filledTonal(
                          onPressed: onRemoveImage,
                          icon: const Icon(Icons.close, size: 16),
                          constraints: const BoxConstraints.tightFor(
                            width: 28,
                            height: 28,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: .85),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: .6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: .04),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: aiText('ছবি যোগ করুন', 'Attach a photo'),
                    onPressed: busy ? null : onPickImage,
                    icon: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: cs.onSurfaceVariant,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: .8),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: TextField(
                        controller: ctrl,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        decoration: InputDecoration(
                          hintText: aiText(
                            'আপনার প্রশ্ন লিখুন…',
                            'Write your question…',
                          ),
                          hintStyle: TextStyle(
                            color: cs.outline,
                            fontSize: 14.5,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: IconButton.filled(
                      onPressed: busy ? null : onSend,
                      icon: Icon(
                        busy
                            ? Icons.hourglass_top_rounded
                            : Icons.arrow_upward_rounded,
                        size: 22,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF1D64F2),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              imagePath == null
                  ? aiText(
                      'এআই-এর পরামর্শ চিকিৎসকের সেবার বিকল্প নয়।',
                      aiDisclaimer,
                    )
                  : aiText(
                      'ছবিটি নির্বাচিত এআই সেবায় পাঠানো হবে। $aiDisclaimer',
                      'Photo will be sent to the configured AI provider. $aiDisclaimer',
                    ),
              style: TextStyle(
                fontSize: 11.5,
                color: cs.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
