import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/models/safety_audit_model.dart';
import 'package:solar_calculator/models/safety_design_model.dart';
import 'package:solar_calculator/widgets/safety_audit_details.dart';

void main() {
  testWidgets(
    'renders missing-data audit state without breaker or cable values',
    (tester) async {
      const report = SafetyAuditReport(
        circuits: [
          SafetyCircuitAudit(
            circuit: SafetyCircuitType.pvDc,
            status: SafetyAuditStatus.incompleteData,
            missingInputIds: ['pv.voc'],
            trace: [
              SafetyAuditTraceEntry(
                stageAr: 'النتيجة',
                messageAr: 'لا يمكن إصدار توصية معيارية لهذه الدارة حالياً.',
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafetyAuditDetails(report: report, onCompleteDesign: () {}),
          ),
        ),
      );

      expect(find.text('بيانات الحماية والتدقيق'), findsOneWidget);
      expect(find.text('بيانات غير مكتملة'), findsOneWidget);
      expect(find.textContaining('Voc للوح'), findsOneWidget);
      expect(
        find.textContaining('لا يمكن إصدار توصية معيارية'),
        findsOneWidget,
      );
      expect(find.textContaining('mm²'), findsNothing);
      expect(find.textContaining('قاطع الألواح'), findsNothing);
    },
  );
}
