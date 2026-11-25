import 'package:get_storage/get_storage.dart';

/// Tutorial step model
class TutorialStep {
  const TutorialStep({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.actionLabel,
    this.videoUrl,
    this.tips = const [],
    this.completed = false,
  });

  final String id;
  final String title;
  final String description;
  final String icon; // emoji or icon name
  final String actionLabel;
  final String? videoUrl;
  final List<String> tips;
  final bool completed;

  TutorialStep copyWith({bool? completed}) {
    return TutorialStep(
      id: id,
      title: title,
      description: description,
      icon: icon,
      actionLabel: actionLabel,
      videoUrl: videoUrl,
      tips: tips,
      completed: completed ?? this.completed,
    );
  }
}

/// Tutorial service managing tutorial flow
class TutorialService {
  static const String _storageKey = 'pharmapath_tutorials';
  final _storage = GetStorage();

  // Predefined tutorials
  late final List<TutorialStep> _tutorials = [
    TutorialStep(
      id: 'welcome',
      title: 'ফার্মাপাথে স্বাগতম',
      description: 'PharmaPath হল একটি সম্পূর্ণ অফলাইন ঔষধ তথ্য অ্যাপ্লিকেশন যা ফার্মাসিস্ট এবং স্বাস্থ্যসেবা কর্মীদের জন্য ডিজাইন করা হয়েছে।',
      icon: '👋',
      actionLabel: 'শুরু করুন',
      tips: [
        'সম্পূর্ণ অফলাইনে কাজ করে',
        'ইন্টারনেট ছাড়াই সব তথ্য অ্যাক্সেস করুন',
        'নিয়মিত আপডেট পান',
      ],
    ),
    TutorialStep(
      id: 'search',
      title: 'ঔষধ খুঁজে বের করুন',
      description: 'সার্চ ফিচার ব্যবহার করে ব্র্যান্ড নাম, জেনেরিক নাম বা কোম্পানির নাম দিয়ে ঔষধ খুঁজুন।',
      icon: '🔍',
      actionLabel: 'সার্চ করুন',
      tips: [
        'বাংলা বা ইংরেজি উভয় ভাষায় খুঁজুন',
        'আপনার সম্প্রতি অনুসন্ধান করা ঔষধগুলি দেখুন',
        'প্রিয় ঔষধ যোগ করুন',
      ],
    ),
    TutorialStep(
      id: 'medicine_details',
      title: 'বিস্তারিত তথ্য দেখুন',
      description: 'ঔষধের সম্পূর্ণ বিবরণ, উপাদান, ডোজেজ এবং পার্শ্বপ্রতিক্রিয়া সম্পর্কে জানুন।',
      icon: '💊',
      actionLabel: 'বিস্তারিত দেখুন',
      tips: [
        'রোগের নির্দেশনা চেক করুন',
        'ডোজেজ এবং প্রশাসন নিয়মিত অনুসরণ করুন',
        'পার্শ্বপ্রতিক্রিয়া এবং সতর্কতা পড়ুন',
      ],
    ),
    TutorialStep(
      id: 'learning',
      title: 'শিখুন এবং উন্নত হন',
      description: 'স্বাস্থ্য শেখার একাডেমিতে বিনামূল্যে কোর্স এবং পাঠ নিন। প্রতিটি পাঠে একটি কুইজ অন্তর্ভুক্ত রয়েছে।',
      icon: '📚',
      actionLabel: 'শিখুন',
      tips: [
        'তিনটি মূল ট্র্যাক: শরীর ও রোগ, ওষুধের মূল কথা, ফার্মেসি',
        'প্রতিটি পাঠ ৫-১৫ মিনিট সময় নেয়',
        'কুইজে ৭০% স্কোর করলে পাস হবেন',
      ],
    ),
    TutorialStep(
      id: 'favorites',
      title: 'প্রিয় যোগ করুন',
      description: 'আপনার সবচেয়ে বেশি ব্যবহৃত ঔষধগুলি প্রিয়তে যোগ করুন এবং দ্রুত অ্যাক্সেস করুন।',
      icon: '❤️',
      actionLabel: 'প্রিয় যোগ করুন',
      tips: [
        'ঔষধ পাতায় হার্ট আইকন ক্লিক করুন',
        'হোম পেজে প্রিয় ঔষধ বিভাগ দেখুন',
        'যেকোনো সময় অপসারণ করুন',
      ],
    ),
    TutorialStep(
      id: 'assistant',
      title: 'AI সহায়ক ব্যবহার করুন',
      description: 'AI সহায়ক দিয়ে যেকোনো রোগ বা ঔষধ সম্পর্কে প্রশ্ন করুন এবং তাৎক্ষণিক উত্তর পান।',
      icon: '🤖',
      actionLabel: 'কথোপকথন শুরু করুন',
      tips: [
        'যেকোনো স্বাস্থ্য প্রশ্ন জিজ্ঞাসা করুন',
        'রোগের লক্ষণ এবং চিকিৎসা সম্পর্কে জানুন',
        'সম্পূর্ণ অফলাইন - কোন ডেটা শেয়ার করা হয় না',
      ],
    ),
  ];

  /// Get all tutorials
  List<TutorialStep> getTutorials() {
    _loadCompletionStatus();
    return _tutorials;
  }

  /// Get a specific tutorial by ID
  TutorialStep? getTutorial(String id) {
    _loadCompletionStatus();
    try {
      return _tutorials.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Mark tutorial as completed
  Future<void> completeTutorial(String id) async {
    final index = _tutorials.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tutorials[index] = _tutorials[index].copyWith(completed: true);
      await _saveCompletionStatus();
    }
  }

  /// Get next incomplete tutorial
  TutorialStep? getNextTutorial() {
    _loadCompletionStatus();
    try {
      return _tutorials.firstWhere((t) => !t.completed);
    } catch (e) {
      return null;
    }
  }

  /// Get completion percentage
  double getCompletionPercentage() {
    _loadCompletionStatus();
    if (_tutorials.isEmpty) return 0.0;
    final completed = _tutorials.where((t) => t.completed).length;
    return (completed / _tutorials.length) * 100;
  }

  /// Reset all tutorials
  Future<void> resetTutorials() async {
    for (int i = 0; i < _tutorials.length; i++) {
      _tutorials[i] = _tutorials[i].copyWith(completed: false);
    }
    await _saveCompletionStatus();
  }

  /// Load completion status from storage
  void _loadCompletionStatus() {
    final stored = _storage.read<Map>(_storageKey);
    if (stored != null) {
      for (int i = 0; i < _tutorials.length; i++) {
        final isCompleted = stored[_tutorials[i].id] ?? false;
        _tutorials[i] = _tutorials[i].copyWith(completed: isCompleted);
      }
    }
  }

  /// Save completion status to storage
  Future<void> _saveCompletionStatus() async {
    final status = <String, bool>{};
    for (final tutorial in _tutorials) {
      status[tutorial.id] = tutorial.completed;
    }
    await _storage.write(_storageKey, status);
  }
}
