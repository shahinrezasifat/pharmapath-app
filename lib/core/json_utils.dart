/// Small, forgiving helpers for third-party JSON whose schema is not documented.
///
/// The MedEx API is not publicly specified. The parser therefore accepts the
/// common envelope shapes (plain list, `{data: [...]}`, `{data: {data: [...]}}`,
/// Laravel pagination, etc.) and never throws on a missing optional field.
library;

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Object>()
        .map(asMap)
        .where((m) => m.isNotEmpty)
        .toList();
  }
  return const <Map<String, dynamic>>[];
}

dynamic pickRaw(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value != null) return value;
  }
  return null;
}

String? pickString(Map<String, dynamic> map, List<String> keys) {
  final value = pickRaw(map, keys);
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? pickInt(Map<String, dynamic> map, List<String> keys) {
  final value = pickRaw(map, keys);
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? pickDouble(Map<String, dynamic> map, List<String> keys) {
  final value = pickRaw(map, keys);
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

/// Finds the first list of objects anywhere in the expected envelope positions.
List<Map<String, dynamic>> extractItems(dynamic decoded) {
  if (decoded is List) return asMapList(decoded);
  final map = asMap(decoded);
  if (map.isEmpty) return const [];

  const listKeys = <String>[
    'data',
    'items',
    'results',
    'records',
    'list',
    'rows',
    'brands',
    'generics',
    'companies',
    'indications',
    'jobs',
    'dosage_forms',
    'drug_classes',
    'campaigns',
    'segments',
  ];

  for (final key in listKeys) {
    final value = map[key];
    if (value is List) return asMapList(value);
  }
  // Laravel style: { data: { data: [...] } }
  final data = map['data'];
  if (data is Map) {
    for (final key in listKeys) {
      final value = data[key];
      if (value is List) return asMapList(value);
    }
  }
  return const [];
}

Map<String, dynamic> extractMeta(dynamic decoded) {
  final map = asMap(decoded);
  if (map.isEmpty) return const {};
  final meta = map['meta'];
  if (meta is Map) return asMap(meta);
  final data = map['data'];
  if (data is Map) {
    final nested = data['meta'];
    if (nested is Map) return asMap(nested);
    return asMap(data);
  }
  return map;
}

/// Returns the server's own error message when the payload is an application
/// level failure (`success: false`), even though HTTP status is 200.
///
/// The catalogue API answers unauthenticated reads with
/// `{"success": false, "message": "Authentication token missing", "data": []}`,
/// which would otherwise look like an empty list.
String? envelopeErrorMessage(dynamic decoded) {
  final map = asMap(decoded);
  if (map.isEmpty) return null;
  final success = map['success'];
  final failed = success == false || success == 0;
  final status = map['status'];
  final statusFailed = status is String && status.toLowerCase() == 'error';
  if (!failed && !statusFailed) return null;
  return pickString(map, const ['message', 'error', 'detail']) ??
      'The API rejected the request';
}

/// Heuristic used only to choose the right UI hint — never to bypass a check.
bool isAuthMessage(String message) => RegExp(
  r'auth|token|unauthor|credential|login',
  caseSensitive: false,
).hasMatch(message);

bool looksLikeHtml(String text) => RegExp(
  r'<\s*(p|div|br|span|ul|ol|li|h[1-6]|strong|em|table)\b',
  caseSensitive: false,
).hasMatch(text);

String stripHtml(String text) => text
    .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
    .replaceAll(
      RegExp(r'</\s*(p|div|li|h[1-6])\s*>', caseSensitive: false),
      '\n',
    )
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .trim();
