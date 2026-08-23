import 'package:flutter/material.dart';

class UpdateInfo {
  final bool isUpdateAvailable;
  final String latestVersion;
  final String downloadUrl;
  final String sha256;

  const UpdateInfo({
    required this.isUpdateAvailable,
    required this.latestVersion,
    required this.downloadUrl,
    this.sha256 = '',
  });
}

class UpdateService {
  Future<UpdateInfo> checkUpdateAvailable() async => const UpdateInfo(
    isUpdateAvailable: false,
    latestVersion: '',
    downloadUrl: '',
  );

  Future<void> checkForUpdatesAndShowDialog(BuildContext context) async {
    // APK installation is intentionally unavailable outside Android.
  }
}
