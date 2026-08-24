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

  test('derives DC and AC design currents from SUN result inputs', () {
    final report = service.evaluate(inputs());
    final battery = report.resultFor(ProtectionResultKind.batteryDcBreaker);
    final ac = report.resultFor(ProtectionResultKind.acBreaker);

    expect(battery.status, ProtectionResultStatus.calculated);
    expect(battery.value, closeTo(105, 0.0001));
    expect(battery.unit, 'A');
    expect(ac.status, ProtectionResultStatus.calculated);
    expect(ac.value, closeTo(5040 / 220, 0.0001));
    expect(ac.trace.map((entry) => entry.stageAr), contains('Source Input'));
    expect(
      ac.trace.map((entry) => entry.stageAr),
      contains('Calculation Rule'),
    );
    expect(ac.trace.map((entry) => entry.stageAr), contains('Final Result'));
    expect(ac.trace.map((entry) => entry.stageAr), contains('Validation'));
  });

  test(
    'never invents PV breaker or DC cable results without topology data',
    () {
      final report = service.evaluate(inputs());
      final pv = report.resultFor(ProtectionResultKind.pvDcBreaker);
      final cable = report.resultFor(ProtectionResultKind.dcCable);

      expect(pv.status, ProtectionResultStatus.missingData);
      expect(pv.value, isNull);
      expect(pv.displayValueAr, 'غير متاح — بيانات غير كافية');
      expect(pv.unavailableReasonAr, contains('التوالي/التوازي'));
      expect(cable.status, ProtectionResultStatus.missingData);
      expect(cable.value, isNull);
      expect(cable.unavailableReasonAr, contains('طول المسار'));
    },
  );

  test('changes computed currents whenever existing source values change', () {
    final original = service.evaluate(inputs());
    final changedLoad = service.evaluate(inputs(inverterWatts: 7200));
    final changedVoltage = service.evaluate(inputs(systemVoltage: 60));

    expect(
      changedLoad.resultFor(ProtectionResultKind.acBreaker).value,
      greaterThan(original.resultFor(ProtectionResultKind.acBreaker).value!),
    );
    expect(
      changedLoad.resultFor(ProtectionResultKind.batteryDcBreaker).value,
      greaterThan(
        original.resultFor(ProtectionResultKind.batteryDcBreaker).value!,
      ),
    );
    expect(
      changedVoltage.resultFor(ProtectionResultKind.batteryDcBreaker).value,
      lessThan(
        original.resultFor(ProtectionResultKind.batteryDcBreaker).value!,
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
        invalid.resultFor(ProtectionResultKind.batteryDcBreaker).status,
        ProtectionResultStatus.invalidInput,
      );
      expect(
        directOnGrid.resultFor(ProtectionResultKind.batteryDcBreaker).status,
        ProtectionResultStatus.notApplicable,
      );
      expect(
        directOnGrid.resultFor(ProtectionResultKind.dcCable).status,
        ProtectionResultStatus.notApplicable,
      );
    },
  );
}
