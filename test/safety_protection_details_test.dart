import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/models/grid_schedule_model.dart';
import 'package:solar_calculator/models/load_model.dart';
import 'package:solar_calculator/models/safety_audit_model.dart';
import 'package:solar_calculator/models/system_mode.dart';
import 'package:solar_calculator/repositories/solar_calculation_repository.dart';
import 'package:solar_calculator/widgets/safety_audit_details.dart';

void main() {
  const duplicateSafeReport = SafetyAuditReport(
    results: [
      SafetyProtectionResult(
        kind: ProtectionResultKind.inverterDcBusCurrent,
        status: ProtectionResultStatus.notApplicable,
        unavailableReasonAr:
            'لا يوجد مسار بطارية/ناقل DC مطلوب في نتيجة SUN الحالية.',
        trace: [
          SafetyAuditTraceEntry(
            stageAr: 'Validation',
            messageAr:
                'لا يوجد مسار بطارية/ناقل DC مطلوب في نتيجة SUN الحالية.',
          ),
        ],
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
        unavailableReasonAr: 'تكوين strings غير محفوظ.',
        trace: [
          SafetyAuditTraceEntry(
            stageAr: 'Source Input',
            messageAr: 'Isc اللوح = 13.80 A؛ عدد الألواح = 15.',
          ),
          SafetyAuditTraceEntry(
            stageAr: 'Validation',
            messageAr: 'تم حجب تيار مصفوفة PV بدلاً من افتراض التوصيل.',
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
        unavailableReasonAr:
            'لا يوجد مسار بطارية DC مطلوب في نتيجة SUN الحالية.',
      ),
    ],
  );

  test(
    'canonical presentation keeps four unique results in electrical order',
    () {
      expect(
        duplicateSafeReport.presentationResults.map((result) => result.kind),
        [
          ProtectionResultKind.pvArrayCurrent,
          ProtectionResultKind.inverterDcBusCurrent,
          ProtectionResultKind.inverterAcOutputCurrent,
          ProtectionResultKind.dcConductorSize,
        ],
      );
      expect(
        duplicateSafeReport.presentationResults
            .where(
              (result) =>
                  result.kind == ProtectionResultKind.inverterDcBusCurrent,
            )
            .length,
        1,
      );
      expect(
        duplicateSafeReport
            .resultFor(ProtectionResultKind.inverterDcBusCurrent)
            .value,
        isNull,
      );
    },
  );

  testWidgets('shows four unique rows and readable RTL audit details', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SafetyAuditDetails(report: duplicateSafeReport)),
      ),
    );

    expect(find.text('الحماية الكهربائية'), findsOneWidget);
    expect(find.text('تيار مصفوفة الألواح PV'), findsOneWidget);
    expect(find.text('تيار ناقل DC للعاكس'), findsOneWidget);
    expect(find.text('تيار خرج العاكس AC'), findsOneWidget);
    expect(find.text('تقييم مقطع موصل DC'), findsOneWidget);
    expect(find.text('999 A'), findsNothing);
    expect(find.text('12.5 A'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('12.5 A')).textDirection,
      TextDirection.ltr,
    );
    expect(find.textContaining('قاطع البطارية'), findsNothing);
    expect(find.textContaining('NEC Standards'), findsNothing);
    expect(find.text('تفاصيل فنية'), findsOneWidget);

    await tester.tap(find.text('تفاصيل فنية'));
    await tester.pumpAndSettle();

    expect(find.text('مدخل المصدر'), findsOneWidget);
    expect(find.text('التحقق'), findsOneWidget);
    expect(find.textContaining('Isc اللوح = 13.80 A'), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(
            find.byKey(const ValueKey('protection-trace-Source Input')),
          )
          .textDirection,
      TextDirection.rtl,
    );
  });

  testWidgets('renders a calculated direct-grid report as four unique rows', (
    tester,
  ) async {
    final result = SolarCalculationRepository().calculateSystem(
      [
        LoadModel(
          name: 'حمل شبكة',
          unit: PowerUnit.watt,
          powerValue: 2000,
          dailyUsageHours: 8,
          daytimeHours: 8,
          nighttimeHours: 0,
        ),
      ],
      gridVoltage: 220,
      systemVoltage: 48,
      panelCapacity: 540,
      panelIsc: 13.8,
      systemMode: SystemMode.directOnGrid,
      gridSchedule: const GridScheduleModel(
        gridOnHours: 24,
        gridOffHours: 0,
        gridChargeDependencyPercent: 0,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SafetyAuditDetails(report: result.safetyAudit)),
      ),
    );

    final labels = [
      'تيار مصفوفة الألواح PV',
      'تيار ناقل DC للعاكس',
      'تيار خرج العاكس AC',
      'تقييم مقطع موصل DC',
    ];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(Card), findsNWidgets(4));

    final yPositions = labels
        .map((label) => tester.getTopLeft(find.text(label)).dy)
        .toList();
    expect(yPositions, orderedEquals([...yPositions]..sort()));
    expect(
      result.safetyAudit.presentationResults.map((row) => row.kind).toSet(),
      hasLength(4),
    );
  });
}
