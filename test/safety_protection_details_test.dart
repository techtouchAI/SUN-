import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/models/dc_cable_installation_model.dart';
import 'package:solar_calculator/models/pv_array_topology_model.dart';
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

  testWidgets('routes only missing PV and cable results to their input kinds', (
    tester,
  ) async {
    ProtectionResultKind? requestedKind;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafetyAuditDetails(
            report: conciseReport,
            onInputRequested: (kind) => requestedKind = kind,
          ),
        ),
      ),
    );

    expect(find.text('اضغط لإدخال البيانات'), findsNWidgets(2));
    await tester.tap(find.text('يلزم حفظ التوالي/التوازي.'));
    await tester.pump();
    expect(requestedKind, ProtectionResultKind.pvArrayCurrent);

    requestedKind = null;
    await tester.tap(find.text('بيانات الكابل غير محفوظة.'));
    await tester.pump();
    expect(requestedKind, ProtectionResultKind.dcConductorSize);

    requestedKind = null;
    await tester.tap(find.text('12.5 A'));
    await tester.pump();
    expect(requestedKind, isNull);
  });

  testWidgets(
    'shows valid panel factor pairs, marks the saved topology, and explains saved cable inputs',
    (tester) async {
      PvArrayTopologyModel? selectedTopology;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafetyAuditDetails(
              report: conciseReport,
              requiredPanels: 18,
              panelIscAmps: 13.8,
              savedTopology: const PvArrayTopologyModel(
                modulesPerString: 9,
                parallelStrings: 2,
              ),
              savedDcCable: const DcCableInstallationModel(
                oneWayLengthMeters: 20,
                conductorMaterial: 'copper',
                insulationRating: '70C',
                installationMethod: 'tray',
                ambientTemperatureCelsius: 48,
                loadedConductors: 10,
              ),
              onTopologySelected: (topology) => selectedTopology = topology,
            ),
          ),
        ),
      );

      expect(find.byType(Card), findsNWidgets(4));
      expect(find.text('خيارات ترتيب الألواح'), findsOneWidget);
      expect(find.text('9 على التوالي × 2 بالتوازي'), findsOneWidget);
      expect(find.text('الخيار المستخدم حالياً.'), findsOneWidget);
      expect(find.text('3 على التوالي × 6 بالتوازي'), findsOneWidget);
      expect(find.text('خصائص الكابل المستخدمة'), findsOneWidget);
      expect(find.textContaining('الموصل: نحاس'), findsOneWidget);
      expect(find.textContaining('العزل: 70C'), findsOneWidget);
      expect(find.textContaining('التمديد: على حاملة كابلات'), findsOneWidget);

      await tester.tap(find.text('3 على التوالي × 6 بالتوازي'));
      await tester.pump();
      expect(selectedTopology?.modulesPerString, 3);
      expect(selectedTopology?.parallelStrings, 6);
    },
  );
}
