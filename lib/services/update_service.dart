import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
          for (var asset in data['assets']) {
            if (asset['name'].toString().endsWith('.apk')) {
              downloadUrl = asset['browser_download_url'];
              break;
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
      }
    } catch (e) {
      // Ignored for now, fail silently and do not interrupt normal app flow.
    }

    return UpdateInfo(
      isUpdateAvailable: false,
      latestVersion: '',
      downloadUrl: '',
    );
  }

  bool _isNewerVersion(String currentVersion, String latestVersion) {
    List<String> currentParts = currentVersion.split('.');
    List<String> latestParts = latestVersion.split('.');

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
    final updateInfo = await checkUpdateAvailable();
    if (updateInfo.isUpdateAvailable) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('تحديث جديد متوفر'),
            content: Text('تم إصدار نسخة جديدة من التطبيق (${updateInfo.latestVersion}). هل ترغب في التحميل الآن؟'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('لاحقاً'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final Uri url = Uri.parse(updateInfo.downloadUrl);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('تحميل التحديث'),
              ),
            ],
          );
        },
      );
    }
  }
}
