import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pharmapath_app/services/prescription_analyzer.dart';
import 'package:pharmapath_app/services/oxion_assistant.dart';

void main() {
  test(
    'prescription API uses the strict JSON prompt and a free vision model',
    () async {
      Map<String, dynamic>? sentBody;
      final assistant = OxionAssistant(
        apiKey: 'test-key',
        baseUrl: 'https://openrouter.test/api/v1',
        client: MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return httpResponse('{"choices":[{"message":{"content":"[]"}}]}');
        }),
      );

      final response = await assistant.analyzePrescriptionImage(
        Uint8List.fromList([1, 2, 3]),
      );

      expect(response, '[]');
      expect(sentBody?['model'], 'nvidia/nemotron-3.5-super-vl:free');
      final messages = sentBody?['messages'] as List;
      expect(
        messages.first['content'],
        contains('STRICTLY IGNORE all medical tests'),
      );
      expect(
        messages.first['content'],
        contains('Output the result STRICTLY as a JSON array'),
      );
      expect(
        messages.last['content'][1]['image_url']['url'],
        'data:image/jpeg;base64,AQID',
      );
      assistant.dispose();
    },
  );

  group('parsePrescriptionMedicines', () {
    test('maps medicine names and dosage instructions from a JSON array', () {
      final result = parsePrescriptionMedicines(
        '[{"medicine_name":"Napa Extend 665mg",'
        '"dosage_rules":"1-0-1 after meal for 5 days"}]',
      );

      expect(result, hasLength(1));
      expect(result.single.name, 'Napa Extend 665mg');
      expect(result.single.dosageRules, '1-0-1 after meal for 5 days');
    });

    test('accepts an empty medicine list', () {
      expect(parsePrescriptionMedicines('[]'), isEmpty);
    });

    test('rejects non-array responses and missing fields', () {
      expect(
        () => parsePrescriptionMedicines('{"medicine_name":"Napa"}'),
        throwsFormatException,
      );
      expect(
        () => parsePrescriptionMedicines(
          '[{"medicine_name":"Napa","dosage_rules":""}]',
        ),
        throwsFormatException,
      );
    });
  });
}

http.Response httpResponse(String body) =>
    http.Response(body, 200, headers: {'content-type': 'application/json'});
