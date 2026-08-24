import 'safety_audit_model.dart';
import 'safety_design_model.dart';

/// Identity of a future, explicitly selected ruleset. It is intentionally
/// separate from project location metadata so no country becomes a default.
class SafetyRulesetIdentity {
  final String country;
  final String jurisdiction;
  final String authority;
  final String standard;
  final String edition;
  final String rulesetId;
  final String source;

  const SafetyRulesetIdentity({
    this.country = '',
    this.jurisdiction = '',
    this.authority = '',
    this.standard = '',
    this.edition = '',
    this.rulesetId = '',
    this.source = '',
  });

  bool get isDeclared =>
      jurisdiction.trim().isNotEmpty &&
      standard.trim().isNotEmpty &&
      edition.trim().isNotEmpty &&
      rulesetId.trim().isNotEmpty &&
      source.trim().isNotEmpty;

  factory SafetyRulesetIdentity.fromDesign(SafetyDesignModel design) {
    return SafetyRulesetIdentity(
      country: design.inputFor('context.country').value,
      jurisdiction: design.inputFor('context.jurisdiction').value,
      authority: design.inputFor('context.authority').value,
      standard: design.inputFor('rules.standard').value,
      edition: design.inputFor('rules.edition').value,
      rulesetId: design.inputFor('rules.rulesetId').value,
      source: design.inputFor('rules.rulesetSource').value,
    );
  }
}

enum SafetyEvaluationState {
  blockedIncompleteData,
  blockedRulesetUnavailable,
  evaluated,
}

class SafetyRuleConstraint {
  final String id;
  final String labelAr;
  final String source;
  final bool satisfied;

  const SafetyRuleConstraint({
    required this.id,
    required this.labelAr,
    this.source = '',
    this.satisfied = false,
  });
}

class SafetyValidationResult {
  final String id;
  final String messageAr;
  final bool isBlocking;

  const SafetyValidationResult({
    required this.id,
    required this.messageAr,
    this.isBlocking = true,
  });
}

class SafetyRulesEvaluationRequest {
  final SafetyCircuitType circuit;
  final SafetyDesignModel design;
  final SafetyRulesetIdentity ruleset;

  const SafetyRulesEvaluationRequest({
    required this.circuit,
    required this.design,
    required this.ruleset,
  });
}

/// Future rulesets return structured calculated outputs and never raw display
/// strings. Safety Engine v1 always returns an empty output map.
class SafetyRulesEvaluation {
  final SafetyCircuitType circuit;
  final SafetyRulesetIdentity ruleset;
  final SafetyEvaluationState state;
  final Map<String, String> auditableOutputs;
  final List<SafetyRuleConstraint> constraints;
  final List<SafetyValidationResult> validations;
  final List<SafetyAuditTraceEntry> trace;

  const SafetyRulesEvaluation({
    required this.circuit,
    required this.ruleset,
    required this.state,
    this.auditableOutputs = const {},
    this.constraints = const [],
    this.validations = const [],
    this.trace = const [],
  });

  bool get hasRecommendation =>
      state == SafetyEvaluationState.evaluated && auditableOutputs.isNotEmpty;
}

abstract interface class SafetyRulesEngine {
  SafetyRulesEvaluation evaluate(SafetyRulesEvaluationRequest request);
}

/// The only engine included in v1. It is intentionally unable to calculate,
/// so a declared country or standard can never be mistaken for applied rules.
class NoRulesetSafetyRulesEngine implements SafetyRulesEngine {
  const NoRulesetSafetyRulesEngine();

  @override
  SafetyRulesEvaluation evaluate(SafetyRulesEvaluationRequest request) {
    final ruleset = request.ruleset;
    final message = ruleset.isDeclared
        ? 'تم تعريف Ruleset في بيانات المشروع، لكنه غير محمل أو معتمد داخل هذا الإصدار.'
        : 'لم يتم تحديد اختصاص ومعيار وإصدار وRuleset معتمد للحساب.';
    return SafetyRulesEvaluation(
      circuit: request.circuit,
      ruleset: ruleset,
      state: SafetyEvaluationState.blockedRulesetUnavailable,
      validations: [
        SafetyValidationResult(id: 'ruleset.unavailable', messageAr: message),
      ],
      trace: [
        const SafetyAuditTraceEntry(
          stageAr: 'Input',
          messageAr: 'مدخلات التصميم موثقة لكل المتطلبات النشطة.',
        ),
        SafetyAuditTraceEntry(stageAr: 'Rule', messageAr: message),
        const SafetyAuditTraceEntry(
          stageAr: 'Calculation',
          messageAr: 'لم تُنفذ أي معادلة أو اختيار قياسي في Safety Engine v1.',
        ),
        const SafetyAuditTraceEntry(
          stageAr: 'Validation',
          messageAr: 'الحالة محجوبة؛ لا توجد توصية أو ادعاء امتثال.',
        ),
      ],
    );
  }
}
