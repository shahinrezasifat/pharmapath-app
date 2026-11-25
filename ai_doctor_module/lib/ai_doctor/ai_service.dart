import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';

/// অ্যাপ চালুর সময় একবার `AiDoctorConfig.init(...)` ডাকো।
/// OpenAI-সামঞ্জস্যপূর্ণ /chat/completions এন্ডপয়েন্ট ধরা হয়েছে।
class AiDoctorConfig {
  static String baseUrl = '';
  static String apiKey = '';
  static String languageCode = 'bn';
  static void Function(String)? onLanguageChanged;
  static Future<List<AiMedicineOption>> Function(String query)? medicineLookup;

  static void init({
    required String baseUrl,
    required String apiKey,
    String languageCode = 'bn',
    void Function(String)? onLanguageChanged,
  }) {
    AiDoctorConfig.baseUrl = baseUrl;
    AiDoctorConfig.apiKey = apiKey;
    AiDoctorConfig.languageCode = languageCode;
    AiDoctorConfig.onLanguageChanged = onLanguageChanged;
  }

  static void setLanguage(String value) {
    if (value != 'bn' && value != 'en') {
      throw ArgumentError.value(value, 'value', 'Expected "bn" or "en".');
    }
    languageCode = value;
    onLanguageChanged?.call(value);
  }
}

const aiDisclaimer = 'AI guidance does not replace professional medical care.';

const _emergencyWords = [
  'chest pain',
  'shortness of breath',
  'difficulty breathing',
  "can't breathe",
  'fainting',
  'seizure',
  'vomiting blood',
  'slurred speech',
  'face drooping',
  'বুকে ব্যথা',
  'বুক ব্যথা',
  'শ্বাসকষ্ট',
  'শ্বাস নিতে পারছি না',
  'অজ্ঞান',
  'খিঁচুনি',
  'রক্তবমি',
  'মুখ বেঁকে',
  'কথা জড়িয়ে',
];

bool aiIsEmergency(String text) {
  final normalized = text.toLowerCase();
  return _emergencyWords.any(normalized.contains);
}

const aiEmergencyNote =
    'This may be an emergency. Go to the nearest hospital or contact local emergency services now.';

/// উত্তরে রোগীর অ্যালার্জির ওষুধের নাম থাকলে সেটা ফিরিয়ে দেয়
String? aiAllergyHit(String reply, List<AiAllergy> allergies) {
  // Allergy names come from the English catalogue while the model usually
  // replies in Bengali, so a case-sensitive contains() misses real hits and
  // the safety note never appears.
  final normalized = reply.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  for (final a in allergies) {
    final name = a.name.trim();
    if (name.isEmpty) continue;
    if (normalized.contains(name.toLowerCase().replaceAll(RegExp(r'\s+'), ' '))) {
      return a.name;
    }
  }
  return null;
}

String aiBuildSystemPrompt({
  required AiPatient p,
  required AiDoctor doc,
  required List<AiCondition> conditions,
  required List<AiMedication> meds,
  required List<AiAllergy> allergies,
  String medicineContext = '',
  String languageCode = 'bn',
}) {
  String list<T>(Iterable<T> xs, String Function(T) f) =>
      xs.isEmpty ? 'None reported' : xs.map(f).join(', ');

  final cur = conditions.where((c) => c.type == 'current');
  final past = conditions.where((c) => c.type == 'past');

  final patientProfile = p.id == null
      ? 'No saved patient profile was selected. Do not assume personal health details.'
      : '''
Patient profile:
- Name: ${p.name}; age: ${p.age}${p.gender.isEmpty ? '' : '; gender: ${p.gender}'}
- Blood group: ${p.bloodGroup.isEmpty ? 'Unknown' : p.bloodGroup}
- Current conditions: ${list(cur, (c) => c.sinceYear == null ? c.name : '${c.name} (since ${c.sinceYear})')}
- Current medications: ${list(meds, (m) => '${m.name}, ${m.dose} ${m.unit}, ${m.timesPerDay} times/day (${m.dosageForm}; ${m.since})')}
- Medical history: ${list(past, (c) => c.sinceYear == null ? c.name : '${c.name} (since ${c.sinceYear})')}
- Allergies: ${list(allergies, (a) => a.name)}
Always repeat the exact allergy name from this list (English spelling is fine) whenever it is relevant to the advice.
''';
  final languageInstruction = languageCode == 'bn'
      ? 'Reply entirely in Bengali using clear, concise language.'
      : 'Reply entirely in English using clear, concise language.';
  final medicineInstruction = medicineContext.trim().isEmpty
      ? ''
      : '''

Medicine provided by the local catalogue:
$medicineContext
Ground medicine-specific answers in these supplied details. Do not invent missing facts or assume this medicine is prescribed to the patient.
''';

  return '''
You are ${doc.name}, ${doc.role}, an AI health assistant in a Bangladesh pharmacy app.
$languageInstruction

$patientProfile
$medicineInstruction

- Consider this profile when responding. Never recommend a listed allergy.
- Mention relevant interactions with current medications.
- Do not tell the patient to start, stop, or change a medication dose; advise discussing medication decisions with their clinician.
- If emergency symptoms (chest pain, difficulty breathing, fainting) are present, advise immediate in-person emergency care.
- When a visible skin concern, swelling, or wound needs more context, ask for a relevant photo and mention the photo button in chat.
- When an image is provided, describe only visible features. Do not make a definitive diagnosis, prescribe medication, or determine a dose from an image; state uncertainty and recommend in-person care when appropriate.
''';
}

class AiDoctorService {
  Future<String> reply({
    required AiDoctor doc,
    required String system,
    required List<AiChatMessage> history,
    required String userText,
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
  }) async {
    final msgs = <Map<String, dynamic>>[
      {'role': 'system', 'content': system},
      for (final m
          in history
              .where((m) => m.role != 'note')
              .toList()
              .reversed
              .take(12)
              .toList()
              .reversed)
        {'role': m.role, 'content': m.text},
      {
        'role': 'user',
        'content': imageBytes == null
            ? userText
            : [
                {'type': 'text', 'text': userText},
                {
                  'type': 'image_url',
                  'image_url': {
                    'url':
                        'data:$imageMimeType;base64,${base64Encode(imageBytes)}',
                  },
                },
              ],
      },
    ];

    final res = await http
        .post(
          Uri.parse('${AiDoctorConfig.baseUrl}/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${AiDoctorConfig.apiKey}',
          },
          body: jsonEncode({
            'model': doc.model,
            'messages': msgs,
            'temperature': 0.4,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (res.statusCode != 200) {
      throw Exception('AI error ${res.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    // Providers and captive portals can answer 200 with HTML, an empty
    // `choices` list or a non-Map body. Validate the shape before indexing so
    // a RangeError/TypeError never escapes as an uncatchable Error.
    if (decoded is! Map) {
      throw const FormatException('AI response was not a JSON object');
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw const FormatException('AI response did not contain a choice');
    }
    final message = (choices.first as Map)['message'];
    if (message is! Map) {
      throw const FormatException('AI response did not contain a message');
    }
    final content = message['content'];
    if (content is String) return content.trim();
    if (content is List) {
      return content
          .whereType<Map>()
          .where((part) => part['type'] == 'text')
          .map((part) => part['text']?.toString() ?? '')
          .where((text) => text.isNotEmpty)
          .join('\n')
          .trim();
    }
    throw const FormatException('AI response did not contain text');
  }
}
