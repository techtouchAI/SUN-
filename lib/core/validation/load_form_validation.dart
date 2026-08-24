import 'input_parser.dart';

class LoadFormValidation {
  const LoadFormValidation._();

  static String? deviceName(String? raw) {
    return raw == null || raw.trim().isEmpty ? 'أدخل اسم الجهاز.' : null;
  }

  static String? powerValue(String? raw) {
    final value = positiveValue(raw);
    if (value != null) return null;
    return raw == null || raw.trim().isEmpty
        ? 'أدخل القدرة أو الاستهلاك.'
        : 'أدخل رقماً أكبر من صفر.';
  }

  static String? dailyHours(String? raw) {
    final value = hoursValue(raw);
    if (value != null) return null;
    return raw == null || raw.trim().isEmpty
        ? 'أدخل ساعات الاستخدام اليومية.'
        : 'يجب أن تكون الساعات بين 0 و24.';
  }

  static double? positiveValue(String? raw) {
    final value = InputParser.doubleOrNull(raw);
    return value != null && value > 0 ? value : null;
  }

  static double? hoursValue(String? raw) {
    final value = InputParser.doubleOrNull(raw);
    return value != null && value >= 0 && value <= 24 ? value : null;
  }
}
