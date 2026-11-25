import 'dart:convert';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'oxion_assistant.dart';

class PrescriptionMedicine {
  const PrescriptionMedicine({required this.name, required this.dosageRules});

  final String name;
  final String dosageRules;

  factory PrescriptionMedicine.fromJson(Map<String, dynamic> json) {
    final name = json['medicine_name'];
    final dosageRules = json['dosage_rules'];
    if (name is! String ||
        name.trim().isEmpty ||
        dosageRules is! String ||
        dosageRules.trim().isEmpty) {
      throw const FormatException('Invalid prescription item.');
    }
    return PrescriptionMedicine(
      name: name.trim(),
      dosageRules: dosageRules.trim(),
    );
  }
}

List<PrescriptionMedicine> parsePrescriptionMedicines(String response) {
  final decoded = jsonDecode(response);
  if (decoded is! List) throw const FormatException('Expected a JSON array.');
  return decoded.map((item) {
    if (item is! Map<String, dynamic>) {
      throw const FormatException('Invalid prescription item.');
    }
    return PrescriptionMedicine.fromJson(item);
  }).toList();
}

class PrescriptionAnalyzer {
  PrescriptionAnalyzer({required this._assistant, Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final OxionAssistant _assistant;
  final Connectivity _connectivity;

  Future<List<PrescriptionMedicine>> analyze(String imagePath) async {
    final connections = await _connectivity.checkConnectivity();
    if (connections.every(
      (connection) => connection == ConnectivityResult.none,
    )) {
      throw const PrescriptionOfflineException();
    }

    final Uint8List? compressed = await FlutterImageCompress.compressWithFile(
      imagePath,
      minWidth: 1024,
      minHeight: 1024,
      quality: 70,
      format: CompressFormat.jpeg,
    );
    if (compressed == null || compressed.isEmpty) {
      throw const FormatException('Could not process prescription image.');
    }

    final response = await _assistant.analyzePrescriptionImage(compressed);
    try {
      return parsePrescriptionMedicines(response);
    } on FormatException {
      throw const PrescriptionUnreadableException();
    }
  }
}

class PrescriptionOfflineException implements Exception {
  const PrescriptionOfflineException();
}

class PrescriptionUnreadableException implements Exception {
  const PrescriptionUnreadableException();
}
