import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/core/validation/input_parser.dart';

void main() {
  test('parses western and Arabic decimal separators', () {
    expect(InputParser.doubleOrNull('12.5'), 12.5);
    expect(InputParser.doubleOrNull('12,5'), 12.5);
    expect(InputParser.doubleOrNull('١٢٫٥'), 12.5);
    expect(InputParser.intOrNull('١٢'), 12);
  });

  test('rejects blank, malformed and non-finite values', () {
    expect(InputParser.doubleOrNull(''), isNull);
    expect(InputParser.doubleOrNull('abc'), isNull);
    expect(InputParser.doubleOrNull('Infinity'), isNull);
    expect(InputParser.doubleOrNull(null), isNull);
  });
}
