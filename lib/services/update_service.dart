import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class UpdateInfo {
  final bool isUpdateAvailable;
  final String latestVersion;
  final String downloadUrl;

  UpdateInfo({
    required this.isUpdateAvailable,
    required this.latestVersion,
    required this.downloadUrl,
  });
}

class UpdateService {
  static const String repoOwner = 'techtouchAI';
  static const String repoName = 'SUN-';

  Future<UpdateInfo> checkUpdateAvailable() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersionStr = packageInfo.version;

      final Uri url = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
      final response = await http.get(url, headers: {'Accept': 'application/vnd.github.v3+json'});

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        String latestVersionStr = data['tag_name'];
        if (latestVersionStr.startsWith('v')) {
          latestVersionStr = latestVersionStr.substring(1);
        }

        String downloadUrl = data['html_url'];
        if (data['assets'] != null && data['assets'].isNotEmpty) {
          // Identify device architecture if on Android
          String targetArchitecture = '';
          if (Platform.isAndroid) {
            DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
            AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
            // Examples: arm64-v8a, armeabi-v7a, x86, x86_64
            targetArchitecture = androidInfo.supportedAbis.isNotEmpty ? androidInfo.supportedAbis.first : '';
          }

          bool foundArchSpecificApk = false;

          if (targetArchitecture.isNotEmpty) {
            for (var asset in data['assets']) {
              String assetName = asset['name'].toString().toLowerCase();
              if (assetName.endsWith('.apk') && assetName.contains(targetArchitecture.toLowerCase())) {
                downloadUrl = asset['browser_download_url'];
                foundArchSpecificApk = true;
                break;
              }
            }
          }

          // Fallback if no arch specific APK is found
          if (!foundArchSpecificApk) {
             for (var asset in data['assets']) {
              if (asset['name'].toString().endsWith('.apk')) {
                downloadUrl = asset['browser_download_url'];
                break;
              }
            }
          }
        }

        if (_isNewerVersion(currentVersionStr, latestVersionStr)) {
          return UpdateInfo(
            isUpdateAvailable: true,
            latestVersion: latestVersionStr,
            downloadUrl: downloadUrl,
          );
        }
      } else {
        throw Exception('فشل جلب التحديثات من الخادم. الحالة: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('فشل الاتصال: $e');
    }

    return UpdateInfo(
      isUpdateAvailable: false,
      latestVersion: '',
      downloadUrl: '',
    );
  }

  bool _isNewerVersion(String currentVersion, String latestVersion) {
    // إزالة رقم البناء (Build Number) إن وجد (مثل +559 أو -559)
    String currentBase = currentVersion.split('+')[0].split('-')[0];
    String latestBase = latestVersion.split('+')[0].split('-')[0];

    List<String> currentParts = currentBase.split('.');
    List<String> latestParts = latestBase.split('.');

    for (int i = 0; i < currentParts.length && i < latestParts.length; i++) {
      int currentPart = int.tryParse(currentParts[i]) ?? 0;
      int latestPart = int.tryParse(latestParts[i]) ?? 0;

      if (latestPart > currentPart) {
        return true;
      } else if (latestPart < currentPart) {
        return false;
      }
    }

    return latestParts.length > currentParts.length;
  }

  Future<void> checkForUpdatesAndShowDialog(BuildContext context) async {
    try {
      final updateInfo = await checkUpdateAvailable();
      if (!context.mounted) return;

      // Notify success for checking connection
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        )
      );

      if (updateInfo.isUpdateAvailable) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('تحديث جديد متوفر'),
              content: Text('تم إصدار نسخة جديدة من التطبيق (${updateInfo.latestVersion}). هل ترغب في التحميل الآن؟'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('لاحقاً'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (Platform.isAndroid) {
                      // Request necessary permissions for downloading and installing APK on Android
                      Map<Permission, PermissionStatus> statuses = await [
                        Permission.requestInstallPackages,
                        Permission.manageExternalStorage,
                        Permission.storage,
                      ].request();

                      // Storage / manage storage
                      if (statuses[Permission.manageExternalStorage]?.isDenied == true || statuses[Permission.storage]?.isDenied == true) {
                         // We might still proceed depending on Android version, but let's try our best.
                      }

                      if (statuses[Permission.requestInstallPackages]?.isDenied == true) {
                          // Note: REQUEST_INSTALL_PACKAGES cannot be requested at runtime the same way, but permission_handler handles app settings prompt or ignores if granted.
                      }
                    }

                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop(); // Close initial dialog
                    _downloadAndInstallUpdate(context, updateInfo.downloadUrl);
                  },
                  child: const Text('تحميل التحديث'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          )
        );
      }
    }
  }

  Future<void> _downloadAndInstallUpdate(BuildContext context, String url) async {
    final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);
    final dio = Dio();
    String savePath = '';

    try {
      final dir = await getTemporaryDirectory();
      savePath = '${dir.path}/update.apk';

      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext progressContext) {
          return AlertDialog(
            title: const Text('جاري تحميل التحديث...'),
            content: ValueListenableBuilder<double>(
              valueListenable: progressNotifier,
              builder: (context, progress, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(value: progress > 0 ? progress : null),
                    const SizedBox(height: 16),
                    Text('${(progress * 100).toStringAsFixed(1)}%'),
                  ],
                );
              },
            ),
          );
        },
      );

      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            progressNotifier.value = received / total;
          }
        },
      );

      if (context.mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        _installApk(context, savePath);
      }

    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close progress dialog on error
        _showErrorSnackbar(context, '⚠️ فشل التحميل: ${e.toString()}');
      }
    } finally {
      progressNotifier.dispose();
    }
  }

  Future<void> _installApk(BuildContext context, String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        if (context.mounted) {
          _showErrorSnackbar(context, '⚠️ فشل في فتح ملف التثبيت: ${result.message}');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackbar(context, '⚠️ حدث خطأ غير متوقع: $e');
      }
    }
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
        )
      );
    }
  }
}
