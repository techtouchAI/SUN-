import 'package:flutter/material.dart';

import '../models/safety_audit_model.dart';

class SafetyAuditDetails extends StatelessWidget {
  final SafetyAuditReport report;

  const SafetyAuditDetails({super.key, required this.report});

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
                'الحماية الكهربائية',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                report.summaryAr,
                style: const TextStyle(fontSize: 15, height: 1.45),
              ),
              const Divider(height: 28, thickness: 1.5),
              for (final kind in ProtectionResultKind.values)
                _ProtectionResultRow(result: report.resultFor(kind)),
              const SizedBox(height: 12),
              const Text(
                'القيم المحسوبة هنا هي تيار ناقل DC للعاكس أو تيار خرج العاكس AC فقط؛ لا تمثل تيار مصفوفة PV أو اختيار جهاز حماية أو مقطع موصل للتنفيذ.',
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

class _ProtectionResultRow extends StatelessWidget {
  final SafetyProtectionResult result;

  const _ProtectionResultRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = switch (result.status) {
      ProtectionResultStatus.calculated => Colors.green.shade700,
      ProtectionResultStatus.notApplicable => Colors.grey.shade700,
      ProtectionResultStatus.missingData ||
      ProtectionResultStatus.invalidInput ||
      ProtectionResultStatus.unsupportedConfiguration => Colors.deepOrange,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    result.kind.labelAr,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  result.displayValueAr,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (!result.isCalculated &&
                result.unavailableReasonAr.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                result.unavailableReasonAr,
                style: TextStyle(color: color, height: 1.35),
              ),
            ],
            if (result.trace.isNotEmpty) ...[
              const SizedBox(height: 4),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'تفاصيل فنية',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                children: [
                  for (final entry in result.trace)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                            children: [
                              TextSpan(
                                text: '${entry.stageAr}: ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(text: entry.messageAr),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
