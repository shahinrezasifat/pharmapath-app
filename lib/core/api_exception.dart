class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.uri,
    this.bodySnippet,
    this.authRequired = false,
  });

  final String message;
  final int? statusCode;
  final Uri? uri;
  final String? bodySnippet;

  /// True when the server rejected the request because no valid account token
  /// was supplied. The UI turns this into a "connection settings" hint instead
  /// of a generic failure.
  final bool authRequired;

  bool get isNetwork => statusCode == null && !authRequired;

  @override
  String toString() {
    final parts = <String>[
      if (statusCode != null) 'HTTP $statusCode',
      message,
      if (uri != null) uri.toString(),
    ];
    return parts.join(' · ');
  }
}
