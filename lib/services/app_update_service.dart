import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_config.dart';

class AppRelease {
  const AppRelease({
    required this.version,
    required this.tag,
    required this.notes,
    required this.releaseUrl,
    required this.apkUrl,
  });

  final String version;
  final String tag;
  final String notes;
  final Uri releaseUrl;
  final Uri? apkUrl;

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final assets = (json['assets'] as List? ?? const [])
        .whereType<Map<String, dynamic>>();
    Uri? apkUrl;
    for (final asset in assets) {
      final name = asset['name']?.toString().toLowerCase() ?? '';
      final url = Uri.tryParse(asset['browser_download_url']?.toString() ?? '');
      if (name.endsWith('.apk') && url?.scheme == 'https') {
        apkUrl = url;
        break;
      }
    }

    return AppRelease(
      version: AppUpdateService.cleanVersion(json['tag_name']?.toString() ?? ''),
      tag: json['tag_name']?.toString() ?? '',
      notes: json['body']?.toString().trim() ?? '',
      releaseUrl: Uri.parse(json['html_url']?.toString() ?? ''),
      apkUrl: apkUrl,
    );
  }
}

class AppUpdateService {
  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  static const _owner = AppConfig.githubOwner;
  static const _repository = AppConfig.githubRepository;
  static const _installer = MethodChannel('pharmapath/app_installer');

  final http.Client _client;
  AppRelease? latestRelease;
  String? _downloadedApkPath;

  bool get isConfigured =>
      _validRepositoryPart(_owner) && _validRepositoryPart(_repository);

  static String cleanVersion(String input) => input
      .trim()
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split('+')
      .first;

  static bool _validRepositoryPart(String value) =>
      value.isNotEmpty &&
      !value.contains('/') &&
      !value.contains(' ') &&
      !value.contains('..');

  Future<AppRelease?> checkForUpdate() async {
    if (!kReleaseMode || !isConfigured) return null;
    final uri = Uri.https(
      'api.github.com',
      '/repos/$_owner/$_repository/releases/latest',
    );
    final response = await _client
        .get(uri, headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'PharmaPath-Android-App',
          'X-GitHub-Api-Version': '2022-11-28',
        })
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 404) return null;
    if (response.statusCode == 403 && response.body.contains('rate limit')) {
      return _checkLatestReleaseViaWeb();
    }
    if (response.statusCode != 200) {
      throw HttpException('GitHub returned ${response.statusCode}: ${response.body}');
    }
    // A captive portal or proxy can answer 200 with HTML; jsonDecode would
    // throw a FormatException out of this background check and break startup.
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw HttpException('GitHub returned a non-JSON response');
    }
    if (decoded is! Map<String, dynamic> || decoded['draft'] == true || decoded['prerelease'] == true) {
      return null;
    }
    final release = AppRelease.fromJson(decoded);
    if (release.version.isEmpty || !release.releaseUrl.hasScheme) return null;
    final installed = (await PackageInfo.fromPlatform()).version;
    latestRelease = compareVersions(release.version, installed) > 0
        ? release
        : null;
    return latestRelease;
  }

  Future<AppRelease?> _checkLatestReleaseViaWeb() async {
    final uri = Uri.https('github.com', '$_owner/$_repository/releases/latest');
    final response = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw HttpException('GitHub releases page returned ${response.statusCode}');
    }
    final location = RegExp(
      r'href="/[^/]+/[^/]+/releases/tag/([^"?]+)',
    ).firstMatch(response.body);
    final tag = location == null
        ? null
        : Uri.decodeComponent(location.group(1)!);
    if (tag == null || tag.isEmpty) return null;
    final version = cleanVersion(tag);
    final installed = (await PackageInfo.fromPlatform()).version;
    latestRelease = compareVersions(version, installed) > 0
        ? AppRelease(
            version: version,
            tag: tag,
            notes: 'GitHub থেকে নতুন সংস্করণ উপলভ্য।',
            releaseUrl: uri,
            apkUrl: Uri.https(
              'github.com',
              '$_owner/$_repository/releases/download/$tag/PharmaPath-$tag.apk',
            ),
          )
        : null;
    return latestRelease;
  }

  Future<void> downloadAndInstall({
    required void Function(double progress) onProgress,
  }) async {
    final release = latestRelease;
    if (release == null) throw StateError('No app update is available.');
    if (!Platform.isAndroid || release.apkUrl == null) {
      await openReleasePage();
      return;
    }

    final request = http.Request('GET', release.apkUrl!);
    final response = await _client.send(request).timeout(
      const Duration(seconds: 30),
    );
    if (response.statusCode != 200) {
      throw HttpException('APK download returned ${response.statusCode}');
    }
    final length = response.contentLength;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}pharmapath-update.apk');
    final sink = file.openWrite();
    var received = 0;
    try {
      // A timeout on the initial response is not enough: the body stream can
      // stall forever, so bound the whole download as well.
      await () async {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (length != null && length > 0) {
            onProgress((received / length).clamp(0.0, 1.0));
          }
        }
        await sink.flush();
      }().timeout(const Duration(minutes: 5));
    } finally {
      await sink.close();
    }
    if (received == 0 || (length != null && received != length)) {
      await file.delete().catchError((_) => file);
      throw const FileSystemException('APK download was incomplete.');
    }
    final header = await file.openRead(0, 4).fold<List<int>>(
      <int>[],
      (bytes, chunk) => bytes..addAll(chunk),
    );
    if (header.length < 4 ||
        header[0] != 0x50 ||
        header[1] != 0x4b ||
        header[2] != 0x03 ||
        header[3] != 0x04) {
      await file.delete().catchError((_) => file);
      throw const FileSystemException('The downloaded file is not an APK.');
    }
    _downloadedApkPath = file.path;

    try {
      await _installer.invokeMethod<void>('installApk', {'path': file.path});
    } on PlatformException catch (error) {
      if (error.code == 'permission_required') {
        await _installer.invokeMethod<void>('openInstallPermissionSettings');
        throw const AppInstallPermissionRequired();
      }
      rethrow;
    }
  }

  Future<void> resumeInstall() async {
    final path = _downloadedApkPath;
    if (path == null || !await File(path).exists()) {
      throw StateError('APK must be downloaded again.');
    }
    await _installer.invokeMethod<void>('installApk', {'path': path});
  }

  Future<void> openReleasePage() async {
    final uri = latestRelease?.releaseUrl ?? Uri.https(
      'github.com',
      '$_owner/$_repository/releases/latest',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static int compareVersions(String left, String right) {
    final a = cleanVersion(left).split('.');
    final b = cleanVersion(right).split('.');
    for (var i = 0; i < max(a.length, b.length); i++) {
      final x = i < a.length ? int.tryParse(a[i]) ?? 0 : 0;
      final y = i < b.length ? int.tryParse(b[i]) ?? 0 : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }
}

class AppInstallPermissionRequired implements Exception {
  const AppInstallPermissionRequired();
}
