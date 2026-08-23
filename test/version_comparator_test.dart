import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/core/errors/app_exceptions.dart';
import 'package:solar_calculator/services/version_comparator.dart';

void main() {
  test('build increment is an available update', () {
    final current = SemanticBuildVersion.parse('1.0.18+568');
    final latest = SemanticBuildVersion.parse('1.0.18+569');
    expect(latest.isNewerThan(current), isTrue);
  });

  test('same version and build is not an update', () {
    final current = SemanticBuildVersion.parse('v1.0.18+568');
    final latest = SemanticBuildVersion.parse('1.0.18+568');
    expect(latest.isNewerThan(current), isFalse);
  });

  test('downgrade is not an update', () {
    final current = SemanticBuildVersion.parse('1.1.0+1');
    final latest = SemanticBuildVersion.parse('1.0.99+999');
    expect(latest.isNewerThan(current), isFalse);
  });

  test('invalid versions throw a typed update failure', () {
    expect(
      () => SemanticBuildVersion.parse('1.x.0+1'),
      throwsA(isA<UpdateFailure>()),
    );
  });
}
