import 'package:flutter/material.dart';

/// Icon + gradient pair for each learning course, keyed by the `icon` string in
/// `assets/learning/courses.json` and body systems. Keeping this in one place means the course
/// list, course detail and quiz hub all render the same visual identity.
abstract final class LearningVisuals {
  static IconData iconFor(String name) => switch (name) {
    'hearing' => Icons.hearing_outlined,
    'psychology' || 'brain' => Icons.psychology_alt_outlined,
    'heart' || 'favorite' => Icons.favorite_outline,
    'air' || 'lungs' => Icons.air_outlined,
    'restaurant' || 'stomach' => Icons.restaurant_outlined,
    'science' || 'liver' => Icons.science_outlined,
    'water_drop' || 'kidney' => Icons.water_drop_outlined,
    'tune' || 'hormone' => Icons.tune_outlined,
    'accessibility_new' || 'bone' => Icons.accessibility_new_outlined,
    'spa' || 'skin' => Icons.spa_outlined,
    'visibility' || 'eye' => Icons.visibility_outlined,
    'female' || 'reproductive' => Icons.female_outlined,
    'bloodtype' || 'blood' => Icons.bloodtype_outlined,
    'bedtime' || 'mind' => Icons.bedtime_outlined,
    'coronavirus' || 'shield' => Icons.coronavirus_outlined,
    'local_dining' || 'nutrition' => Icons.local_dining_outlined,
    'emergency' => Icons.emergency_outlined,
    'elderly' || 'child' => Icons.elderly_outlined,
    'medication' => Icons.medication_outlined,
    'tooth' => Icons.sentiment_satisfied_outlined,
    _ => Icons.menu_book_outlined,
  };

  static List<Color> colorsFor(String name, {bool dark = false}) {
    if (dark) {
      return const [Color(0xFF1E3A8A), Color(0xFF60A5FA)];
    }
    return const [Color(0xFF93C5FD), Color(0xFF2563EB)];
  }
}
