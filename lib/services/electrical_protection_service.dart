import '../models/safety_audit_model.dart';
import '../models/protection_ruleset_contract.dart';
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
        _pvDcBreaker(inputs),
        _batteryDcBreaker(inputs),
        _acBreaker(inputs),
        _dcCable(inputs),
      ]),
    );
  }

  SafetyProtectionResult _pvDcBreaker(ProtectionCalculationInputs input) {
    if (input.systemMode == SystemMode.ups) {
      return _notApplicable(
        ProtectionResultKind.pvDcBreaker,
        'وضع UPS في SUN لا يستخدم مصفوفة ألواح شمسية.',
      );
    }
    if (!_positiveFinite(input.panelIscAmps) || input.requiredPanels <= 0) {
      return _missing(
        ProtectionResultKind.pvDcBreaker,
        'تتطلب الدارة Isc موجباً وعدد ألواح محسوباً أكبر من صفر.',
      );
    }
    return _missing(
      ProtectionResultKind.pvDcBreaker,
      'تكوين الألواح على التوالي/التوازي غير محفوظ في SUN؛ لا يمكن اشتقاق تيار الدارة أو اختيار قاطع DC من Isc وعدد الألواح فقط.',
      trace: [
        SafetyAuditTraceEntry(
          stageAr: 'Source Input',
          messageAr:
              'Isc اللوح = ${input.panelIscAmps.toStringAsFixed(2)} A؛ عدد الألواح = ${input.requiredPanels}.',
        ),
        const SafetyAuditTraceEntry(
          stageAr: 'Validation',
          messageAr:
              'تكوين strings غير متاح؛ تم حجب نتيجة القاطع بدلاً من افتراض التوصيل.',
        ),
      ],
    );
  }

  SafetyProtectionResult _batteryDcBreaker(ProtectionCalculationInputs input) {
    if (input.systemMode == SystemMode.directOnGrid ||
        input.nighttimeConsumptionWh <= 0 ||
        input.requiredBatteryCapacityAh <= 0) {
      return _notApplicable(
        ProtectionResultKind.batteryDcBreaker,
        'لا توجد بطارية مطلوبة في نتيجة SUN الحالية.',
      );
    }
    if (!_positiveFinite(input.systemVoltageVolts) ||
        !_positiveFinite(input.requiredInverterCapacityWatts)) {
      return _invalid(
        ProtectionResultKind.batteryDcBreaker,
        'جهد النظام أو قدرة العاكس المطلوبة غير صالحين للحساب.',
      );
    }
    final current =
        input.requiredInverterCapacityWatts / input.systemVoltageVolts;
    if (!_positiveFinite(current)) {
      return _invalid(
        ProtectionResultKind.batteryDcBreaker,
        'نتيجة تيار البطارية غير منتهية أو غير موجبة.',
      );
    }
    return SafetyProtectionResult(
      kind: ProtectionResultKind.batteryDcBreaker,
      status: ProtectionResultStatus.calculated,
      value: current,
      unit: 'A',
      trace: [
        SafetyAuditTraceEntry(
          stageAr: 'Source Input',
          messageAr:
              'قدرة العاكس المطلوبة = ${input.requiredInverterCapacityWatts.toStringAsFixed(1)} W من ملف الأحمال؛ جهد النظام = ${input.systemVoltageVolts.toStringAsFixed(1)} V.',
        ),
        const SafetyAuditTraceEntry(
          stageAr: 'Calculation Rule',
          messageAr: 'تيار DC التصميمي = قدرة العاكس المطلوبة ÷ جهد النظام.',
        ),
        SafetyAuditTraceEntry(
          stageAr: 'Final Result',
          messageAr: 'تيار DC التصميمي = ${current.toStringAsFixed(2)} A.',
        ),
        const SafetyAuditTraceEntry(
          stageAr: 'Validation',
          messageAr:
              'هذه قيمة تيار محسوبة؛ اختيار موديل/تصنيف القاطع يتطلب مواصفات الجهاز وقواعد الاختصاص.',
        ),
      ],
    );
  }

  SafetyProtectionResult _acBreaker(ProtectionCalculationInputs input) {
    if (!_positiveFinite(input.requiredInverterCapacityWatts) ||
        !_positiveFinite(input.gridVoltageVolts)) {
      return _invalid(
        ProtectionResultKind.acBreaker,
        'قدرة العاكس المطلوبة أو جهد AC غير صالحين للحساب.',
      );
    }
    final current =
        input.requiredInverterCapacityWatts / input.gridVoltageVolts;
    if (!_positiveFinite(current)) {
      return _invalid(
        ProtectionResultKind.acBreaker,
        'نتيجة تيار AC غير منتهية أو غير موجبة.',
      );
    }
    return SafetyProtectionResult(
      kind: ProtectionResultKind.acBreaker,
      status: ProtectionResultStatus.calculated,
      value: current,
      unit: 'A',
      trace: [
        SafetyAuditTraceEntry(
          stageAr: 'Source Input',
          messageAr:
              'قدرة العاكس المطلوبة = ${input.requiredInverterCapacityWatts.toStringAsFixed(1)} W؛ جهد AC = ${input.gridVoltageVolts.toStringAsFixed(1)} V.',
        ),
        const SafetyAuditTraceEntry(
          stageAr: 'Calculation Rule',
          messageAr:
              'تيار AC التصميمي = قدرة العاكس المطلوبة ÷ جهد AC في نموذج SUN أحادي الطور.',
        ),
        SafetyAuditTraceEntry(
          stageAr: 'Final Result',
          messageAr: 'تيار AC التصميمي = ${current.toStringAsFixed(2)} A.',
        ),
        const SafetyAuditTraceEntry(
          stageAr: 'Validation',
          messageAr:
              'لم يتم اختيار تصنيف قاطع تجاري لأن الطور والمعدة والقواعد المحلية غير نمذجة في SUN.',
        ),
      ],
    );
  }

  SafetyProtectionResult _dcCable(ProtectionCalculationInputs input) {
    if (input.systemMode == SystemMode.directOnGrid ||
        input.requiredBatteryCapacityAh <= 0) {
      return _notApplicable(
        ProtectionResultKind.dcCable,
        'لا يوجد مسار بطارية DC مطلوب في نتيجة SUN الحالية.',
      );
    }
    return _missing(
      ProtectionResultKind.dcCable,
      'طول المسار ومادة الموصل والعزل وطريقة التمديد ودرجة الحرارة وعدد الموصلات الحاملة للتيار غير محفوظة في SUN؛ لا يمكن إخراج mm² موثوق.',
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
