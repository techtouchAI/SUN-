import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/models/safety_audit_model.dart';
import 'package:solar_calculator/widgets/safety_audit_details.dart';

void main() {
  const conciseReport = SafetyAuditReport(
    results: [
      SafetyProtectionResult(
        kind: ProtectionResultKind.inverterDcBusCurrent,
        status: ProtectionResultStatus.notApplicable,
        unavailableReasonAr: 'تفاصيل قديمة لا يجب عرضها.',
      ),
      SafetyProtectionResult(
        kind: ProtectionResultKind.inverterDcBusCurrent,
        status: ProtectionResultStatus.calculated,
        value: 999,
        unit: 'A',
      ),
      SafetyProtectionResult(
        kind: ProtectionResultKind.pvArrayCurrent,
        status: ProtectionResultStatus.missingData,
        unavailableReasonAr: 'تفاصيل قديمة لا يجب عرضها.',
        trace: [
          SafetyAuditTraceEntry(
            stageAr: 'Source Input',
            messageAr: 'Isc اللوح = 13.80 A؛ عدد الألواح = 15.',
          ),
        ],
      ),
      SafetyProtectionResult(
        kind: ProtectionResultKind.inverterAcOutputCurrent,
        status: ProtectionResultStatus.calculated,
        value: 12.5,
        unit: 'A',
      ),
      SafetyProtectionResult(
        kind: ProtectionResultKind.dcConductorSize,
        status: ProtectionResultStatus.notApplicable,
        unavailableReasonAr: 'تفاصيل قديمة لا يجب عرضها.',
      ),
    ],
  );

  test(
    'canonical presentation keeps four unique results in requested order',
    () {
      expect(conciseReport.presentationResults.map((result) => result.kind), [
        ProtectionResultKind.pvArrayCurrent,
        ProtectionResultKind.inverterDcBusCurrent,
        ProtectionResultKind.inverterAcOutputCurrent,
        ProtectionResultKind.dcConductorSize,
      ]);
      expect(
        conciseReport.presentationResults
            .where(
              (result) =>
                  result.kind == ProtectionResultKind.inverterDcBusCurrent,
            )
            .length,
        1,
      );
    },
  );

  testWidgets('shows only four concise requested protection categories', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SafetyAuditDetails(report: conciseReport)),
      ),
    );

    const labels = [
      'جوزات الألواح (DC Breakers)',
      'جوزات البطاريات (DC Breakers)',
      'جوزات التيار المتردد (AC Breakers)',
      'أحجام الأسلاك (DC Wire Sizing)',
    ];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(Card), findsNWidgets(4));
    expect(find.text('999 A'), findsNothing);
    expect(find.text('12.5 A'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('12.5 A')).textDirection,
      TextDirection.ltr,
    );
    expect(find.text('غير متاح'), findsOneWidget);
    expect(find.text('غير منطبق'), findsNWidgets(2));
    expect(find.text('يلزم حفظ التوالي/التوازي.'), findsOneWidget);
    expect(find.text('لا توجد بطارية مطلوبة في هذا النظام.'), findsOneWidget);
    expect(find.text('بيانات الكابل غير محفوظة.'), findsOneWidget);
    expect(find.text('تفاصيل فنية'), findsNothing);
    expect(find.text('مدخل المصدر'), findsNothing);
    expect(find.textContaining('تفاصيل قديمة'), findsNothing);
    expect(find.textContaining('تم اشتقاق النتائج'), findsNothing);
    expect(find.textContaining('NEC Standards'), findsNothing);
  });
}
