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

typedef LatestReleaseFetcher =
    Future<http.Response> Function(String currentVersion);

class UpdateService {
  static const String repoOwner = 'techtouchAI';
  static const String repoName = 'SUN-';
  static const String universalApkName = 'sun-universal-release.apk';
  static const Duration requestTimeout = Duration(seconds: 20);
  static const Duration downloadTimeout = Duration(minutes: 10);
  static const int maxAttempts = 2;

  final DateTime Function()? _clock;
  final LatestReleaseFetcher? _latestReleaseFetcher;

  UpdateService({
    DateTime Function()? clock,
    LatestReleaseFetcher? latestReleaseFetcher,
  }) : _clock = clock,
       _latestReleaseFetcher = latestReleaseFetcher;

  Future<UpdateInfo> checkUpdateAvailable() async {
    if (!Platform.isAndroid) return const UpdateInfo.none();

    final packageInfo = await PackageInfo.fromPlatform();
    return checkUpdateAvailableForVersion(packageInfo.version);
  }

  Future<UpdateInfo> checkUpdateAvailableForVersion(
    String currentVersionRaw,
  ) async {
    final currentVersion = SemanticBuildVersion.parse(currentVersionRaw);
    final release = await _loadLatestRelease(currentVersionRaw);
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

  Future<PublishedRelease> _loadLatestRelease(String currentVersion) async {
    final now = (_clock?.call() ?? DateTime.now()).toUtc();

    try {
      final fetcher = _latestReleaseFetcher;
      final response = fetcher == null
          ? await _getLatestReleaseWithRetry(currentVersion: currentVersion)
          : await fetcher(currentVersion);
      if (response.statusCode == HttpStatus.ok) {
        return PublishedRelease.fromGitHub(jsonDecode(response.body));
      }
      final rateLimitRetryAt = retryAtForResponse(response, now);
      if (rateLimitRetryAt != null) {
        throw UpdateCheckDeferred(rateLimitRetryAt);
      }
      throw UpdateFailure(
        'تعذر التحقق من التحديثات. رمز الخادم: ${response.statusCode}.',
      );
    } on UpdateCheckDeferred {
      rethrow;
    } on UpdateFailure {
      rethrow;
    } catch (error) {
      throw UpdateFailure('تعذر الاتصال بخادم التحديث: $error');
    }
  }

  Future<http.Response> _getLatestReleaseWithRetry({
    required String currentVersion,
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
          'User-Agent': 'SUN-OTA/$currentVersion',
        };
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

  static Future<void> deletePartialFile(File? file) async {
    if (file == null || !await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {
      // A failed cleanup must not mask the original download error.
    }
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
      await deletePartialFile(partialFile);
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

class PublishedRelease {
  final String tagName;
  final UpdateAsset asset;

  const PublishedRelease({required this.tagName, required this.asset});

  factory PublishedRelease.fromGitHub(dynamic payload) {
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
    return PublishedRelease(tagName: tagName, asset: asset);
  }
}

String? _header(Map<String, String> headers, String name) {
  final expected = name.toLowerCase();
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == expected) return entry.value;
  }
  return null;
}
