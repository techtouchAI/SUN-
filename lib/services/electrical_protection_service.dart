import '../models/protection_ruleset_contract.dart';
import '../models/safety_audit_model.dart';
import '../models/system_mode.dart';

/// Calculates only quantities justified by existing SUN state. It deliberately
/// does not choose catalogue breaker ratings, conductor sections, NEC/IEC
/// values, or installation corrections when their source data is absent.
class ElectricalProtectionService {
  final ProtectionRuleset? ruleset;

  const ElectricalProtectionService({this.ruleset});

  SafetyAuditReport evaluate(ProtectionCalculationInputs inputs) {
    return SafetyAuditReport(
      results: List.unmodifiable([
        _pvArrayCurrent(inputs),
        _inverterDcBusCurrent(inputs),
        _inverterAcOutputCurrent(inputs),
        _dcConductorSize(inputs),
      ]),
    );
  }

  SafetyProtectionResult _pvArrayCurrent(ProtectionCalculationInputs input) {
    if (input.systemMode == SystemMode.ups) {
      return _notApplicable(
        ProtectionResultKind.pvArrayCurrent,
        'وضع UPS في SUN لا يستخدم مصفوفة ألواح شمسية.',
      );
    }
    if (!_positiveFinite(input.panelIscAmps) || input.requiredPanels <= 0) {
      return _missing(
        ProtectionResultKind.pvArrayCurrent,
        'يتطلب تيار مصفوفة PV قيمة Isc موجبة وعدد ألواح محسوباً أكبر من صفر.',
      );
    }
    return _missing(
      ProtectionResultKind.pvArrayCurrent,
      'تكوين الألواح على التوالي/التوازي غير محفوظ في SUN؛ لا يمكن اشتقاق تيار مصفوفة PV أو اختيار حماية PV من Isc وعدد الألواح فقط.',
      trace: [
        SafetyAuditTraceEntry(
          stageAr: 'Source Input',
          messageAr:
              'Isc اللوح = ${input.panelIscAmps.toStringAsFixed(2)} A؛ عدد الألواح = ${input.requiredPanels}.',
        ),
        const SafetyAuditTraceEntry(
          stageAr: 'Validation',
          messageAr:
              'تكوين strings غير متاح؛ تم حجب تيار مصفوفة PV بدلاً من افتراض التوصيل.',
        ),
      ],
    );
  }

  SafetyProtectionResult _inverterDcBusCurrent(
    ProtectionCalculationInputs input,
  ) {
    if (input.systemMode == SystemMode.directOnGrid ||
        input.nighttimeConsumptionWh <= 0 ||
        input.requiredBatteryCapacityAh <= 0) {
      return _notApplicable(
        ProtectionResultKind.inverterDcBusCurrent,
        'لا يوجد مسار بطارية/ناقل DC مطلوب في نتيجة SUN الحالية.',
      );
    }
    if (!_positiveFinite(input.systemVoltageVolts) ||
        !_positiveFinite(input.requiredInverterCapacityWatts)) {
      return _invalid(
        ProtectionResultKind.inverterDcBusCurrent,
        'جهد نظام DC أو قدرة العاكس المطلوبة غير صالحين للحساب.',
      );
    }
    final current =
        input.requiredInverterCapacityWatts / input.systemVoltageVolts;
    if (!_positiveFinite(current)) {
      return _invalid(
        ProtectionResultKind.inverterDcBusCurrent,
        'نتيجة تيار ناقل DC للعاكس غير منتهية أو غير موجبة.',
      );
    }
    return SafetyProtectionResult(
      kind: ProtectionResultKind.inverterDcBusCurrent,
      status: ProtectionResultStatus.calculated,
      value: current,
      unit: 'A',
      trace: [
        SafetyAuditTraceEntry(
          stageAr: 'Source Input',
          messageAr:
              'قدرة العاكس المطلوبة = ${input.requiredInverterCapacityWatts.toStringAsFixed(1)} W من ملف الأحمال؛ جهد نظام DC = ${input.systemVoltageVolts.toStringAsFixed(1)} V.',
        ),
        const SafetyAuditTraceEntry(
          stageAr: 'Calculation Rule',
          messageAr:
              'تيار ناقل DC للعاكس = قدرة العاكس المطلوبة ÷ جهد نظام DC.',
        ),
        SafetyAuditTraceEntry(
          stageAr: 'Final Result',
          messageAr: 'تيار ناقل DC للعاكس = ${current.toStringAsFixed(2)} A.',
        ),
        const SafetyAuditTraceEntry(
          stageAr: 'Validation',
          messageAr:
              'هذا تيار ناقل DC للعاكس، وليس تيار مصفوفة PV أو اختياراً لموديل/تصنيف قاطع.',
        ),
      ],
    );
  }

  SafetyProtectionResult _inverterAcOutputCurrent(
    ProtectionCalculationInputs input,
  ) {
    if (!_positiveFinite(input.requiredInverterCapacityWatts) ||
        !_positiveFinite(input.gridVoltageVolts)) {
      return _invalid(
        ProtectionResultKind.inverterAcOutputCurrent,
        'قدرة العاكس المطلوبة أو جهد AC غير صالحين للحساب.',
      );
    }
    final current =
        input.requiredInverterCapacityWatts / input.gridVoltageVolts;
    if (!_positiveFinite(current)) {
      return _invalid(
        ProtectionResultKind.inverterAcOutputCurrent,
        'نتيجة تيار خرج العاكس AC غير منتهية أو غير موجبة.',
      );
    }
    return SafetyProtectionResult(
      kind: ProtectionResultKind.inverterAcOutputCurrent,
      status: ProtectionResultStatus.calculated,
      value: current,
      unit: 'A',
      trace: [
        SafetyAuditTraceEntry(
          stageAr: 'Source Input',
          messageAr:
              'قدرة العاكس المطلوبة = ${input.requiredInverterCapacityWatts.toStringAsFixed(1)} W؛ جهد خرج AC = ${input.gridVoltageVolts.toStringAsFixed(1)} V.',
        ),
        const SafetyAuditTraceEntry(
          stageAr: 'Calculation Rule',
          messageAr:
              'تيار خرج العاكس AC = قدرة العاكس المطلوبة ÷ جهد AC في نموذج SUN أحادي الطور.',
        ),
        SafetyAuditTraceEntry(
          stageAr: 'Final Result',
          messageAr: 'تيار خرج العاكس AC = ${current.toStringAsFixed(2)} A.',
        ),
        const SafetyAuditTraceEntry(
          stageAr: 'Validation',
          messageAr:
              'هذه قيمة خرج عاكس AC ضمن نموذج أحادي الطور، وليست تيار شبكة عاماً أو تصنيف قاطع تجارياً.',
        ),
      ],
    );
  }

  SafetyProtectionResult _dcConductorSize(ProtectionCalculationInputs input) {
    if (input.systemMode == SystemMode.directOnGrid ||
        input.requiredBatteryCapacityAh <= 0) {
      return _notApplicable(
        ProtectionResultKind.dcConductorSize,
        'لا يوجد مسار بطارية DC مطلوب في نتيجة SUN الحالية.',
      );
    }
    return _missing(
      ProtectionResultKind.dcConductorSize,
      'طول المسار ومادة الموصل والعزل وطريقة التمديد ودرجة الحرارة وعدد الموصلات الحاملة للتيار غير محفوظة في SUN؛ لا يمكن إخراج mm² موثوق.',
      trace: const [
        SafetyAuditTraceEntry(
          stageAr: 'Source Input',
          messageAr:
              'بيانات مسار موصل DC والتركيب المطلوبة لتقييم المقطع غير محفوظة في SUN.',
        ),
        SafetyAuditTraceEntry(
          stageAr: 'Validation',
          messageAr:
              'تم حجب مقطع موصل DC؛ لا يمكن إخراج mm² موثوق من تيار ناقل DC وحده.',
        ),
      ],
    );
  }

  bool _positiveFinite(double value) => value.isFinite && value > 0;

  SafetyProtectionResult _notApplicable(
    ProtectionResultKind kind,
    String reason,
  ) => SafetyProtectionResult(
    kind: kind,
    status: ProtectionResultStatus.notApplicable,
    unavailableReasonAr: reason,
    trace: [SafetyAuditTraceEntry(stageAr: 'Validation', messageAr: reason)],
  );

  SafetyProtectionResult _missing(
    ProtectionResultKind kind,
    String reason, {
    List<SafetyAuditTraceEntry> trace = const [],
  }) => SafetyProtectionResult(
    kind: kind,
    status: ProtectionResultStatus.missingData,
    unavailableReasonAr: reason,
    trace: trace.isEmpty
        ? [SafetyAuditTraceEntry(stageAr: 'Validation', messageAr: reason)]
        : trace,
  );

  SafetyProtectionResult _invalid(ProtectionResultKind kind, String reason) =>
      SafetyProtectionResult(
        kind: kind,
        status: ProtectionResultStatus.invalidInput,
        unavailableReasonAr: reason,
        trace: [
          SafetyAuditTraceEntry(stageAr: 'Validation', messageAr: reason),
        ],
      );
}
