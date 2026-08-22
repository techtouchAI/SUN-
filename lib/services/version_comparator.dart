import '../core/errors/app_exceptions.dart';

class SemanticBuildVersion implements Comparable<SemanticBuildVersion> {
  final List<int> parts;
  final int build;
  final String display;

  const SemanticBuildVersion(this.parts, this.build, this.display);

  factory SemanticBuildVersion.parse(String raw) {
    final display = raw.trim().replaceFirst(
      RegExp(r'^v', caseSensitive: false),
      '',
    );
    final plus = display.indexOf('+');
    final dash = display.indexOf('-');
    var baseEnd = display.length;
    if (plus >= 0 && plus < baseEnd) baseEnd = plus;
    if (dash >= 0 && dash < baseEnd) baseEnd = dash;
    final base = display.substring(0, baseEnd);
    final parts = base.split('.').map((part) => int.tryParse(part)).toList();
    if (parts.isEmpty || parts.any((part) => part == null || part < 0)) {
      throw UpdateFailure('صيغة الإصدار غير صالحة: $raw');
    }

    var build = 0;
    if (plus >= 0) {
      final buildEnd = dash > plus ? dash : display.length;
      build = int.tryParse(display.substring(plus + 1, buildEnd)) ?? -1;
      if (build < 0) throw UpdateFailure('رقم البناء غير صالح: $raw');
    }
    return SemanticBuildVersion(parts.cast<int>(), build, display);
  }

  bool isNewerThan(SemanticBuildVersion other) => compareTo(other) > 0;

  @override
  int compareTo(SemanticBuildVersion other) {
    final length = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var index = 0; index < length; index++) {
      final left = index < parts.length ? parts[index] : 0;
      final right = index < other.parts.length ? other.parts[index] : 0;
      if (left != right) return left.compareTo(right);
    }
    return build.compareTo(other.build);
  }
}
