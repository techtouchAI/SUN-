import 'safety_audit_model.dart';

/// Future standard-specific layer. The current release supplies no Ruleset.
/// This keeps the SUN-state normalization and core calculations independent
/// from licensed NEC, IEC, or local-jurisdiction data.
class ProtectionRulesetIdentity {
  final String jurisdiction;
  final String standard;
  final String edition;
  final String source;

  const ProtectionRulesetIdentity({
    required this.jurisdiction,
    required this.standard,
    required this.edition,
    required this.source,
  });
}

class ProtectionRulesetRequest {
  final ProtectionResultKind resultKind;
  final ProtectionCalculationInputs inputs;
  final double designCurrentAmps;

  const ProtectionRulesetRequest({
    required this.resultKind,
    required this.inputs,
    required this.designCurrentAmps,
  });
}

class ProtectionRulesetDecision {
  final ProtectionRulesetIdentity identity;
  final double? selectedValue;
  final String unit;
  final List<SafetyAuditTraceEntry> trace;

  const ProtectionRulesetDecision({
    required this.identity,
    required this.selectedValue,
    required this.unit,
    this.trace = const [],
  });
}

abstract interface class ProtectionRuleset {
  ProtectionRulesetIdentity get identity;

  ProtectionRulesetDecision select(ProtectionRulesetRequest request);
}
