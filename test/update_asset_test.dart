import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/core/errors/app_exceptions.dart';
import 'package:solar_calculator/services/update_service_native.dart';

const validHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Map<String, dynamic> asset({
  required String name,
  String? url,
  String digest = 'sha256:$validHash',
  int size = 1024,
}) {
  return {
    'name': name,
    'browser_download_url':
        url ??
        'https://github.com/techtouchAI/SUN-/releases/download/v1.0.19/$name',
    'digest': digest,
    'size': size,
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
    expect(selected.size, 1024);
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

  test('rejects universal APK assets without a positive published size', () {
    expect(
      () => UpdateService.selectUniversalApkAsset([
        asset(name: UpdateService.universalApkName, size: 0),
      ]),
      throwsA(isA<UpdateFailure>()),
    );
  });

  test('respects retry-after before the GitHub rate-limit reset header', () {
    final now = DateTime.utc(2026, 8, 23, 21);
    final retryAt = UpdateService.retryAtFromHeaders({
      'Retry-After': '120',
      'X-RateLimit-Reset':
          '${now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000}',
    }, now);
    expect(retryAt, now.add(const Duration(seconds: 120)));
  });

  test('uses GitHub rate-limit reset time when retry-after is unavailable', () {
    final now = DateTime.utc(2026, 8, 23, 21);
    final expected = now.add(const Duration(minutes: 15));
    final retryAt = UpdateService.retryAtFromHeaders({
      'x-ratelimit-reset': '${expected.millisecondsSinceEpoch ~/ 1000}',
    }, now);
    expect(retryAt, expected);
  });

  test('uses a conservative delay when GitHub omits rate-limit headers', () {
    final now = DateTime.utc(2026, 8, 23, 21);
    expect(
      UpdateService.retryAtFromHeaders(const {}, now),
      now.add(const Duration(minutes: 1)),
    );
  });
}
