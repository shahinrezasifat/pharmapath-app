import 'dart:io';

import 'package:flutter/material.dart';

import '../models.dart';

class AiPatientAvatar extends StatelessWidget {
  const AiPatientAvatar({super.key, required this.patient, this.radius = 24});

  final AiPatient patient;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final photoPath = patient.photoPath;
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.primaryContainer,
      child: photoPath.isEmpty
          ? _initial(colors)
          : ClipOval(
              child: SizedBox.square(
                dimension: radius * 2,
                child: Image.file(
                  File(photoPath),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _initial(colors),
                ),
              ),
            ),
    );
  }

  Widget _initial(ColorScheme colors) => Center(
    child: Text(
      patient.name.characters.firstOrNull ?? '?',
      style: TextStyle(
        color: colors.onPrimaryContainer,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
