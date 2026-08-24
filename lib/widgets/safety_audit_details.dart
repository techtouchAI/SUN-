import 'package:flutter/material.dart';

import '../models/safety_audit_model.dart';
import '../models/safety_design_model.dart';

class SafetyAuditDetails extends StatelessWidget {
  final SafetyAuditReport report;
  final VoidCallback onCompleteDesign;

  const SafetyAuditDetails({
    super.key,
    required this.report,
    required this.onCompleteDesign,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'بيانات الحماية والتدقيق',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Safety Engine v1 — بيانات وتدقيق فقط',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              const Divider(height: 28, thickness: 1.5),
              Text(
                report.summaryAr,
                style: const TextStyle(fontSize: 16, height: 1.45),
              ),
              const SizedBox(height: 16),
              for (final audit in report.circuits)
                _CircuitAuditCard(audit: audit),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onCompleteDesign,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('استكمال بيانات التصميم ومصادرها'),
              ),
              const SizedBox(height: 8),
              const Text(
                'لا يعرض هذا الإصدار قاطعاً أو مقطع موصل أو ادعاء امتثال؛ ستضاف قواعد الحساب فقط بعد اختيار اختصاص ومعيار وإصدار وRuleset معتمد.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.center,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('حسناً'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircuitAuditCard extends StatelessWidget {
  final SafetyCircuitAudit audit;

  const _CircuitAuditCard({required this.audit});

  @override
  Widget build(BuildContext context) {
    final color = switch (audit.status) {
      SafetyAuditStatus.notApplicable => Colors.grey,
      SafetyAuditStatus.incompleteData => Colors.deepOrange,
      SafetyAuditStatus.rulesetRequired => Colors.blue,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    audit.circuit.labelAr,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    audit.status.labelAr,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (audit.missingInputIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'البيانات أو مصادرها الناقصة:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              for (final id in audit.missingInputIds)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '• ${SafetyDesignModel.definitionFor(id)?.labelAr ?? id}',
                    style: const TextStyle(color: Colors.deepOrange),
                  ),
                ),
            ],
            const SizedBox(height: 10),
            const Text(
              'Calculation / Audit Trace',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            for (final entry in audit.trace)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    children: [
                      TextSpan(
                        text: '${entry.stageAr}: ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: entry.messageAr),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
