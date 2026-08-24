import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/models/grid_schedule_model.dart';
import 'package:solar_calculator/models/load_model.dart';
import 'package:solar_calculator/models/safety_audit_model.dart';
import 'package:solar_calculator/models/system_mode.dart';
import 'package:solar_calculator/repositories/solar_calculation_repository.dart';
import 'package:solar_calculator/services/electrical_protection_service.dart';

/// Acceptance baseline for SUN's Engineering Calculation & Data Sufficiency
/// Engine. These tests deliberately protect the scope boundary: current
/// calculation is allowed; breaker, conductor, topology, and code compliance
/// recommendations are not.
void main() {
  const service = ElectricalProtectionService();
  final repository = SolarCalculationRepository();

  ProtectionCalculationInputs inputs({
    SystemMode mode = SystemMode.hybrid,
    double panelIsc = 13.8,
    int panels = 15,
    double systemVoltage = 48,
    double gridVoltage = 220,
    double inverterWatts = 5040,
    double batteryAh = 250,
    double nightWh = 2400,
  }) => ProtectionCalculationInputs(
    systemMode: mode,
    panelIscAmps: panelIsc,
    requiredPanels: panels,
    systemVoltageVolts: systemVoltage,
    gridVoltageVolts: gridVoltage,
    requiredInverterCapacityWatts: inverterWatts,
    requiredBatteryCapacityAh: batteryAh,
    nighttimeConsumptionWh: nightWh,
  );

  LoadModel load(double watts) => LoadModel(
    name: 'حمل اختبار الانحدار',
    unit: PowerUnit.watt,
    powerValue: watts,
    dailyUsageHours: 8,
    daytimeHours: 4,
    nighttimeHours: 4,
  );

  GridScheduleModel offGridSchedule() => const GridScheduleModel(
    gridOnHours: 0,
    gridOffHours: 24,
    gridChargeDependencyPercent: 0,
  );

  group('Data sufficiency and unavailable-state regressions', () {
    test('uses explicit unavailable states and never uses zero as Unknown', () {
      final report = service.evaluate(inputs());

      expect(report.results, hasLength(4));
      for (final result in report.results) {
        expect(result.value == null || result.value! > 0, isTrue);
        expect(result.trace, isNotEmpty);
      }

      final pv = report.resultFor(ProtectionResultKind.pvArrayCurrent);
      final conductor = report.resultFor(ProtectionResultKind.dcConductorSize);
      expect(pv.status, ProtectionResultStatus.missingData);
      expect(pv.value, isNull);
      expect(pv.unavailableReasonAr, contains('التوالي/التوازي'));
      expect(
        pv.trace.map((entry) => entry.stageAr),
        containsAll(['Source Input', 'Validation']),
      );
      expect(conductor.status, ProtectionResultStatus.missingData);
      expect(conductor.value, isNull);
      expect(
        conductor.trace.map((entry) => entry.stageAr),
        containsAll(['Source Input', 'Validation']),
      );
    });

    test('Isc plus panel count never implies a PV-array topology', () {
      final report = service.evaluate(inputs(panelIsc: 18.2, panels: 24));
      final pv = report.resultFor(ProtectionResultKind.pvArrayCurrent);

      expect(pv.status, ProtectionResultStatus.missingData);
      expect(pv.value, isNull);
      expect(pv.unavailableReasonAr, contains('التوالي/التوازي'));
      expect(
        pv.trace.map((entry) => entry.messageAr).join(' '),
        contains('18.20 A'),
      );
    });

    test('invalid prerequisites do not preserve a prior DC-bus value', () {
      final before = service.evaluate(inputs());
      final after = service.evaluate(inputs(systemVoltage: 0));

      expect(
        before.resultFor(ProtectionResultKind.inverterDcBusCurrent).value,
        isNotNull,
      );
      final current = after.resultFor(
        ProtectionResultKind.inverterDcBusCurrent,
      );
      expect(current.status, ProtectionResultStatus.invalidInput);
      expect(current.value, isNull);
      expect(current.unavailableReasonAr, isNotEmpty);
    });
  });

  group('Calculation correctness and current-source regressions', () {
    test(
      'derives only the documented inverter DC-bus and AC-output currents',
      () {
        final report = service.evaluate(inputs());
        final dcBus = report.resultFor(
          ProtectionResultKind.inverterDcBusCurrent,
        );
        final acOutput = report.resultFor(
          ProtectionResultKind.inverterAcOutputCurrent,
        );

        expect(dcBus.value, closeTo(5040 / 48, 0.0001));
        expect(acOutput.value, closeTo(5040 / 220, 0.0001));
        expect(dcBus.unit, 'A');
        expect(acOutput.unit, 'A');
        expect(dcBus.kind.labelAr, 'جوزات البطاريات (DC Breakers)');
        expect(acOutput.kind.labelAr, 'جوزات التيار المتردد (AC Breakers)');
        expect(
          dcBus.trace.map((entry) => entry.messageAr).join(' '),
          contains('ليس تيار مصفوفة PV'),
        );
        expect(
          acOutput.trace.map((entry) => entry.messageAr).join(' '),
          contains('نموذج أحادي الطور'),
        );
      },
    );

    test(
      'calculateSystem rebuilds from current state after a prerequisite is removed',
      () {
        final previous = repository.calculateSystem(
          [load(1000)],
          gridVoltage: 220,
          systemVoltage: 48,
          panelCapacity: 540,
          panelIsc: 13.8,
          systemMode: SystemMode.offGrid,
          gridSchedule: offGridSchedule(),
        );
        final current = repository.calculateSystem(
          [load(1000)],
          gridVoltage: 220,
          systemVoltage: 48,
          panelCapacity: 540,
          panelIsc: 13.8,
          systemMode: SystemMode.directOnGrid,
          gridSchedule: offGridSchedule(),
        );

        expect(
          previous.safetyAudit
              .resultFor(ProtectionResultKind.inverterDcBusCurrent)
              .isCalculated,
          isTrue,
        );
        final dcBusAfterRemoval = current.safetyAudit.resultFor(
          ProtectionResultKind.inverterDcBusCurrent,
        );
        expect(dcBusAfterRemoval.status, ProtectionResultStatus.notApplicable);
        expect(dcBusAfterRemoval.value, isNull);
      },
    );
  });

  group('Safety boundary and traceability regressions', () {
    test(
      'does not expose a breaker, cable-size, or compliance recommendation',
      () {
        final report = service.evaluate(inputs());
        final displayedLabels = report.results
            .map((result) => result.kind.labelAr)
            .join(' ');
        final combinedTrace = report.results
            .expand((result) => result.trace)
            .map((entry) => entry.messageAr)
            .join(' ');

        expect(displayedLabels, isNot(contains('قاطع')));
        expect(displayedLabels, isNot(contains('mm²')));
        expect(report.summaryAr, isNot(contains('NEC')));
        expect(report.summaryAr, isNot(contains('IEC')));
        expect(report.summaryAr, isNot(contains('مطابق')));
        expect(combinedTrace, contains('ليس تيار مصفوفة PV'));
        expect(combinedTrace, contains('ليست تيار شبكة عاماً'));
        expect(combinedTrace, contains('لا يمكن إخراج mm² موثوق'));
      },
    );

    test(
      'numeric results include input, rule, result, and validation trace',
      () {
        final report = service.evaluate(inputs());

        for (final kind in [
          ProtectionResultKind.inverterDcBusCurrent,
          ProtectionResultKind.inverterAcOutputCurrent,
        ]) {
          final result = report.resultFor(kind);
          expect(result.isCalculated, isTrue);
          expect(
            result.trace.map((entry) => entry.stageAr),
            containsAll([
              'Source Input',
              'Calculation Rule',
              'Final Result',
              'Validation',
            ]),
          );
        }
      },
    );
  });
}
