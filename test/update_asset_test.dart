import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/core/errors/app_exceptions.dart';
import 'package:solar_calculator/services/update_service_native.dart';

const validHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Map<String, String> asset({
  required String name,
  String? url,
  String digest = 'sha256:$validHash',
}) {
  return {
    'name': name,
    'browser_download_url':
        url ??
        'https://github.com/techtouchAI/SUN-/releases/download/v1.0.19/$name',
    'digest': digest,
  };
}

void main() {
  test('selects the single universal APK by its exact name', () {
    final selected = UpdateService.selectUniversalApkAsset([
      asset(name: 'app-arm64-v8a-release.apk'),
      asset(name: UpdateService.universalApkName),
      asset(name: 'app-x86_64-release.apk'),
    ]);

    expect(selected.name, UpdateService.universalApkName);
  });

  test('rejects missing universal APK, split APK and HTML asset', () {
    expect(
      () => UpdateService.selectUniversalApkAsset([]),
      throwsA(isA<UpdateFailure>()),
    );
    expect(
      () => UpdateService.selectUniversalApkAsset([
        asset(name: 'app-arm64-v8a-release.apk'),
      ]),
      throwsA(isA<UpdateFailure>()),
    );
    expect(
      () =>
          UpdateService.selectUniversalApkAsset([asset(name: 'release.html')]),
      throwsA(isA<UpdateFailure>()),
    );
  });

  test(
    'rejects malformed digest, non-GitHub URL and duplicate universal APK',
    () {
      expect(
        () => UpdateService.selectUniversalApkAsset([
          asset(
            name: UpdateService.universalApkName,
            digest: 'sha256:not-a-hash',
          ),
        ]),
        throwsA(isA<UpdateFailure>()),
      );
      expect(
        () => UpdateService.selectUniversalApkAsset([
          asset(
            name: UpdateService.universalApkName,
            url: 'https://example.com/sun-universal-release.apk',
          ),
        ]),
        throwsA(isA<UpdateFailure>()),
      );
      expect(
        () => UpdateService.selectUniversalApkAsset([
          asset(name: UpdateService.universalApkName),
          asset(name: UpdateService.universalApkName),
        ]),
        throwsA(isA<UpdateFailure>()),
      );
    },
  );
}
