import 'package:flutter/material.dart';

import '../models/learning.dart';
import '../widgets/glass.dart';
import '../widgets/medical_term_dialog.dart';

class MedicalTermsView extends StatefulWidget {
  const MedicalTermsView({super.key});

  @override
  State<MedicalTermsView> createState() => _MedicalTermsViewState();
}

class _MedicalTermsViewState extends State<MedicalTermsView> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _category = 'All';

  static const List<MedicalTerm> _defaultTerms = [
    MedicalTerm(
      id: 'term_pharyngitis',
      termEn: 'Pharyngitis',
      termBn: 'গলবিল প্রদাহ',
      definitionBn: 'গলবিলের (Pharynx) মিউকাস মেমব্রেনে সংক্রমণ বা উত্তেজনার ফলে সৃষ্ট প্রদাহ।',
      simpleExplanationBn:
          'গলার ভেতরের লাল হয়ে ফুলে যাওয়া বা সাধারণ গলাব্যথা।',
      exampleBn:
          'ভাইরাস বা ব্যাকটেরিয়ার সংক্রমণে অ্যাকিউট ফ্যারিঞ্জাইটিস হতে পারে।',
    ),
    MedicalTerm(
      id: 'term_tonsillitis',
      termEn: 'Tonsillitis',
      termBn: 'টনসিলের প্রদাহ',
      definitionBn: 'গলার দুপাশের টনসিলে জীবাণুজনিত সংক্রমণ ও পুঁজ সৃষ্টি।',
      simpleExplanationBn: 'টনসিল ফুলে ঢোক গিলতে প্রচণ্ড কষ্ট হওয়া।',
      exampleBn: 'স্ট্রেপ্টোকক্কাস ব্যাকটেরিয়ায় আক্রান্ত হয়ে তীব্র টনসিলাইটিস হতে পারে।',
    ),
    MedicalTerm(
      id: 'term_dysphagia',
      termEn: 'Dysphagia',
      termBn: 'গিলতে সমস্যা বা ব্যথা',
      definitionBn: 'খাবার বা তরল মুখ থেকে পাকস্থলীতে নামার সময় অস্বাভাবিক কষ্ট বা বাধা।',
      simpleExplanationBn:
          'ঢোক গিলতে গেলে গলায় আটকে যাওয়া বা তীব্র ব্যথা হওয়া।',
      exampleBn:
          'তীব্র গলাব্যথা বা গলায় পুঁজ জমলে সাময়িক ডিসফেজিয়া দেখা দেয়।',
    ),
    MedicalTerm(
      id: 'term_centor',
      termEn: 'Centor Criteria',
      termBn: 'সেন্টর ক্রাইটেরিয়া',
      definitionBn: 'গলাব্যথার রোগীর স্ট্রেপ ব্যাকটেরিয়া সংক্রমণের সম্ভাবনা মূল্যায়নের ক্লিনিক্যাল স্কোর।',
      simpleExplanationBn: 'কিছু লক্ষণ দেখে চিকিৎসক স্ট্রেপ সংক্রমণের সম্ভাবনা অনুমান করতে এই স্কোর ব্যবহার করতে পারেন; এটি একা রোগ নিশ্চিত করে না।',
      exampleBn: 'সেন্টর স্কোর ৩ বা ৪ হলে চিকিৎসক অ্যান্টিবায়োটিক দেওয়ার কথা বিবেচনা করেন।',
    ),
    MedicalTerm(
      id: 'term_amr',
      termEn: 'Antimicrobial Resistance (AMR)',
      termBn: 'অ্যান্টিমাইক্রোবিয়াল রেজিস্ট্যান্স',
      definitionBn: 'জীবাণু যখন তাদের ধ্বংসকারী ওষুধের বিরুদ্ধে প্রতিরোধ ক্ষমতা অর্জন করে।',
      simpleExplanationBn:
          'অপ্রয়োজনে অ্যান্টিবায়োটিক খেলে জীবাণু আর সেই ওষুধে মরে না।',
      exampleBn: 'সর্দি-কাশিতে অপ্রয়োজনে অ্যান্টিবায়োটিক খেলে ড্রাগ রেজিস্ট্যান্স বাড়ে।',
    ),
    MedicalTerm(
      id: 'term_otc',
      termEn: 'Over-The-Counter (OTC)',
      termBn: 'প্রেসক্রিপশনবিহীন ওষুধ',
      definitionBn: 'স্থানীয় নিয়ম অনুযায়ী চিকিৎসকের প্রেসক্রিপশন ছাড়া বিক্রির অনুমোদিত ওষুধ।',
      simpleExplanationBn: 'প্রেসক্রিপশন ছাড়া পাওয়া গেলেও ভুলভাবে ব্যবহার করলে ক্ষতি হতে পারে; প্যাকেটের নির্দেশনা মানুন।',
      exampleBn: 'ওটিসি ওষুধেরও নির্দিষ্ট মাত্রা ও সতর্কতা থাকে।',
    ),
    MedicalTerm(
      id: 'term_hypertension',
      termEn: 'Hypertension',
      termBn: 'উচ্চ রক্তচাপ',
      definitionBn: 'ধমনি গাত্রে রক্তের চাপ দীর্ঘসময় স্বাভাবিক সীমার (১৪০/৯০ মিমি পারদ) ওপরে থাকা।',
      simpleExplanationBn: 'রক্তের প্রেসার বেড়ে গিয়ে রক্তনালি ও হৃৎপিণ্ডের ওপর অতিরিক্ত চাপ সৃষ্টি হওয়া।',
      exampleBn: 'অনিয়ন্ত্রিত উচ্চ রক্তচাপ হার্ট অ্যাটাক ও স্ট্রোকের ঝুঁকি বহুগুণ বাড়ায়।',
    ),
    MedicalTerm(
      id: 'term_diabetes',
      termEn: 'Diabetes Mellitus',
      termBn: 'ডায়াবেটিস / বহুমূত্র রোগ',
      definitionBn: 'ইনসুলিনের ঘাটতি বা অকার্যকারিতার কারণে রক্তে গ্লুকোজের মাত্রা অস্বাভাবিক বৃদ্ধি পাওয়া।',
      simpleExplanationBn: 'ইনসুলিন কম তৈরি হলে বা ঠিকমতো কাজ না করলে রক্তে শর্করা বেড়ে যেতে পারে।',
      exampleBn: 'নিয়মিত ব্যায়াম ও খাদ্যাভ্যাস নিয়ন্ত্রণে ডায়াবেটিস নিয়ন্ত্রণে থাকে।',
    ),
    MedicalTerm(
      id: 'term_trismus',
      termEn: 'Trismus',
      termBn: 'মুখ খুলতে বাধা (লক জ)',
      definitionBn:
          'চোয়ালের পেশির খিঁচুনির কারণে স্বাভাবিকভাবে মুখ খুলতে না পারা।',
      simpleExplanationBn:
          'গলায় তীব্র পুঁজ জমলে বা টিটেনাসে মুখ হাঁ করা বন্ধ হয়ে যাওয়া।',
      exampleBn: 'গলাব্যথার সাথে ট্রিসমাস বা মুখ খুলতে না পারা তাৎক্ষণিক হাসপাতালের রেড ফ্ল্যাগ।',
    ),
    MedicalTerm(
      id: 'term_stridor',
      termEn: 'Stridor',
      termBn: 'শ্বাসকষ্টের বাঁশির মতো শব্দ',
      definitionBn: 'উর্ধ্ব শ্বাসনালিতে বাধার কারণে শ্বাস নেওয়ার সময় কর্কশ বা তীক্ষ্ণ শব্দ হওয়া।',
      simpleExplanationBn: 'গলা বা শ্বাসনালি চেপে আসার কারণে শ্বাস নিতে গেলে সাঁ সাঁ শব্দ হওয়া।',
      exampleBn:
          'শিশুদের স্ট্রাইডর দেখা দিলে অবিলম্বে জরুরি হাসপাতালে নিতে হবে।',
    ),
    MedicalTerm(
      id: 'term_fever',
      termEn: 'Fever',
      termBn: 'জ্বর',
      category: 'Symptoms',
      definitionBn: 'শরীরের তাপমাত্রা স্বাভাবিকের চেয়ে বেড়ে যাওয়া।',
      simpleExplanationBn: 'শরীর গরম লাগা বা থার্মোমিটারে তাপমাত্রা বেশি দেখা।',
    ),
    MedicalTerm(
      id: 'term_cough',
      termEn: 'Cough',
      termBn: 'কাশি',
      category: 'Symptoms',
      definitionBn:
          'শ্বাসনালির উদ্দীপনা বা মিউকাস পরিষ্কার করার স্বাভাবিক প্রতিক্রিয়া।',
      simpleExplanationBn:
          'গলা বা বুকের অস্বস্তি দূর করতে জোরে বাতাস বের হওয়া।',
    ),
    MedicalTerm(
      id: 'term_dyspnea',
      termEn: 'Dyspnea',
      termBn: 'শ্বাসকষ্ট',
      category: 'Symptoms',
      definitionBn: 'শ্বাস নিতে কষ্ট বা বাতাস কম পাওয়ার অনুভূতি।',
      simpleExplanationBn: 'স্বাভাবিকভাবে শ্বাস নিতে না পারা। হঠাৎ বা তীব্র হলে জরুরি চিকিৎসা নিন।',
    ),
    MedicalTerm(
      id: 'term_rash',
      termEn: 'Rash',
      termBn: 'ত্বকের ফুসকুড়ি',
      category: 'Symptoms',
      definitionBn:
          'ত্বকে নতুন করে দেখা দেওয়া দাগ, লালভাব, গুটি বা রঙের পরিবর্তন।',
      simpleExplanationBn: 'চুলকানি বা জ্বালাসহ ত্বকে দানা/দাগ উঠতে পারে; কারণ নির্ধারণে পরীক্ষা লাগতে পারে।',
    ),
    MedicalTerm(
      id: 'term_edema',
      termEn: 'Edema',
      termBn: 'শরীর ফুলে যাওয়া',
      category: 'Symptoms',
      definitionBn: 'টিস্যুতে অতিরিক্ত তরল জমে ফুলে যাওয়া।',
      simpleExplanationBn:
          'পা, হাত বা শরীরের কোনো অংশ অস্বাভাবিকভাবে ফুলে থাকা।',
    ),
    MedicalTerm(
      id: 'term_nausea',
      termEn: 'Nausea',
      termBn: 'বমি বমি ভাব',
      category: 'Symptoms',
      definitionBn: 'বমি হওয়ার আগের অস্বস্তিকর অনুভূতি।',
      simpleExplanationBn: 'পেটে অস্বস্তি বা বমি আসছে এমন মনে হওয়া।',
    ),
    MedicalTerm(
      id: 'term_syncope',
      termEn: 'Syncope',
      termBn: 'অজ্ঞান হয়ে যাওয়া',
      category: 'Symptoms',
      definitionBn:
          'মস্তিষ্কে সাময়িকভাবে রক্তপ্রবাহ কমে অল্প সময়ের জন্য জ্ঞান হারানো।',
      simpleExplanationBn:
          'হঠাৎ অল্প সময়ের জন্য অচেতন হওয়া; কারণ মূল্যায়ন জরুরি হতে পারে।',
    ),
    MedicalTerm(
      id: 'term_anemia',
      termEn: 'Anemia',
      termBn: 'রক্তস্বল্পতা',
      category: 'Conditions',
      definitionBn: 'রক্তে হিমোগ্লোবিন বা লোহিত রক্তকণিকার পরিমাণ কমে যাওয়া।',
      simpleExplanationBn:
          'শরীরের টিস্যুতে পর্যাপ্ত অক্সিজেন পৌঁছাতে অসুবিধা হতে পারে।',
    ),
    MedicalTerm(
      id: 'term_asthma',
      termEn: 'Asthma',
      termBn: 'হাঁপানি',
      category: 'Conditions',
      definitionBn: 'শ্বাসনালির দীর্ঘমেয়াদি প্রদাহজনিত অবস্থা, যাতে শ্বাসনালি সংকুচিত হতে পারে।',
      simpleExplanationBn:
          'শ্বাসে বাঁশির মতো শব্দ, কাশি বা শ্বাসকষ্টের পর্ব হতে পারে।',
    ),
    MedicalTerm(
      id: 'term_gastritis',
      termEn: 'Gastritis',
      termBn: 'পাকস্থলীর আবরণের প্রদাহ',
      category: 'Conditions',
      definitionBn: 'পাকস্থলীর ভেতরের আবরণে প্রদাহ বা জ্বালা।',
      simpleExplanationBn:
          'পেটের ওপরের দিকে ব্যথা, অস্বস্তি বা বমি বমি ভাব হতে পারে।',
    ),
    MedicalTerm(
      id: 'term_migraine',
      termEn: 'Migraine',
      termBn: 'মাইগ্রেন',
      category: 'Conditions',
      definitionBn: 'বারবার হওয়া মাথাব্যথার একটি স্নায়বিক ধরন।',
      simpleExplanationBn:
          'মাথার এক পাশে ব্যথা, আলো/শব্দে অস্বস্তি বা বমি বমি ভাব থাকতে পারে।',
    ),
    MedicalTerm(
      id: 'term_uti',
      termEn: 'Urinary Tract Infection (UTI)',
      termBn: 'মূত্রনালির সংক্রমণ',
      category: 'Conditions',
      definitionBn: 'মূত্রতন্ত্রের কোনো অংশে জীবাণুর সংক্রমণ।',
      simpleExplanationBn:
          'প্রস্রাবে জ্বালা, ঘন ঘন প্রস্রাব বা তলপেটে অস্বস্তি হতে পারে।',
    ),
    MedicalTerm(
      id: 'term_dehydration',
      termEn: 'Dehydration',
      termBn: 'পানিশূন্যতা',
      category: 'Conditions',
      definitionBn:
          'শরীর থেকে বেরিয়ে যাওয়া তরলের তুলনায় পর্যাপ্ত তরল গ্রহণ না হওয়া।',
      simpleExplanationBn:
          'ডায়রিয়া, বমি বা কম পানি খাওয়ায় শরীরে পানির ঘাটতি হতে পারে।',
    ),
    MedicalTerm(
      id: 'term_infection',
      termEn: 'Infection',
      termBn: 'সংক্রমণ',
      category: 'Conditions',
      definitionBn:
          'ভাইরাস, ব্যাকটেরিয়া, ছত্রাক বা পরজীবীর শরীরে প্রবেশ ও বংশবৃদ্ধি।',
      simpleExplanationBn:
          'জীবাণু শরীরে ঢুকে অসুস্থতা তৈরি করলে তাকে সংক্রমণ বলে।',
    ),
    MedicalTerm(
      id: 'term_inflammation',
      termEn: 'Inflammation',
      termBn: 'প্রদাহ',
      category: 'Conditions',
      definitionBn: 'আঘাত বা সংক্রমণের প্রতিক্রিয়ায় শরীরের টিস্যুতে হওয়া প্রতিরক্ষামূলক পরিবর্তন।',
      simpleExplanationBn:
          'কোনো স্থানে লালভাব, গরম, ব্যথা বা ফোলা দেখা দিতে পারে।',
    ),
    MedicalTerm(
      id: 'term_cbc',
      termEn: 'Complete Blood Count (CBC)',
      termBn: 'সম্পূর্ণ রক্ত গণনা',
      category: 'Tests',
      definitionBn: 'রক্তের লোহিত ও শ্বেত রক্তকণিকা, হিমোগ্লোবিন ও প্লেটলেট মাপার পরীক্ষা।',
      simpleExplanationBn:
          'রক্তের কয়েক ধরনের কোষের সংখ্যা ও মাত্রা সম্পর্কে ধারণা দেয়।',
    ),
    MedicalTerm(
      id: 'term_hba1c',
      termEn: 'HbA1c',
      termBn: 'গত কয়েক মাসের গড় রক্তশর্করা',
      category: 'Tests',
      definitionBn: 'হিমোগ্লোবিনের সঙ্গে যুক্ত গ্লুকোজের শতকরা পরিমাণ মাপার রক্ত পরীক্ষা।',
      simpleExplanationBn:
          'সাম্প্রতিক কয়েক মাসের রক্তশর্করার গড় সম্পর্কে ধারণা দেয়।',
    ),
    MedicalTerm(
      id: 'term_blood_glucose',
      termEn: 'Blood Glucose',
      termBn: 'রক্তের গ্লুকোজ',
      category: 'Tests',
      definitionBn: 'রক্তে থাকা গ্লুকোজ বা শর্করার পরিমাণ।',
      simpleExplanationBn: 'খালি পেটে বা খাবারের পরে—কখন মাপা হয়েছে তার ওপর ফলের ব্যাখ্যা নির্ভর করে।',
    ),
    MedicalTerm(
      id: 'term_blood_pressure',
      termEn: 'Blood Pressure (BP)',
      termBn: 'রক্তচাপ',
      category: 'Tests',
      definitionBn: 'হৃৎপিণ্ড রক্ত পাম্প করার সময় এবং বিশ্রামের সময় ধমনির দেয়ালে রক্তের চাপ।',
      simpleExplanationBn: 'সাধারণত ওপরের (সিস্টোলিক) ও নিচের (ডায়াস্টোলিক) দুটি সংখ্যায় লেখা হয়।',
    ),
    MedicalTerm(
      id: 'term_pulse',
      termEn: 'Pulse',
      termBn: 'নাড়ির স্পন্দন',
      category: 'Tests',
      definitionBn: 'হৃৎস্পন্দনের সঙ্গে ধমনিতে অনুভূত ছন্দময় স্পন্দন।',
      simpleExplanationBn:
          'নাড়ি গুনে নির্দিষ্ট সময়ে হৃদস্পন্দনের হার বোঝা যায়।',
    ),
    MedicalTerm(
      id: 'term_spo2',
      termEn: 'Oxygen Saturation (SpO₂)',
      termBn: 'রক্তে অক্সিজেনের মাত্রা',
      category: 'Tests',
      definitionBn:
          'রক্তের হিমোগ্লোবিনের কত অংশ অক্সিজেন বহন করছে তার আনুমানিক পরিমাপ।',
      simpleExplanationBn: 'সাধারণত আঙুলে লাগানো পালস অক্সিমিটার দিয়ে মাপা হয়; ফল উপসর্গসহ ব্যাখ্যা করতে হয়।',
    ),
    MedicalTerm(
      id: 'term_antibiotic',
      termEn: 'Antibiotic',
      termBn: 'অ্যান্টিবায়োটিক',
      category: 'Medicines & safety',
      definitionBn: 'নির্দিষ্ট ব্যাকটেরিয়াজনিত সংক্রমণের চিকিৎসায় ব্যবহৃত ওষুধের শ্রেণি।',
      simpleExplanationBn: 'ভাইরাসজনিত সর্দি-কাশিতে অ্যান্টিবায়োটিক কাজ করে না; চিকিৎসকের পরামর্শ ছাড়া ব্যবহার করবেন না।',
    ),
    MedicalTerm(
      id: 'term_analgesic',
      termEn: 'Analgesic',
      termBn: 'ব্যথানাশক',
      category: 'Medicines & safety',
      definitionBn: 'ব্যথা কমাতে ব্যবহৃত ওষুধের সাধারণ নাম।',
      simpleExplanationBn: 'ব্যথানাশকের ধরনভেদে ঝুঁকি ও ব্যবহারের নিয়ম ভিন্ন—লেবেল বা চিকিৎসকের নির্দেশ মানুন।',
    ),
    MedicalTerm(
      id: 'term_antihistamine',
      termEn: 'Antihistamine',
      termBn: 'অ্যালার্জির উপসর্গ কমানোর ওষুধ',
      category: 'Medicines & safety',
      definitionBn: 'হিস্টামিনের প্রভাব কমিয়ে কিছু অ্যালার্জির উপসর্গ উপশমে ব্যবহৃত ওষুধ।',
      simpleExplanationBn:
          'কিছু ওষুধে ঘুম ঘুম ভাব হতে পারে; প্যাকেটের নির্দেশনা দেখুন।',
    ),
    MedicalTerm(
      id: 'term_analgesia_dose',
      termEn: 'Dose',
      termBn: 'ওষুধের মাত্রা',
      category: 'Medicines & safety',
      definitionBn:
          'একবারে বা নির্দিষ্ট সময়ে গ্রহণ/প্রয়োগ করার ওষুধের পরিমাণ।',
      simpleExplanationBn: 'মাত্রা রোগী, ওষুধ ও ব্যবহারের উদ্দেশ্য অনুযায়ী বদলায়; নিজে থেকে পরিবর্তন করবেন না।',
    ),
    MedicalTerm(
      id: 'term_side_effect',
      termEn: 'Side Effect',
      termBn: 'পার্শ্বপ্রতিক্রিয়া',
      category: 'Medicines & safety',
      definitionBn: 'ওষুধের কাঙ্ক্ষিত প্রভাবের পাশাপাশি দেখা দিতে পারে এমন অনাকাঙ্ক্ষিত প্রভাব।',
      simpleExplanationBn:
          'নতুন বা গুরুতর উপসর্গ হলে চিকিৎসক বা ফার্মাসিস্টের পরামর্শ নিন।',
    ),
    MedicalTerm(
      id: 'term_contraindication',
      termEn: 'Contraindication',
      termBn: 'যে অবস্থায় ওষুধ ব্যবহার অনুপযুক্ত',
      category: 'Medicines & safety',
      definitionBn: 'নির্দিষ্ট রোগী বা শারীরিক অবস্থায় কোনো চিকিৎসা ব্যবহার না করার চিকিৎসাগত কারণ।',
      simpleExplanationBn: 'অ্যালার্জি, অন্য রোগ বা অন্য ওষুধের কারণে কিছু ওষুধ কারও জন্য অনুপযুক্ত হতে পারে।',
    ),
    MedicalTerm(
      id: 'term_generic_name',
      termEn: 'Generic Name',
      termBn: 'জেনেরিক নাম',
      category: 'Medicines & safety',
      definitionBn: 'ওষুধের সক্রিয় উপাদানের স্বীকৃত সাধারণ নাম।',
      simpleExplanationBn: 'ভিন্ন ব্র্যান্ডে একই সক্রিয় উপাদান থাকতে পারে; বদলানোর আগে ফার্মাসিস্টকে জিজ্ঞেস করুন।',
    ),
    MedicalTerm(
      id: 'term_drug_interaction',
      termEn: 'Drug Interaction',
      termBn: 'ওষুধের পারস্পরিক প্রতিক্রিয়া',
      category: 'Medicines & safety',
      definitionBn: 'একাধিক ওষুধ বা কোনো ওষুধ ও খাবার একসঙ্গে ব্যবহারে একটির প্রভাব অন্যটির কারণে বদলে যাওয়া।',
      simpleExplanationBn: 'নতুন ওষুধ নেওয়ার আগে চলমান সব ওষুধের কথা চিকিৎসক বা ফার্মাসিস্টকে জানান।',
    ),
    MedicalTerm(
      id: 'term_ors',
      termEn: 'Oral Rehydration Solution (ORS)',
      termBn: 'খাওয়ার স্যালাইন',
      category: 'Medicines & safety',
      definitionBn: 'পানি ও নির্দিষ্ট অনুপাতে লবণ-চিনি মিশিয়ে তৈরি পানিশূন্যতা পূরণের দ্রবণ।',
      simpleExplanationBn:
          'প্যাকেটের নির্দেশে যতটুকু পানি বলা আছে ঠিক ততটুকুতেই গুলে নিন।',
    ),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final query = _query.trim().toLowerCase();
    final categories = [
      'All',
      ..._defaultTerms.map((term) => term.category).toSet().toList()..sort(),
    ];

    final filtered = _defaultTerms.where((t) {
      final matchesCategory = _category == 'All' || t.category == _category;
      final matchesQuery =
          query.isEmpty ||
          t.termBn.toLowerCase().contains(query) ||
          t.termEn.toLowerCase().contains(query) ||
          t.definitionBn.toLowerCase().contains(query) ||
          t.simpleExplanationBn.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList()..sort((a, b) => a.termEn.compareTo(b.termEn));

    return AppBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('Medical glossary')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(Icons.menu_book_rounded, color: scheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Understand health terms',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_defaultTerms.length} terms · Simple Bengali explanations',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              onChanged: (val) => setState(() => _query = val),
              decoration: InputDecoration(
                hintText: 'Search in English or Bengali',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final category in categories)
                  ChoiceChip(
                    label: Text(category),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${filtered.length} ${filtered.length == 1 ? 'term' : 'terms'}',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                if (_category != 'All' || query.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      _search.clear();
                      setState(() {
                        _query = '';
                        _category = 'All';
                      });
                    },
                    child: const Text('Clear filters'),
                  ),
              ],
            ),
            if (filtered.isEmpty)
              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 34,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    const Text('No matching terms'),
                    const SizedBox(height: 4),
                    Text(
                      'Try another spelling or switch categories.',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              for (final term in filtered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    onTap: () => showMedicalTermSheet(context, term),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.medical_information_outlined,
                            color: scheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                term.termEn,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                term.termBn,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                term.simpleExplanationBn.isNotEmpty
                                    ? term.simpleExplanationBn
                                    : term.definitionBn,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                term.category,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: scheme.outline),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
