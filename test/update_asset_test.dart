import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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
        'https://github.com/techtouchAI/SUN-/releases/download/v1.0.22%2B572/$name',
    'digest': digest,
    'size': size,
  };
}

String releaseBody(String version) {
  return '''{
    "tag_name":"$version",
    "assets":[{
      "name":"${UpdateService.universalApkName}",
      "browser_download_url":"https://github.com/techtouchAI/SUN-/releases/download/$version/${UpdateService.universalApkName}",
      "digest":"sha256:$validHash",
      "size":1024
    }]
  }''';
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

  test('rejects malformed digest, non-GitHub URL and duplicate APK', () {
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
  });

  test('rejects universal APK assets without a positive published size', () {
    expect(
      () => UpdateService.selectUniversalApkAsset([
        asset(name: UpdateService.universalApkName, size: 0),
      ]),
      throwsA(isA<UpdateFailure>()),
    );
  });

  test('respects retry-after before the GitHub rate-limit reset header', () {
    final now = DateTime.utc(2026, 8, 24);
    final retryAt = UpdateService.retryAtFromHeaders({
      'Retry-After': '120',
      'X-RateLimit-Reset':
          '${now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000}',
    }, now);
    expect(retryAt, now.add(const Duration(seconds: 120)));
  });

  test('uses GitHub rate-limit reset time when retry-after is unavailable', () {
    final now = DateTime.utc(2026, 8, 24);
    final expected = now.add(const Duration(minutes: 15));
    expect(
      UpdateService.retryAtFromHeaders({
        'x-ratelimit-reset': '${expected.millisecondsSinceEpoch ~/ 1000}',
      }, now),
      expected,
    );
  });

  test('uses a conservative delay when GitHub omits rate-limit headers', () {
    final now = DateTime.utc(2026, 8, 24);
    expect(
      UpdateService.retryAtFromHeaders(const {}, now),
      now.add(const Duration(minutes: 1)),
    );
  });

  test('parses a full GitHub release payload directly', () {
    final release = PublishedRelease.fromGitHub({
      'tag_name': 'v1.0.22+572',
      'assets': [
        asset(name: 'SHA256SUMS.txt'),
        asset(name: UpdateService.universalApkName, size: 60536924),
      ],
    });

    expect(release.tagName, 'v1.0.22+572');
    expect(release.asset.name, UpdateService.universalApkName);
    expect(release.asset.size, 60536924);
  });

  test('classifies 403 and 429 responses as rate-limit backoff windows', () {
    final now = DateTime.utc(2026, 8, 24);
    expect(
      UpdateService.retryAtForResponse(
        http.Response('', 403, headers: {'retry-after': '90'}),
        now,
      ),
      now.add(const Duration(seconds: 90)),
    );
    expect(
      UpdateService.retryAtForResponse(
        http.Response('', 429, headers: {'retry-after': '60'}),
        now,
      ),
      now.add(const Duration(seconds: 60)),
    );
    expect(
      UpdateService.retryAtForResponse(http.Response('', 500), now),
      isNull,
    );
  });

  test('does not offer an old release after a 403 response', () async {
    final now = DateTime.utc(2026, 8, 24, 12);
    final service = UpdateService(
      clock: () => now,
      latestReleaseFetcher: (_) async =>
          http.Response('', 403, headers: {'retry-after': '120'}),
    );

    await expectLater(
      service.checkUpdateAvailableForVersion('1.0.20+570'),
      throwsA(
        isA<UpdateCheckDeferred>().having(
          (value) => value.retryAt,
          'retryAt',
          now.add(const Duration(seconds: 120)),
        ),
      ),
    );
  });

  test('uses the latest GitHub response on every update check', () async {
    var calls = 0;
    final service = UpdateService(
      latestReleaseFetcher: (_) async {
        calls++;
        final version = calls == 1 ? 'v1.0.21+571' : 'v1.0.22+572';
        return http.Response(releaseBody(version), HttpStatus.ok);
      },
    );

    final first = await service.checkUpdateAvailableForVersion('1.0.20+570');
    final second = await service.checkUpdateAvailableForVersion('1.0.20+570');

    expect(calls, 2);
    expect(first.latestVersion, '1.0.21+571');
    expect(second.latestVersion, '1.0.22+572');
  });

  test('combines PackageInfo version and Android build number for OTA', () {
    expect(
      UpdateService.versionWithBuildNumber('1.0.24', '2569'),
      '1.0.24+2569',
    );
    expect(
      UpdateService.versionWithBuildNumber('1.0.24+2569', '2569'),
      '1.0.24+2569',
    );
  });

  test(
    'does not offer an identical release and Android build as an update',
    () async {
      final service = UpdateService(
        latestReleaseFetcher: (_) async =>
            http.Response(releaseBody('v1.0.24+2569'), HttpStatus.ok),
      );

      final update = await service.checkUpdateAvailableForVersion(
        '1.0.24+2569',
      );

      expect(update.isUpdateAvailable, isFalse);
    },
  );

  test(
    'verifies and promotes an APK atomically while retaining the final file',
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
    },
  );

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

  test(
    'cleans up a failed partial APK without deleting a verified APK',
    () async {
      final directory = await Directory.systemTemp.createTemp('sun-ota-test-');
      addTearDown(() => directory.delete(recursive: true));
      final partial = File('${directory.path}/update.apk.part');
      final verified = File('${directory.path}/update.apk');
      await partial.writeAsBytes([1, 2, 3]);
      await verified.writeAsBytes([4, 5, 6]);

      await UpdateService.deletePartialFile(partial);

      expect(await partial.exists(), isFalse);
      expect(await verified.exists(), isTrue);
    },
  );
}
