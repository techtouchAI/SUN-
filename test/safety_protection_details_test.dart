import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/models/safety_audit_model.dart';
import 'package:solar_calculator/widgets/safety_audit_details.dart';

void main() {
  testWidgets('shows precise current labels without manual entry', (
    tester,
  ) async {
    const report = SafetyAuditReport(
      results: [
        SafetyProtectionResult(
          kind: ProtectionResultKind.inverterDcBusCurrent,
          status: ProtectionResultStatus.calculated,
          value: 105,
          unit: 'A',
        ),
        SafetyProtectionResult(
          kind: ProtectionResultKind.pvArrayCurrent,
          status: ProtectionResultStatus.missingData,
          unavailableReasonAr: 'تكوين strings غير محفوظ.',
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SafetyAuditDetails(report: report)),
      ),
    );

    expect(find.text('الحماية الكهربائية'), findsOneWidget);
    expect(find.text('تيار ناقل DC للعاكس'), findsOneWidget);
    expect(find.text('105 A'), findsOneWidget);
    expect(find.text('تيار مصفوفة الألواح PV'), findsOneWidget);
    expect(find.text('غير متاح — بيانات غير كافية'), findsNWidgets(3));
    expect(find.textContaining('قاطع البطارية'), findsNothing);
    expect(find.textContaining('استكمال بيانات التصميم'), findsNothing);
    expect(find.textContaining('NEC Standards'), findsNothing);
  });
}
