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

  const UpdateInfo({
    required this.isUpdateAvailable,
    required this.latestVersion,
    required this.downloadUrl,
    required this.sha256,
  });
}

class UpdateService {
  static const String repoOwner = 'techtouchAI';
  static const String repoName = 'SUN-';
  static const Duration requestTimeout = Duration(seconds: 15);
  static const int maxAttempts = 2;

  Future<UpdateInfo> checkUpdateAvailable() async {
    if (!Platform.isAndroid) {
      return const UpdateInfo(
        isUpdateAvailable: false,
        latestVersion: '',
        downloadUrl: '',
        sha256: '',
      );
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = SemanticBuildVersion.parse(packageInfo.version);
    final response = await _getLatestReleaseWithRetry();
    if (response.statusCode != 200) {
      throw UpdateFailure(
        'تعذر التحقق من التحديثات. رمز الخادم: ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const UpdateFailure('استجابة التحديث غير صالحة.');
    }
    final release = Map<String, dynamic>.from(decoded);
    final tag = release['tag_name'];
    if (tag is! String) {
      throw const UpdateFailure('الإصدار المنشور لا يحتوي على رقم صالح.');
    }
    final latestVersion = SemanticBuildVersion.parse(tag);
    if (!latestVersion.isNewerThan(currentVersion)) {
      return const UpdateInfo(
        isUpdateAvailable: false,
        latestVersion: '',
        downloadUrl: '',
        sha256: '',
      );
    }

    final assets = release['assets'];
    if (assets is! List) {
      throw const UpdateFailure('الإصدار لا يحتوي على قائمة أصول.');
    }
    final asset = selectUniversalApkAsset(assets);
    return UpdateInfo(
      isUpdateAvailable: true,
      latestVersion: latestVersion.display,
      downloadUrl: asset.url,
      sha256: asset.sha256,
    );
  }

  Future<http.Response> _getLatestReleaseWithRetry() async {
    final url = Uri.https(
      'api.github.com',
      '/repos/$repoOwner/$repoName/releases/latest',
    );
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await http
            .get(url, headers: const {'Accept': 'application/vnd.github+json'})
            .timeout(requestTimeout);
      } catch (error) {
        lastError = error;
        if (attempt + 1 < maxAttempts) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
    }
    throw UpdateFailure('تعذر الاتصال بخادم التحديث: $lastError');
  }

  static const universalApkName = 'sun-universal-release.apk';

  static UpdateAsset selectUniversalApkAsset(List<dynamic> assets) {
    final matching = <UpdateAsset>[];
    for (final item in assets) {
      if (item is! Map) continue;
      final name = item['name'];
      final url = item['browser_download_url'];
      final digest = item['digest'];
      if (name is! String || url is! String || digest is! String) continue;
      if (name.toLowerCase() != universalApkName) continue;
      final parsedUrl = Uri.tryParse(url);
      final normalizedDigest = digest.toLowerCase();
      if (parsedUrl == null ||
          parsedUrl.scheme != 'https' ||
          parsedUrl.host != 'github.com') {
        continue;
      }
      if (!normalizedDigest.startsWith('sha256:')) continue;
      final hash = normalizedDigest.substring('sha256:'.length);
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) continue;
      matching.add(UpdateAsset(name: name, url: url, sha256: hash));
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
    } catch (error) {
      if (context.mounted) _showErrorSnackbar(context, error.toString());
    }
  }

  Future<void> _downloadAndInstallUpdate(
    BuildContext context,
    UpdateInfo info,
  ) async {
    final progress = ValueNotifier<double>(0);
    String? path;
    var progressDialogOpen = false;
    try {
      final permission = await Permission.requestInstallPackages.request();
      if (!permission.isGranted && !permission.isLimited) {
        throw const UpdateFailure('يجب السماح بتثبيت التحديثات من هذا المصدر.');
      }
      final directory = await getTemporaryDirectory();
      path =
          '${directory.path}/sun-update-${info.latestVersion.replaceAll(RegExp(r'[^0-9.]'), '_')}.apk';
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

      await Dio().download(
        info.downloadUrl,
        path,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: requestTimeout,
          sendTimeout: requestTimeout,
          validateStatus: (status) => status == 200,
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) progress.value = received / total;
        },
      );
      final bytes = await File(path).readAsBytes();
      final actual = sha256.convert(bytes).toString();
      if (actual != info.sha256) {
        throw const UpdateFailure(
          'فشل التحقق من سلامة APK؛ لن يتم تثبيت الملف.',
        );
      }

      if (progressDialogOpen && context.mounted) {
        Navigator.of(context).pop();
        progressDialogOpen = false;
      }
      final openResult = await OpenFilex.open(
        path,
        type: 'application/vnd.android.package-archive',
      );
      if (openResult.type != ResultType.done && context.mounted) {
        _showErrorSnackbar(context, 'تعذر فتح مثبت APK: ${openResult.message}');
      }
    } catch (error) {
      if (progressDialogOpen && context.mounted) Navigator.of(context).pop();
      if (context.mounted) _showErrorSnackbar(context, error.toString());
    } finally {
      progress.dispose();
      if (path != null) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {
          // Cleanup failure must not crash the UI after the main operation.
        }
      }
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

  const UpdateAsset({
    required this.name,
    required this.url,
    required this.sha256,
  });
}
