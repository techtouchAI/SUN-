import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/models/safety_audit_model.dart';
import 'package:solar_calculator/models/system_mode.dart';
import 'package:solar_calculator/services/electrical_protection_service.dart';

void main() {
  const service = ElectricalProtectionService();

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

  test('derives inverter DC-bus and AC-output currents from SUN inputs', () {
    final report = service.evaluate(inputs());
    final dcBus = report.resultFor(ProtectionResultKind.inverterDcBusCurrent);
    final acOutput = report.resultFor(
      ProtectionResultKind.inverterAcOutputCurrent,
    );

    expect(dcBus.status, ProtectionResultStatus.calculated);
    expect(dcBus.value, closeTo(105, 0.0001));
    expect(dcBus.unit, 'A');
    expect(dcBus.kind.labelAr, 'جوزات البطاريات (DC Breakers)');
    expect(
      dcBus.trace.map((entry) => entry.messageAr).join(' '),
      contains('ليس تيار مصفوفة PV'),
    );
    expect(acOutput.status, ProtectionResultStatus.calculated);
    expect(acOutput.value, closeTo(5040 / 220, 0.0001));
    expect(acOutput.kind.labelAr, 'جوزات التيار المتردد (AC Breakers)');
    expect(
      acOutput.trace.map((entry) => entry.messageAr).join(' '),
      contains('نموذج أحادي الطور'),
    );
    expect(
      acOutput.trace.map((entry) => entry.stageAr),
      containsAll([
        'Source Input',
        'Calculation Rule',
        'Final Result',
        'Validation',
      ]),
    );
  });

  test('never invents PV-array current or DC conductor size without data', () {
    final report = service.evaluate(inputs());
    final pv = report.resultFor(ProtectionResultKind.pvArrayCurrent);
    final cable = report.resultFor(ProtectionResultKind.dcConductorSize);

    expect(pv.status, ProtectionResultStatus.missingData);
    expect(pv.value, isNull);
    expect(pv.displayValueAr, 'غير متاح — بيانات غير كافية');
    expect(pv.kind.labelAr, 'جوزات الألواح (DC Breakers)');
    expect(pv.unavailableReasonAr, contains('التوالي/التوازي'));
    expect(cable.status, ProtectionResultStatus.missingData);
    expect(cable.value, isNull);
    expect(cable.unavailableReasonAr, contains('طول المسار'));
  });

  test('changes computed currents whenever existing source values change', () {
    final original = service.evaluate(inputs());
    final changedLoad = service.evaluate(inputs(inverterWatts: 7200));
    final changedVoltage = service.evaluate(inputs(systemVoltage: 60));

    expect(
      changedLoad.resultFor(ProtectionResultKind.inverterAcOutputCurrent).value,
      greaterThan(
        original.resultFor(ProtectionResultKind.inverterAcOutputCurrent).value!,
      ),
    );
    expect(
      changedLoad.resultFor(ProtectionResultKind.inverterDcBusCurrent).value,
      greaterThan(
        original.resultFor(ProtectionResultKind.inverterDcBusCurrent).value!,
      ),
    );
    expect(
      changedVoltage.resultFor(ProtectionResultKind.inverterDcBusCurrent).value,
      lessThan(
        original.resultFor(ProtectionResultKind.inverterDcBusCurrent).value!,
      ),
    );
  });

  test(
    'uses explicit states for invalid and not-applicable configurations',
    () {
      final invalid = service.evaluate(inputs(systemVoltage: 0));
      final directOnGrid = service.evaluate(
        inputs(mode: SystemMode.directOnGrid, batteryAh: 0, nightWh: 0),
      );

      expect(
        invalid.resultFor(ProtectionResultKind.inverterDcBusCurrent).status,
        ProtectionResultStatus.invalidInput,
      );
      expect(
        directOnGrid
            .resultFor(ProtectionResultKind.inverterDcBusCurrent)
            .status,
        ProtectionResultStatus.notApplicable,
      );
      expect(
        directOnGrid.resultFor(ProtectionResultKind.dcConductorSize).status,
        ProtectionResultStatus.notApplicable,
      );
    },
  );
}
