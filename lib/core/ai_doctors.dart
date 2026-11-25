/// Every OxionAI cloud model dressed as a doctor.
///
/// The assistant's model picker shows these personas instead of raw ids:
/// each model gets a Bangla doctor name, a one-line clinical style, and a
/// ranking score — the models that reason best as doctors (deep analysis,
/// safe dosing judgement) sit at the top of the list. Unknown or newly
/// added ids still get a sensible family-based persona.
class AiDoctor {
  const AiDoctor({
    required this.model,
    required this.name,
    required this.rank,
    required this.blurb,
    required this.score,
  });

  final String model;

  /// Bangla doctor name, e.g. 'ডা. আফতাব উদ্দিন'.
  final String name;

  /// Seniority line, e.g. 'প্রধান পরামর্শক'.
  final String rank;

  /// One-line consultation style shown under the name.
  final String blurb;

  /// 0-100 “how good a doctor is this model” — drives the list order.
  final int score;

  /// First letter of the given name for the avatar circle.
  String get initial {
    final bare = name.replaceFirst('ডা. ', '').trim();
    if (bare.isEmpty) return 'ড';
    return String.fromCharCodes(bare.runes.take(1));
  }
}

/// Vision / audio capability heuristics for any model id (shared by the
/// picker badges and the live service getters).
bool modelHasVision(String id) {
  final s = id.toLowerCase();
  return s.contains('vision') ||
      s.contains('gpt-4o') ||
      s.contains('gpt-4.1') ||
      s.contains('gpt-5') ||
      s.contains('gemini') ||
      s.contains('claude') ||
      s.contains('gemma') ||
      s.contains('flash') ||
      s.contains('pro');
}

bool modelHasAudio(String id) {
  final s = id.toLowerCase();
  return s.contains('audio') ||
      s.contains('realtime') ||
      s.contains('gpt-4o') ||
      s.contains('gpt-5') ||
      s.contains('gemini');
}

/// Hand-mapped personas for the current OxionAI catalogue, then ranked.
/// Deeper-reasoning flagships lead (they best follow the long interview and
/// dose judgement); small/fast models are honest about being juniors.
const Map<String, AiDoctor> _knownDoctors = {
  'nvidia/nemotron-3-ultra-550b-a55b:free': AiDoctor(
    model: 'nvidia/nemotron-3-ultra-550b-a55b:free',
    name: 'ডা. আফতাব উদ্দিন',
    rank: 'প্রধান কনসালট্যান্ট · ফ্রি মডেল',
    blurb: 'এনভিডিয়া ৫৫০ বিলিয়ন ফ্ল্যাগশিপ—গভীর চিকিৎসা বিশ্লেষণ ও নির্ভুল পরামর্শ',
    score: 98,
  ),
  'nvidia/nemotron-3.5-super-vl:free': AiDoctor(
    model: 'nvidia/nemotron-3.5-super-vl:free',
    name: 'ডা. আরিফুল ইসলাম',
    rank: 'সিনিয়র কনসালট্যান্ট · ভিশন স্পেশালিস্ট',
    blurb: 'প্রেসক্রিপশন ও ওষুধের ছবি বুঝে চিকিৎসা পরামর্শ দেয়',
    score: 97,
  ),
  'nvidia/nemotron-3.5-lightning:free': AiDoctor(
    model: 'nvidia/nemotron-3.5-lightning:free',
    name: 'ডা. মাহমুদা খাতুন',
    rank: 'সিনিয়র কনসালট্যান্ট · ফ্রি মডেল',
    blurb: 'বিদ্যুৎগতির উচ্চ ক্ষমতাসম্পন্ন এআই ডাক্তার—বাংলায় দ্রুত পরামর্শ',
    score: 96,
  ),
  'liquid/lfm-2.5-2.6b:free': AiDoctor(
    model: 'liquid/lfm-2.5-2.6b:free',
    name: 'ডা. সোহেল রানা',
    rank: 'রেসিডেন্ট · ফ্রি মডেল',
    blurb: 'লিকুইড এআই—হালকা ও দ্রুত প্রাথমিক স্বাস্থ্য জিজ্ঞাসা',
    score: 85,
  ),
  'google/gemma-4-31b-it:free': AiDoctor(
    model: 'google/gemma-4-31b-it:free',
    name: 'ডা. সাজিদ করিম',
    rank: 'কনসালট্যান্ট · ফ্রি মডেল',
    blurb: 'গুগল গেমা ৩১বি—গভীর লক্ষণ বিশ্লেষণ ও স্বাস্থ্য সচেতনতা',
    score: 90,
  ),
  'google/gemma-4-26b-a4b-it:free': AiDoctor(
    model: 'google/gemma-4-26b-a4b-it:free',
    name: 'ডা. তানভীর আহমেদ',
    rank: 'রেসিডেন্ট · ফ্রি মডেল',
    blurb: 'গুগল গেমা ফ্রি সংস্করণ—দ্রুত ও সাবলীল প্রাথমিক স্বাস্থ্য পরামর্শ',
    score: 88,
  ),
  'meta-llama/llama-3.3-70b-instruct:free': AiDoctor(
    model: 'meta-llama/llama-3.3-70b-instruct:free',
    name: 'ডা. আশফাক চৌধুরী',
    rank: 'সিনিয়র কনসালট্যান্ট · ফ্রি মডেল',
    blurb: '৭০ বিলিয়ন প্যারামিটারের গভীর চিন্তাশক্তি—নির্ভুল লক্ষণ বিশ্লেষণ',
    score: 93,
  ),
  'deepseek/deepseek-r1:free': AiDoctor(
    model: 'deepseek/deepseek-r1:free',
    name: 'ডা. শাফায়াত হোসেন',
    rank: 'রিজনিং কনসালট্যান্ট · ফ্রি মডেল',
    blurb: 'ধাপে ধাপে কারণ খুঁজে গভীর স্বাস্থ্য পরামর্শ দেয়',
    score: 95,
  ),
  'deepseek/deepseek-chat:free': AiDoctor(
    model: 'deepseek/deepseek-chat:free',
    name: 'ডা. ফারদিন ইসলাম',
    rank: 'রেসিডেন্ট · ফ্রি মডেল',
    blurb: 'বাংলায় দ্রুত ও সাবলীল প্রাথমিক পরামর্শ',
    score: 89,
  ),
  'meta-llama/llama-3.1-8b-instruct:free': AiDoctor(
    model: 'meta-llama/llama-3.1-8b-instruct:free',
    name: 'ডা. আরিফুর রহমান',
    rank: 'রেসিডেন্ট · ফ্রি মডেল',
    blurb: 'হালকা ও দ্রুত প্রাথমিক স্বাস্থ্য বিশ্লেষণ',
    score: 82,
  ),
  'qwen/qwen-2.5-coder-32b-instruct:free': AiDoctor(
    model: 'qwen/qwen-2.5-coder-32b-instruct:free',
    name: 'ডা. তাহমিনা রহমান',
    rank: 'রেসিডেন্ট · ফ্রি মডেল',
    blurb: 'সুশৃঙ্খল ও কাঠামোগত প্রেসক্রিপশন বিশ্লেষণ',
    score: 84,
  ),
  'mistralai/mistral-7b-instruct:free': AiDoctor(
    model: 'mistralai/mistral-7b-instruct:free',
    name: 'ডা. নাঈম হাসান',
    rank: 'ইন্টার্ন · ফ্রি মডেল',
    blurb: 'সাধারণ স্বাস্থ্য জিজ্ঞাসা ও দ্রুত উত্তর',
    score: 78,
  ),
  'meta-llama/llama-3.2-3b-instruct:free': AiDoctor(
    model: 'meta-llama/llama-3.2-3b-instruct:free',
    name: 'ডা. পলাশ সাহা',
    rank: 'ইন্টার্ন · ফ্রি মডেল',
    blurb: 'হালকা সমস্যায় দ্রুত সাহায্যকারী',
    score: 72,
  ),
  'google/gemini-2.0-flash-001': AiDoctor(
    model: 'google/gemini-2.0-flash-001',
    name: 'ডা. আফিফ চৌধুরী',
    rank: 'সিনিয়র কনসালট্যান্ট',
    blurb: 'উচ্চগতির আধুনিক মাল্টিমডাল বিশ্লেষণ ও চিকিৎসা নির্দেশিকা',
    score: 92,
  ),
  'claude-opus-5.5': AiDoctor(
    model: 'claude-opus-5.5',
    name: 'ডা. আফতাব উদ্দিন',
    rank: 'প্রধান পরামর্শক',
    blurb: 'সবচেয়ে গভীর চিন্তা—জটিল ও মিশ্র লক্ষণে নিখুঁত ডোজ-বিচার',
    score: 97,
  ),
  'claude-opus-5': AiDoctor(
    model: 'claude-opus-5',
    name: 'ডা. রেহানা পারভীন',
    rank: 'প্রধান পরামর্শক',
    blurb: 'দীর্ঘ সাক্ষাৎকার ধরে রাখে, প্রতিটি উত্তর মিলিয়ে সিদ্ধান্ত দেয়',
    score: 95,
  ),
  'gpt-5.5-pro': AiDoctor(
    model: 'gpt-5.5-pro',
    name: 'ডা. ফারহান মালিক',
    rank: 'সিনিয়র কনসালট্যান্ট',
    blurb: 'ধীর কিন্তু পাকা—সন্দেহজনক কেসে একাধিক সম্ভাবনা তোলে',
    score: 94,
  ),
  'claude-mythos-preview': AiDoctor(
    model: 'claude-mythos-preview',
    name: 'ডা. মিশাল রহমান',
    rank: 'গবেষণা কনসালট্যান্ট',
    blurb: 'অত্যন্ত তীক্ষ্ণ, তবে পরীক্ষামূলক—সবসময় চোখ-কান খোলা রাখে',
    score: 93,
  ),
  'claude-opus-4.8': AiDoctor(
    model: 'claude-opus-4.8',
    name: 'ডা. কামরুল হাসান',
    rank: 'সিনিয়র কনসালট্যান্ট',
    blurb: 'নিরাপত্তা-প্রথমে বিশ্বস্ত—সতর্কতা ও পার্শ্বপ্রতিক্রিয়া এড়ায় না',
    score: 92,
  ),
  'gemini-3.1-pro': AiDoctor(
    model: 'gemini-3.1-pro',
    name: 'ডা. আরিফুল ইসলাম',
    rank: 'সিনিয়র কনসালট্যান্ট',
    blurb: 'ছবি-রোগ চেনায় দক্ষ—র‍্যাশ-ক্ষতের ফটো বুঝে প্রশ্ন সাজায়',
    score: 92,
  ),
  'claude-opus-4.7': AiDoctor(
    model: 'claude-opus-4.7',
    name: 'ডা. শাহনাজ আক্তার',
    rank: 'কনসালট্যান্ট',
    blurb: 'নরম স্বরে গভীর জেরা—রোগীর অস্পষ্ট উত্তর স্পষ্ট করায়',
    score: 91,
  ),
  'claude-opus-4.6': AiDoctor(
    model: 'claude-opus-4.6',
    name: 'ডা. বশীর আহমেদ',
    rank: 'কনসালট্যান্ট',
    blurb: 'অভিজ্ঞ স্থির হাত—পরীক্ষার আগেই জরুরি লক্ষণ ধরে ফেলে',
    score: 90,
  ),
  'claude-fable-5.1': AiDoctor(
    model: 'claude-fable-5.1',
    name: 'ডা. নুজহাত চৌধুরী',
    rank: 'কনসালট্যান্ট',
    blurb: 'বাংলা কথায় সহজ-সরল ব্যাখ্যা, জটিল রোগেও গুছানো পরামর্শ',
    score: 89,
  ),
  'gpt-5.5': AiDoctor(
    model: 'gpt-5.5',
    name: 'ডা. জরিনা তাসনিম',
    rank: 'কনসালট্যান্ট',
    blurb: 'দ্রুত ও ভারসাম্যপূর্ণ—প্রশ্ন-উত্তরে তথ্য হারায় না',
    score: 88,
  ),
  'gpt-5.6-sol': AiDoctor(
    model: 'gpt-5.6-sol',
    name: 'ডা. রুহুল আমিন',
    rank: 'কনসালট্যান্ট',
    blurb: 'তথ্য-প্রমাণ মেলায় নিপুণ, ডোজ-তালিকায় নিখুঁত',
    score: 87,
  ),
  'claude-fable-5': AiDoctor(
    model: 'claude-fable-5',
    name: 'ডা. সাইফুল ইসলাম',
    rank: 'সহকারী কনসালট্যান্ট',
    blurb: 'সাধারণ সমস্যায় দ্রুত, জটিলতায় সময় নিয়ে ভাবে',
    score: 86,
  ),
  'gpt-5.6-luna': AiDoctor(
    model: 'gpt-5.6-luna',
    name: 'ডা. লামিয়া আফরোজ',
    rank: 'সহকারী কনসালট্যান্ট',
    blurb: 'শান্ত স্বরে লক্ষণের ক্রম সাজায়, ছবি-বর্ণনা মিলিয়ে নেয়',
    score: 85,
  ),
  'qwen3.8-max': AiDoctor(
    model: 'qwen3.8-max',
    name: 'ডা. শারমিন সুলতানা',
    rank: 'সহকারী কনসালট্যান্ট',
    blurb: 'বহুভাষিক কেসে মজবুত—বাংলা-ইংরেজি মিশ্র প্রশ্নে সহজ',
    score: 84,
  ),
  'claude-sonnet-5': AiDoctor(
    model: 'claude-sonnet-5',
    name: 'ডা. তানভীর সামাদ',
    rank: 'রেজিডেন্ট (জুনিয়র কনসালট্যান্ট)',
    blurb: 'দ্রুত, খরচ-সাশ্রয়ী—প্রতিদিনের পরামর্শে ধারালো',
    score: 83,
  ),
  'kimi-k3': AiDoctor(
    model: 'kimi-k3',
    name: 'ডা. কামরুন নাহার',
    rank: 'রেজিডেন্ট',
    blurb: 'লম্বা কথোপকথন মনে রাখে, উত্তরের অসঙ্গতি ধরে ফেলে',
    score: 82,
  ),
  'deepseek-v4-pro-max': AiDoctor(
    model: 'deepseek-v4-pro-max',
    name: 'ডা. নাজমুল হক',
    rank: 'রেজিডেন্ট',
    blurb: 'যুক্তি-পর্যায়ে কড়া—ধাপে ধাপে কারণ বিশ্লেষণ করে',
    score: 81,
  ),
  'gpt-5.6-terra': AiDoctor(
    model: 'gpt-5.6-terra',
    name: 'ডা. সাদিয়া আফতাব',
    rank: 'রেজিডেন্ট',
    blurb: 'হালকা-ফুলকা সমস্যায় দ্রুত গুছিয়ে বলে',
    score: 80,
  ),
  'qwen3.7-max': AiDoctor(
    model: 'qwen3.7-max',
    name: 'ডা. গিয়াস উদ্দিন',
    rank: 'রেজিডেন্ট',
    blurb: 'সাধারণ পরামর্শে নির্ভরযোগ্য, জটিলতায় বাড়তি যাচাই চায়',
    score: 79,
  ),
  'deepseek-v4-pro-0813': AiDoctor(
    model: 'deepseek-v4-pro-0813',
    name: 'ডা. ফারুক আহমেদ',
    rank: 'রেজিডেন্ট',
    blurb: 'ডোজ-হিসাবে নিখুঁত—ধাপে ধাপে গাণিতিক যাচাই',
    score: 78,
  ),
  'gemini-3.7-flash': AiDoctor(
    model: 'gemini-3.7-flash',
    name: 'ডা. মাহমুদা খাতুন',
    rank: 'রেজিডেন্ট',
    blurb: 'দ্রুততম সাড়া, বাংলায় স্বাভাবিক—হালকা সমস্যায় সেরা',
    score: 77,
  ),
  'grok-4.6': AiDoctor(
    model: 'grok-4.6',
    name: 'ডা. হারুন অর রশিদ',
    rank: 'রেজিডেন্ট',
    blurb: 'সরাসরি কথা, অপ্রয়োজনীয় বাঁকানো নেই',
    score: 76,
  ),
  'glm-5.3': AiDoctor(
    model: 'glm-5.3',
    name: 'ডা. রুবিনা ইয়াসমিন',
    rank: 'সহকারী রেজিডেন্ট',
    blurb: 'ছোটখাটো পরামর্শে ঠিকমতো, জটিলতায় সন্দেহ তোলে',
    score: 75,
  ),
  'seed-2.1-pro': AiDoctor(
    model: 'seed-2.1-pro',
    name: 'ডা. মেহেদী হাসান',
    rank: 'সহকারী রেজিডেন্ট',
    blurb: 'সাধারণ তথ্যে ঝামেলামুক্ত, গভীরতায় প্রমাণ চায়',
    score: 74,
  ),
  'kimi-k2.6': AiDoctor(
    model: 'kimi-k2.6',
    name: 'ডা. সোহেল রানা',
    rank: 'সহকারী রেজিডেন্ট',
    blurb: 'মনে-রাখার ক্ষমতা ভালো, সিদ্ধান্তে সতর্ক',
    score: 73,
  ),
  'grok-4.5': AiDoctor(
    model: 'grok-4.5',
    name: 'ডা. নাদিয়া কামাল',
    rank: 'সহকারী রেজিডেন্ট',
    blurb: 'দ্রুত উত্তর, প্রশ্ন এড়ালে একবার আবার জিজ্ঞেস করে',
    score: 72,
  ),
  'glm-5.2': AiDoctor(
    model: 'glm-5.2',
    name: 'ডা. আশিক ইকবাল',
    rank: 'সহকারী রেজিডেন্ট',
    blurb: 'হালকা কেসে সময় কম নেয়, জটিলে ডাক্তার ডাকে',
    score: 71,
  ),
  'seed-2.1-turbo': AiDoctor(
    model: 'seed-2.1-turbo',
    name: 'ডা. প্রিতম কুমার',
    rank: 'ইন্টার্ন',
    blurb: 'বেশ দ্রুত, তবে গভীর বিশ্লেষণে অগভীর',
    score: 70,
  ),
  'deepseek-v4-flash-0731': AiDoctor(
    model: 'deepseek-v4-flash-0731',
    name: 'ডা. রাসেল মিয়া',
    rank: 'ইন্টার্ন',
    blurb: 'দ্রুত ড্রাফট, ডোজ-নির্বাচনে বাড়তি যাচাই দরকার',
    score: 69,
  ),
  'gemini-3.6-flash': AiDoctor(
    model: 'gemini-3.6-flash',
    name: 'ডা. জাকির হোসেন',
    rank: 'ইন্টার্ন',
    blurb: 'আগের প্রজন্মের দ্রুত সাড়া, সহজ প্রশ্নে ঠিকঠাক',
    score: 68,
  ),
  'qwen3.8-27b': AiDoctor(
    model: 'qwen3.8-27b',
    name: 'ডা. তানিয়া রহমান',
    rank: 'ইন্টার্ন',
    blurb: 'ছোট কিন্তু ফুরফুরে—প্রাথমিক জেরায় সাহায্য করে',
    score: 66,
  ),
  'muse-spark-1.1': AiDoctor(
    model: 'muse-spark-1.1',
    name: 'ডা. ঐশী গোস্বামী',
    rank: 'ইন্টার্ন',
    blurb: 'সৃজনশীল ব্যাখ্যা, কড়া ক্লিনিকে দুর্বল',
    score: 62,
  ),
  'gemma-2-2b': AiDoctor(
    model: 'gemma-2-2b',
    name: 'ডা. পলাশ চন্দ্র',
    rank: 'তত্ত্বাবধানে ইন্টার্ন',
    blurb: 'খুব ছোট মডেল—শুধু হালকা প্রশ্নে, জরুরিতে নয়',
    score: 42,
  ),
};

/// Persona for any model id — exact table first, then family heuristics so
/// newly listed models still arrive as a doctor instead of a raw string.
AiDoctor doctorFor(String model) {
  final exact = _knownDoctors[model];
  if (exact != null) return exact;
  final s = model.toLowerCase();
  AiDoctor byFamily(String name, String rank, String blurb, int score) =>
      AiDoctor(
        model: model,
        name: name,
        rank: rank,
        blurb: blurb,
        score: score,
      );
  if (s.contains('opus')) {
    return byFamily(
      'ডা. আনিসুর রহমান',
      'সিনিয়র কনসালট্যান্ট',
      'নতুন সংস্করণ—গভীর চিন্তার ধারা অব্যাহত',
      90,
    );
  }
  if (s.contains('claude')) {
    return byFamily(
      'ডা. সাইমূর রহমান',
      'কনসালট্যান্ট',
      'যত্নশীল পাঠক, লম্বা সাক্ষাৎকার সামলায়',
      84,
    );
  }
  if (s.contains('gpt-5') || s.contains('gpt-4')) {
    return byFamily(
      'ডা. রায়হান কামাল',
      'কনসালট্যান্ট',
      'নতুন প্রজন্মের GPT—বহুমুখী বিশ্লেষণ',
      85,
    );
  }
  if (s.contains('gemini') && s.contains('pro')) {
    return byFamily(
      'ডা. নভিনা চৌধুরী',
      'সিনিয়র কনসালট্যান্ট',
      'ছবি-বিশ্লেষণে অত্যন্ত ধারালো',
      88,
    );
  }
  if (s.contains('gemini')) {
    return byFamily(
      'ডা. তানভীর আহমেদ',
      'রেজিডেন্ট',
      'দ্রুত বাংলা সাড়া, হালকা সমস্যায় তৎপর',
      76,
    );
  }
  if (s.contains('deepseek')) {
    return byFamily(
      'ডা. সাগর মাহমুদ',
      'রেজিডেন্ট',
      'ধাপে ধাপে যুক্তি সাজায়',
      78,
    );
  }
  if (s.contains('qwen')) {
    return byFamily(
      'ডা. সাবিহা মনসুর',
      'রেজিডেন্ট',
      'বহুভাষিক প্রশ্নে স্বাচ্ছন্দ্য',
      78,
    );
  }
  if (s.contains('kimi')) {
    return byFamily(
      'ডা. নাবিদ আলম',
      'সহকারী রেজিডেন্ট',
      'দীর্ঘ প্রসঙ্গ-মনে রাখে',
      74,
    );
  }
  if (s.contains('grok')) {
    return byFamily(
      'ডা. শাইন চৌধুরী',
      'সহকারী রেজিডেন্ট',
      'সরাসরি ও দ্রুত',
      72,
    );
  }
  if (s.contains('glm') || s.contains('seed') || s.contains('muse')) {
    return byFamily(
      'ডা. রিমঝিম আক্তার',
      'ইন্টার্ন',
      'নতুন ক্যাডেট—হালকা কেসে ভালো',
      68,
    );
  }
  if (s.contains('gemma') ||
      s.contains('llama') ||
      s.contains('mistral') ||
      s.contains('phi')) {
    return byFamily('ডা. সুমন দত্ত', 'ইন্টার্ন', 'ছোট মডেল—জরুরি কেসে নয়', 50);
  }
  return byFamily(
    'ডা. রফিকুল ইসলাম',
    'রেজিডেন্ট',
    'নতুন মডেল—ক্লিনিক্যাল ধারা যাচাই হচ্ছে',
    60,
  );
}

/// Rank a raw model list best-doctor-first (score, then id).
List<AiDoctor> rankDoctors(Iterable<String> models) {
  final doctors = models.map(doctorFor).toList()
    ..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.model.compareTo(b.model);
    });
  return doctors;
}
