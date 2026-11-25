// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../core/app_config.dart';
import '../core/assistant_diseases.dart';
import '../core/assistant_triage.dart';
import '../core/json_utils.dart' show stripHtml;
import '../data/ai_dao.dart';
import '../models/medicine.dart';
import '../services/assistant_knowledge.dart';
import '../services/oxion_assistant.dart';

/// A file the patient attached to a bubble (image / voice note). Persisted
/// with the message so reopening a chat still shows the thumbnails.
class ChatAttachment {
  const ChatAttachment({
    required this.kind,
    required this.path,
    required this.name,
  });

  final String kind; // 'image' | 'audio'
  final String path;
  final String name;

  bool get isImage => kind == 'image';

  Map<String, dynamic> toJson() => {'kind': kind, 'path': path, 'name': name};

  static ChatAttachment? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = (raw['kind'] as String? ?? '').trim();
    if (kind != 'image' && kind != 'audio') return null;
    return ChatAttachment(
      kind: kind,
      path: raw['path'] as String? ?? '',
      name: raw['name'] as String? ?? '',
    );
  }

  static List<ChatAttachment> decode(String? jsonText) {
    if (jsonText == null || jsonText.isEmpty) return const [];
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! List) return const [];
      return [for (final item in decoded) ?fromJson(item)];
    } catch (_) {
      return const [];
    }
  }

  static String? encode(List<ChatAttachment> attachments) {
    if (attachments.isEmpty) return null;
    return jsonEncode([for (final a in attachments) a.toJson()]);
  }
}

/// One chat bubble. [fromModel] marks whether the text was phrased by the
/// cloud LLM (true) or assembled deterministically from our data (false).
class ChatTurn {
  const ChatTurn({
    required this.role,
    required this.text,
    this.medicines = const [],
    this.fromModel = false,
    this.attachments = const [],
  });

  final String role; // 'user' | 'assistant'
  final String text;
  final List<Medicine> medicines;
  final bool fromModel;
  final List<ChatAttachment> attachments;

  bool get isUser => role == 'user';
}

/// A picked file waiting to be sent with the next message.
class PendingAttachment {
  const PendingAttachment({
    required this.kind,
    required this.name,
    required this.mimeType,
    required this.bytes,
    this.path,
  });

  final AssistantMediaKind kind;
  final String name;
  final String mimeType;
  final Uint8List bytes;
  final String? path;

  bool get isImage => kind == AssistantMediaKind.image;

  AssistantMedia toMedia() => AssistantMedia(
    kind: kind,
    bytes: bytes,
    mimeType: mimeType,
    fileName: name,
  );

  ChatAttachment toChatAttachment() => ChatAttachment(
    kind: isImage ? 'image' : 'audio',
    path: path ?? '',
    name: name,
  );
}

/// One stored chat thread shown in the conversations picker.
class ChatSession {
  const ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final int messages;
  final DateTime updatedAt;
}

class AssistantController extends GetxController {
  AssistantController(this._knowledge, this._assistant, this._aiDao);

  final AssistantKnowledge _knowledge;
  final OxionAssistant _assistant;
  final AiDao _aiDao;
  final ImagePicker _images = ImagePicker();

  final RxList<ChatTurn> messages = <ChatTurn>[].obs;
  final RxString draft = ''.obs;
  final RxList<String> suggestions = <String>[].obs;
  final RxBool thinking = false.obs;
  final RxBool modelActive = false.obs;

  // --- model catalogue & live switching (proxied straight from the
  // service, so both stay the same reactive instance across model changes) ---
  RxList<String> get availableModels => _assistant.models;
  RxString get selectedModel => _assistant.selectedModel;
  final RxBool modelsLoading = false.obs;
  final RxString modelsError = ''.obs;

  // --- multiple chat sessions ---
  final RxList<ChatSession> sessions = <ChatSession>[].obs;
  final RxInt activeConversationId = 0.obs;

  // --- multimodal input: files waiting to ride the next message ---
  final RxList<PendingAttachment> pending = <PendingAttachment>[].obs;
  final RxBool attaching = false.obs;

  // --- live mic recording for voice notes (chat input bar) ---
  // Built lazily: the plugin's constructor already talks to a platform
  // channel, which plain widget/unit tests cannot serve.
  AudioRecorder? _recorder;
  final RxBool recording = false.obs;
  final RxInt recordSeconds = 0.obs;
  Timer? _recordTicker;

  // --- symptom-interview (triage) state, mirrored for the telemedicine UI ---
  TriagePlan? _plan;
  List<String> _questions = const [];
  int _questionIndex = 0;
  int _followUpsInserted = 0;
  int _safetyRepairs = 0;
  final Map<String, String> _answers = {};
  final Set<TriageSlot> _answeredSlots = {};
  String _caseQuery = '';
  final List<AssistantMedia> _heldMedia = [];

  final RxBool interviewActive = false.obs;
  final RxString interviewTopic = ''.obs;
  final RxString currentQuestion = ''.obs;
  final RxInt questionNumber = 0.obs;
  final RxInt questionTotal = 0.obs;
  final RxDouble confidence = 0.0.obs;
  final RxList<String> quickReplies = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    // The assistant's model state is exposed via getters above — no copying,
    // so a model switch is visible everywhere instantly with no re-init.
    unawaited(
      _restore().catchError((Object error) {
        debugPrint('Assistant restore failed: $error');
      }),
    );
    loadModels();
  }

  /// Pulls the account's model list so the picker can offer every model.
  /// The currently selected (default) model keeps answering even if this
  /// fails — the catalogue is only for choosing, not for use.
  Future<void> loadModels() async {
    if (modelsLoading.value) return;
    modelsLoading.value = true;
    modelsError.value = '';
    try {
      await _assistant.refreshModels();
    } on AssistantUnavailable catch (error) {
      modelsError.value = error.message;
    } finally {
      modelsLoading.value = false;
    }
  }

  /// Switches the answer model instantly; the next reply simply uses it.
  void selectModel(String model) => _assistant.setModel(model);

  /// Prefills a starter question when the assistant is opened from a medicine
  /// or lesson profile. Safe to call on every view open (the controller is a
  /// permanent singleton, so this is not handled in [onInit]).
  void applySeed(String? seed) {
    final value = seed?.trim() ?? '';
    if (value.isNotEmpty) draft.value = _seedQuestion(value);
  }

  String _seedQuestion(String seed) {
    final compact = seed.replaceAll(RegExp(r'\s+'), ' ').trim();
    final clipped = compact.length <= 240
        ? compact
        : '${compact.substring(0, 240)}…';
    return 'এই তথ্যের ভিত্তিতে সহজ বাংলায় বুঝিয়ে বলো: $clipped';
  }

  // ------------------------------------------------------------- attachments

  /// Picks a photo (camera on native, file dialog on web/desktop) and queues
  /// it as the multimodal "visual symptom" input for the next message.
  Future<void> pickImage({bool fromCamera = false}) async {
    if (attaching.value) return;
    if (!_checkRoom()) return;
    attaching.value = true;
    try {
      final file = await _images.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      _addPending(
        kind: AssistantMediaKind.image,
        name: file.name,
        mimeType: _imageMime(file.name),
        bytes: bytes,
        path: kIsWeb ? null : file.path,
      );
    } catch (error) {
      _attachNotice('ছবি যোগ করা যায়নি। (${_short(error)})');
    } finally {
      attaching.value = false;
    }
  }

  /// Picks a voice note / audio file for the consultation.
  Future<void> pickAudio() async {
    if (attaching.value) return;
    if (!_checkRoom()) return;
    attaching.value = true;
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'ভয়েস নোট / অডিও ফাইল বেছে নিন',
        type: FileType.audio,
      );
      final picked = files.firstOrNull;
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      _addPending(
        kind: AssistantMediaKind.audio,
        name: picked.name,
        mimeType: _audioMime(picked.name),
        bytes: bytes,
        path: picked.path,
      );
    } catch (error) {
      _attachNotice('ভয়েস নোট যোগ করা যায়নি। (${_short(error)})');
    } finally {
      attaching.value = false;
    }
  }

  /// Paperclip button: documents, images and any other readable file.
  /// Each pick is routed by extension — pictures and audio ride as real
  /// multimodal attachments, plain-text files are quoted into the message.
  Future<void> pickFiles() async {
    if (attaching.value) return;
    attaching.value = true;
    try {
      final pickedFiles = await FilePicker.pickFiles(
        dialogTitle: 'ছবি, ভয়েস নোট বা ডকুমেন্ট পাঠান',
        type: FileType.custom,
        allowedExtensions: [
          ...AppConfig.assistantImageExtensions,
          ...AppConfig.assistantAudioExtensions,
          ...AppConfig.assistantTextExtensions,
        ],
      );
      for (final picked in pickedFiles) {
        if (!_checkRoom()) break;
        try {
          final bytes = await picked.readAsBytes();
          switch (attachmentKindOf(picked.name)) {
            case 'image':
              _addPending(
                kind: AssistantMediaKind.image,
                name: picked.name,
                mimeType: _imageMime(picked.name),
                bytes: bytes,
                path: kIsWeb ? null : picked.path,
              );
            case 'audio':
              _addPending(
                kind: AssistantMediaKind.audio,
                name: picked.name,
                mimeType: _audioMime(picked.name),
                bytes: bytes,
                path: kIsWeb ? null : picked.path,
              );
            case 'text':
              _embedTextFile(picked.name, utf8.decode(bytes));
            default:
              _attachNotice(
                '“${picked.name}”—এই ধরনের ফাইল মডেল এখনো পড়তে পারে '
                'না; ছবি, অডিও বা টেক্সট (txt/csv) ফাইল পাঠান।',
              );
          }
        } catch (error) {
          _attachNotice('ফাইলটি পড়া যায়নি: ${picked.name}');
        }
      }
    } catch (error) {
      _attachNotice('ফাইল সংযোগ করা যায়নি। (${_short(error)})');
    } finally {
      attaching.value = false;
    }
  }

  /// Classifies an attached file by extension so the picker can route it.
  static String attachmentKindOf(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (AppConfig.assistantImageExtensions.contains(ext)) return 'image';
    if (AppConfig.assistantAudioExtensions.contains(ext)) return 'audio';
    if (AppConfig.assistantTextExtensions.contains(ext)) return 'text';
    return 'other';
  }

  /// Quotes a plain-text document into the draft so the doctor reads it as
  /// part of the next message (preserving anything already typed).
  void _embedTextFile(String name, String content) {
    final body = content.replaceAll('\r', '').trim();
    if (body.isEmpty) {
      _attachNotice('“$name” ফাইলটি খালি।');
      return;
    }
    final clipped = body.length <= AppConfig.assistantMaxTextFileChars
        ? body
        : '${body.substring(0, AppConfig.assistantMaxTextFileChars)}…';
    final quote = 'ফাইল ($name):\n"""\n$clipped\n"""';
    final current = draft.value.trim();
    draft.value = current.isEmpty ? quote : '$current\n\n$quote';
    _attachNotice('“$name” পড়া হয়েছে—দরকার হলে আরও লিখে পাঠান।');
  }

  // ------------------------------------------------------------- voice notes

  /// Mic button: first tap starts recording, the second tap stops and sends
  /// the voice note straight to the doctor.
  Future<void> toggleRecording() async {
    if (recording.value) {
      await _stopRecording();
      return;
    }
    if (kIsWeb) {
      _attachNotice(
        'এই প্ল্যাটফর্মে রেকর্ডিং এখনো চলে না—মেনু থেকে অডিও ফাইল '
        'সংযোগ করুন।',
      );
      return;
    }
    if (!_checkRoom()) return;
    try {
      final recorder = _recorder ??= AudioRecorder();
      if (!await recorder.hasPermission()) {
        _attachNotice('মাইকের অনুমতি দেওয়া হয়নি—সেটিংস থেকে চালু করুন।');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 96000,
          sampleRate: 44100,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );
      recording.value = true;
      recordSeconds.value = 0;
      _recordTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
        recordSeconds.value = timer.tick;
        if (timer.tick >= AppConfig.assistantMaxVoiceSeconds) {
          unawaited(_stopRecording());
        }
      });
    } catch (error) {
      recording.value = false;
      _attachNotice('মাইক চালু করা যায়নি। (${_short(error)})');
    }
  }

  Future<void> _stopRecording() async {
    _recordTicker?.cancel();
    _recordTicker = null;
    recording.value = false;
    final recorder = _recorder;
    if (recorder == null) return;
    final seconds = recordSeconds.value;
    try {
      final path = await recorder.stop();
      if (path == null) return;
      if (seconds < 1) {
        _attachNotice('রেকর্ডিং অনেক ছোট—অন্তত এক সেকেন্ড কথা বলুন।');
        return;
      }
      final bytes = await File(path).readAsBytes();
      _addPending(
        kind: AssistantMediaKind.audio,
        name: 'ভয়েস-নোট-${seconds}s.m4a',
        mimeType: 'audio/mp4',
        bytes: bytes,
        path: path,
      );
      // The recorded note goes straight to the doctor—no extra tap needed.
      await send();
    } catch (error) {
      _attachNotice('ভয়েস নোটটি পাওয়া যায়নি। (${_short(error)})');
    }
  }

  @override
  void onClose() {
    _recordTicker?.cancel();
    final recorder = _recorder;
    if (recorder != null) unawaited(recorder.dispose());
    super.onClose();
  }

  void removePending(int index) {
    if (index >= 0 && index < pending.length) pending.removeAt(index);
  }

  bool _checkRoom() {
    if (pending.length >= AppConfig.assistantMaxAttachments) {
      _attachNotice(
        'একবারে সর্বোচ্চ ${AppConfig.assistantMaxAttachments}টি ফাইল যোগ করা যাবে।',
      );
      return false;
    }
    return true;
  }

  void _addPending({
    required AssistantMediaKind kind,
    required String name,
    required String mimeType,
    required Uint8List bytes,
    String? path,
  }) {
    if (bytes.isEmpty) {
      _attachNotice('ফাইলটি খালি—আবার চেষ্টা করুন।');
      return;
    }
    if (bytes.length > AppConfig.assistantMaxAttachmentBytes) {
      final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      _attachNotice('ফাইল অনেক বড় ($mb MB)। ছোট ফাইল পাঠান।');
      return;
    }
    pending.add(
      PendingAttachment(
        kind: kind,
        name: name,
        mimeType: mimeType,
        bytes: bytes,
        path: path,
      ),
    );
  }

  void _attachNotice(String message) {
    Get.snackbar('সংযোগ', message, snackPosition: SnackPosition.BOTTOM);
  }

  static String _imageMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  static String _audioMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.ogg') || lower.endsWith('.opus')) return 'audio/ogg';
    if (lower.endsWith('.webm')) return 'audio/webm';
    return 'audio/wav';
  }

  static String _short(Object error) {
    final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= 80 ? text : '${text.substring(0, 80)}…';
  }

  // ---------------------------------------------------------------- sessions

  Future<void> _restore() async {
    await _loadSessions();
    final id = await _aiDao.ensureLatestConversation();
    activeConversationId.value = id;
    await _loadMessages(id);
  }

  Future<void> _loadSessions() async {
    final rows = await _aiDao.conversations();
    sessions.assignAll(
      rows.map(
        (row) => ChatSession(
          id: row['id'] as int,
          title: (row['title'] as String?) ?? AiDao.defaultTitle,
          messages: (row['messages'] as int?) ?? 0,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (row['updated_at'] as int?) ?? 0,
          ),
        ),
      ),
    );
  }

  Future<void> _loadMessages(int conversationId) async {
    final rows = await _aiDao.messagesFor(conversationId, limit: 60);
    final turns = rows.reversed
        .map(
          (row) => ChatTurn(
            role: (row['role'] as String?) ?? 'user',
            text: (row['content'] as String?) ?? '',
            attachments: ChatAttachment.decode(row['attachments'] as String?),
          ),
        )
        .where((turn) => turn.text.isNotEmpty)
        .toList();
    messages.assignAll(turns);
  }

  /// Starts a fresh chat; the previous thread stays in the history list.
  Future<void> newChat() async {
    // Never stack up empty threads: reuse the active one if untouched.
    final active = activeConversationId.value;
    if (active != 0) {
      final existing = await _aiDao.messagesFor(active, limit: 1);
      if (existing.isEmpty) return;
    }
    _resetInterview();
    final id = await _aiDao.createConversation(AiDao.defaultTitle);
    activeConversationId.value = id;
    messages.clear();
    await _loadSessions();
  }

  Future<void> openChat(int id) async {
    if (id == activeConversationId.value) return;
    _resetInterview();
    activeConversationId.value = id;
    messages.clear();
    await _loadMessages(id);
  }

  Future<void> deleteChat(int id) async {
    await _aiDao.deleteConversation(id);
    if (id == activeConversationId.value) {
      _resetInterview();
      final next = await _aiDao.ensureLatestConversation();
      activeConversationId.value = next;
      await _loadMessages(next);
    }
    await _loadSessions();
  }

  // ------------------------------------------------------------------ chat

  /// Live autocomplete: disease titles plus, when a condition is recognised,
  /// its mapped medicines surfaced as chips.
  Future<void> suggest(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      suggestions.clear();
      return;
    }
    final diseases = await _knowledge.suggestDiseases(trimmed);
    suggestions.assignAll(diseases.take(6));
  }

  /// Tapping a suggestion chip fills the input and sends it.
  Future<void> ask(String text) async {
    // While the doctor is still writing, chips do nothing rather than swap a
    // typed answer out of the composer for a message that cannot be sent.
    if (thinking.value) return;
    draft.value = text;
    await send();
  }

  /// Answering the doctor's current interview question with a quick-reply
  /// chip. Anything already typed is kept and sent along with it — the
  /// patient's own words are never dropped in favour of a tap.
  Future<void> answerQuickly(String text) async {
    if (thinking.value) return;
    final typed = draft.value.trim();
    draft.value = typed.isEmpty || typed == text ? text : '$typed $text';
    await send();
  }

  /// Sends the draft plus any attached files.
  ///
  /// Returns true only when the message was accepted, so the composer can
  /// keep the patient's text (instead of wiping it) when a reply is still in
  /// flight — a typed answer must never be lost because the doctor is busy.
  Future<bool> send() async {
    final query = draft.value.trim();
    if (thinking.value) return false;
    if (query.isEmpty && pending.isEmpty) return false;
    var conversationId = activeConversationId.value;
    if (conversationId == 0) {
      conversationId = await _aiDao.ensureLatestConversation();
      activeConversationId.value = conversationId;
    }

    final media = [for (final item in pending) item.toMedia()];
    final metas = [for (final item in pending) item.toChatAttachment()];
    pending.clear();

    // Media-only message while the interview is running: the doctor
    // acknowledges the photo/voice note without counting it as an answer.
    if (_plan != null && query.isEmpty) {
      final note = ChatTurn(
        role: 'user',
        text: metas.map((a) => a.name).join(', '),
        attachments: metas,
      );
      messages.add(note);
      draft.value = '';
      thinking.value = true;
      try {
        await _aiDao.addMessage(
          conversationId,
          'user',
          note.text,
          attachmentsJson: ChatAttachment.encode(metas),
        );
        _heldMedia.addAll(media);
        final ack = ChatTurn(
          role: 'assistant',
          text:
              'সংযোগটা পেয়েছি। ছবি/ভয়েস নোটের বিষয়ও বিবেচনা করব—তবে '
              'প্রথমে চলতি প্রশ্নের উত্তরটা দিন।',
        );
        messages.add(ack);
        await _aiDao.addMessage(conversationId, 'assistant', ack.text);
        await _loadSessions();
      } finally {
        thinking.value = false;
      }
      return true;
    }

    messages.add(
      ChatTurn(
        role: 'user',
        text: query.isEmpty ? 'সংযুক্ত ছবি/ভয়েস নোট' : query,
        attachments: metas,
      ),
    );
    // A media-only message outside an interview: ask the doctor to read the
    // attachment itself and describe what it shows.
    final prompt = query.isNotEmpty
        ? query
        : 'এই সংযোগটি (ছবি/ভয়েস নোট) দেখে-শুনে বলুন—রোগীর কী সমস্যা মনে '
              'হচ্ছে, কী করা উচিত, আর কখন দ্রুত ডাক্তার দেখানো দরকার। '
              'নিশ্চিত হতে কয়েকটি প্রশ্নও করতে পারেন।';
    draft.value = '';
    suggestions.clear();
    thinking.value = true;
    final before = messages.length;
    try {
      await _aiDao.autoTitle(conversationId, messages[before - 1].text);
      await _aiDao.addMessage(
        conversationId,
        'user',
        messages[before - 1].text,
        attachmentsJson: ChatAttachment.encode(metas),
      );
      if (_plan != null) {
        // Any media sent mid-interview is held for the final assessment.
        _heldMedia.addAll(media);
        await _advanceInterview(query);
      } else if (query.isEmpty) {
        // Media-only: let the vision-capable model read the photo/voice note
        // right away instead of pattern-matching the placeholder text.
        await _directAnswer(prompt, media: media);
      } else {
        await _startOrAnswer(query, media);
      }
      // Persist every assistant bubble the turn produced (the doctor may
      // send a closing line and the treatment plan as separate messages).
      for (final turn in messages.skip(before)) {
        await _aiDao.addMessage(conversationId, 'assistant', turn.text);
      }
      await _loadSessions();
    } finally {
      thinking.value = false;
    }
    return true;
  }

  /// A fresh message with no interview running: handles greetings, pleasantries,
  /// recognized clinical complaints, medicine/dosage inquiries, or general questions.
  Future<void> _startOrAnswer(String query, List<AssistantMedia> media) async {
    final trimmed = query.trim();

    // 1. Pure greeting: greet back warmly and prompt for their issue
    if (isGreetingQuery(trimmed)) {
      await _greetingAnswer(trimmed);
      return;
    }

    // 2. Pure gratitude or farewell
    if (isGratitudeOrFarewell(trimmed)) {
      await _farewellAnswer(trimmed);
      return;
    }

    // 3. Medicine details or dosage query:
    if (isMedicineOrDoseQuery(trimmed)) {
      await _medicineAnswer(trimmed, media: media);
      return;
    }

    // 4. Matched condition: start doctor triage interview (concise 2-3 questions)
    final entry = findEntry(query);
    final plan = entry == null ? null : planFor(entry, query);
    if (plan != null && plan.questions.isNotEmpty) {
      _beginInterview(plan, query, media);
      return;
    }

    // 5. Looks like symptoms:
    if (looksLikeSymptoms(query)) {
      _beginInterview(generalPlan(query), query, media);
      return;
    }

    // 6. Direct medicine/informational inquiry
    await _directAnswer(query, media: media);
  }

  /// Answers direct questions about a medicine's identity, indication, and
  /// tiered dosing ladder (initial, standard, and ceiling dosage).
  Future<void> _medicineAnswer(
    String query, {
    List<AssistantMedia> media = const [],
  }) async {
    final context = await _knowledge.buildContext(query);
    final medicines = await _knowledge.medicinesFor(query, cap: 6);
    final history = _transcript(dropLast: 1);
    var answered = false;
    try {
      final text = await _assistant.reply(
        query: query,
        context: context,
        history: history,
        media: media,
        mode: AssistantReplyMode.medicineDetail,
      );
      modelActive.value = _assistant.ready;
      messages.add(
        ChatTurn(
          role: 'assistant',
          text: text,
          medicines: medicines,
          fromModel: true,
        ),
      );
      answered = true;
    } on AssistantUnavailable {
      modelActive.value = false;
    }
    if (!answered) {
      final fallback = await _knowledgeAnswer(query, medicines);
      messages.add(
        ChatTurn(role: 'assistant', text: fallback, medicines: medicines),
      );
    }
  }

  Future<void> _greetingAnswer(String query) async {
    try {
      final text = await _assistant.reply(
        query: query,
        context:
            'রোগী কেবল আপনাকে কুশল বিনিময় বা সালাম জানিয়েছেন। কোনো সাধারণ পথ্য বা ওষুধ বা বিশ্রামের উপদেশ চাপিয়ে না দিয়ে, '
            'একজন অভিজ্ঞ ও সহানুভূতিশীল বাংলাদেশি চিকিৎসকের মতো সালাম/হ্যালোর আন্তরিক উত্তর দিন এবং '
            'রোগীর কী শারীরিক সমস্যা বা অসুবিধা হচ্ছে তা যত্নসহকারে জানতে চান।',
        history: _transcript(dropLast: 1),
        mode: AssistantReplyMode.consult,
      );
      modelActive.value = _assistant.ready;
      messages.add(
        ChatTurn(role: 'assistant', text: text, fromModel: true),
      );
    } catch (_) {
      messages.add(
        const ChatTurn(
          role: 'assistant',
          text:
              'হ্যালো! আসসালামু আলাইকুম। আমি ডা. ফার্মাপাথ, আপনার এআই চিকিৎসক। '
              'আপনি কেমন আছেন? আপনার কী শারীরিক সমস্যা বা লক্ষণ দেখা দিচ্ছে বলুন—'
              'আমি শুনে প্রয়োজনীয় পরামর্শ ও সঠিক দিকনির্দেশনা দিচ্ছি।',
        ),
      );
    }
  }

  Future<void> _farewellAnswer(String query) async {
    try {
      final text = await _assistant.reply(
        query: query,
        context:
            'রোগী আপনাকে ধন্যবাদ বা বিদায় জানিয়েছেন। একজন চিকিৎসকের মতো আন্তরিকভাবে '
            'ধন্যবাদ গ্রহণ করুন এবং তার সুস্থতা কামনা করুন।',
        history: _transcript(dropLast: 1),
        mode: AssistantReplyMode.consult,
      );
      modelActive.value = _assistant.ready;
      messages.add(
        ChatTurn(role: 'assistant', text: text, fromModel: true),
      );
    } catch (_) {
      messages.add(
        const ChatTurn(
          role: 'assistant',
          text:
              'আপনাকে অনেক ধন্যবাদ! সুস্থ থাকুন এবং নিজের যত্ন নিন। যেকোনো স্বাস্থ্য সমস্যায় আমি সবসময় পাশে আছি।',
        ),
      );
    }
  }

  void _beginInterview(
    TriagePlan plan,
    String query,
    List<AssistantMedia> media,
  ) {
    _plan = plan;
    _questions = [...plan.questions];
    _questionIndex = 0;
    _followUpsInserted = 0;
    _safetyRepairs = 0;
    _answers.clear();
    _answeredSlots.clear();
    _caseQuery = query;
    _heldMedia
      ..clear()
      ..addAll(media);
    interviewTopic.value = plan.labelBn;
    final mediaNote = media.isEmpty
        ? ''
        : 'আপনার পাঠানো ছবি/ভয়েস নোটও আমি মূল্যায়নে রাখব।\n\n';
    // The opening line repeats the complaint back before the first question.
    messages.add(
      ChatTurn(
        role: 'assistant',
        text:
            '$mediaNote${openingAcknowledgement(query)}\n\n'
            '${interviewGreeting(plan)}',
      ),
    );
    _updateInterviewUi();
  }

  /// Records the answer to the current question — the doctor then *reads* it
  /// (see [_doctorReadsAnswer]) and acknowledges it before the next question —
  /// probes dynamically when the answer hides a red flag, a filler-only reply
  /// or a dodge, and only finishes once every clinical slot the script asks
  /// for is genuinely on record (or once an early finish still covers every
  /// safety critical slot).
  Future<void> _advanceInterview(String answer) async {
    final question = _questions[_questionIndex];
    _answers[question] = answer;
    // A dodge or a one-word filler leaves the detail missing: a slot is only
    // credited when the patient actually answered it.
    if (!isDodging(answer) && !isVagueAnswer(question, answer)) {
      _answeredSlots.add(slotOf(question));
    }
    final answeredCount = _answers.length;

    var nextPreface = '';
    if (wantsFinish(answer)) {
      if (answeredCount >= kMinAnswersBeforeFinish && _missingSafety.isEmpty) {
        await _finalizeInterview(fullyConfident: _slotCoverage >= 1.0);
        return;
      }
      if (answeredCount >= kMinAnswersBeforeFinish) {
        // A hurried patient still cannot leave without the safety basics, and
        // the doctor must not re-ask what the script already holds: the
        // unanswered safety questions move to the front of what is left.
        final wanted = _safetyQuestions();
        final ahead = _questions.sublist(_questionIndex + 1);
        final missing = <String>[
          for (final q in wanted)
            if (ahead.contains(q) || !_questions.contains(q)) q,
        ];
        if (missing.isNotEmpty) {
          final rest = [
            for (final q in ahead)
              if (!missing.contains(q)) q,
          ];
          _questions.replaceRange(_questionIndex + 1, _questions.length, [
            ...missing,
            ...rest,
          ]);
          nextPreface =
              'তাড়াহুড়ো বুঝতে পারছি। নিরাপদ পরামর্শ দিতে আগে এই তথ্যটুকু '
              'জানাটা জরুরি:\n\n';
        }
      }
    } else if (_followUpsInserted < 4) {
      final probe = followUpFor(question, answer);
      if (probe != null && probe != question && !_questions.contains(probe)) {
        _questions.insert(_questionIndex + 1, probe);
        _followUpsInserted++;
      }
    }

    if (_questionIndex + 1 < _questions.length) {
      await _askNextQuestion(question, answer, preface: nextPreface);
      return;
    }
    // The script is spent. A doctor still cannot prescribe without the safety
    // basics, so a dodged or filler-only urgency/age/risk answer gets those
    // questions asked once more before any plan is written.
    if (_safetyRepairs < 1 &&
        _missingSafety.isNotEmpty &&
        answeredCount >= kMinAnswersBeforeFinish) {
      _safetyRepairs++;
      _questions.addAll(_safetyQuestions());
      await _askNextQuestion(
        question,
        answer,
        preface: 'শেষ এই তথ্যটুকু না জেনে ঔষধের পরামর্শ দিতে পারব না:\n\n',
      );
      return;
    }
    await _finalizeInterview(
      fullyConfident: _missingSafety.isEmpty && _slotCoverage >= 1.0,
    );
  }

  /// Safety slots still without a genuine answer.
  List<TriageSlot> get _missingSafety => missingSafetySlots(_answeredSlots);

  /// The catalogue questions covering the safety slots still unanswered.
  List<String> _safetyQuestions() => [
    for (final slot in _missingSafety) ?safetyQuestionFor(slot),
  ];

  /// Delivers the next scripted question, after letting the model read the
  /// answer that just arrived.
  Future<void> _askNextQuestion(
    String question,
    String answer, {
    required String preface,
  }) async {
    // The reply cannot just be the next scripted question: the model reads
    // this answer first, acknowledges it in the patient's own terms, and
    // only then asks the next question — which is appended verbatim if the
    // model forgot it or paraphrased it away (see [withScriptedQuestion]).
    final read = await _doctorReadsAnswer(
      question: question,
      answer: answer,
      nextQuestion: _questions[_questionIndex + 1],
    );
    _questionIndex++;
    messages.add(ChatTurn(role: 'assistant', text: preface + read));
    _updateInterviewUi();
  }

  /// The doctor's turn after hearing [answer]: the model reads the answer and
  /// acknowledges it in its own words, then the next scripted question is
  /// delivered. Falls back to [acknowledgeAnswer] when the cloud is away, so
  /// the interview keeps its clinical rhythm offline too.
  Future<String> _doctorReadsAnswer({
    required String question,
    required String answer,
    required String nextQuestion,
  }) async {
    try {
      final text = await _assistant.reply(
        query: answer,
        context: _interviewBrief(
          question: question,
          answer: answer,
          nextQuestion: nextQuestion,
        ),
        // Everything before this answer: the greeting, the questions already
        // asked and the patient's earlier replies.
        history: _windowForAnswer(answer, question),
        mode: AssistantReplyMode.interview,
        scriptedQuestion: nextQuestion,
      );
      modelActive.value = _assistant.ready;
      // A reply that slid past what the patient just typed is repaired here:
      // the acknowledgement is guaranteed, then the scripted question.
      final read = withAnswerAcknowledgement(
        text: text,
        question: question,
        answer: answer,
      );
      return withScriptedQuestion(read, nextQuestion);
    } on AssistantUnavailable {
      modelActive.value = false;
      return acknowledgeAnswer(
        question: question,
        answer: answer,
        nextQuestion: nextQuestion,
      );
    }
  }

  /// The window this turn's request must carry: the whole thread up to (but not
  /// including) the answer that goes out as the new message, and it always ends
  /// on the doctor's question the answer responds to. A typed answer therefore
  /// reaches the model exactly once, and the question it belongs to can never
  /// be missing from the context.
  List<({String role, String text})> _windowForAnswer(
    String answer,
    String question,
  ) {
    final turns = _transcript(dropLast: 1);
    if (turns.isNotEmpty &&
        turns.last.role == 'user' &&
        turns.last.text == answer.trim()) {
      turns.removeLast(); // already the outgoing message — never sent twice
    }
    if (turns.isEmpty || turns.last.role != 'assistant') {
      turns.add((role: 'assistant', text: question));
    }
    return turns;
  }

  /// Grounding for one mid-interview turn: the complaint the interview started
  /// from, the question just answered, that answer in the patient's own words,
  /// what has already been collected and the exact question that must come
  /// next.
  String _interviewBrief({
    required String question,
    required String answer,
    required String nextQuestion,
  }) {
    final buffer = StringBuffer()
      ..writeln('=== চলমান সাক্ষাৎকার ===')
      ..writeln('বিষয়: ${interviewTopic.value}')
      ..writeln('রোগীর অভিযোগ: $_caseQuery')
      ..writeln('প্রশ্ন ${_questionIndex + 1}/${_questions.length}')
      ..writeln('ডাক্তারের শেষ প্রশ্ন: $question')
      ..writeln('রোগীর উত্তর: $answer');
    final earlier = [
      for (final entry in _answers.entries)
        if (entry.key != question) '• ${entry.key} → ${entry.value}',
    ];
    if (earlier.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('আগের উত্তর:')
        ..writeln(earlier.join('\n'));
    }
    buffer
      ..writeln()
      ..writeln('এখন হুবহু যে প্রশ্নটি করতে হবে:')
      ..writeln(nextQuestion);
    return buffer.toString();
  }

  // ---------------------------------------------------- conversation window

  /// The turns the model must read before answering, oldest first.
  ///
  /// Every request — interview turn, treatment plan, direct answer — is built
  /// here, so an answer the patient typed can never be dropped: the window
  /// always ends with the freshest exchange. [dropLast] leaves out trailing
  /// turns that are being sent as the new user message, and the window is
  /// capped so a long consultation still fits the context budget.
  List<({String role, String text})> _transcript({int dropLast = 0}) {
    final end = (messages.length - dropLast).clamp(0, messages.length);
    final turns = <({String role, String text})>[
      for (final turn in messages.take(end))
        if (turn.text.trim().isNotEmpty)
          (role: turn.role, text: turn.text.trim()),
    ];
    if (turns.length <= AppConfig.assistantHistoryTurns) return turns;
    return turns.sublist(turns.length - AppConfig.assistantHistoryTurns);
  }

  /// Makes sure the scripted clinical question actually reaches the patient:
  /// a paraphrase is left as the model phrased it, and anything else gets the
  /// scripted question appended unchanged — so the interview can never skip a
  /// safety question, and never asks the same one twice in a row.
  static String withScriptedQuestion(String text, String question) {
    final body = text.trim();
    final asked = question.trim();
    if (asked.isEmpty) return body;
    if (body.isEmpty) return asked;
    if (body.contains(asked) || asksAbout(body, asked)) return body;
    return '$body\n\n$asked';
  }

  void _updateInterviewUi() {
    if (_plan == null) {
      interviewActive.value = false;
      currentQuestion.value = '';
      quickReplies.clear();
      questionNumber.value = 0;
      questionTotal.value = 0;
      confidence.value = 0;
      return;
    }
    interviewActive.value = true;
    questionTotal.value = _questions.length;
    questionNumber.value = (_questionIndex + 1).clamp(0, _questions.length);
    // Progress means clinical detail on record, not bubbles exchanged: a
    // dodged or one-word answer never moves the bar.
    confidence.value = _slotCoverage;
    final question = _questions[_questionIndex];
    currentQuestion.value = question;
    quickReplies.assignAll(quickRepliesFor(question));
  }

  /// Fraction of the slots this interview asks about that genuinely have an
  /// answer. Drives both the live confidence bar and "may we prescribe".
  double get _slotCoverage {
    final needed = {for (final question in _questions) slotOf(question)};
    if (needed.isEmpty) return 0;
    return needed.intersection(_answeredSlots).length / needed.length;
  }

  /// Turns the completed interview into a grounded, DB-based treatment plan.
  /// The model is told the consultation is closed ([AssistantReplyMode
  /// .treatmentPlan]) so it answers as a plan, not another question round.
  Future<void> _finalizeInterview({required bool fullyConfident}) async {
    final query = _caseQuery;
    final media = [..._heldMedia];
    // The whole consultation is the model's window: every answer the patient
    // typed, not just the question→answer digest below. Captured before the
    // closing preamble is added, so it ends on the patient's last answer.
    final history = _transcript();
    messages.add(
      ChatTurn(
        role: 'assistant',
        text: finalisePreamble(fullyConfident: fullyConfident),
      ),
    );
    final detail = _answers.entries
        .map((e) => '${e.key}\nউত্তর: ${e.value}')
        .join('\n\n');
    final medicines = await _knowledge.medicinesFor(query, cap: 6);
    final context = await _knowledge.buildContext(query);
    final rich = <String>[
      if (context != null && context.isNotEmpty) context,
      if (detail.isNotEmpty) 'রোগীর বিস্তারিত তথ্য:\n$detail',
      if (media.isNotEmpty)
        'রোগী ${media.length}টি ছবি/ভয়েস নোটও সংযুক্ত করেছে (বার্তায় দেখুন)।',
    ].join('\n\n');
    var answered = false;
    try {
      final text = await _assistant.reply(
        query:
            '$query — সাক্ষাৎকার সম্পন্ন হয়েছে। এখন ওয়েবসাইট ও ফার্মাকোলজি জ্ঞান মিলিয়ে রোগীর জন্য সম্পূর্ণ সমাধান বিস্তারিত বাংলায় সাজিয়ে দাও:\n'
            '১) লক্ষণ ও কারণ বিশ্লেষণ: রোগীর সমস্যাটি কেন হচ্ছে এবং মূলত কী কারণে ও কোন সমস্যার প্রেক্ষিতে এই ওষুধগুলো দেওয়া হয় তার ডাক্তারি ব্যাখ্যা।\n'
            '২) ওষুধ ও পর্যায়ক্রমিক ডোজ নির্দেশিকা:\n'
            '   প্রতিটি প্রস্তাবিত ওষুধের জন্য:\n'
            '   • ওষুধের নাম (জেনেরিক — ব্র্যান্ড নাম ও শক্তি)\n'
            '   • কেন এই ওষুধ দেওয়া হচ্ছে (ক্লিনিক্যাল কারণ)\n'
            '   • পর্যায়ক্রমিক ডোজ (Dosing Ladder):\n'
            '     - ১ম ধাপ / প্রারম্ভিক ডোজ: রোগের শুরুতে কতটুকু দিয়ে শুরু করতে হবে\n'
            '     - ২য় ধাপ / নিয়মিত রক্ষণাবেক্ষণ ডোজ: নিয়মিত কতদিন ও দিনে কয়বেলা কয়বার খেতে হবে\n'
            '     - ৩য় ধাপ / সর্বোচ্চ (শেষ) ডোজ: ২৪ ঘণ্টায় সর্বোচ্চ কতটুকু পর্যন্ত নেওয়া নিরাপদ (সর্বোচ্চ শেষ মাত্রা)\n'
            '   • বয়স ও সেবনের নিয়ম:\n'
            '     - শিশু / বাচ্চা (প্রযোজ্য ক্ষেত্রে): বয়স অনুযায়ী দিনে কয়বেলা এবং কতটুকু (সিরাপ/ড্রপ/চামচ)\n'
            '     - কিশোর ও প্রাপ্তবয়স্ক (১২+ বছর): দিনে কয়বেলা (যেমন সকালে ও রাতে), কয়টি ট্যাবলেট\n'
            '     - খাওয়ার নিয়ম: খাবারের আগে না পরে (যেমন খালি পেটে / খাবারের ৩০ মিনিট আগে / ভরা পেটে)\n'
            '   • সাধারণ পার্শ্বপ্রতিক্রিয়া ও সতর্কতা\n'
            '৩) ঘরোয়া যত্ন ও লাইফস্টাইল সমাধান: কার্যকর ঘরোয়া পথ্য, খাদ্য নিয়ন্ত্রণ ও অভ্যাস।\n'
            '৪) বিপদ সংকেত: কোন জরুরি লক্ষণ দেখা দিলে সাথে সাথে হাসপাতালে বা ডাক্তারের কাছে যেতে হবে।',
        context: rich.isEmpty ? null : rich,
        history: history,
        media: media,
        mode: AssistantReplyMode.treatmentPlan,
      );
      modelActive.value = _assistant.ready;
      messages.add(
        ChatTurn(
          role: 'assistant',
          text: text,
          medicines: medicines,
          fromModel: true,
        ),
      );
      answered = true;
    } on AssistantUnavailable {
      modelActive.value = false;
    }
    if (!answered) {
      final fallback = await _interviewPlanFallback(query, medicines);
      messages.add(
        ChatTurn(role: 'assistant', text: fallback, medicines: medicines),
      );
    }
    _resetInterview();
  }

  /// The deterministic four-part plan shown when the model cannot answer:
  /// the gathered history is summarised verbatim, then home care, the
  /// database's medicines and the red-flag line — never a dead end.
  Future<String> _interviewPlanFallback(
    String query,
    List<Medicine> medicines,
  ) async {
    final lesson = await _knowledge.matchLesson(query);
    final buffer = StringBuffer();
    // Bangla-only promise: whatever script the patient typed, the reply is
    // always fluent Bengali — so the offline answer never branches by script.
    buffer.writeln('আপনার বর্ণনার সারসংক্ষেপ (সাক্ষাৎকার):');
    for (final entry in _answers.entries) {
      final question = entry.key.replaceAll(RegExp(r'\s+'), ' ').trim();
      final short = question.length <= 70
          ? question
          : '${question.substring(0, 70)}…';
      buffer.writeln('• $short → ${entry.value}');
    }
    buffer.writeln();
    if (lesson != null) {
      buffer.writeln(lesson.summary.trim());
      buffer.writeln();
    }
    buffer.writeln(
      'ঘরোয়া ও লাইফস্টাইল ব্যবস্থা: বিশ্রাম, পর্যাপ্ত পানি-তরল, হালকা '
      'খাবার; সমস্যার জায়গায় প্রয়োজনে ঠান্ডা/গরম সেঁক; নুন-তেল-মসলা '
      'কমিয়ে রাখুন; ধূমপান পরিহার করুন এবং ঘুম ঠিক রাখুন।',
    );
    buffer.writeln();
    if (medicines.isNotEmpty) {
      buffer.writeln(
        'প্রচলিত ওষুধ ও পর্যায়ক্রমিক ডোজ নির্দেশিকা (জেনেরিক — ব্র্যান্ড):',
      );
      for (final medicine in medicines) {
        final generic = (medicine.genericName ?? '').trim();
        final strength = (medicine.strength ?? '').trim();
        final brand = medicine.brandName;
        final title = [
          brand,
          if (generic.isNotEmpty) '($generic)',
          if (strength.isNotEmpty) strength,
        ].join(' ');
        buffer.writeln('• **$title**');
        final dosage = (medicine.dosageAndAdministration ?? '').trim();
        if (dosage.isNotEmpty) {
          final cleanDos = stripHtml(dosage).replaceAll(RegExp(r'\s+'), ' ').trim();
          final shortDos = cleanDos.length <= 250 ? cleanDos : '${cleanDos.substring(0, 250)}…';
          buffer.writeln('  - মাত্রা ও সেবনের নিয়ম: $shortDos');
        } else {
          buffer.writeln('  - মাত্রা: রোগীর বয়স ও চিকিৎসকের পরামর্শ অনুযায়ী সেব্য।');
        }
      }
      buffer.writeln();
    }
    buffer.writeln(
      'কখন দ্রুত ডাক্তার দেখাবেন: জ্বর ৩ দিনের বেশি, শ্বাসকষ্ট, বুক '
      'ব্যথা, অজ্ঞান/খিঁচুনি, তীব্র পানিশূন্যতা, রক্তপাত বা অ্যালার্জির '
      'ফুলা দেখা দিলে—এইগুলোতে অপেক্ষা না করে কাছের হাসপাতালে '
      'যান। কোনো ঔষধ শুরু/বন্ধ বা ডোজ পরিবর্তন আসল চিকিৎসকের '
      'পরামর্শ নিয়েই করুন।',
    );
    return buffer.toString().trim();
  }

  /// A single-shot, history-aware answer for medicine-name or general queries.
  /// [media] (photos / voice notes) rides along when the model supports it.
  Future<void> _directAnswer(
    String query, {
    List<AssistantMedia> media = const [],
  }) async {
    final context = await _knowledge.buildContext(query);
    final medicines = await _knowledge.medicinesFor(query, cap: 6);
    // Everything said so far, minus the message being answered right now.
    final history = _transcript(dropLast: 1);
    var answered = false;
    try {
      final text = await _assistant.reply(
        query: query,
        context: context,
        history: history,
        media: media,
      );
      modelActive.value = _assistant.ready;
      messages.add(
        ChatTurn(
          role: 'assistant',
          text: text,
          medicines: medicines,
          fromModel: true,
        ),
      );
      answered = true;
    } on AssistantUnavailable {
      modelActive.value = false;
      // Fall through to the deterministic knowledge answer.
    }
    if (!answered) {
      final fallback = await _knowledgeAnswer(query, medicines);
      messages.add(
        ChatTurn(role: 'assistant', text: fallback, medicines: medicines),
      );
    }
  }

  /// An answer built purely from our data, shown when the model is unavailable.
  /// A doctor-style reply: whatever matched is presented as guidance — never an
  /// apology and never a request to rephrase the question.
  Future<String> _knowledgeAnswer(
    String query,
    List<Medicine> medicines,
  ) async {
    // Bangla-only: the offline reply never switches to English, even when
    // the question arrived in Latin script or romanized Bangla.
    final lesson = await _knowledge.matchLesson(query);
    final buffer = StringBuffer();
    if (lesson != null) {
      buffer.writeln(lesson.summary.trim());
      buffer.writeln();
    }
    if (medicines.isNotEmpty) {
      buffer.writeln('প্রয়োজনীয় ওষুধ ও বিস্তারিত ডোজ নির্দেশিকা:');
      for (final medicine in medicines) {
        final generic = (medicine.genericName ?? '').trim();
        final strength = (medicine.strength ?? '').trim();
        final brand = medicine.brandName;
        final title = [
          brand,
          if (generic.isNotEmpty) '($generic)',
          if (strength.isNotEmpty) strength,
        ].join(' ');
        buffer.writeln('• **$title**');
        final indications = (medicine.indications ?? '').trim();
        if (indications.isNotEmpty) {
          final cleanInd = stripHtml(indications).replaceAll(RegExp(r'\s+'), ' ').trim();
          final shortInd = cleanInd.length <= 160 ? cleanInd : '${cleanInd.substring(0, 160)}…';
          buffer.writeln('  - কেন দেওয়া হয়: $shortInd');
        }
        final dosage = (medicine.dosageAndAdministration ?? '').trim();
        if (dosage.isNotEmpty) {
          final cleanDos = stripHtml(dosage).replaceAll(RegExp(r'\s+'), ' ').trim();
          final shortDos = cleanDos.length <= 300 ? cleanDos : '${cleanDos.substring(0, 300)}…';
          buffer.writeln('  - সেবনবিধি ও পর্যায়ক্রমিক মাত্রা: $shortDos');
        } else {
          buffer.writeln('  - সেবনবিধি: বয়স ও চিকিৎসকের পরামর্শ অনুযায়ী নিয়মিত সেব্য।');
        }
        buffer.writeln();
      }
      buffer.writeln(
        'গুরুত্বপূর্ণ: রোগীর সুনির্দিষ্ট বয়স, ওজন ও তীব্রতা অনুযায়ী ডোজ নিশ্চিত করতে একজন রেজিস্টার্ড চিকিৎসকের পরামর্শ নিন। '
        'নিচের তালিকা থেকে যেকোনো ঔষধে ট্যাপ করলে তার পূর্ণাঙ্গ প্রোফাইল দেখতে পাবেন।',
      );
    } else {
      if (isGreetingQuery(query)) {
        buffer.writeln(
          'হ্যালো! আসসালামু আলাইকুম। আমি ডা. ফার্মাপাথ। আপনার কী শারীরিক সমস্যা বা লক্ষণ দেখা দিচ্ছে, বলুন—আমি বিস্তারিত শুনে প্রয়োজনীয় পরামর্শ ও তথ্য দিচ্ছি।',
        );
      } else if (isGratitudeOrFarewell(query)) {
        buffer.writeln(
          'আপনাকে অনেক ধন্যবাদ! সুস্থ থাকুন এবং নিজের যত্ন নিন। যেকোনো স্বাস্থ্য জিজ্ঞাসায় আমি সবসময় আছি।',
        );
      } else {
        buffer.writeln(
          'আপনার লক্ষণ বা সমস্যাটি আরেকটু স্পষ্ট করে বলুন—শরীরে ঠিক কী অসুবিধা হচ্ছে বা কোন বিষয়ে জানতে চান। তাহলে আমি সঠিক ডাক্তারি দিকনির্দেশনা দিতে পারব।',
        );
      }
    }
    return buffer.toString().trim();
  }

  void _resetInterview() {
    _plan = null;
    _questions = const [];
    _answers.clear();
    _answeredSlots.clear();
    _questionIndex = 0;
    _followUpsInserted = 0;
    _safetyRepairs = 0;
    _caseQuery = '';
    _heldMedia.clear();
    interviewActive.value = false;
    interviewTopic.value = '';
    currentQuestion.value = '';
    quickReplies.clear();
    questionNumber.value = 0;
    questionTotal.value = 0;
    confidence.value = 0;
  }

  /// Empties the current thread (delete + fresh conversation).
  Future<void> clearChat() async {
    _resetInterview();
    final id = activeConversationId.value;
    if (id != 0) {
      await _aiDao.deleteConversation(id);
      final fresh = await _aiDao.createConversation(AiDao.defaultTitle);
      activeConversationId.value = fresh;
    }
    messages.clear();
    await _loadSessions();
  }
}
