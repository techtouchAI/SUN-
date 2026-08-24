import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/core/validation/load_form_validation.dart';

void main() {
  group('LoadFormValidation', () {
    test('accepts Arabic and decimal positive power values', () {
      expect(LoadFormValidation.powerValue('١٢٠٠٫٥'), isNull);
      expect(LoadFormValidation.positiveValue('١٢٠٠٫٥'), 1200.5);
    });

    test('rejects missing, zero, negative, and nonnumeric power values', () {
      expect(LoadFormValidation.powerValue(''), isNotNull);
      expect(LoadFormValidation.powerValue('0'), isNotNull);
      expect(LoadFormValidation.powerValue('-10'), isNotNull);
      expect(LoadFormValidation.powerValue('abc'), isNotNull);
    });

    test('accepts hours from zero through twenty-four inclusively', () {
      expect(LoadFormValidation.dailyHours('٠'), isNull);
      expect(LoadFormValidation.dailyHours('24'), isNull);
    });

    test('rejects hours outside the daily range and nonnumeric input', () {
      expect(LoadFormValidation.dailyHours('-0.1'), isNotNull);
      expect(LoadFormValidation.dailyHours('24.1'), isNotNull);
      expect(LoadFormValidation.dailyHours('invalid'), isNotNull);
    });
  });
}
