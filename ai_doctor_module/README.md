# এআই ডাক্তার মডিউল (PharmaPath-এর ভেতরের একটি ফিচার)

নিজের ডাটাবেস (`ai_doctor.db`), নিজের নামের ক্লাস (সব `Ai...` দিয়ে শুরু), নিজের `main.dart` নেই।
আপনার বিদ্যমান অ্যাপের কোড বা ডাটাবেসের সাথে সংঘর্ষ হবে না।

## PharmaPath-এ ব্যবহার
মডিউলটি লোকাল Flutter package হিসেবে যুক্ত। অ্যাপের `pubspec.yaml`-এ
`ai_doctor_module: path: ai_doctor_module` dependency আছে; সোর্স কপি বা
ডেটাবেস মিশ্রিত করার দরকার নেই।

অ্যাপ চালুর জায়গায় (যেমন `main()`):
   ```dart
   import 'package:ai_doctor_module/ai_doctor.dart';
   AiDoctorConfig.init(baseUrl: 'https://YOUR-ENDPOINT/v1', apiKey: 'YOUR_KEY');
   ```
PharmaPath-এর `main()` মডিউলটিকে বিদ্যমান OxionAI/OpenRouter API configuration
দিয়ে কনফিগার করে।

রোগী তালিকার **Add demo patient** অপশনটি দিয়ে একটি নমুনা profile খোলা যায়।
এটি শুধু স্থানীয় profile তৈরি করে; কোনো fake medical history বা AI message যোগ করে না।

আপনার মেনু বা হোমের "এআই ডাক্তার" বাটনে:
   ```dart
   Navigator.push(context, MaterialPageRoute(builder: (_) => const AiDoctorHomePage()));
   ```
প্রসঙ্গসহ প্রশ্ন খুলতে:
   ```dart
   AiDoctorHomePage(initialQuestion: 'ওষুধ বা পাঠের প্রসঙ্গসহ প্রশ্ন');
   ```

(ঐচ্ছিক) ওষুধের বর্ণনা নিজের মেডিসিন ডাটাবেস থেকে আনতে:
   ```dart
   AiDrugInfo.lookupOverride = (name) => MyMedicineDb.shortInfo(name);
   ```

## মনে রাখার বিষয়
- রঙ ও ফন্ট আপনার অ্যাপের `Theme` থেকে আসে। আলাদা থিম লাগে না।
- Flutter 3.22+ ও Material 3 লাগবে (`Badge`, `surfaceContainerHighest`)। পুরনো হলে `Badge.count`-কে `Badge` বা `Stack` দিয়ে বদলান।
- API key অ্যাপে রাখলে তা বের করে নেওয়া সম্ভব। প্রোডাকশনে নিজের সার্ভারের মাধ্যমে পাঠানো নিরাপদ।
- রোগীর প্রোফাইল ও চ্যাট স্থানীয় `ai_doctor.db`-এ থাকে; AI-কে প্রশ্ন করলে ওই প্রোফাইল ও কথোপকথনের সাম্প্রতিক অংশ provider-এ পাঠানো হয়।
- রোগীর ছবি, রক্তের গ্রুপ ও যোগাযোগের তথ্য ডিভাইসে থাকে। ছবি ও ফোন নম্বর AI-কে পাঠানো হয় না।
- ডাক্তারদের তালিকা `ai_doctor_module/lib/ai_doctor/models.dart`-এর `aiDoctors`। ষষ্ঠ ডাক্তার সেখানে যোগ করুন।
- `flutter analyze` চালিয়ে মডিউল/অ্যাপের পরিবর্তন যাচাই করুন।
