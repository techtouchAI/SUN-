import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/core/errors/app_exceptions.dart';
import 'package:solar_calculator/services/update_service_native.dart';

const validHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Map<String, String> asset({
  required String name,
  String url =
      'https://github.com/techtouchAI/SUN-/releases/download/v1.0.19/app-arm64-v8a-release.apk',
  String digest = 'sha256:$validHash',
}) => {'name': name, 'browser_download_url': url, 'digest': digest};

void main() {
  test('selects the exact Android ABI and rejects x86/x86_64 confusion', () {
    final selected = UpdateService.selectApkAsset([
      asset(name: 'app-x86_64-release.apk'),
      asset(
        name: 'app-x86-release.apk',
        url:
            'https://github.com/techtouchAI/SUN-/releases/download/v1.0.19/app-x86-release.apk',
      ),
    ], 'x86');
    expect(selected.name, 'app-x86-release.apk');
  });

  test('rejects missing APK, HTML asset and malformed digest', () {
    expect(
      () => UpdateService.selectApkAsset([], 'arm64-v8a'),
      throwsA(isA<UpdateFailure>()),
    );
    expect(
      () => UpdateService.selectApkAsset([
        asset(
          name: 'release.html',
          url:
              'https://github.com/techtouchAI/SUN-/releases/download/v1.0.19/release.html',
        ),
      ], 'arm64-v8a'),
      throwsA(isA<UpdateFailure>()),
    );
    expect(
      () => UpdateService.selectApkAsset([
        asset(name: 'app-arm64-v8a-release.apk', digest: 'sha256:not-a-hash'),
      ], 'arm64-v8a'),
      throwsA(isA<UpdateFailure>()),
    );
  });

  test('rejects wrong architecture and non-GitHub download URL', () {
    expect(
      () => UpdateService.selectApkAsset([
        asset(name: 'app-armeabi-v7a-release.apk'),
      ], 'arm64-v8a'),
      throwsA(isA<UpdateFailure>()),
    );
    expect(
      () => UpdateService.selectApkAsset([
        asset(
          name: 'app-arm64-v8a-release.apk',
          url: 'https://example.com/app.apk',
        ),
      ], 'arm64-v8a'),
      throwsA(isA<UpdateFailure>()),
    );
  });
}
