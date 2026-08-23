import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:solar_calculator/core/errors/app_exceptions.dart';
import 'package:solar_calculator/services/update_service_native.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('parses a full GitHub release payload into a cacheable release', () {
    final checkedAt = DateTime.utc(2026, 8, 24);
    final release = CachedRelease.fromGitHub({
      'tag_name': 'v1.0.20+570',
      'assets': [
        asset(name: 'SHA256SUMS.txt'),
        asset(
          name: UpdateService.universalApkName,
          size: 60536924,
          url:
              'https://github.com/techtouchAI/SUN-/releases/download/v1.0.20%2B570/sun-universal-release.apk',
        ),
      ],
    }, etag: 'W/"release-etag"', checkedAt: checkedAt);

    expect(release.tagName, 'v1.0.20+570');
    expect(release.asset.name, UpdateService.universalApkName);
    expect(release.asset.size, 60536924);
    expect(release.etag, 'W/"release-etag"');
    expect(release.toJson()['checkedAt'], checkedAt.toIso8601String());
  });

  test('round-trips a cached release and clears a saved retry window', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final cache = ReleaseCache(preferences);
    final release = CachedRelease.fromGitHub({
      'tag_name': 'v1.0.20+570',
      'assets': [asset(name: UpdateService.universalApkName)],
    }, etag: 'etag', checkedAt: DateTime.utc(2026, 8, 24));

    await cache.saveRetryAt(DateTime.utc(2026, 8, 24, 1));
    expect(cache.retryAt(), DateTime.utc(2026, 8, 24, 1));
    await cache.save(release);

    final read = cache.read();
    expect(read?.tagName, release.tagName);
    expect(read?.asset.sha256, validHash);
    expect(cache.retryAt(), isNull);
  });

  test('classifies 403 and 429 responses as rate-limit backoff windows', () {
    final now = DateTime.utc(2026, 8, 24);
    final forbidden = http.Response('', 403, headers: {'retry-after': '90'});
    final tooMany = http.Response('', 429, headers: {'retry-after': '60'});

    expect(
      UpdateService.retryAtForResponse(forbidden, now),
      now.add(const Duration(seconds: 90)),
    );
    expect(
      UpdateService.retryAtForResponse(tooMany, now),
      now.add(const Duration(seconds: 60)),
    );
    expect(UpdateService.retryAtForResponse(http.Response('', 500), now), isNull);
  });

  test('verifies and promotes an APK atomically while retaining the final file',
      () async {
    final directory = await Directory.systemTemp.createTemp('sun-ota-test-');
    addTearDown(() => directory.delete(recursive: true));
    final bytes = [1, 2, 3, 4, 5];
    final partial = File('${directory.path}/update.apk.part');
    final destination = File('${directory.path}/update.apk');
    await partial.writeAsBytes(bytes);

    final result = await UpdateService.verifyAndPromoteApk(
      partialFile: partial,
      destinationFile: destination,
      expectedSize: bytes.length,
      expectedSha256: sha256.convert(bytes).toString(),
    );

    expect(result.path, destination.path);
    expect(await partial.exists(), isFalse);
    expect(await destination.exists(), isTrue);
    expect(await destination.readAsBytes(), bytes);
  });

  test('rejects APK promotion when the size or checksum is wrong', () async {
    final directory = await Directory.systemTemp.createTemp('sun-ota-test-');
    addTearDown(() => directory.delete(recursive: true));
    final partial = File('${directory.path}/update.apk.part');
    final destination = File('${directory.path}/update.apk');
    await partial.writeAsBytes([1, 2, 3]);

    await expectLater(
      UpdateService.verifyAndPromoteApk(
        partialFile: partial,
        destinationFile: destination,
        expectedSize: 4,
        expectedSha256: sha256.convert([1, 2, 3]).toString(),
      ),
      throwsA(isA<UpdateFailure>()),
    );
    expect(await partial.exists(), isTrue);
    expect(await destination.exists(), isFalse);

    await expectLater(
      UpdateService.verifyAndPromoteApk(
        partialFile: partial,
        destinationFile: destination,
        expectedSize: 3,
        expectedSha256: validHash,
      ),
      throwsA(isA<UpdateFailure>()),
    );
    expect(await partial.exists(), isTrue);
    expect(await destination.exists(), isFalse);
  });
}
