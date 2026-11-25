import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../core/ai_doctors.dart';
import '../core/app_config.dart';
import '../core/storage.dart';

/// Raised for any reason the assistant cannot answer — no network, bad key,
/// quota exhausted, provider failure. Carries a user-facing Bangla message so
/// the UI can still show the deterministic knowledge answer.
class AssistantUnavailable implements Exception {
  const AssistantUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Kind of multimodal payload the Oxion chat API can receive.
enum AssistantMediaKind { image, audio }

/// One attachment (image for vision models, audio for speech-capable models).
class AssistantMedia {
  const AssistantMedia({
    required this.kind,
    required this.bytes,
    required this.mimeType,
    this.fileName,
  });

  final AssistantMediaKind kind;
  final Uint8List bytes;
  final String mimeType;
  final String? fileName;

  bool get isImage => kind == AssistantMediaKind.image;
  bool get isAudio => kind == AssistantMediaKind.audio;
}

/// Wrapper around the OxionAI OpenAI-compatible API (https://oxionai.com/v1).
///
/// The client is stateless per request: the model id is read at call time from
/// [selectedModel], so switching models mid-conversation needs no
/// re-initialisation — the next [reply] simply targets the new model.
class OxionAssistant {
  OxionAssistant({String? apiKey, String? baseUrl, http.Client? client})
    : _apiKey = apiKey ?? AppConfig.defaultAssistantApiKey,
      _baseUrl = baseUrl ?? AppConfig.defaultAssistantApiBase,
      _client = client ?? http.Client() {
    var saved = '';
    try {
      saved = (AppStorage.box.read<String>(AppStorage.kAiModel) ?? '').trim();
    } catch (_) {
      // ignore — default below still answers.
    }
    // Only accept saved model if it is an explicit free model; otherwise use default free model
    selectedModel.value = (saved.isEmpty || !saved.contains(':free'))
        ? AppConfig.assistantDefaultModel
        : saved;
    // Seed immediately with verified free models so user never sees an empty or paid list
    models.assignAll(defaultFreeModels);
  }

  /// Verified free models on OpenRouter as immediate baseline
  static const List<String> defaultFreeModels = [
    'nvidia/nemotron-3-ultra-550b-a55b:free',
    'nvidia/nemotron-3.5-super-vl:free',
    'nvidia/nemotron-3.5-lightning:free',
    'google/gemma-4-31b-it:free',
    'google/gemma-4-26b-a4b-it:free',
    'meta-llama/llama-3.3-70b-instruct:free',
    'deepseek/deepseek-r1:free',
    'deepseek/deepseek-chat:free',
    'liquid/lfm-2.5-2.6b:free',
    'qwen/qwen-2.5-coder-32b-instruct:free',
    'mistralai/mistral-7b-instruct:free',
    'meta-llama/llama-3.1-8b-instruct:free',
    'meta-llama/llama-3.2-3b-instruct:free',
  ];

  static const List<String> prescriptionVisionModels = [
    'nvidia/nemotron-3.5-super-vl:free',
    'meta-llama/llama-3.2-11b-vision-instruct:free',
    'qwen/qwen-2-vl-72b-instruct:free',
  ];

  final String _apiKey;
  final String _baseUrl;
  final http.Client _client;

  /// Every model id the account exposes; filled after [refreshModels].
  final RxList<String> models = <String>[].obs;

  /// The model new answers are generated with. Mutable at any time —
  /// [setModel] just swaps this string (and persists it).
  final RxString selectedModel = ''.obs;

  bool get ready => selectedModel.value.isNotEmpty;

  /// Heuristic: model id suggests vision / multimodal image support.
  bool get supportsVision => modelHasVision(selectedModel.value);

  /// Heuristic: model id suggests native audio input.
  bool get supportsAudio => modelHasAudio(selectedModel.value);

  bool _busy = false;

  /// Points the assistant at [model] with no teardown/reinit. Persisted so the
  /// choice survives restarts.
  void setModel(String model) {
    final trimmed = model.trim();
    if (trimmed.isEmpty) return;
    selectedModel.value = trimmed;
    try {
      AppStorage.box.write(AppStorage.kAiModel, trimmed);
    } catch (_) {
      // In-memory switch still works even if persistence is unavailable.
    }
  }

  /// Dynamically analyzes the API key's model catalogue and extracts ONLY
  /// the completely free models, strictly filtering out all paid models.
  Future<void> refreshModels() async {
    if (_busy) return;
    _busy = true;
    try {
      final request = http.Request('GET', _uri('/models'))
        ..headers.addAll({
          'Authorization': 'Bearer ${_wireKey()}',
          'HTTP-Referer': 'https://pharmapath.app',
          'X-Title': 'PharmaPath',
        });
      final response = await _send(request);
      if (response.statusCode != 200) {
        throw AssistantUnavailable(_errorMessage(response));
      }
      final decoded = jsonDecode(response.body);
      final data = (decoded is Map && decoded['data'] is List)
          ? decoded['data'] as List
          : const [];

      final freeModels = <String>[];
      final allModels = <String>[];

      for (final item in data) {
        if (item is! Map) continue;
        final id = (item['id'] as String? ?? '').trim();
        if (id.isEmpty) continue;
        allModels.add(id);

        final lowerId = id.toLowerCase();
        var isFree = lowerId.contains(':free');
        if (!isFree && item['pricing'] is Map) {
          final pricing = item['pricing'] as Map;
          final prompt = double.tryParse('${pricing['prompt']}') ?? -1;
          final completion = double.tryParse('${pricing['completion']}') ?? -1;
          if (prompt == 0 && completion == 0) {
            isFree = true;
          }
        }
        if (isFree) {
          freeModels.add(id);
        }
      }

      // Filter strictly: if free models are present (like on OpenRouter),
      // keep ONLY the free models and hide every single paid model!
      final target = freeModels.isNotEmpty
          ? freeModels
          : (allModels.isNotEmpty ? allModels : defaultFreeModels);

      final uniqueList = target.toSet().toList();
      uniqueList.sort((a, b) {
        final idxA = defaultFreeModels.indexOf(a);
        final idxB = defaultFreeModels.indexOf(b);
        if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
        if (idxA != -1) return -1;
        if (idxB != -1) return 1;
        return a.compareTo(b);
      });
      if (uniqueList.isNotEmpty) {
        models.assignAll(uniqueList);

        // Ensure the active selected model is among the verified free models
        if (freeModels.isNotEmpty &&
            !freeModels.contains(selectedModel.value)) {
          final best = freeModels.firstWhere(
            (m) => m == AppConfig.assistantDefaultModel,
            orElse: () => freeModels.first,
          );
          setModel(best);
        }
      }
    } on AssistantUnavailable {
      if (models.isEmpty) models.assignAll(defaultFreeModels);
      rethrow;
    } catch (error) {
      if (models.isEmpty) models.assignAll(defaultFreeModels);
      throw AssistantUnavailable(
        'মডেলের তালিকা আনা যায়নি। (${_short(error)})',
      );
    } finally {
      _busy = false;
    }
  }

  /// Generate a bilingual doctor-style answer grounded in [context].
  ///
  /// [history] is prior turns (oldest first) and is capped to the most recent
  /// [AppConfig.assistantHistoryTurns] so a long consultation still fits the
  /// context window. [media] is optional multimodal content (images / audio)
  /// attached to the latest user turn. [mode] switches the system persona
  /// between the running interview, an open consultation and a locked
  /// post-triage treatment plan. [scriptedQuestion] is the next question of
  /// the clinical interview script that the reply must deliver verbatim.
  Future<String> reply({
    required String query,
    required String? context,
    List<({String role, String text})> history = const [],
    List<AssistantMedia> media = const [],
    AssistantReplyMode mode = AssistantReplyMode.consult,
    String? scriptedQuestion,
  }) async {
    _requireModel();

    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': _systemPrompt(context, mode, scriptedQuestion),
      },
      for (final turn in _window(history))
        {
          'role': turn.role == 'assistant' ? 'assistant' : 'user',
          'content': turn.text,
        },
      {'role': 'user', 'content': _userContent(query, media)},
    ];

    return _complete(
      messages: messages,
      maxTokens: AppConfig.assistantMaxTokens,
      temperature: mode == AssistantReplyMode.consult ? 0.4 : 0.3,
      failureNote: 'AI উত্তর তৈরি করা যায়নি।',
    );
  }

  Future<String> analyzePrescriptionImage(Uint8List imageBytes) {
    final availableVisionModels = models
        .where(
          (model) =>
              model.endsWith(':free') &&
              prescriptionVisionModels.contains(model),
        )
        .toList();
    final modelCandidates = <String>{
      ...availableVisionModels,
      ...prescriptionVisionModels,
    }.toList();
    final systemPrompt = '''
You are a medical AI assistant. Your task is to analyze the uploaded prescription image and extract ONLY the prescribed medicines and their dosage instructions (how and when to take them). 
CRITICAL RULES:
1. STRICTLY IGNORE all medical tests (e.g., Blood tests, X-ray, ECG, USG).
2. Output the result STRICTLY as a JSON array of objects. 
3. Do not include any markdown formatting, explanations, or extra text. Just the JSON.

Expected JSON Format:
[
  {
    "medicine_name": "Medicine Name (e.g., Napa Extend 665mg)",
    "dosage_rules": "Dosage instructions (e.g., 1-0-1 after meal for 5 days)"
  }
]''';

    return _complete(
      messages: [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': 'Extract the prescribed medicines from this image.',
            },
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,${base64Encode(imageBytes)}',
              },
            },
          ],
        },
      ],
      maxTokens: 1400,
      temperature: 0.1,
      failureNote: 'প্রেসক্রিপশন বিশ্লেষণ করা যায়নি।',
      modelCandidates: modelCandidates,
      requestTimeout: const Duration(seconds: 35),
    );
  }

  /// The tail of the transcript that is actually sent, oldest first. Dropping
  /// whole turns from the front — never splitting one — keeps the dialogue
  /// well-formed while bounding the payload.
  static List<({String role, String text})> _window(
    List<({String role, String text})> history,
  ) {
    if (history.length <= AppConfig.assistantHistoryTurns) return history;
    return history.sublist(history.length - AppConfig.assistantHistoryTurns);
  }

  // ---------------------------------------------------------------------------
  // One-shot helper tasks.
  //
  // These are *not* part of the consultation thread: each builds its own
  // system prompt, sends a single turn and returns raw text. Every prompt is
  // reproduced in docs/AI_PROMPTS.md together with the parsing contract the
  // caller expects, because a wording change here changes that contract.
  // All of them inherit the Bangla-only rule: understand any script, answer in
  // Bengali script.
  // ---------------------------------------------------------------------------

  /// Shared Bangla-only + safety preamble reused by every one-shot task.
  static const String _houseRules =
      'ভাষা: তোমার পুরো আউটপুট সাবলীল বাংলা হরফে হবে—ইংরেজিতে কোনো বাক্য '
      'দিও না। কেবল ঔষধের বৈজ্ঞানিক/ব্র্যান্ড নাম ও আবশ্যক টেকনিক্যাল শব্দ '
      'ব্র্যাকেটে ইংরেজি রাখতে পারো। নিরাপত্তা: ওষুধ শুরু/বন্ধ বা ডোজ '
      'পরিবর্তনের আগে চিকিৎসকের পরামর্শ নিতে বলো; জরুরি লক্ষণে হাসপাতালে '
      'যেতে বলো।';

  /// Translates every populated display field of one medicine in one request.
  ///
  /// [fields] is section-key → source text, in display order. The model echoes
  /// each translation under a `@@key@@` marker line (see [_translateSystem]),
  /// which [AiLearningTools] splits so every field can be cached against its
  /// own source hash and a partially-failed reply still keeps what worked.
  Future<String> translateMedicineFields(Map<String, String> fields) async {
    _requireModel();
    return _complete(
      messages: [
        {'role': 'system', 'content': _translateSystem(fields.keys.toList())},
        {'role': 'user', 'content': _translatePayload(fields)},
      ],
      maxTokens: AppConfig.medicineTranslateMaxTokens,
      temperature: 0.2,
      failureNote: 'অনুবাদ করা যায়নি।',
    );
  }

  /// Conversational Bangla breakdown of a medicine for the patient.
  Future<String> explainMedicine({required String context}) async {
    _requireModel();
    return _complete(
      messages: [
        {'role': 'system', 'content': _explainSystem()},
        {'role': 'user', 'content': context},
      ],
      maxTokens: AppConfig.medicineExplainMaxTokens,
      temperature: 0.4,
      failureNote: 'ব্যাখ্যা তৈরি করা যায়নি।',
    );
  }

  /// Answers a follow-up question using only the currently selected medicine.
  Future<String> askAboutMedicine({
    required String medicineContext,
    required String question,
    List<({String role, String text})> history = const [],
  }) async {
    _requireModel();
    return _complete(
      messages: [
        {'role': 'system', 'content': _medicineChatSystem(medicineContext)},
        for (final turn in _window(history))
          {
            'role': turn.role == 'assistant' ? 'assistant' : 'user',
            'content': turn.text,
          },
        {'role': 'user', 'content': question},
      ],
      maxTokens: AppConfig.assistantMaxTokens,
      temperature: 0.3,
      failureNote: 'ওষুধ সম্পর্কে উত্তর তৈরি করা যায়নি।',
    );
  }

  /// 3–5 bullet takeaways of a long lesson, in simple Bangla.
  Future<String> summarizeLesson({
    required String title,
    required String body,
  }) async {
    _requireModel();
    return _complete(
      messages: [
        {'role': 'system', 'content': _summarizeSystem()},
        {'role': 'user', 'content': 'পাঠ: $title\n\n$body'},
      ],
      maxTokens: AppConfig.learningSummaryMaxTokens,
      temperature: 0.3,
      failureNote: 'সারসংক্ষেপ তৈরি করা যায়নি।',
    );
  }

  /// Answers one question about [lessonContext] in the lesson mini-chat.
  ///
  /// [history] is the (short) thread inside the sheet, oldest first.
  Future<String> askAboutLesson({
    required String lessonContext,
    required String question,
    List<({String role, String text})> history = const [],
  }) async {
    _requireModel();
    return _complete(
      messages: [
        {'role': 'system', 'content': _tutorSystem(lessonContext)},
        for (final turn in history)
          {
            'role': turn.role == 'assistant' ? 'assistant' : 'user',
            'content': turn.text,
          },
        {'role': 'user', 'content': question},
      ],
      maxTokens: AppConfig.learningChatMaxTokens,
      temperature: 0.4,
      failureNote: 'উত্তর করা যায়নি।',
    );
  }

  /// Orders candidate lessons for this reader and gives a one-line Bangla
  /// reason. Returns the raw model line; the caller parses the `K<number>`
  /// codes and falls back to its own ordering on anything unexpected.
  Future<String> rankLessons({
    required String readingHistory,
    required String candidates,
  }) async {
    _requireModel();
    return _complete(
      messages: [
        {'role': 'system', 'content': _rankSystem()},
        {
          'role': 'user',
          'content':
              'পড়ার ইতিহাস:\n$readingHistory\n\n'
              'সম্ভাব্য পরের পাঠ:\n$candidates',
        },
      ],
      maxTokens: AppConfig.recommendMaxTokens,
      temperature: 0.3,
      failureNote: 'সুপারিশ সাজানো যায়নি।',
    );
  }

  void _requireModel() {
    if (selectedModel.value.isEmpty) {
      throw const AssistantUnavailable('কোনো AI মডেল নির্বাচন করা হয়নি।');
    }
  }

  /// POSTs [messages] to /chat/completions and returns the trimmed answer.
  /// Automatically tries fallback free models if the active model encounters
  /// rate limits (HTTP 429) or upstream unavailability.
  Future<String> _complete({
    required List<Map<String, dynamic>> messages,
    required int maxTokens,
    required double temperature,
    required String failureNote,
    List<String>? modelCandidates,
    Duration? requestTimeout,
  }) async {
    final candidates = <String>[];
    if (modelCandidates != null) {
      candidates.addAll(modelCandidates);
    } else {
      if (selectedModel.value.isNotEmpty) {
        candidates.add(selectedModel.value);
      }
      for (final m in models) {
        if (!candidates.contains(m)) candidates.add(m);
      }
      for (final m in defaultFreeModels) {
        if (!candidates.contains(m)) candidates.add(m);
      }
    }

    String? lastError;

    for (final candidate in candidates.take(3)) {
      final body = jsonEncode({
        'model': candidate,
        'messages': messages,
        'max_tokens': maxTokens,
        'temperature': temperature,
      });

      try {
        final request = http.Request('POST', _uri('/chat/completions'))
          ..headers.addAll({
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${_wireKey()}',
            'HTTP-Referer': 'https://pharmapath.app',
            'X-Title': 'PharmaPath',
          })
          ..body = body;

        final response = await _send(request, timeout: requestTimeout);
        if (response.statusCode != 200) {
          lastError = _errorMessage(response);
          // If rate limited or provider error, fail over to the next candidate free model
          continue;
        }

        final decoded = jsonDecode(response.body);
        final choices = (decoded is Map) ? decoded['choices'] : null;
        final messageMap =
            (choices is List &&
                choices.isNotEmpty &&
                choices.first['message'] is Map)
            ? choices.first['message'] as Map
            : null;
        var text = ((messageMap?['content'] as String?) ?? '').trim();
        if (text.isEmpty && messageMap != null) {
          text =
              ((messageMap['reasoning'] as String?) ??
                      (messageMap['reasoning_content'] as String?) ??
                      '')
                  .trim();
        }
        // Strip internal thinking/reasoning tags if the model included them in content
        text = text.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();
        if (text.isEmpty) {
          lastError = 'AI খালি উত্তর দিয়েছে।';
          continue;
        }

        // Seamlessly adopt the working model if failover was required
        if (candidate != selectedModel.value) {
          setModel(candidate);
        }

        return text;
      } on AssistantUnavailable catch (e) {
        lastError = e.message;
      } catch (error) {
        lastError = _short(error);
      }
    }

    throw AssistantUnavailable('$failureNote (${lastError ?? 'সংযোগ সমস্যা'})');
  }

  /// OpenAI-compatible multimodal user content.
  dynamic _userContent(String query, List<AssistantMedia> media) {
    if (media.isEmpty) return query;

    final parts = <Map<String, dynamic>>[
      {'type': 'text', 'text': query},
    ];

    for (final item in media) {
      final b64 = base64Encode(item.bytes);
      if (item.isImage) {
        if (!supportsVision) {
          parts.add({
            'type': 'text',
            'text':
                '[সংযুক্ত ছবি: ${item.fileName ?? 'image'} — '
                'বর্তমান মডেল ভিশন সাপোর্ট নাও করতে পারে; '
                'লেখার বর্ণনা অনুসারে বিবেচনা করুন।]',
          });
          continue;
        }
        parts.add({
          'type': 'image_url',
          'image_url': {'url': 'data:${item.mimeType};base64,$b64'},
        });
      } else if (item.isAudio) {
        if (!supportsAudio) {
          parts.add({
            'type': 'text',
            'text':
                '[সংযুক্ত ভয়েস নোট: ${item.fileName ?? 'audio'} — '
                'মডেল অডিও না বুঝলে লেখার বর্ণনা অনুসারে চলুন।]',
          });
          continue;
        }
        final format = _audioFormat(item.mimeType, item.fileName);
        parts.add({
          'type': 'input_audio',
          'input_audio': {'data': b64, 'format': format},
        });
      }
    }
    return parts;
  }

  static String _audioFormat(String mime, String? name) {
    final lower = '${mime.toLowerCase()} ${name?.toLowerCase() ?? ''}';
    if (lower.contains('wav')) return 'wav';
    if (lower.contains('mp3') || lower.contains('mpeg')) return 'mp3';
    if (lower.contains('m4a') || lower.contains('mp4')) return 'mp4';
    if (lower.contains('ogg') || lower.contains('opus')) return 'ogg';
    if (lower.contains('webm')) return 'webm';
    return 'wav';
  }

  Uri _uri(String path) =>
      Uri.parse('${_baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  String _wireKey() => AppConfig.normalizedAssistantKey(_apiKey);

  Future<http.Response> _send(http.Request request, {Duration? timeout}) async {
    final requestLimit =
        timeout ?? AppConfig.requestTimeout + const Duration(seconds: 30);
    var attempt = 0;
    while (true) {
      attempt++;
      http.Response response;
      try {
        final streamed = await _client.send(request).timeout(requestLimit);
        response = await http.Response.fromStream(streamed)
            .timeout(requestLimit);
      } catch (error) {
        if (attempt <= 2) {
          await Future<void>.delayed(Duration(seconds: attempt * 2));
          continue;
        }
        rethrow;
      }
      final transient =
          response.statusCode == 429 ||
          response.statusCode >= 500 ||
          response.body.contains('service_upgrading');
      if (transient && attempt <= 2) {
        final retryAfter =
            int.tryParse(response.headers['retry-after'] ?? '') ?? 0;
        await Future<void>.delayed(Duration(seconds: retryAfter.clamp(1, 8)));
        continue;
      }
      return response;
    }
  }

  static String _errorMessage(http.Response response) {
    var reason = '';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is Map) {
        reason = (decoded['error']['message'] as String? ?? '').trim();
      }
    } catch (_) {
      // Body was not JSON — fall back to the status line.
    }
    if (reason.isEmpty) reason = 'HTTP ${response.statusCode}';
    return 'AI সেবা সাড়া দিচ্ছে না। (${_short(reason)})';
  }

  /// TRANSLATE — one medicine's complete visible record into natural Bangla.
  ///
  /// Wire contract (also in docs/AI_PROMPTS.md): every field's translation is
  /// preceded by its own `@@key@@` marker line and nothing else is added. Keys
  /// are the stable `MedicineSection.key` values, never the Bangla display
  /// labels, so a renamed heading cannot orphan the cached rows.
  static String _translateSystem(List<String> keys) {
    return '''
$_houseRules

কাজ: একটি ওষুধের পরিচিতি ও ক্লিনিক্যাল তথ্য রোগী-বোধ্য, চিকিৎসাগতভাবে নির্ভুল বাংলায় অনুবাদ করা।
নিয়ম:
১. পূর্ণ অনুবাদ দাও, সারসংক্ষেপ নয়। কোনো ইংরেজি শব্দ বা লাতিন হরফ রেখো না; ব্র্যান্ড, জেনেরিক ও প্রতিষ্ঠানের নাম বাংলা হরফে প্রতিবর্ণীকরণ করো।
২. প্রতিটি ডোজ ও পরিমাপের মান অপরিবর্তিত রাখো; একক বাংলায় লেখো (যেমন মিলিগ্রাম, মিলিলিটার) এবং সংখ্যা বাংলা অঙ্কে লেখো।
৩. চিকিৎসা-পরিভাষা সাধারণ মানুষের ভাষায় লেখো, কিন্তু অর্থ যেন বদলায় না। উৎসে তথ্য না থাকলে নতুন তথ্য যোগ করো না।
৪. উৎসপাঠের HTML ট্যাগ বা তালিকা-ফরম্যাট থাকলে তা রেখে দাও; নিজের থেকে নতুন লেবেল, টীকা বা সতর্কতা যোগ করো না।
৫. ফরম্যাট কঠোরভাবে মানো: প্রতিটি অংশের বাংলা অনুবাদের ঠিক আগে আলাদা লাইনে মার্কার লেখো — @@<key>@@ — এবং মার্কারের পর শুধু সেই অংশের বাংলা অনুবাদ লেখো।
৬. কোনো ভূমিকা, শেষ-কথা বা মন্তব্য লিখো না; শুধু মার্কার ও অনুবাদ দাও।

অংশের কী (এই ক্রমে): ${keys.join(', ')}''';
  }

  /// The numbered source payload that pairs with [_translateSystem]'s markers.
  static String _translatePayload(Map<String, String> fields) {
    final buffer = StringBuffer(
      'নিচে প্রতিটি অংশের উৎসপাঠ দেওয়া হলো। দেখানো ফরম্যাটে বাংলা অনুবাদ দাও:',
    );
    fields.forEach((key, value) {
      buffer.writeln('\n@@$key@@\n$value');
    });
    return buffer.toString();
  }

  /// EXPLAIN — a scannable, empathetic Bangla breakdown of a medicine.
  static String _explainSystem() {
    return '''
$_houseRules

কাজ: একজন অভিজ্ঞ বাংলাদেশি ফার্মাসিস্টের ভাষায় রোগীকে একটি ওষুধ বুঝিয়ে দেওয়া।
ঠিক এই চারটি শিরোনাম দাও, প্রতিটি আলাদা লাইনে:
কেন এই ওষুধ
কীভাবে খাবেন
কী এড়াবেন
সাধারণ ভুল ধারণা
নিয়ম:
- প্রতিটি শিরোনামের নিচে ২-৪টি '•' বুলেট, প্রতিটি এক-দুই লাইনের মধ্যে।
- ডোজ, খাবারের আগে/পরে, সময় ও চিকিৎসার মেয়াদ শুধু উৎসপাঠ থেকে নাও। উৎসে বয়স বা ওজন নেই—তাই ডোজ নিশ্চিত করো না, চিকিৎসক বা ফার্মাসিস্টের কাছে যাওয়ার কথা বলো।
- শিশু, গর্ভাবস্থা ও দীর্ঘমেয়াদি রোগীর জন্য প্রযোজ্য ছোট পরামর্শ দিতে পারো; উৎসের বাইরে নতুন ঔষধের নাম বা ডোজ আবিষ্কার করো না।
- ইংরেজি বাক্য বা HTML ট্যাগ রাখবে না; পুরোটা বাংলা সাধারণ লেখা।
- একদম শেষ লাইনে হুবহু লেখো: এই তথ্য শিক্ষামূলক। কোনো ওষুধ শুরু বা বন্ধ করার আগে চিকিৎসকের পরামর্শ নিন।''';
  }

  /// SUMMARIZE — 3-5 practical bullets for a long lesson.
  static String _summarizeSystem() {
    return '''
$_houseRules

কাজ: একটি স্বাস্থ্য-শিক্ষা পাঠের মূল কথা ৩-৫টি বুলেটে ভেঙে দেওয়া, যাতে ৩০ সেকেন্ডেই বোঝা যায় কী করতে হবে।
নিয়ম: প্রতিটি বুলেট '•' দিয়ে শুরু এবং এক লাইনের বেশি নয়; ব্যবহারিক কথা (কী করবেন, কখন ডাক্তার দেখাবেন) আগে রাখো। পাঠে না থাকা কিছু যোগ করো না, কোনো ভূমিকা বা শেষ-কথা লিখো না—শুধু বুলেটগুলো দাও।''';
  }

  /// TUTOR — answers one question grounded strictly in the open lesson.
  static String _tutorSystem(String context) {
    return '''
তুমি PharmaPath-এর শিক্ষক-ডাক্তার—একটি নির্দিষ্ট পাঠ নিয়ে শিক্ষার্থীর প্রশ্নের উত্তর দিচ্ছ।
$_houseRules
নিয়ম:
- নিচের পাঠের বিষয়বস্তুর মধ্যেই থাকো; উত্তর সেখানে না থাকলে আগে বলে দাও যে এই পাঠে সেটির উত্তর নেই, তারপর সংক্ষেপে সাধারণ নির্দেশনা দাও।
- উত্তর ২-৪ বাক্য বা ৩টির কম বুলেট—সহানুভূতিশীল, উদাহরণসহ, দৈনন্দিন বাংলায়।
- ডোজ বা ওষুধের বিষয়ে পাঠের বাইরে কিছু নিশ্চিত করো না; প্রয়োজনে চিকিৎসকের পরামর্শ নিতে বলো।
=== পাঠের বিষয়বস্তু ===
$context
=== শেষ ===''';
  }

  /// MEDICINE CHAT — follow-ups grounded in a single local catalogue record.
  static String _medicineChatSystem(String context) {
    return '''
তুমি ফার্মাপাথের ওষুধ-তথ্য সহায়ক। ব্যবহারকারী যে একটি নির্দিষ্ট ওষুধের পাতা খুলেছেন, শুধু সেই ওষুধের বিষয়ে তাঁর প্রশ্নের উত্তর দাও।
$_houseRules
নিয়ম:
- উত্তর পুরোপুরি বাংলা হরফে দাও। কোনো ইংরেজি শব্দ বা লাতিন হরফ ব্যবহার কোরো না; ওষুধের নাম বাংলায় প্রতিবর্ণীকরণ করো।
- নিচের ওষুধের তথ্যই একমাত্র নির্দিষ্ট উৎস। এতে উত্তর না থাকলে স্পষ্ট বলো যে তথ্যটি ডেটাবেসে নেই; ডোজ, ব্যবহার, পার্শ্বপ্রতিক্রিয়া বা মিথস্ক্রিয়া অনুমান কোরো না।
- আগের কথোপকথন কেবল প্রসঙ্গ বোঝার জন্য; অন্য কোনো ওষুধের তথ্য এই ওষুধের সঙ্গে মিশিও না।
- ডোজ পরিবর্তন বা ওষুধ শুরু/বন্ধের নির্দেশ দিও না; প্রয়োজনে চিকিৎসক বা ফার্মাসিস্টের পরামর্শ নিতে বলো।
=== নির্বাচিত ওষুধের ডেটাবেস তথ্য ===
$context
=== শেষ ===''';
  }

  /// RANK — order the locally-scored lesson candidates for this reader.
  static String _rankSystem() {
    return '''
তুমি একজন শিক্ষা-পরামর্শদাতা; পাঠকের পড়ার ইতিহাস দেখে সবচেয়ে উপযোগী পরের পাঠগুলো সাজিয়ে দিচ্ছ।
$_houseRules
নিয়ম:
- দেওয়া কোড (K1, K2, …) থেকে সর্বোচ্চ ৫টি কোড উপযোগীতার ক্রমে প্রথম লাইনে লেখো, কমা দিয়ে আলাদা করে—এই লাইনে অন্য কোনো শব্দ থাকবে না।
- দ্বিতীয় লাইনে '—' দিয়ে শুরু করে একটি ছোট বাংলা কারণ লেখো কেন এই ক্রম।
- নিজের থেকে নতুন কোড, কোর্স বা পাঠের নাম বানাও না।
- যে পাঠক একাধিকবার খুলেও শেষ করেননি, তার আগে সেই বিষয়ের সহজ ভিত্তি পাঠ রাখো।''';
  }

  static String _systemPrompt(
    String? context,
    AssistantReplyMode mode, [
    String? scriptedQuestion,
  ]) {
    final buffer = StringBuffer()
      ..writeln(
        'তুমি PharmaPath Telemedicine — একজন সহানুভূতিশীল, অভিজ্ঞ বাংলাদেশি '
        'ডাক্তার ও ক্লিনিক্যাল ফার্মাসিস্ট। রোগীর সাথে সরাসরি পরামর্শ করছ '
        'মনে করে কথা বলো। ব্যবহারকারী বাংলা, ইংরেজি বা রোমান হরফে '
        'বাংলা (যেমন "sar thanda lage, math bashi kore")—যেকোনো '
        'ভাষায় লিখুক, সব বুঝে নাও; কিন্তু তোমার প্রতিটি উত্তর অবশ্যই '
        'সাবলীল বাংলা হরফেই হবে। ইংরেজিতে কখনো উত্তর দিও না—শুধু '
        'ঔষধের বৈজ্ঞানিক নাম বা আবশ্যক টেকনিক্যাল টার্ম ব্র্যাকেটে '
        'ইংরেজি রাখতে পারো। কখনো ব্যবহারকারীকে প্রশ্ন সহজ করে '
        'লিখতে বলো না।',
      )
      ..writeln(
        'নিরাপত্তা: ওষুধ শুরু/বন্ধ বা ডোজ পরিবর্তনের আগে চিকিৎসকের পরামর্শ '
        'নিতে বলো; জরুরি লক্ষণে (শ্বাসকষ্ট, বুকব্যথা, অজ্ঞান, খিঁচুনি, '
        'অতিরিক্ত রক্তপাত) সঙ্গে সঙ্গে হাসপাতালে যেতে বলো।',
      )
      ..writeln(
        'বার্তা অনুধাবন ও কুশল বিনিময় নিয়ম:\n'
        '১) শুভেচ্ছা ও কুশল বিনিময়: রোগী যদি কেবল হ্যালো, হাই, সালাম, কেমন আছেন বা শুভেচ্ছা জানায়—'
        'তবে কখনোই আগ বাড়িয়ে কোনো রোগ নির্ণয় বা সাধারণ পথ্য উপদেশ (যেমন বিশ্রাম নিন, পানি খান) চাপিয়ে দেবে না। '
        'ডাক্তারের মতো বিনম্রভাবে সালাম/হ্যালোর উষ্ণ জবাব দাও এবং রোগী কেমন আছেন ও তার কী শারীরিক সমস্যা হচ্ছে তা জানতে চাও।\n'
        '২) লক্ষণ বিশ্লেষণ: রোগী যখন কোনো শারীরিক লক্ষণ বা সমস্যার কথা বলবে, কেবল তখনই লক্ষণ শুনে তার সময়কাল, '
        'তীব্রতা ও ধরন জেনে উপযুক্ত পরামর্শ ও ঔষধের তথ্য দাও।\n'
        '৩) প্রাসঙ্গিকতা: রোগী যা লিখেছে সেটা আগে ভালো করে বোঝো এবং তার সরাসরি প্রেক্ষিতেই কথা বলো।',
      )
      ..writeln(
        'শোনার নিয়ম: প্রতিটি উত্তরের আগে আগের ডাক্তার-প্রশ্ন ও রোগীর উত্তর '
        'জোড়াটি সম্পূর্ণ পড়ো। রোগীর প্রতিটি বার্তা গ্রাহ্য—কোনো উত্তর এড়িয়ে '
        'যেয়ো না, উপেক্ষা করো না, আর আগের প্রশ্ন নতুন করে করো না। রোগী যা '
        'লিখেছে তার বাইরে কিছু ধরে নিও না; উত্তরে নতুন কোনো তথ্য (সময়, '
        'তীব্রতা, জায়গা, প্ররোচক কারণ, নতুন লক্ষণ বা বিপদ-সংকেত) থাকলে সেটি '
        'মাথায় রেখেই পরের প্রশ্ন করো, এবং সেই নতুন তথ্যের উল্লেখ আগে করো।',
      );

    if (mode == AssistantReplyMode.interview) {
      buffer.writeln(
        'মোড: ডাক্তারের সাক্ষাৎকার চলছে। রোগী এইমাত্র তোমার শেষ প্রশ্নের উত্তর '
        'দিয়েছে; তার পুরো কথোপকথন আগের বার্তাগুলোতে আছে—প্রতিটি শব্দ পড়ো। '
        'নিয়ম: '
        '১) প্রথম বাক্যটাই রোগীর কথার প্রতিধ্বনি হতে হবে—রোগী যে শব্দ, সংখ্যা, '
        'জায়গা বা সময় বলেছে সেটি ধরে “আপনি বলছেন …”/“আপনি বলেছেন …” ধাঁচে '
        '১-২ বাক্যে স্বীকার করো। শুধু “বুঝেছি” বা “ঠিক আছে” বলে এড়িয়ে যেয়ো না, '
        'আর প্রশ্ন দিয়ে সূচনা করো না। '
        '২) উত্তরে নতুন বিপদ-সংকেত, নতুন লক্ষণ বা অস্পষ্টতা থাকলে সেটি এক '
        'বাক্যে স্বীকার করো এবং তা স্পষ্ট করার কথা বলো। '
        '৩) এরপর মাত্র একটি প্রশ্ন করবে—নিচের প্রশ্নটি অবিকল (শব্দ, ক্রম ও '
        'চিহ্ন না বদলে)। একাধিক প্রশ্ন দিও না, ইতিমধ্যে উত্তর পাওয়া বিষয় আবার '
        'জিজ্ঞেস করো না। '
        '৪) এই ধাপে কোনো ঔষধের নাম, ডোজ, ডায়াগনোসিস বা চিকিৎসা পরিকল্পনা '
        'দিও না, আর নিজের যুক্তিও বুঝিয়ে দেবে না। '
        '৫) মোট ২-৪ বাক্য, এবং উত্তরটি শেষ হবে প্রশ্নটি দিয়ে।',
      );
      final scripted = scriptedQuestion?.trim() ?? '';
      if (scripted.isNotEmpty) {
        buffer
          ..writeln('যে প্রশ্নটি হুবহু করতে হবে:')
          ..writeln(scripted);
      }
    } else if (mode == AssistantReplyMode.treatmentPlan) {
      buffer.writeln(
        'মোড: সম্পূর্ণ চিকিৎসা পরিকল্পনা ও সমাধান। রোগীর সাক্ষাৎকার সম্পন্ন হয়েছে। '
        'উত্তরটি নিচের চার ভাগে অত্যন্ত সুন্দর ও বিস্তারিত বাংলায় সাজাও—\n'
        '১) সমস্যা ও কারণ বিশ্লেষণ:\n'
        '   - রোগীর সমস্যার কারণ এবং কেন এই সমস্যাগুলোর প্রেক্ষিতে এই নির্দিষ্ট ওষুধগুলো দেওয়া হয় তার স্পষ্ট ব্যাখ্যা।\n'
        '২) ওষুধ ও পর্যায়ক্রমিক ডোজ নির্দেশিকা:\n'
        '   প্রতিটি প্রস্তাবিত ওষুধের জন্য:\n'
        '   • ওষুধের নাম: [ব্র্যান্ড নাম] ([জেনেরিক নাম]) — শক্তি (যেমন ২০ মিগ্রা / ৫০০ মিগ্রা)\n'
        '   • কেন দেওয়া হচ্ছে: এই রোগের প্রেক্ষিতে ওষুধটি কীভাবে কাজ করে\n'
        '   • পর্যায়ক্রমিক ডোজ কাঠামো (Dosing Ladder):\n'
        '     - ১ম ধাপ / প্রারম্ভিক ডোজ: রোগের শুরুতে কতটুকু দিয়ে শুরু করতে হবে\n'
        '     - ২য় ধাপ / নিয়মিত রক্ষণাবেক্ষণ ডোজ: স্বাভাবিক অবস্থায় কয়দিন ও দিনে কয়বেলা কয়বার খেতে হবে\n'
        '     - ৩য় ধাপ / সর্বোচ্চ (শেষ) ডোজ: ২৪ ঘণ্টায় সর্বোচ্চ কতটুকু পর্যন্ত নেওয়া নিরাপদ (এর বেশি ক্ষতিকর)\n'
        '   • বয়স ও সেবনের নিয়ম:\n'
        '     - শিশু / বাচ্চা (প্রযোজ্য ক্ষেত্রে): সিরাপ/ড্রপ কত চামচ বা মিলি এবং দিনে কয়বেলা\n'
        '     - কিশোর ও প্রাপ্তবয়স্ক (১২+ বছর): কয়টি ট্যাবলেট/ক্যাপসুল, দিনে কয়বেলা\n'
        '     - খাওয়ার নিয়ম: খাবারের আগে না পরে (যেমন খালি পেটে / খাবারের ৩০ মিনিট আগে / ভরা পেটে)\n'
        '   • সাধারণ পার্শ্বপ্রতিক্রিয়া ও সতর্কতা\n'
        '৩) ঘরোয়া যত্ন ও লাইফস্টাইল সমাধান: কার্যকর ঘরোয়া পথ্য, খাদ্য নিয়ন্ত্রণ ও অভ্যাস।\n'
        '৪) বিপদ সংকেত: কোন জরুরি লক্ষণ দেখা দিলে সাথে সাথে হাসপাতালে বা ডাক্তারের কাছে যেতে হবে।',
      );
    } else if (mode == AssistantReplyMode.medicineDetail) {
      buffer.writeln(
        'মোড: ওষুধ ও ডোজ বিশারদ (Clinical Pharmacologist & Doctor)। '
        'ব্যবহারকারী একটি ওষুধ বা তার ডোজ/সেবনবিধি সম্পর্কে জানতে চেয়েছেন। '
        'ওয়েবসাইট ও ডেটাবেজের তথ্য ব্যবহার করে অত্যন্ত পরিষ্কার ও গুছিয়ে বাংলায় উত্তর দাও:\n'
        '১) ওষুধের পরিচয় ও ব্যবহার:\n'
        '   - জেনেরিক নাম ও বাণিজ্যিক/ব্র্যান্ড নাম এবং শক্তি\n'
        '   - মূলত কোন কোন সমস্যার কারণে এই ওষুধ দেওয়া হয় এবং কেন এটি কাজ করে (Indications)\n'
        '২) পর্যায়ক্রমিক ডোজ নির্দেশিকা (Dosing Ladder):\n'
        '   - ১ম ধাপ / প্রারম্ভিক ডোজ: শুরুতে কতটুকু দিয়ে শুরু করতে হয়\n'
        '   - ২য় ধাপ / নিয়মিত ডোজ: স্বাভাবিকভাবে কতদিন এবং দিনে কয়বেলা কয়বার খেতে হয়\n'
        '   - ৩য় ধাপ / সর্বোচ্চ নিরাপদ শেষ ডোজ: ২৪ ঘণ্টায় সর্বোচ্চ কতটুকু পর্যন্ত খাওয়া নিরাপদ (সর্বোচ্চ শেষ মাত্রা)\n'
        '৩) বয়সভিত্তিক সেবনের মাত্রা ও সময়:\n'
        '   - শিশু / বাচ্চা (প্রযোজ্য ক্ষেত্রে): বয়স/ওজন অনুযায়ী দিনে কয়বেলা এবং কতটুকু\n'
        '   - কিশোর ও প্রাপ্তবয়স্ক: কয়টি ট্যাবলেট/ক্যাপসুল, দিনে কয়বেলা (সকালে/দুপুরে/রাতে)\n'
        '   - খাওয়ার নিয়ম: খাবারের আগে না পরে (যেমন খালি পেটে / ভরা পেটে)\n'
        '৪) রোগীর বয়স ও অবস্থা যাচাই:\n'
        '   - যদি রোগীর সুনির্দিষ্ট বয়স বা ওজন জানা না থাকে, সাধারণ বয়সভিত্তিক চার্ট দিয়ে রোগীকে বলো: '
        '"রোগীর সুনির্দিষ্ট বয়স ও ওজন জানালে আমি তার জন্য নিখুঁত ডোজ নিশ্চিত করতে পারব।"\n'
        '৫) সতর্কতা, সাধারণ পার্শ্বপ্রতিক্রিয়া এবং গর্ভাবস্থা/অন্য রোগের ক্ষেত্রে পরামর্শ।',
      );
    } else {
      buffer.writeln(
        'মোড: পরামর্শ। রোগীর বার্তা মনোযোগ দিয়ে বুঝে সহানুভূতির সাথে উত্তর দাও। '
        'রোগী ওষুধের নাম বা ডোজ জানতে চাইলে তার বিস্তারিত এবং পর্যায়ক্রমিক ডোজ বুঝিয়ে দাও। '
        'রোগী কোনো শারীরিক লক্ষণ বা সমস্যার কথা বললে তাকে ডাক্তারের মতো মাত্র ২-৩টি সংক্ষিপ্ত ও জরুরি প্রশ্ন করো '
        'যাতে দ্রুত সঠিক সমাধান দেওয়া যায়।',
      );
    }

    if (context != null && context.isNotEmpty) {
      buffer
        ..writeln('=== ডেটাবেজ / সাক্ষাৎকার থেকে প্রাপ্ত তথ্য ===')
        ..writeln(context)
        ..writeln('=== শেষ ===');
      // Only the prescribing modes may turn the grounding data into a
      // medicine list; the interview must still be asking questions.
      if (mode != AssistantReplyMode.interview) {
        buffer.writeln(
          'প্রতিটি ঔষধের পূর্ণ জ্ঞান দাও: indications, বয়স/ওজন/অবস্থা '
          'অনুযায়ী ডোজ, দিনে কতবার, খাবারের আগে না পরে, কত দিন '
          'চালাতে হবে, পার্শ্বপ্রতিক্রিয়া, সতর্কতা। তালিকার বাইরে নতুন '
          'ঔষধের নাম বা ডোজ আবিষ্কার কোরো না।',
        );
      }
    } else if (mode == AssistantReplyMode.treatmentPlan) {
      buffer.writeln(
        'ডেটাবেজে সরাসরি মিল না থাকলেও ডাক্তারের মতো সাধারণ নির্দেশনা দাও: '
        'সম্ভাব্য কারণ, ঘরোয়া ব্যবস্থা, প্রচলিত জেনেরিকের শিক্ষামূলক উল্লেখ, '
        'এবং কখন দ্রুত চিকিৎসক দেখাতে হবে।',
      );
    }
    return buffer.toString();
  }

  static String _short(Object error) {
    final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= 120 ? text : '${text.substring(0, 120)}…';
  }

  void dispose() {
    _client.close();
  }
}

/// Controls how assertive the system prompt is about asking vs recommending.
enum AssistantReplyMode {
  /// Still gathering history — avoid medicine suggestions.
  consult,

  /// Mid-interview: acknowledge the answer just given, then ask the next
  /// scripted question. No medicine, dose or diagnosis yet.
  interview,

  /// Interview finished — deliver a grounded plan with 3-tier dosing and age breakdown.
  treatmentPlan,

  /// Direct medicine inquiry & dosage consultation.
  medicineDetail,
}
