class InputParser {
  const InputParser._();

  static String normalize(String raw) {
    var normalized = raw.trim();
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const extendedArabicDigits = '۰۱۲۳۴۵۶۷۸۹';
    for (var index = 0; index < 10; index++) {
      normalized = normalized.replaceAll(arabicDigits[index], '$index');
      normalized = normalized.replaceAll(extendedArabicDigits[index], '$index');
    }
    return normalized
        .replaceAll('\u066c', '')
        .replaceAll('\u066b', '.')
        .replaceAll(',', '.');
  }

  static double? doubleOrNull(String? raw) {
    if (raw == null) return null;
    final normalized = normalize(raw);
    final parsed = double.tryParse(normalized);
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  static int? intOrNull(String? raw) {
    if (raw == null) return null;
    final normalized = normalize(raw);
    final parsed = int.tryParse(normalized);
    return parsed;
  }
}
