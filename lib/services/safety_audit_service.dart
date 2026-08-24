import '../models/safety_audit_model.dart';
import '../models/safety_design_model.dart';
import '../models/safety_rules_engine_contract.dart';
import '../models/system_mode.dart';

/// Evaluates documented design data only. It intentionally does not contain
/// NEC, IEC, national-code tables, conductor sizes, breaker sizes, or formulas.
class SafetyAuditService {
  final SafetyRulesEngine rulesEngine;

  const SafetyAuditService({
    this.rulesEngine = const NoRulesetSafetyRulesEngine(),
  });

  static const _requirements = <SafetyCircuitType, List<String>>{
    SafetyCircuitType.pvDc: [
      'topology.dcAc',
      'protection.existingDevices',
      'equipment.pvModuleModel',
      'pv.voc',
      'pv.vmp',
      'pv.isc',
      'pv.imp',
      'pv.vocTemperatureCoefficient',
      'pv.maxSeriesFuse',
      'pv.maxSystemVoltage',
      'pv.modulesPerString',
      'pv.parallelStrings',
      'equipment.inverterModel',
      'inverter.mpptCount',
      'inverter.mpptVoltageRange',
      'inverter.maxPvVoltage',
      'inverter.maxPvCurrent',
      'pv.routeLength',
      'pv.conductorMaterial',
      'pv.insulationType',
      'pv.installationMethod',
      'pv.ambientTemperature',
      'pv.currentCarryingConductors',
    ],
    SafetyCircuitType.batteryDc: [
      'topology.dcAc',
      'protection.existingDevices',
      'equipment.batteryModel',
      'battery.voltageRange',
      'battery.maxChargeCurrent',
      'battery.maxDischargeCurrent',
      'battery.shortCircuitCapability',
      'battery.bmsLimits',
      'equipment.inverterModel',
      'inverter.batteryInputLimits',
      'battery.routeLength',
      'battery.conductorMaterial',
      'battery.insulationType',
      'battery.installationMethod',
      'battery.ambientTemperature',
      'battery.currentCarryingConductors',
    ],
    SafetyCircuitType.acOutput: [
      'topology.dcAc',
      'protection.existingDevices',
      'equipment.inverterModel',
      'inverter.acOutputPower',
      'inverter.acOutputVoltage',
      'inverter.acPhaseCount',
      'inverter.acOutputCurrent',
      'inverter.terminalTemperatureRating',
      'ac.routeLength',
      'ac.conductorMaterial',
      'ac.insulationType',
      'ac.installationMethod',
      'ac.ambientTemperature',
      'ac.currentCarryingConductors',
    ],
    SafetyCircuitType.groundingProtection: [
      'topology.dcAc',
      'protection.existingDevices',
      'grounding.topology',
      'grounding.route',
      'grounding.conductorMaterial',
      'grounding.protectionDevices',
    ],
  };

  SafetyAuditReport evaluate(SafetyDesignModel design, SystemMode systemMode) {
    final active = <SafetyCircuitType>{
      SafetyCircuitType.acOutput,
      SafetyCircuitType.groundingProtection,
      if (systemMode != SystemMode.ups) SafetyCircuitType.pvDc,
      if (systemMode != SystemMode.directOnGrid) SafetyCircuitType.batteryDc,
    };

    return SafetyAuditReport(
      circuits: List.unmodifiable([
        for (final circuit in SafetyCircuitType.values)
          _evaluateCircuit(
            design,
            circuit,
            active.contains(circuit),
            systemMode,
          ),
      ]),
    );
  }

  SafetyCircuitAudit _evaluateCircuit(
    SafetyDesignModel design,
    SafetyCircuitType circuit,
    bool isActive,
    SystemMode systemMode,
  ) {
    if (!isActive) {
      return SafetyCircuitAudit(
        circuit: circuit,
        status: SafetyAuditStatus.notApplicable,
        trace: [
          SafetyAuditTraceEntry(
            stageAr: 'نطاق الدارة',
            messageAr:
                '${circuit.labelAr} غير منطبقة على وضع ${systemMode.name}.',
          ),
        ],
      );
    }

    final required = _requirements[circuit] ?? const <String>[];
    final missing = [
      for (final id in required)
        if (!design.inputFor(id).isDocumented) id,
    ];
    final documented = required.length - missing.length;

    if (missing.isNotEmpty) {
      return SafetyCircuitAudit(
        circuit: circuit,
        status: SafetyAuditStatus.incompleteData,
        missingInputIds: List.unmodifiable(missing),
        trace: [
          SafetyAuditTraceEntry(
            stageAr: 'المدخلات',
            messageAr:
                'تم توثيق $documented من ${required.length} مدخلاً مطلوباً.',
          ),
          const SafetyAuditTraceEntry(
            stageAr: 'القواعد والحساب',
            messageAr:
                'تم حجب الحساب واختيار القاطع أو الموصل لأن بيانات حرجة أو مصدرها غير مكتمل.',
          ),
          const SafetyAuditTraceEntry(
            stageAr: 'النتيجة',
            messageAr: 'لا يمكن إصدار توصية معيارية لهذه الدارة حالياً.',
          ),
        ],
      );
    }

    final evaluation = rulesEngine.evaluate(
      SafetyRulesEvaluationRequest(
        circuit: circuit,
        design: design,
        ruleset: SafetyRulesetIdentity.fromDesign(design),
      ),
    );
    return SafetyCircuitAudit(
      circuit: circuit,
      status: SafetyAuditStatus.rulesetRequired,
      rulesEvaluation: evaluation,
      trace: evaluation.trace,
    );
  }
}
