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
              const SizedBox(height: 16),
              for (final result in report.presentationResults)
                _ProtectionResultRow(result: result),
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
                  result.conciseStatusAr,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (!result.isCalculated) ...[
              const SizedBox(height: 5),
              Text(
                result.conciseReasonAr,
                style: TextStyle(color: color, height: 1.35),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
