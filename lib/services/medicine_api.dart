import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_exception.dart';
import '../core/app_config.dart';
import '../core/json_utils.dart';
import '../models/medicine.dart';

/// Client for the self-hosted BD Medicine API
/// (`GET /medicines`, `/medicines/{id}`, `/stats`, `/health`).
class MedicineApi {
  MedicineApi({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String Function() baseUrl;
  final http.Client _client;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final raw = baseUrl().trim();
    final base = Uri.tryParse(
      raw.isEmpty ? AppConfig.defaultMedicineApiBase : raw,
    );
    if (base == null || !base.hasScheme) {
      throw ApiException('API ঠিকানাটি সঠিক নয়। সেটিংসে গিয়ে ঠিক করুন।');
    }
    var basePath = base.path;
    if (basePath.endsWith('/')) {
      basePath = basePath.substring(0, basePath.length - 1);
    }
    final relative = path.startsWith('/') ? path : '/$path';
    final params = <String, String>{};
    query?.forEach((key, value) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) params[key] = text;
    });
    return base.replace(
      path: '$basePath$relative',
      queryParameters: params.isEmpty ? null : params,
    );
  }

  Future<dynamic> _get(String path, [Map<String, dynamic>? query]) async {
    final uri = _uri(path, query);
    late http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': AppConfig.userAgent,
            },
          )
          .timeout(AppConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException('সার্ভারে পৌঁছানো যাচ্ছে না (সময় শেষ)।', uri: uri);
    } catch (error) {
      throw ApiException(
        'নেটওয়ার্ক সমস্যা। ইন্টারনেট ও API ঠিকানা পরীক্ষা করুন।',
        uri: uri,
      );
    }

    if (response.statusCode == 404) {
      throw ApiException(
        'অনুরোধ করা তথ্য পাওয়া যায়নি।',
        statusCode: 404,
        uri: uri,
      );
    }
    if (response.statusCode >= 400) {
      throw ApiException(
        'সার্ভার ত্রুটি (HTTP ${response.statusCode})।',
        statusCode: response.statusCode,
        uri: uri,
        bodySnippet: response.body.length > 200
            ? response.body.substring(0, 200)
            : response.body,
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      final error = envelopeErrorMessage(decoded);
      if (error != null) {
        throw ApiException(error, statusCode: response.statusCode, uri: uri);
      }
      return decoded;
    } on FormatException {
      throw ApiException(
        'সার্ভার JSON নয় এমন উত্তর দিয়েছে।',
        statusCode: response.statusCode,
        uri: uri,
      );
    }
  }

  Future<void> health() async {
    final decoded = asMap(await _get('/health'));
    if (decoded['status']?.toString() != 'ok') {
      throw ApiException('API স্বাস্থ্য-পরীক্ষায় উত্তীর্ণ হয়নি।');
    }
  }

  Future<Map<String, dynamic>> stats() async => asMap(await _get('/stats'));

  Future<MedicinePage> medicines({
    int page = 1,
    int limit = AppConfig.syncPageSize,
    String? search,
    String? company,
    String? generic,
    String? dosageForm,
  }) async {
    final decoded = asMap(
      await _get('/medicines', {
        'page': page,
        'limit': limit,
        'search': search,
        'company': company,
        'generic': generic,
        'dosage_form': dosageForm,
      }),
    );
    final results = decoded['results'];
    final items = (results is List ? results : const [])
        .whereType<Map>()
        .map((e) => Medicine.fromApi(e.cast<String, dynamic>()))
        .where((m) => m.id > 0)
        .toList();
    final total = pickInt(decoded, const ['total']) ?? items.length;
    final totalPages =
        pickInt(decoded, const ['total_pages']) ??
        (total == 0 ? 0 : (total / limit).ceil());
    return MedicinePage(
      items: items,
      page: page,
      totalPages: totalPages,
      total: total,
    );
  }

  Future<Medicine> medicine(int id) async {
    final map = asMap(await _get('/medicines/$id'));
    return Medicine.fromApi(map);
  }

  void dispose() => _client.close();
}
