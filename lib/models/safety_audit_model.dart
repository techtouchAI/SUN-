import 'system_mode.dart';

enum ProtectionResultKind { pvDcBreaker, batteryDcBreaker, acBreaker, dcCable }

extension ProtectionResultKindLabels on ProtectionResultKind {
  String get labelAr => switch (this) {
    ProtectionResultKind.pvDcBreaker => 'قاطع الألواح DC',
    ProtectionResultKind.batteryDcBreaker => 'قاطع البطارية DC',
    ProtectionResultKind.acBreaker => 'قاطع التيار المتردد AC',
    ProtectionResultKind.dcCable => 'مقطع أسلاك DC',
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

  const ProtectionCalculationInputs({
    required this.systemMode,
    required this.panelIscAmps,
    required this.requiredPanels,
    required this.systemVoltageVolts,
    required this.gridVoltageVolts,
    required this.requiredInverterCapacityWatts,
    required this.requiredBatteryCapacityAh,
    required this.nighttimeConsumptionWh,
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

  bool get hasCalculatedValue => results.any((result) => result.isCalculated);

  String get summaryAr => hasCalculatedValue
      ? 'تم اشتقاق النتائج المتاحة تلقائياً من إعدادات SUN ونتيجة الحساب الحالية. لا تمثل هذه النتائج اعتماداً معيارياً أو اختيار جهاز تجاري.'
      : 'لا توجد بيانات كافية في إعدادات SUN الحالية لإصدار نتائج حماية موثوقة.';
}
