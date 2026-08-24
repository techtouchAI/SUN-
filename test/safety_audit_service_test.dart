import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/models/safety_audit_model.dart';
import 'package:solar_calculator/models/safety_design_model.dart';
import 'package:solar_calculator/models/safety_rules_engine_contract.dart';
import 'package:solar_calculator/models/system_mode.dart';
import 'package:solar_calculator/services/safety_audit_service.dart';

void main() {
  const service = SafetyAuditService();

  SafetyCircuitAudit auditFor(
    SafetyAuditReport report,
    SafetyCircuitType circuit,
  ) => report.circuits.singleWhere((audit) => audit.circuit == circuit);

  SafetyDesignModel completeDesign() => SafetyDesignModel(
    inputs: Map.unmodifiable({
      for (final definition in SafetyDesignModel.definitions)
        definition.id: const SafetyDesignInput(
          value: 'قيمة موثقة',
          source: 'datasheet المصنع',
        ),
    }),
  );

  test(
    'blocks every active circuit when documented design inputs are absent',
    () {
      final report = service.evaluate(
        const SafetyDesignModel(),
        SystemMode.hybrid,
      );

      expect(report.cardValueAr, 'بيانات غير مكتملة');
      expect(
        auditFor(report, SafetyCircuitType.pvDc).status,
        SafetyAuditStatus.incompleteData,
      );
      expect(
        auditFor(report, SafetyCircuitType.batteryDc).status,
        SafetyAuditStatus.incompleteData,
      );
      expect(
        auditFor(report, SafetyCircuitType.acOutput).status,
        SafetyAuditStatus.incompleteData,
      );
      expect(
        auditFor(report, SafetyCircuitType.groundingProtection).status,
        SafetyAuditStatus.incompleteData,
      );
      expect(
        auditFor(report, SafetyCircuitType.pvDc).trace.last.messageAr,
        contains('لا يمكن إصدار توصية معيارية'),
      );
    },
  );

  test('treats a value without a source as incomplete data', () {
    final design = const SafetyDesignModel().updateInput(
      'pv.voc',
      value: '49.5 V',
    );
    final report = service.evaluate(design, SystemMode.hybrid);
    final pvAudit = auditFor(report, SafetyCircuitType.pvDc);

    expect(pvAudit.status, SafetyAuditStatus.incompleteData);
    expect(pvAudit.missingInputIds, contains('pv.voc'));
  });

  test(
    'keeps a complete design blocked until a ruleset is explicitly added',
    () {
      final report = service.evaluate(completeDesign(), SystemMode.hybrid);

      expect(report.hasIncompleteData, isFalse);
      expect(report.requiresRuleset, isTrue);
      expect(report.cardValueAr, 'مرجع قواعد مطلوب');
      for (final audit in report.circuits) {
        expect(audit.status, SafetyAuditStatus.rulesetRequired);
        expect(
          audit.rulesEvaluation?.state,
          SafetyEvaluationState.blockedRulesetUnavailable,
        );
        expect(audit.rulesEvaluation?.auditableOutputs, isEmpty);
        expect(audit.rulesEvaluation?.hasRecommendation, isFalse);
        expect(audit.trace.any((entry) => entry.stageAr == 'Rule'), isTrue);
      }
    },
  );

  test(
    'does not activate a declared ruleset unless implementation is loaded',
    () {
      var design = completeDesign();
      design = design
          .updateInput(
            'context.jurisdiction',
            value: 'اختصاص يحدده المستخدم',
            source: 'اختيار المستخدم',
          )
          .updateInput(
            'rules.standard',
            value: 'معيار مُحدد',
            source: 'وثيقة الجهة',
          )
          .updateInput(
            'rules.edition',
            value: 'إصدار محدد',
            source: 'وثيقة الجهة',
          )
          .updateInput(
            'rules.rulesetId',
            value: 'ruleset.example.1',
            source: 'سجل قواعد مرخّص',
          )
          .updateInput(
            'rules.rulesetSource',
            value: 'مرجع الترخيص',
            source: 'سجل قواعد مرخّص',
          );

      final report = service.evaluate(design, SystemMode.hybrid);
      final evaluation = auditFor(
        report,
        SafetyCircuitType.pvDc,
      ).rulesEvaluation!;

      expect(evaluation.ruleset.isDeclared, isTrue);
      expect(evaluation.state, SafetyEvaluationState.blockedRulesetUnavailable);
      expect(evaluation.hasRecommendation, isFalse);
      expect(evaluation.auditableOutputs, isEmpty);
      expect(
        evaluation.validations.single.messageAr,
        contains('غير محمل أو معتمد'),
      );
    },
  );

  test(
    'marks inactive paths as not applicable instead of inventing a size',
    () {
      final report = service.evaluate(
        completeDesign(),
        SystemMode.directOnGrid,
      );

      expect(
        auditFor(report, SafetyCircuitType.batteryDc).status,
        SafetyAuditStatus.notApplicable,
      );
      expect(
        auditFor(report, SafetyCircuitType.pvDc).status,
        SafetyAuditStatus.rulesetRequired,
      );
      expect(
        auditFor(report, SafetyCircuitType.acOutput).status,
        SafetyAuditStatus.rulesetRequired,
      );
    },
  );

  test(
    'serializes source-tracked design inputs without a default jurisdiction',
    () {
      final design = const SafetyDesignModel().updateInput(
        'context.country',
        value: 'العراق',
        source: 'اختيار المستخدم',
      );
      final restored = SafetyDesignModel.fromJson(design.toJson());

      expect(restored.inputFor('context.country').value, 'العراق');
      expect(restored.inputFor('context.country').source, 'اختيار المستخدم');
      expect(restored.inputFor('rules.standard').hasValue, isFalse);
    },
  );
}
