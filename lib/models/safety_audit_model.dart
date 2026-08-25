import 'system_mode.dart';

enum ProtectionResultKind {
  pvArrayCurrent,
  inverterDcBusCurrent,
  inverterAcOutputCurrent,
  dcConductorSize,
}

extension ProtectionResultKindLabels on ProtectionResultKind {
  String get labelAr => switch (this) {
    ProtectionResultKind.pvArrayCurrent => 'جوزات الألواح (DC Breakers)',
    ProtectionResultKind.inverterDcBusCurrent =>
      'جوزات البطاريات (DC Breakers)',
    ProtectionResultKind.inverterAcOutputCurrent =>
      'جوزات التيار المتردد (AC Breakers)',
    ProtectionResultKind.dcConductorSize => 'أحجام الأسلاك (DC Wire Sizing)',
  };
}

enum ProtectionResultStatus {
  calculated,
  missingData,
  invalidInput,
  notApplicable,
  unsupportedConfiguration,
}

extension ProtectionResultStatusLabels on ProtectionResultStatus {
  String get labelAr => switch (this) {
    ProtectionResultStatus.calculated => 'تم الحساب',
    ProtectionResultStatus.missingData => 'غير متاح — بيانات غير كافية',
    ProtectionResultStatus.invalidInput => 'غير متاح — بيانات غير صالحة',
    ProtectionResultStatus.notApplicable => 'غير منطبق',
    ProtectionResultStatus.unsupportedConfiguration => 'غير مدعوم',
  };
}

class SafetyAuditTraceEntry {
  final String stageAr;
  final String messageAr;

  const SafetyAuditTraceEntry({required this.stageAr, required this.messageAr});

  String get stageLabelAr => switch (stageAr) {
    'Source Input' => 'مدخل المصدر',
    'Calculation Rule' => 'قاعدة الحساب',
    'Final Result' => 'النتيجة',
    'Validation' => 'التحقق',
    _ => stageAr,
  };
}

/// Immutable electrical quantities normalized from existing SUN settings and
/// calculation results. No field is collected from a safety-specific screen.
class ProtectionCalculationInputs {
  final SystemMode systemMode;
  final double panelIscAmps;
  final int requiredPanels;
  final double systemVoltageVolts;
  final double gridVoltageVolts;
  final double requiredInverterCapacityWatts;
  final double requiredBatteryCapacityAh;
  final double nighttimeConsumptionWh;
  final int? pvModulesPerString;
  final int? pvParallelStrings;
  final double? dcCableOneWayLengthMeters;
  final String? dcCableMaterial;
  final String? dcCableInsulation;
  final String? dcCableInstallationMethod;
  final double? dcCableAmbientTemperatureCelsius;
  final int? dcCableLoadedConductors;

  const ProtectionCalculationInputs({
    required this.systemMode,
    required this.panelIscAmps,
    required this.requiredPanels,
    required this.systemVoltageVolts,
    required this.gridVoltageVolts,
    required this.requiredInverterCapacityWatts,
    required this.requiredBatteryCapacityAh,
    required this.nighttimeConsumptionWh,
    this.pvModulesPerString,
    this.pvParallelStrings,
    this.dcCableOneWayLengthMeters,
    this.dcCableMaterial,
    this.dcCableInsulation,
    this.dcCableInstallationMethod,
    this.dcCableAmbientTemperatureCelsius,
    this.dcCableLoadedConductors,
  });
}

class SafetyProtectionResult {
  final ProtectionResultKind kind;
  final ProtectionResultStatus status;
  final double? value;
  final String unit;
  final String unavailableReasonAr;
  final List<SafetyAuditTraceEntry> trace;

  const SafetyProtectionResult({
    required this.kind,
    required this.status,
    this.value,
    this.unit = '',
    this.unavailableReasonAr = '',
    this.trace = const [],
  });

  bool get isCalculated =>
      status == ProtectionResultStatus.calculated &&
      value != null &&
      value!.isFinite &&
      value! > 0;

  String get displayValueAr {
    if (!isCalculated) return status.labelAr;
    final decimals = value! >= 100 ? 0 : 1;
    return '${value!.toStringAsFixed(decimals)} $unit';
  }

  String get conciseStatusAr {
    if (isCalculated) return displayValueAr;
    return status == ProtectionResultStatus.notApplicable
        ? 'غير منطبق'
        : 'غير متاح';
  }

  String get conciseReasonAr => switch (kind) {
    ProtectionResultKind.pvArrayCurrent =>
      unavailableReasonAr.contains('لا يطابق')
          ? 'التوالي/التوازي لا يطابق عدد الألواح.'
          : 'يلزم حفظ التوالي/التوازي.',
    ProtectionResultKind.inverterDcBusCurrent =>
      'لا توجد بطارية مطلوبة في هذا النظام.',
    ProtectionResultKind.inverterAcOutputCurrent =>
      'بيانات العاكس أو الجهد غير كافية.',
    ProtectionResultKind.dcConductorSize =>
      status == ProtectionResultStatus.unsupportedConfiguration
          ? 'يلزم معيار لاختيار مقطع السلك.'
          : 'بيانات الكابل غير محفوظة.',
  };
}

class SafetyAuditReport {
  final List<SafetyProtectionResult> results;

  const SafetyAuditReport({this.results = const []});
  const SafetyAuditReport.empty() : results = const [];

  SafetyProtectionResult resultFor(ProtectionResultKind kind) {
    return results.firstWhere(
      (result) => result.kind == kind,
      orElse: () => SafetyProtectionResult(
        kind: kind,
        status: ProtectionResultStatus.missingData,
        unavailableReasonAr: 'لم تُنشأ نتيجة الحماية بعد.',
      ),
    );
  }

  /// Canonical presentation projection. It prevents duplicated persisted or
  /// malformed result records from creating duplicate rows in the UI, while
  /// preserving the established electrical-result order.
  List<SafetyProtectionResult> get presentationResults =>
      List.unmodifiable(ProtectionResultKind.values.map(resultFor));

  bool get hasCalculatedValue => results.any((result) => result.isCalculated);

  String get summaryAr => hasCalculatedValue
      ? 'تم اشتقاق النتائج المتاحة تلقائياً من إعدادات SUN ونتيجة الحساب الحالية. لا تمثل هذه النتائج اعتماداً معيارياً أو اختيار جهاز تجاري.'
      : 'لا توجد بيانات كافية في إعدادات SUN الحالية لإصدار نتائج حماية موثوقة.';
}
