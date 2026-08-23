import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors/app_exceptions.dart';
import 'version_comparator.dart';

class UpdateInfo {
  final bool isUpdateAvailable;
  final String latestVersion;
  final String downloadUrl;
  final String sha256;
  final int assetSize;

  const UpdateInfo({
    required this.isUpdateAvailable,
    required this.latestVersion,
    required this.downloadUrl,
    required this.sha256,
    required this.assetSize,
  });

  const UpdateInfo.none()
    : isUpdateAvailable = false,
      latestVersion = '',
      downloadUrl = '',
      sha256 = '',
      assetSize = 0;
}

class UpdateService {
  static const String repoOwner = 'techtouchAI';
  static const String repoName = 'SUN-';
  static const String universalApkName = 'sun-universal-release.apk';
  static const Duration requestTimeout = Duration(seconds: 20);
  static const Duration downloadTimeout = Duration(minutes: 10);
  static const Duration cacheTtl = Duration(hours: 6);
  static const int maxAttempts = 2;

  Future<UpdateInfo> checkUpdateAvailable() async {
    if (!Platform.isAndroid) return const UpdateInfo.none();

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = SemanticBuildVersion.parse(packageInfo.version);
    final release = await _loadLatestRelease(packageInfo);
    final latestVersion = SemanticBuildVersion.parse(release.tagName);
    if (!latestVersion.isNewerThan(currentVersion)) {
      return const UpdateInfo.none();
    }

    return UpdateInfo(
      isUpdateAvailable: true,
      latestVersion: latestVersion.display,
      downloadUrl: release.asset.url,
      sha256: release.asset.sha256,
      assetSize: release.asset.size,
    );
  }

  Future<CachedRelease> _loadLatestRelease(PackageInfo packageInfo) async {
    final preferences = await SharedPreferences.getInstance();
    final cache = ReleaseCache(preferences);
    final now = DateTime.now().toUtc();
    final cached = cache.read();

    if (cached != null && now.difference(cached.checkedAt) < cacheTtl) {
      return cached;
    }

    final retryAt = cache.retryAt();
    if (retryAt != null && now.isBefore(retryAt)) {
      if (cached != null) return cached;
      throw UpdateCheckDeferred(retryAt);
    }

    try {
      final response = await _getLatestReleaseWithRetry(
        packageInfo: packageInfo,
        etag: cached?.etag,
      );
      if (response.statusCode == HttpStatus.notModified && cached != null) {
        final refreshed = cached.withCheckedAt(now);
        await cache.save(refreshed);
        return refreshed;
      }
      if (response.statusCode == HttpStatus.ok) {
        final parsed = CachedRelease.fromGitHub(
          jsonDecode(response.body),
          etag: _header(response.headers, 'etag'),
          checkedAt: now,
        );
        await cache.save(parsed);
        return parsed;
      }
      final rateLimitRetryAt = retryAtForResponse(response, now);
      if (rateLimitRetryAt != null) {
        final nextRetry = rateLimitRetryAt;
        await cache.saveRetryAt(nextRetry);
        if (cached != null) return cached;
        throw UpdateCheckDeferred(nextRetry);
      }
      throw UpdateFailure(
        'تعذر التحقق من التحديثات. رمز الخادم: ${response.statusCode}.',
      );
    } on UpdateCheckDeferred {
      rethrow;
    } on UpdateFailure {
      rethrow;
    } catch (error) {
      if (cached != null) return cached;
      throw UpdateFailure('تعذر الاتصال بخادم التحديث: $error');
    }
  }

  Future<http.Response> _getLatestReleaseWithRetry({
    required PackageInfo packageInfo,
    String? etag,
  }) async {
    final url = Uri.https(
      'api.github.com',
      '/repos/$repoOwner/$repoName/releases/latest',
    );
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final headers = <String, String>{
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': 'SUN-OTA/${packageInfo.version}',
        };
        if (etag != null && etag.isNotEmpty) headers['If-None-Match'] = etag;
        final response = await http
            .get(url, headers: headers)
            .timeout(requestTimeout);
        if (response.statusCode == HttpStatus.forbidden ||
            response.statusCode == HttpStatus.tooManyRequests ||
            response.statusCode < HttpStatus.internalServerError) {
          return response;
        }
        lastError = 'رمز الخادم ${response.statusCode}';
      } catch (error) {
        lastError = error;
      }
      if (attempt + 1 < maxAttempts) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }
    throw UpdateFailure('تعذر الاتصال بخادم التحديث: $lastError');
  }

  static DateTime retryAtFromHeaders(
    Map<String, String> headers,
    DateTime now,
  ) {
    final retryAfter = int.tryParse(_header(headers, 'retry-after') ?? '');
    if (retryAfter != null && retryAfter > 0) {
      return now.add(Duration(seconds: retryAfter));
    }
    final resetEpoch = int.tryParse(
      _header(headers, 'x-ratelimit-reset') ?? '',
    );
    if (resetEpoch != null && resetEpoch > 0) {
      return DateTime.fromMillisecondsSinceEpoch(
        resetEpoch * 1000,
        isUtc: true,
      );
    }
    return now.add(const Duration(minutes: 1));
  }

  static DateTime? retryAtForResponse(http.Response response, DateTime now) {
    if (response.statusCode != HttpStatus.forbidden &&
        response.statusCode != HttpStatus.tooManyRequests) {
      return null;
    }
    return retryAtFromHeaders(response.headers, now);
  }

  static Future<File> verifyAndPromoteApk({
    required File partialFile,
    required File destinationFile,
    required int expectedSize,
    required String expectedSha256,
  }) async {
    final actualSize = await partialFile.length();
    if (actualSize != expectedSize) {
      throw const UpdateFailure('حجم ملف التحديث غير مطابق للنسخة المنشورة.');
    }
    final actualHash = await sha256.bind(partialFile.openRead()).first;
    if (actualHash.toString() != expectedSha256) {
      throw const UpdateFailure('فشل التحقق من سلامة APK؛ لن يتم تثبيت الملف.');
    }
    if (await destinationFile.exists()) await destinationFile.delete();
    return partialFile.rename(destinationFile.path);
  }

  static UpdateAsset selectUniversalApkAsset(List<dynamic> assets) {
    final matching = <UpdateAsset>[];
    for (final item in assets) {
      if (item is! Map) continue;
      final name = item['name'];
      final url = item['browser_download_url'];
      final digest = item['digest'];
      final size = item['size'];
      if (name is! String ||
          url is! String ||
          digest is! String ||
          size is! int ||
          size <= 0) {
        continue;
      }
      if (name.toLowerCase() != universalApkName) continue;
      final parsedUrl = Uri.tryParse(url);
      final normalizedDigest = digest.toLowerCase();
      if (parsedUrl == null || parsedUrl.scheme != 'https') continue;
      if (parsedUrl.host != 'github.com') continue;
      if (!normalizedDigest.startsWith('sha256:')) continue;
      final hash = normalizedDigest.substring('sha256:'.length);
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) continue;
      matching.add(UpdateAsset(name: name, url: url, sha256: hash, size: size));
    }
    if (matching.isEmpty) {
      throw const UpdateFailure('لا يوجد Universal APK صالح مرفق مع الإصدار.');
    }
    if (matching.length > 1) {
      throw const UpdateFailure(
        'الإصدار يحتوي على أكثر من Universal APK بالاسم نفسه.',
      );
    }
    return matching.single;
  }

  Future<void> checkForUpdatesAndShowDialog(BuildContext context) async {
    try {
      final updateInfo = await checkUpdateAvailable();
      if (!context.mounted || !updateInfo.isUpdateAvailable) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تحديث جديد متوفر'),
          content: Text(
            'تم إصدار ${updateInfo.latestVersion}. هل تريد تنزيله؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('لاحقاً'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _downloadAndInstallUpdate(context, updateInfo);
              },
              child: const Text('تنزيل وتثبيت'),
            ),
          ],
        ),
      );
    } on UpdateCheckDeferred {
      // An automatic check must not interrupt the user while GitHub is throttling.
    } catch (error) {
      if (context.mounted) _showErrorSnackbar(context, error.toString());
    }
  }

  Future<void> _downloadAndInstallUpdate(
    BuildContext context,
    UpdateInfo info,
  ) async {
    final progress = ValueNotifier<double>(0);
    File? partialFile;
    var progressDialogOpen = false;
    try {
      final permission = await Permission.requestInstallPackages.request();
      if (!permission.isGranted && !permission.isLimited) {
        throw const UpdateFailure('يجب السماح بتثبيت التحديثات من هذا المصدر.');
      }

      final directory = await getApplicationSupportDirectory();
      final safeVersion = info.latestVersion.replaceAll(
        RegExp(r'[^0-9.]'),
        '_',
      );
      final finalFile = File('${directory.path}/sun-update-$safeVersion.apk');
      partialFile = File('${finalFile.path}.part');
      if (await partialFile.exists()) await partialFile.delete();
      if (!context.mounted) return;

      progressDialogOpen = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (context, value, child) => AlertDialog(
            title: const Text('جاري تنزيل التحديث'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: value == 0 ? null : value),
                const SizedBox(height: 12),
                Text('${(value * 100).toStringAsFixed(1)}%'),
              ],
            ),
          ),
        ),
      );

      final response = await Dio().download(
        info.downloadUrl,
        partialFile.path,
        options: Options(
          responseType: ResponseType.bytes,
          connectTimeout: requestTimeout,
          receiveTimeout: downloadTimeout,
          sendTimeout: requestTimeout,
          followRedirects: true,
          maxRedirects: 5,
          validateStatus: (status) => status == HttpStatus.ok,
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) progress.value = received / total;
        },
      );
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateFailure(
          'تعذر تنزيل ملف التحديث. رمز الخادم: ${response.statusCode}.',
        );
      }
      final installedFile = await verifyAndPromoteApk(
        partialFile: partialFile,
        destinationFile: finalFile,
        expectedSize: info.assetSize,
        expectedSha256: info.sha256,
      );
      partialFile = null;

      if (progressDialogOpen && context.mounted) {
        Navigator.of(context).pop();
        progressDialogOpen = false;
      }
      final openResult = await OpenFilex.open(
        installedFile.path,
        type: 'application/vnd.android.package-archive',
      );
      if (openResult.type != ResultType.done) {
        throw UpdateFailure('تعذر فتح مثبت APK: ${openResult.message}');
      }
      // Do not delete installedFile here. Android reads the FileProvider URI asynchronously.
    } catch (error) {
      if (progressDialogOpen && context.mounted) Navigator.of(context).pop();
      if (partialFile != null && await partialFile.exists()) {
        try {
          await partialFile.delete();
        } catch (_) {
          // A failed cleanup must not mask the original download error.
        }
      }
      if (context.mounted) _showErrorSnackbar(context, error.toString());
    } finally {
      progress.dispose();
    }
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }
}

class UpdateAsset {
  final String name;
  final String url;
  final String sha256;
  final int size;

  const UpdateAsset({
    required this.name,
    required this.url,
    required this.sha256,
    required this.size,
  });
}

class UpdateCheckDeferred implements Exception {
  final DateTime retryAt;

  const UpdateCheckDeferred(this.retryAt);
}

class CachedRelease {
  final String tagName;
  final UpdateAsset asset;
  final String? etag;
  final DateTime checkedAt;

  const CachedRelease({
    required this.tagName,
    required this.asset,
    required this.etag,
    required this.checkedAt,
  });

  factory CachedRelease.fromGitHub(
    dynamic payload, {
    required String? etag,
    required DateTime checkedAt,
  }) {
    if (payload is! Map) {
      throw const UpdateFailure('استجابة التحديث غير صالحة.');
    }
    final release = Map<String, dynamic>.from(payload);
    final tagName = release['tag_name'];
    final assets = release['assets'];
    if (tagName is! String || assets is! List) {
      throw const UpdateFailure('الإصدار المنشور لا يحتوي على بيانات صالحة.');
    }
    SemanticBuildVersion.parse(tagName);
    final asset = UpdateService.selectUniversalApkAsset(assets);
    return CachedRelease(
      tagName: tagName,
      asset: asset,
      etag: etag,
      checkedAt: checkedAt,
    );
  }

  factory CachedRelease.fromJson(Map<String, dynamic> json) {
    final tagName = json['tagName'];
    final url = json['url'];
    final sha256 = json['sha256'];
    final size = json['size'];
    final checkedAt = json['checkedAt'];
    if (tagName is! String ||
        url is! String ||
        sha256 is! String ||
        size is! int ||
        size <= 0 ||
        checkedAt is! String) {
      throw const FormatException('Invalid cached update release.');
    }
    return CachedRelease(
      tagName: tagName,
      asset: UpdateAsset(
        name: UpdateService.universalApkName,
        url: url,
        sha256: sha256,
        size: size,
      ),
      etag: json['etag'] as String?,
      checkedAt: DateTime.parse(checkedAt).toUtc(),
    );
  }

  CachedRelease withCheckedAt(DateTime value) => CachedRelease(
    tagName: tagName,
    asset: asset,
    etag: etag,
    checkedAt: value,
  );

  Map<String, Object?> toJson() => {
    'tagName': tagName,
    'url': asset.url,
    'sha256': asset.sha256,
    'size': asset.size,
    'etag': etag,
    'checkedAt': checkedAt.toIso8601String(),
  };
}

class ReleaseCache {
  static const _releaseKey = 'ota.release.cache.v1';
  static const _retryAtKey = 'ota.release.retry_at.v1';
  final SharedPreferences preferences;

  const ReleaseCache(this.preferences);

  CachedRelease? read() {
    final raw = preferences.getString(_releaseKey);
    if (raw == null) return null;
    try {
      return CachedRelease.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw)),
      );
    } catch (_) {
      preferences.remove(_releaseKey);
      return null;
    }
  }

  DateTime? retryAt() {
    final raw = preferences.getString(_retryAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> save(CachedRelease value) async {
    await preferences.setString(_releaseKey, jsonEncode(value.toJson()));
    await preferences.remove(_retryAtKey);
  }

  Future<void> saveRetryAt(DateTime value) =>
      preferences.setString(_retryAtKey, value.toUtc().toIso8601String());
}

String? _header(Map<String, String> headers, String name) {
  final expected = name.toLowerCase();
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == expected) return entry.value;
  }
  return null;
}
