import 'safety_design_model.dart';
import 'safety_rules_engine_contract.dart';

enum SafetyAuditStatus { notApplicable, incompleteData, rulesetRequired }

extension SafetyAuditStatusLabels on SafetyAuditStatus {
  String get labelAr => switch (this) {
    SafetyAuditStatus.notApplicable => 'غير منطبق على وضع النظام',
    SafetyAuditStatus.incompleteData => 'بيانات غير مكتملة',
    SafetyAuditStatus.rulesetRequired => 'مرجع قواعد مطلوب',
  };
}

class SafetyAuditTraceEntry {
  final String stageAr;
  final String messageAr;

  const SafetyAuditTraceEntry({required this.stageAr, required this.messageAr});
}

class SafetyCircuitAudit {
  final SafetyCircuitType circuit;
  final SafetyAuditStatus status;
  final List<String> missingInputIds;
  final List<SafetyAuditTraceEntry> trace;
  final SafetyRulesEvaluation? rulesEvaluation;

  const SafetyCircuitAudit({
    required this.circuit,
    required this.status,
    this.missingInputIds = const [],
    this.trace = const [],
    this.rulesEvaluation,
  });
}

class SafetyAuditReport {
  final List<SafetyCircuitAudit> circuits;

  const SafetyAuditReport({this.circuits = const []});
  const SafetyAuditReport.empty() : circuits = const [];

  bool get hasIncompleteData =>
      circuits.any((audit) => audit.status == SafetyAuditStatus.incompleteData);

  bool get requiresRuleset => circuits.any(
    (audit) => audit.status == SafetyAuditStatus.rulesetRequired,
  );

  String get cardValueAr {
    if (hasIncompleteData) return 'بيانات غير مكتملة';
    if (requiresRuleset) return 'مرجع قواعد مطلوب';
    return 'بيانات التصميم';
  }

  String get summaryAr {
    if (hasIncompleteData) {
      return 'لا يمكن إصدار توصية معيارية حالياً. أكمل بيانات المعدات والتركيب ومصدر كل قيمة.';
    }
    if (requiresRuleset) {
      return 'تم استكمال بيانات التصميم للدوائر النشطة، لكن لم يتم تحديد ملف قواعد معتمد للحساب.';
    }
    return 'بيانات تدقيق الحماية جاهزة للمراجعة.';
  }
}
