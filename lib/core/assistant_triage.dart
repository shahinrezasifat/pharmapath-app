/// Doctor-style multi-turn triage for the PharmaPath assistant.
///
/// Before any medicine or treatment plan is suggested, the assistant runs a
/// structured interview — duration, severity, associated symptoms, age band,
/// and risk factors — so recommendations only happen once enough clinical
/// detail is on record.
library;

import 'assistant_diseases.dart';

/// Ordered interview questions for a recognised (or general) complaint.
class TriagePlan {
  const TriagePlan({
    required this.entry,
    required this.questions,
    this.isGeneral = false,
  });

  final ConditionEntry? entry;
  final List<String> questions;
  final bool isGeneral;

  String get labelBn =>
      entry?.bn.firstOrNull ?? entry?.lessonId ?? 'সাধারণ লক্ষণ';
}

const String _ageQ =
    'রোগীর বয়স-শ্রেণি কোনটা? (শিশু / কিশোর / প্রাপ্তবয়স্ক / ৬০+)';
const String _weightQ = 'ডোজ ঠিকমতো দিতে বলুন—রোগীর আনুমানিক ওজন কত কেজি?';
const String _riskQ =
    'গর্ভাবস্থা বা বুকের দুধ খাওয়ানো, কোনো ঔষধ/খাবারের অ্যালার্জি, অথবা '
    'আগে থেকে ডায়াবেটিস / উচ্চ রক্তচাপ / কিডনি / লিভার / হৃদরোগ—এগুলোর '
    'কিছু প্রযোজ্য কি? (না হলে “না” লিখুন)';
const String _medicationQ =
    'এখন কোনো ঔষধ বা ঘরোয়া চিকিৎসা চলছে কি? চললে নাম ও ডোজ লিখুন।';
const String _urgencyQ =
    'জরুরি কোনো লক্ষণ আছে কি—শ্বাসকষ্ট, বুকব্যথা, অজ্ঞান হওয়া, খিঁচুনি, '
    'অতিরিক্ত রক্তপাত, বা মুখ-জিভ ফুলে যাওয়া?';

/// User can explicitly end the interview early — but only after enough
/// answers AND the safety-critical slots are on record (see [safetyGaps]).
final RegExp _finishCue = RegExp(
  r'(যথেষ্ট|বাকি নাই|ব্যাকি নাই|শেষ করো|পরামর্শ দাও|ওষুধ বলো|ঔষধ বলো|'
  r'সমাধান দিন|সমাধান দাও|ওষুধ দিন|ঔষধ দিন|কি খাব|কী খাব|কি করব|কী করব|'
  r'সাজেস্ট করো|ডায়াগনোসিস|enough|suggest now|finish interview|solution|treatment)',
  caseSensitive: false,
);

bool _hasDuration(String q) => RegExp(
  r'(দিন|সপ্তাহ|ঘণ্টা|মাস|বছর|ধরে|week|hour|month|day)',
  caseSensitive: false,
).hasMatch(q);

/// Informational / medicine-name lookups skip the interview.
final RegExp _infoWord = RegExp(
  r'(^|\s)(কি|কী|কেন|কিভাবে|কীভাবে|নাম|what|why|how|which)(\s|$|\?|।)',
  caseSensitive: false,
);

/// Rough symptom phrasing — triggers a general interview when no disease matches.
final RegExp _symptomCue = RegExp(
  r'(ব্যথা|জ্বর|বমি|কাশি|সর্দি|ডায়রিয়া|পাতলা|শ্বাস|চুলকানি|ফোলা|রক্ত|'
  r'মাথা|পেট|গলা|প্রস্রাব|দুর্বল|অসুস্থ|লেগেছে|হয়েছে|pain|fever|vomit|'
  r'cough|diarrhea|rash|ache|sick|hurt|swollen)',
  caseSensitive: false,
);

bool wantsFinish(String answer) => _finishCue.hasMatch(answer);

/// True when the answer dodges the question (“জানা নাই / মনে নাই”) — the
/// slot stays unfilled and the doctor re-asks in plainer terms.
bool isDodging(String answer) => _dodgeCue.hasMatch(answer);

/// Slots a bare হ্যাঁ/না genuinely completes — the flag is either present or
/// not, so a one-word answer there is not “vague”.
const Set<TriageSlot> _yesNoSlots = {
  TriageSlot.urgency,
  TriageSlot.risk,
  TriageSlot.medication,
  TriageSlot.history,
  TriageSlot.associated,
};

/// Whole-answer fillers that carry no clinical detail at all.
const Set<String> _fillerAnswers = {
  'হ্যাঁ',
  'হ্যা',
  'yes',
  'y',
  'না',
  'নেই',
  'ok',
  'oke',
  'ঠিক',
  'ঠিক আছে',
  'ভালো',
  'ভালই',
  'অল্প',
  'সামান্য',
  'বেশি',
  'খারাপ',
  'আছে',
  'হচ্ছে',
  'হয়নি',
  'জানা',
  'মনে',
};

/// Proof that a descriptive slot really got its detail — a number, a duration
/// unit, a severity/quality/location word. Bengali numerals count too.
final RegExp _specificCue = RegExp(
  r'([\u09e6-\u09ef0-9]|দিন|সপ্তাহ|মাস|বছর|ঘণ্টা|ক্ষণ|শিশু|কিশোর|প্রাপ্তবয়স্ক|'
  r'৬০|হালকা|মাঝারি|তীব্র|ছুরি|ধকধক|যন্ত্রণা|পোড়া|একপাশ|দুইপাশ|মাঝ|'
  r'হঠাৎ|ধীরে|খাওয়া|চাপ|ঘুম|অ্যালার্জি|ডায়াবেটিস|প্রেশার|কিডনি|কিডনি|লিভার|'
  r'হৃদরোগ|গর্ভ|দুধ|কেজি|বার)',
);

/// A single word answer like “হ্যাঁ” or “বেশি” to a question that needs a
/// description. Such an answer leaves the clinical slot empty, so the doctor
/// must clarify it instead of rolling on to the next scripted question.
bool isVagueAnswer(String question, String answer) {
  final said = answer.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (said.isEmpty) return true;
  // The dodge and red-flag probes own those answers.
  if (_dodgeCue.hasMatch(said) || _redFlagCue.hasMatch(said)) return false;
  if (_yesNoSlots.contains(slotOf(question))) return false;
  final lower = said.toLowerCase().replaceAll(RegExp(r'[।.,!?]+'), '').trim();
  final flat = lower.replaceAll(RegExp(r'\s+'), '');
  final words = _tokens(lower);
  if (words.isEmpty) return true;
  // Anything the patient picked from the chips offered for this question is a
  // complete answer, however short.
  for (final option in quickRepliesFor(question)) {
    if (option.toLowerCase().replaceAll(RegExp(r'\s+'), '').startsWith(flat)) {
      return false;
    }
  }
  if (_specificCue.hasMatch(lower)) return false;
  return _fillerAnswers.contains(lower) || words.length <= 1;
}

/// Clinical slots every question maps to. The interview is only “100%
/// confident” when each slot present in the plan has a real answer.
enum TriageSlot {
  duration,
  severity,
  quality,
  location,
  onset,
  associated,
  triggers,
  history,
  urgency,
  age,
  weight,
  medication,
  risk,
  observation,
}

/// Which clinical detail a question is collecting.
TriageSlot slotOf(String question) {
  if (question == _ageQ) return TriageSlot.age;
  if (question == _riskQ) return TriageSlot.risk;
  if (question == _medicationQ) return TriageSlot.medication;
  if (question == _urgencyQ) return TriageSlot.urgency;
  if (question.contains('ওজন')) return TriageSlot.weight;
  if (question.contains('ছুরি') ||
      question.contains('ধকধক') ||
      question.contains('যন্ত্রণা') ||
      question.contains('পোড়া') ||
      question.contains('ফাঁস লাগা')) {
    return TriageSlot.quality;
  }
  if (question.contains('কোথায়') || question.contains('জায়গায়')) {
    return TriageSlot.location;
  }
  if (question.contains('বয়স')) return TriageSlot.age;
  if (question.contains('হঠাৎ') || question.contains('ধীরে ধীরে')) {
    return TriageSlot.onset;
  }
  if (question.contains('কীসে') || question.contains('বাড়ে')) {
    return TriageSlot.triggers;
  }
  if (question.contains('পুরোনো') || question.contains('ইতিহাস')) {
    return TriageSlot.history;
  }
  if (question.contains('তীব্রতা') ||
      question.contains('তীব্র (হালকা') ||
      question.contains('হালকা / মাঝারি / তীব্র')) {
    return TriageSlot.severity;
  }
  if (_hasDuration(question)) return TriageSlot.duration;
  if (question.contains('সাথে') ||
      question.contains('আছে কি') ||
      question.contains('কী কী')) {
    return TriageSlot.associated;
  }
  return TriageSlot.observation;
}

/// Slots a doctor can never prescribe without — even if the patient is in a
/// hurry and asks to finish the interview.
const Set<TriageSlot> kSafetyCriticalSlots = {
  TriageSlot.urgency,
  TriageSlot.age,
  TriageSlot.risk,
};

/// Answers that dodge a question — the doctor re-asks instead of accepting.
final RegExp _dodgeCue = RegExp(
  r'(জানা নাই|জানি না|মনে নাই|ঠিক বলতে পার(ব|েন) না|যাই বলুন)',
  caseSensitive: false,
);

/// Red flags hidden inside an ordinary answer — demand an immediate focused
/// follow-up before anything else moves on.
final RegExp _redFlagCue = RegExp(
  r'(রক্তপাত|রক্ত উ(ঠলে|ঠে)|শ্বাস কষ্ট|শ্বাসকষ্ট|অজ্ঞান|খিঁচুনি|প্রল্যাপ্ত|'
  r'বুক ব্যথা|বুকব্যথা|নীল হয়ে|ফুলা যাওয়া|তীব্র ঠান্ডা)',
  caseSensitive: false,
);

/// One dynamic follow-up question the doctor asks after hearing the patient's
/// answer — null when the answer needs no probing. Never re-asks the same
/// question text; the controller caps how many are inserted.
String? followUpFor(String question, String answer) {
  final a = answer.trim();
  if (a.isEmpty) return null;
  // A red flag in a non-urgency answer: focus on it right away.
  if (question != _urgencyQ && _redFlagCue.hasMatch(a)) {
    return 'আপনি যে-বিষয়টা বললেন সেটা দ্রুত জানা দরকার—এটা আজই প্রথম বার '
        'হচ্ছে, না আগেও এমন হয়েছে? এখনও কি সেই অবস্থা চলছে?';
  }
  // Dodged answer: re-ask plainly, one short either/or form.
  if (_dodgeCue.hasMatch(a)) {
    final slot = slotOf(question);
    switch (slot) {
      case TriageSlot.duration:
        return 'ঠিক আছে, আনুমানিকই বলুন—সমস্যাটা এক-দুই দিনের, এক সপ্তাহের '
            'বেশি, না তারও অনেক দিনের?';
      case TriageSlot.severity:
        return 'সংখ্যা না বলেও বলা যায়—স্বাভাবিক কাজ-কর্ম (চলাফেরা, খাওয়া, '
            'ঘুম) কি এই সমস্যায় বেশি ব্যাহত হয়, না তেমন না?';
      case TriageSlot.age:
        return 'শুধু একটা কথা বললেই হবে—রোগী কি ১২ বছরের কম, ১২-৬০-এর '
            'মধ্যে, না ৬০-এর বেশি?';
      default:
        return 'এক বাক্যে সংক্ষেপে বলুন—এ বিষয়ে এখন পর্যন্ত যা মনে আছে সেটাই।';
    }
  }
  final slot = slotOf(question);
  // A bare “হ্যাঁ” to a yes/no question says something exists but says nothing
  // about it — a doctor never moves on without knowing what.
  if (_yesNoSlots.contains(slot) && _bareAffirmation.hasMatch(a)) {
    return 'যে-বিষয়টা স্বীকার করলেন সেটা একটু বুঝি—ঠিক কী হচ্ছে, কতটা, '
        'আর এখনও চলছে কি?';
  }
  // A filler answer to a descriptive question leaves the slot empty: ask the
  // very same detail again in a form that cannot be answered with one word.
  if (isVagueAnswer(question, a)) return clarifyQuestionFor(question);
  // “তীব্র” severity: quantify the impact like a clinician would.
  if (slotOf(question) == TriageSlot.severity &&
      RegExp(r'তীব্র|বেশি|অসহ্য|খুব খারাপ').hasMatch(a) &&
      !_redFlagCue.hasMatch(a)) {
    return 'এই তীব্রতায় কি খাওয়া-দাওয়া, ঘুম বা কাজ একেবারে ব্যাহত হয়েছে? '
        'গত ২৪ ঘণ্টায় অবস্থা আগের চেয়ে ভালো, না খারাপ হয়েছি?';
  }
  // Nothing relieves it: that itself is a clinical signal worth pinning down.
  if (slotOf(question) == TriageSlot.triggers &&
      RegExp(r'কিছুতেই|কমে না|থামনা|সারাদিন|দিনভর|পরিষ্কার না').hasMatch(a)) {
    return 'যেহেতু কিছুতেই স্বস্তি হয় না—গত ২৪ ঘণ্টায় তীব্রতা কি আগের '
        'মতোই আছে, না ক্রমশ বাড়ছে? শেষ এক সপ্তাহে এমন কতদিন লেগেছে?';
  }
  // Vision / light-sound complaints: separate aura from photophobia.
  if (RegExp(r'ঝাপসা|দৃষ্টি|অরা|আলো|শব্দ').hasMatch(a) &&
      slotOf(question) != TriageSlot.location &&
      slotOf(question) != TriageSlot.urgency) {
    return 'চোখ-দৃষ্টি নিয়ে একটু বুঝি—ব্যথা শুরুর আগে চোখের সামনে ঝাপসা '
        'বা ঢেউখেলানো পর্দা দেখা যায়, না ব্যথার সময় শুধু আলো-শব্দে '
        'কষ্ট হয়?';
  }
  return null;
}

/// Bare হ্যাঁ-style agreement with no substance behind it.
final RegExp _bareAffirmation = RegExp(
  r'^(হ্যাঁ|হ্যা|yes|y|আছে|হচ্ছে|হয়েছে|লাগছে|ব্যথা আছে)[।.!\s]*$',
  caseSensitive: false,
);

/// The same clinical slot asked again, in a form one word cannot answer. Each
/// wording keeps its slot's own cue word, so the clarifying question still
/// maps back to the detail it is collecting (see [slotOf]).
String clarifyQuestionFor(String question) {
  return switch (slotOf(question)) {
    TriageSlot.duration =>
      'আমি ঠিক নিশ্চিত হইনি—এই সমস্যাটা কতদিন ধরে চলছে? দিন, সপ্তাহ না '
          'মাস—যেকোনো একটা বলে দিলেই হবে।',
    TriageSlot.severity =>
      'তীব্রতাটা একটু বুঝি—১০-এর মধ্যে কত, আর দিনে কতক্ষণ এমন থাকে?',
    TriageSlot.quality =>
      'ব্যথা-অস্বস্তির ধরনটা আবার বলুন—ছুরি মারার মতো, যন্ত্রণা-চাপ, '
          'পোড়া, না ধকধক?',
    TriageSlot.location =>
      'ঠিক কোন জায়গায় সমস্যাটা বেশি? আঙুল দিয়ে দেখালে বলতে পারবেন?',
    TriageSlot.onset => 'শুরুটা কেমন হয়েছিল—হঠাৎ, না ধীরে ধীরে বেড়েছে?',
    TriageSlot.triggers =>
      'কীসে সমস্যাটা বাড়ে, আর কীসে একটু কমে—এক বাক্যে বলবেন?',
    TriageSlot.age =>
      'বয়স-শ্রেণিটা আবার বলুন—শিশু, কিশোর, প্রাপ্তবয়স্ক, না ৬০+?',
    TriageSlot.weight => 'ডোজ ঠিক করতে ওজনটা দরকার—আনুমানিক কত কেজি?',
    _ => 'এক-দুই বাক্যে একটু বুঝিয়ে বলুন—ঠিক কী অনুভূত হচ্ছে, কেমন লাগে?',
  };
}

/// Short tap-to-answer chips for structured questions (telemedicine-style
/// quick replies). Empty list for free-text questions.
List<String> quickRepliesFor(String question) {
  switch (slotOf(question)) {
    case TriageSlot.duration:
      return const ['আজ/গতরাত', '২-৩ দিন', '১ সপ্তাহের মতো', 'তারও বেশি'];
    case TriageSlot.severity:
      if (question.contains('১০')) {
        return const ['১-৩ (সহনীয়)', '৪-৬ (মাঝারি)', '৭-১০ (তীব্র)'];
      }
      return const ['হালকা', 'মাঝারি', 'তীব্র'];
    case TriageSlot.quality:
      return const ['ধকধক/থলকথলক', 'ছুরি মারার মতো', 'যন্ত্রণা-চাপ', 'পোড়া'];
    case TriageSlot.location:
      return const ['একপাশে', 'দুইপাশে', 'মাঝ বরাবর/সাধারণ'];
    case TriageSlot.onset:
      return const ['হঠাৎ', 'ধীরে ধীরে'];
    case TriageSlot.triggers:
      return const [
        'খাওয়া-দাওয়ার সাথে',
        'চাপ-কষ্ট/ঘুমের অভাবে',
        'কিছুতেই পরিষ্কার না',
      ];
    case TriageSlot.age:
      return const ['শিশু (০-১২)', 'কিশোর (১৩-১৯)', 'প্রাপ্তবয়স্ক', '৬০+'];
    case TriageSlot.weight:
      return const ['১০-২০ কেজি', '২১-৪০ কেজি', '৪১-৬০ কেজি', '৬১+ কেজি'];
    case TriageSlot.urgency:
    case TriageSlot.risk:
    case TriageSlot.medication:
      return const ['না', 'হ্যাঁ — বিস্তারিত লিখছি'];
    case TriageSlot.history:
      return const ['না, আগে হয়নি', 'হ্যাঁ — বিস্তারিত লিখছি'];
    case TriageSlot.associated:
      return const ['না, অন্য লক্ষণ নেই', 'হ্যাঁ — লিখছি'];
    case TriageSlot.observation:
      // A couple of common structured clinical readings get chips too.
      if (question.contains('ডিগ্রি') || question.contains('Fahrenheit')) {
        return const ['৯৯-১০০', '১০১-১০২', '১০৩+'];
      }
      if (question.contains('রঙ')) {
        return const ['সাদা', 'হলুদ/সবুজ', 'রক্তাভ'];
      }
      return const [];
  }
}

/// Checks if the input is a pure greeting or pleasantry (e.g. হ্যালো, হাই,
/// আসসালামু আলাইকুম, কেমন আছেন ডাক্তার, hello doc).
bool isGreetingQuery(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return false;

  // Medical symptoms, complaints, or medicine inquiries are never pure greetings
  final medicalCues = RegExp(
    r'(জ্বর|ব্যথা|ব্যাথা|কাশি|ঠান্ডা|সর্দি|বমি|ডায়রিয়া|ডায়রিয়া|প্রেসার|'
    r'গ্যাস|গ্যাস্ট্রিক|পেট|মাথা|ওষুধ|ঔষধ|ট্যাবলেট|খাব|ডোজ|ইনফেকশন|রক্ত|ক্যান্সার|'
    r'fever|pain|cough|cold|vomit|diarrhea|medicine|tablet|dose)',
    caseSensitive: false,
  );
  if (medicalCues.hasMatch(q)) return false;

  final words = RegExp(r'[\u0980-\u09FFa-zA-Z]+')
      .allMatches(q)
      .map((m) => m.group(0)!.toLowerCase())
      .toList();
  if (words.isEmpty) return false;

  const greetingTokens = {
    'হ্যালো', 'হাই', 'হে', 'সালাম', 'আসসালামু', 'আলাইকুম', 'আসসালামুআলাইকুম',
    'ওয়ালাইকুম', 'ওয়ালাইকুমআসসালাম', 'আদাব', 'নমস্কার',
    'কেমন', 'আছেন', 'ভালো', 'ভাল', 'আছো', 'শুনছেন', 'সাহেব', 'বাবু', 'ডাক্তার',
    'ডাক্তারসাহেব', 'ডাক্তারবাবু', 'স্যার', 'ভাই', 'আপু',
    'hello', 'hi', 'hey', 'greetings', 'good', 'morning', 'afternoon', 'evening',
    'doc', 'doctor', 'sir', 'how', 'are', 'you'
  };

  const strongTerms = {
    'হ্যালো', 'হাই', 'হে', 'সালাম', 'আসসালামু', 'আসসালামুআলাইকুম', 'ওয়ালাইকুম',
    'আদাব', 'নমস্কার', 'hello', 'hi', 'hey', 'greetings', 'doc', 'doctor', 'কেমন'
  };

  final hasStrong = words.any((w) => strongTerms.contains(w));
  if (!hasStrong) return false;

  return words.every((w) => greetingTokens.contains(w));
}

/// Checks if the input is an expression of gratitude or a farewell
bool isGratitudeOrFarewell(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return false;

  final medicalCues = RegExp(
    r'(জ্বর|ব্যথা|ব্যাথা|কাশি|ঠান্ডা|সর্দি|বমি|ডায়রিয়া|ডায়রিয়া|প্রেসার|'
    r'গ্যাস|গ্যাস্ট্রিক|পেট|মাথা|ওষুধ|ঔষধ|ট্যাবলেট|খাব|ডোজ|ইনফেকশন|রক্ত|'
    r'fever|pain|cough|cold|vomit|diarrhea|medicine|tablet|dose)',
    caseSensitive: false,
  );
  if (medicalCues.hasMatch(q)) return false;

  final words = RegExp(r'[\u0980-\u09FFa-zA-Z]+')
      .allMatches(q)
      .map((m) => m.group(0)!.toLowerCase())
      .toList();
  if (words.isEmpty) return false;

  const farewellTokens = {
    'ধন্যবাদ', 'অনেক', 'অনেকধন্যবাদ', 'থ্যাংকস', 'থ্যাংকইউ', 'থ্যাঙ্কস',
    'বিদায়', 'বিদায়', 'আল্লাহহাফেজ', 'আল্লাহ', 'হাফেজ', 'ভালো', 'ভাল',
    'থাকবেন', 'ডাক্তার', 'স্যার', 'ভাই', 'আপু',
    'thanks', 'thank', 'you', 'thx', 'bye', 'goodbye', 'doc', 'doctor'
  };

  const strongFarewell = {
    'ধন্যবাদ', 'অনেকধন্যবাদ', 'থ্যাংকস', 'থ্যাংকইউ', 'থ্যাঙ্কস',
    'বিদায়', 'বিদায়', 'আল্লাহহাফেজ', 'হাফেজ', 'থাকবেন',
    'thanks', 'thank', 'thx', 'bye', 'goodbye'
  };

  final hasStrong = words.any((w) => strongFarewell.contains(w));
  if (!hasStrong) return false;

  return words.every((w) => farewellTokens.contains(w));
}

/// Checks if the query is asking about a medicine, its details, or its dosage
bool isMedicineOrDoseQuery(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return false;

  // Dose, timing, administration keywords
  final dosePattern = RegExp(
    r'(ডোজ|মাত্রা|কীভাবে খাব|কিভাবে খাব|কয়টা খাব|কয়টা খাব|কয়বার|কয়বার|কয়বেলা|কয়বেলা|'
    r'খাওয়ার নিয়ম|খাওয়ার নিয়ম|খাবারের আগে|খাবারের পরে|খালি পেটে|ভরা পেটে|'
    r'কতটুকু|কতদিন খাব|খেতে হয়|খেতে হবে|কত মিলি|ট্যাবলেট|সিরাপ|ক্যাপসুল|ইনজেকশন|'
    r'dose|dosage|how to take|when to take|how many|frequency|mg|tablet|syrup|capsule)',
    caseSensitive: false,
  );
  if (dosePattern.hasMatch(q)) return true;

  // Question pattern about medicine function
  final medicineQuestion = RegExp(
    r'(কিসের ওষুধ|কীসের ওষুধ|কী ওষুধ|কি ওষুধ|ওষুধের কাজ|কাজে লাগে|কিসের জন্য)',
    caseSensitive: false,
  );
  if (medicineQuestion.hasMatch(q)) return true;

  // Common Bangla medicine names
  const banglaMeds = {
    'নাপা', 'এইস', 'সিকলো', 'সেক্লো', 'ওমিপ্রাজল', 'ম্যাক্সপ্রো', 'এসোমিপ্রাজল',
    'নেক্সাম', 'প্যানটোনিক্স', 'প্যান্টোপ্রাজল', 'এন্টাসিড', 'মোনাস', 'মন্টেলুকাস্ট',
    'ফেক্সো', 'ফেক্সোফেনাডিন', 'হিস্টাসিন', 'সিটিরিজিন', 'অ্যালাট্রোল', 'এলার্ট্রল',
    'ফ্ল্যাজিল', 'ফ্লাজিল', 'মেট্রোনিডাজল', 'মেট্রোজিল', 'অ্যাজিথ্রোমাইসিন', 'এজিথ্রো',
    'সিপ্রোসিন', 'সিপ্রোফ্লক্সাসিন', 'অ্যামোক্সিসিলিন', 'মক্সাসিল', 'সিভিট',
    'জিংক', 'স্যালাইন', 'ডাইক্লোফেনাক', 'আইবুপ্রোফেন', 'সালবিউটামল', 'ভেন্টোলিন',
    'অ্যামব্রোক্সল', 'ডমপেরিডন', 'অনডানসেট্রন', 'টুস্কা', 'ক্লোনাজিপাম', 'প্যারাসিটামল'
  };

  for (final med in banglaMeds) {
    if (q.contains(med)) return true;
  }

  // Common Latin medicine tokens
  final latinMeds = RegExp(
    r'\b(napa|ace|seclo|maxpro|monas|fexo|flagyl|ceevit|ors|flexi|pantonix|'
    r'paracetamol|omeprazole|esomeprazole|pantoprazole|antacid|montelukast|'
    r'fexofenadine|cetirizine|metronidazole|azithromycin|ciprofloxacin|amoxicillin|'
    r'ibuprofen|diclofenac|salbutamol|ambroxol|domperidone|ondansetron)\b',
    caseSensitive: false,
  );
  if (latinMeds.hasMatch(q)) return true;

  return false;
}

bool looksLikeInfoQuery(String query) {
  final q = query.trim();
  if (q.isEmpty) return false;
  return _infoWord.hasMatch(q) && !_hasDuration(q) && !_symptomCue.hasMatch(q);
}

bool looksLikeSymptoms(String query) {
  final q = query.trim();
  if (q.isEmpty) return false;
  if (isGreetingQuery(q) || isGratitudeOrFarewell(q)) return false;
  if (isMedicineOrDoseQuery(q)) return false;
  if (looksLikeInfoQuery(q)) return false;
  return _symptomCue.hasMatch(q) || findEntry(q) != null;
}

/// Minimum answered questions before the user may even attempt to finish.
const int kMinAnswersBeforeFinish = 1;

/// Fraction of the scripted plan that must be answered before auto-finalize.
const double kConfidenceThreshold = 0.6;

double interviewConfidence({required int answered, required int total}) {
  if (total <= 0) return 1;
  return (answered / total).clamp(0.0, 1.0);
}

/// Questions (from the full catalogue) that cover a safety slot still
/// unanswered — used to auto-repair the plan when a patient tries to skip.
String? safetyQuestionFor(TriageSlot slot) => switch (slot) {
  TriageSlot.urgency => _urgencyQ,
  TriageSlot.age => _ageQ,
  TriageSlot.weight => _weightQ,
  TriageSlot.risk => _riskQ,
  _ => null,
};

/// Safety slots still missing after everything asked so far.
List<TriageSlot> missingSafetySlots(Set<TriageSlot> answeredSlots) => [
  for (final slot in kSafetyCriticalSlots)
    if (!answeredSlots.contains(slot)) slot,
];

/// Shown by the doctor when the plan is complete: reassurance that the
/// interview actually happened before any medicine is named.
String finalisePreamble({required bool fullyConfident}) => fullyConfident
    ? 'ধন্যবাদ — আপনার দেওয়া তথ্যে আমার প্রয়োজনীয় সব ক্লিনিক্যাল বিবরণ পাওয়া '
          'গেছে। এখন সম্ভাব্য অবস্থা, পরীক্ষা-নিরীক্ষা ও চিকিৎসার কথা বলছি।'
    : 'আপনি তাড়া দিচ্ছেন বুঝতে পারছি। তবু কিছু জরুরি তথ্য অসম্পূর্ণ রাখার '
          'কারণে সাবধানী সংস্করণ বলছি—প্রয়োজনে কাছেের কোনো চিকিৎসককে দেখান।';

/// The doctor's deterministic turn after hearing an answer — used when the
/// model is unreachable, and as the safety net when its reply arrived without
/// the scripted question.
///
/// It echoes the patient's own words back (nothing they typed is silently
/// dropped), adds a one-line clinical read of that specific answer, then asks
/// the next scripted question verbatim so the interview cannot stall.
String acknowledgeAnswer({
  required String question,
  required String answer,
  required String nextQuestion,
}) {
  final buffer = StringBuffer(answerEcho(question, answer));
  final next = nextQuestion.trim();
  if (next.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln()
      ..write(next);
  }
  return buffer.toString();
}

/// The doctor's "I heard you" line: the patient's own words quoted back, plus
/// a one-line clinical read of that specific answer. Used both offline and to
/// repair a model reply that skipped straight past what the patient said.
String answerEcho(String question, String answer) {
  final said = answer.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (said.isEmpty) return 'এই প্রশ্নটির উত্তর পাওয়া যায়নি।';
  final clipped = said.length <= 110 ? said : '${said.substring(0, 110)}…';
  return 'আপনি বলেছেন—“$clipped”। ${_readingFor(question, said)}';
}

/// Words that prove the doctor engaged with this answer instead of rolling
/// straight on to the next question. Bare “বুঝেছি”/“ঠিক আছে” is deliberately
/// absent — that is exactly the brush-off the persona forbids.
final RegExp _ackCue = RegExp(
  r'(আপনি বলেছেন|আপনি বলছেন|আপনার বলা|আপনি যে|আপনি যেহেতু|নোট করলাম|'
  r'খেয়াল করছি|খেয়াল রাখছি|মনে রাখছি|বিবেচনায় রাখছি|বুঝতে পারছি|'
  r'বুঝে নিলাম|বুঝলাম|পরিষ্কার হলো|হলো|পারলাম|ধরতে পারলাম|রাখছি)',
);

/// Content words of an utterance — numbers, symptom names, body parts. Grammatical
/// filler is dropped so a shared word really means the two texts match up.
List<String> _tokens(String text) => text
    .toLowerCase()
    .split(RegExp(r'[^0-9a-z\u0980-\u09ff]+'))
    .where((word) => word.trim().isNotEmpty)
    .toList();

/// Distinctive vocabulary: tokens long enough to carry meaning.
List<String> _distinctiveWords(String text) =>
    _tokens(text)
        .where((word) => word.length >= 3 && !kEchoFiller.contains(word))
        .toList();

const Set<String> kEchoFiller = {
  'আছে',
  'হচ্ছে',
  'হয়েছে',
  'হয়',
  'ছিল',
  'আর',
  'করে',
  'করি',
  'করেন',
  'খুব',
  'বেশি',
  'একটু',
  'কিছু',
  'তবে',
  'কিন্তু',
  'আমি',
  'আমার',
  'আপনি',
  'আপনার',
  'কখন',
  'কেমন',
  'যেহেতু',
  'কারণ',
  'আগে',
  'এখন',
  'in',
  'the',
  'and',
  'with',
  'have',
  'not',
  'for',
  'but',
  'from',
  'was',
  'my',
  'i',
  'it',
  'is',
  'of',
  'to',
};

/// Did the reply actually read this answer — by quoting something the patient
/// said, or by carrying a real acknowledgement line?
bool readsAnswer(String text, String answer) {
  final body = text.toLowerCase();
  for (final word in _distinctiveWords(answer)) {
    if (body.contains(word)) return true;
  }
  return _ackCue.hasMatch(text);
}

/// The persona guarantee the system prompt asks for and a model cannot always
/// keep: every doctor turn must show it read the patient's answer. When the
/// reply is nothing but the next question, the patient's own words are echoed
/// in front of it, so no answer is ever silently skipped.
String withAnswerAcknowledgement({
  required String text,
  required String question,
  required String answer,
}) {
  final body = text.trim();
  if (body.isEmpty) return '';
  if (readsAnswer(body, answer)) return body;
  return '${answerEcho(question, answer)}\n\n$body';
}

/// Did the model ask the scripted question in its own words? Compared on
/// distinctive vocabulary, so a paraphrase counts as asked while a different
/// question can never let a scripted one go unasked.
bool asksAbout(String text, String question) {
  final script = _distinctiveWords(question);
  if (script.isEmpty) return false;
  // Only the model's closing question can stand in for the scripted one —
  // and only its own words count, never the acknowledgement before it.
  final tail = RegExp(r'[^?।]*\?\s*$').firstMatch(text)?.group(0) ?? '';
  final asked = _distinctiveWords(tail);
  if (asked.isEmpty) return false;
  double covered(List<String> from, List<String> into) {
    var hits = 0;
    for (final word in from) {
      if (into.any((other) => other.contains(word) || word.contains(other))) {
        hits++;
      }
    }
    return hits / from.length;
  }

  final forward = covered(script, asked);
  final back = covered(asked, script);
  return (forward > back ? forward : back) >= 0.5;
}

/// What the doctor takes away from one answer, by clinical slot.
String _readingFor(String question, String answer) {
  if (isDodging(answer)) {
    return 'তথ্যটা এখনো অস্পষ্ট—তবু বাকিটা বুঝে নিচ্ছি, দরকার হলে আবার '
        'জিজ্ঞেস করব।';
  }
  if (_redFlagCue.hasMatch(answer)) {
    return 'এই বিষয়টা আমি আলাদা করে খেয়াল রাখছি—নিরাপত্তার কথা মাথায় রেখেই '
        'পরের প্রশ্নটা করছি।';
  }
  return switch (slotOf(question)) {
    TriageSlot.duration => 'সময়কালটা এখন পরিষ্কার হলো।',
    TriageSlot.severity => 'তীব্রতাটা বুঝে নিলাম।',
    TriageSlot.quality => 'ব্যথার ধরনটা ধরতে পারলাম।',
    TriageSlot.location => 'জায়গাটা বুঝলাম।',
    TriageSlot.onset => 'শুরুটা কখন-কীভাবে হলো, বুঝে নিলাম।',
    TriageSlot.associated => 'সহগামী লক্ষণগুলোও নোট করলাম।',
    TriageSlot.triggers => 'কীসে বাড়ে-কমে, সেটাও মনে রাখছি।',
    TriageSlot.history => 'পুরোনো ইতিহাসটা নোট করলাম।',
    TriageSlot.urgency => 'জরুরি লক্ষণের বিষয়টা নিশ্চিত হলো।',
    TriageSlot.age => 'বয়স-শ্রেণিটা নোট করলাম।',
    TriageSlot.weight => 'ওজনটা হিসাবে রাখছি।',
    TriageSlot.medication => 'চলমান ঔষধের তথ্যটা মনে রাখছি।',
    TriageSlot.risk => 'ঝুঁকির বিষয়টা নোট করলাম।',
    TriageSlot.observation => 'লক্ষণটা নোট করলাম।',
  };
}

bool isInterviewComplete({
  required int answered,
  required int total,
  required bool userRequestedFinish,
  required Set<TriageSlot> answeredSlots,
}) {
  if (answered <= 0) return false;
  // Full confidence: every question in the plan has an answer.
  if (total > 0 && answered >= total) return true;
  // A hurried patient may finish early, but never without the three safety
  // slots (urgency, age and risk) on record. Those are the minimum needed to
  // decide whether this can wait for a doctor at all.
  if (userRequestedFinish &&
      kSafetyCriticalSlots.every(answeredSlots.contains)) {
    return true;
  }
  // No other shortcut: partial interviews stay open so the doctor never
  // prescribes from an incomplete history.
  return false;
}

List<String> _conditionOpeners(String lessonId, String query) {
  final hasDur = _hasDuration(query);
  switch (lessonId) {
    case 'fever':
      return [
        if (!hasDur) 'জ্বরটা কতদিন ধরে হচ্ছে এবং তাপমাত্রা কত উঠেছে?',
        'সাথে কি গা ব্যথা, কাঁপুনি, কাশি, বমি বা অন্য কোনো সমস্যা আছে?',
        'রোগীর বয়স কত এবং ইতিমধ্যে কোনো ওষুধ খেয়েছেন কি?',
        _weightQ,
      ];
    case 'cold-cough':
      return [
        if (!hasDur) 'কাশি বা সর্দি কতদিন থেকে হচ্ছে?',
        'কাশি কি শুকনো না কফযুক্ত? কফের রঙ কেমন?',
        'রোগীর বয়স কত? সাথে জ্বর, গলাব্যথা বা শ্বাসকষ্ট আছে কি?',
      ];
    case 'gerd':
    case 'peptic-ulcer':
      return [
        if (!hasDur) 'গ্যাস বা অ্যাসিডিটির সমস্যাটি কতদিন ধরে হচ্ছে?',
        'বুকে জ্বালাপোড়া, টক ঢেকুর, পেট ফাঁপা বা খাবার পর অস্বস্তি—কোনটি বেশি?',
        'রোগীর বয়স কত? সাথে কি তীব্র পেটব্যথা, বমি বা অন্য কোনো অসুখ আছে?',
      ];
    case 'diarrhea':
      return [
        if (!hasDur) 'পাতলা পায়খানা কতদিন থেকে এবং দিনে কতবার হচ্ছে?',
        'বমি, তীব্র পেটব্যথা বা পায়খানায় রক্ত আছে কি? মুখ-জিভ শুকিয়ে তৃষ্ণা লাগছে কি?',
        'রোগীর বয়স কত? খাবার স্যালাইন বা ওআরএস খাচ্ছেন কি?',
      ];
    case 'migraine':
    case 'headache':
      return [
        if (!hasDur) 'মাথাব্যথা কতদিন থেকে এবং কেমন (ধকধক, একপাশে না পুরো মাথায়)?',
        'ব্যথাটা ঠিক কোথায়—কপাল, চোখের পেছনে, নাকের চারপাশে, না পুরো মাথায়?',
        'শুরুটা কেমন—হঠাৎ করে এসেছে, না ধীরে ধীরে বেড়েছে?',
        'তীব্রতা ১০-এর মধ্যে কত? সাথে বমিভাব, চোখে ঝাপসা বা আলোতে অস্বস্তি আছে কি?',
        'কীসে ব্যথা বাড়ে বা কমে—আলো, শব্দ, ঘুমের অভাব, না খাবার?',
        'রোগীর বয়স কত? উচ্চ রক্তচাপ বা চোখের সমস্যার ইতিহাস আছে কি?',
        _weightQ,
      ];
    case 'dengue':
    case 'typhoid':
    case 'malaria':
      return [
        if (!hasDur) 'জ্বর কতদিন থেকে এবং তাপমাত্রা কত?',
        'তীব্র শরীরব্যথা, চোখের পেছনে ব্যথা, বা মাড়ি/ত্বকে কোনো রক্তবিন্দু আছে কি?',
        'রোগীর বয়স কত? সিবিসি বা কোনো রক্ত পরীক্ষা করিয়েছেন কি?',
      ];
    case 'uti':
      return [
        if (!hasDur) 'প্রস্রাবে জ্বালাপোড়া বা ব্যথা কতদিন থেকে হচ্ছে?',
        'ঘন ঘন প্রস্রাব হওয়া, তলপেটে বা কোমরে ব্যথা বা জ্বর আছে কি?',
        'রোগীর বয়স কত? দিনে পর্যাপ্ত পানি খাচ্ছেন কি?',
      ];
    case 'asthma':
    case 'copd':
    case 'pneumonia':
      return [
        'শ্বাসকষ্ট কতদিন থেকে এবং কখন বেশি হয় (রাতে না চলাফেরায়)?',
        'শ্বাসের সময় সাঁই-সাঁই শব্দ, জ্বর বা কফ আছে কি?',
        'রোগীর বয়স কত? আগে থেকে কোনো ইনহেলার নিচ্ছেন কি?',
      ];
    case 'heart-attack':
    case 'angina':
      return [
        'বুকে ব্যথা বা চাপ কতক্ষণ ধরে এবং তা কি বাম হাত, চোয়াল বা পিঠে ছড়িয়ে পড়ছে?',
        'সাথে অতিরিক্ত ঘাম, বমিভাব বা শ্বাসকষ্ট আছে কি?',
        'রোগীর বয়স কত? রক্তচাপ বা ডায়াবেটিস আছে কি?',
      ];
    case 'osteoarthritis':
    case 'gout':
    case 'rheumatoid-arthritis':
    case 'low-back-pain':
      return [
        if (!hasDur) 'ব্যথা বা ফোলাটি কতদিন ধরে হচ্ছে?',
        'শরীরের ঠিক কোথায় ব্যথা বেশি এবং তীব্রতা কেমন? গাঁটে ফোলা বা লালচে ভাব আছে?',
        'রোগীর বয়স কত? কীসে ব্যথা কমে এবং কীসে বাড়ে?',
      ];
    case 'type2-diabetes':
    case 'hypertension':
      return [
        'সমস্যাটা কতদিন থেকে এবং সাম্প্রতিক রিডিং (সুগার / ব্লাড প্রেশার) কত?',
        'এখন কোনো নিয়মিত ওষুধ চলছে কি না এবং রোগীর বয়স কত?',
        'মাথা ঘোরা, দৃষ্টি ঝাপসা বা অন্য কোনো অস্বস্তি হচ্ছে কি?',
      ];
    default:
      return [
        if (!hasDur) 'এই সমস্যাটি কতদিন ধরে দেখা দিচ্ছে?',
        'সমস্যাটির তীব্রতা কেমন এবং শরীরে ঠিক কোথায় অসুবিধা বেশি অনুভূত হচ্ছে?',
        'রোগীর বয়স কত এবং সাথে অন্য কোনো লক্ষণ (যেমন জ্বর, ব্যথা, বমি) আছে কি?',
      ];
  }
}

List<String> _generalOpeners(String query) {
  final hasDur = _hasDuration(query);
  return [
    if (!hasDur) 'আপনার এই শারীরিক সমস্যাটি কতদিন ধরে হচ্ছে?',
    'সমস্যার ধরন ও তীব্রতা কেমন এবং শরীরে ঠিক কোথায় অসুবিধা হচ্ছে?',
    'রোগীর বয়স কত এবং সাথে অন্য কোনো লক্ষণ বা বিপদ-সংকেত আছে কি?',
  ];
}

/// Builds an interview for a recognised condition, or null when the query is
/// an information / medicine-name lookup that should be answered directly.
TriagePlan? planFor(ConditionEntry entry, String query) {
  final q = query.trim();
  if (looksLikeInfoQuery(q) || isMedicineOrDoseQuery(q)) return null;

  final questions = _conditionOpeners(entry.lessonId, q);
  return TriagePlan(entry: entry, questions: questions);
}

/// General telemedicine interview when symptoms are described but no curated
/// condition entry matched.
TriagePlan generalPlan(String query) {
  final questions = _generalOpeners(query);
  return TriagePlan(entry: null, questions: questions, isGeneral: true);
}

/// First doctor turn: the complaint is echoed back in the patient's own words
/// (shortened) before the first question, so the very first reply proves the
/// description was read.
String openingAcknowledgement(String complaint) {
  final said = complaint.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (said.isEmpty) return 'আমি আপনার কথা মনোযোগ দিয়ে শুনছি।';
  final clipped = said.length <= 110 ? said : '${said.substring(0, 110)}…';
  return 'আপনি বলছেন—“$clipped”। আমি আপনার কথা মনোযোগ দিয়ে শুনছি।';
}

/// Empathetic opener shown before the first clinical question.
String interviewGreeting(TriagePlan plan) {
  final topic = plan.labelBn;
  return '“$topic” নিয়ে নিরাপদ পরামর্শ দিতে ডাক্তারের মতো কয়েকটি সংক্ষিপ্ত '
      'প্রশ্ন করব—সমস্যার ধরন, জায়গা, সময়কাল, তীব্রতা, সহগামী লক্ষণ, '
      'প্ররোচক কারণ, বয়স-ওজন ও পুরোনো ইতিহাস। '
      'ঔষধ বা চিকিৎসা পরিকল্পনা পরেই দেব, যখন প্রয়োজনীয় তথ্য সম্পূর্ণ হবে।\n\n'
      '${plan.questions.first}';
}
