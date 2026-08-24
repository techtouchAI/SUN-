import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/models/grid_schedule_model.dart';
import 'package:solar_calculator/models/load_model.dart';
import 'package:solar_calculator/models/safety_audit_model.dart';
import 'package:solar_calculator/models/system_mode.dart';
import 'package:solar_calculator/repositories/solar_calculation_repository.dart';

void main() {
  final repository = SolarCalculationRepository();

  LoadModel load(double watts) => LoadModel(
    name: 'حمل الاختبار',
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

  test('connects existing SUN settings to correctly named current results', () {
    final result = repository.calculateSystem(
      [load(1000)],
      gridVoltage: 220,
      systemVoltage: 48,
      panelCapacity: 540,
      panelIsc: 13.8,
      systemMode: SystemMode.offGrid,
      gridSchedule: offGridSchedule(),
    );

    final dcBus = result.safetyAudit.resultFor(
      ProtectionResultKind.inverterDcBusCurrent,
    );
    final acOutput = result.safetyAudit.resultFor(
      ProtectionResultKind.inverterAcOutputCurrent,
    );
    final pv = result.safetyAudit.resultFor(
      ProtectionResultKind.pvArrayCurrent,
    );

    expect(dcBus.status, ProtectionResultStatus.calculated);
    expect(
      dcBus.value,
      closeTo(result.requiredInverterCapacityW / result.systemVoltage, 0.0001),
    );
    expect(acOutput.status, ProtectionResultStatus.calculated);
    expect(
      acOutput.value,
      closeTo(result.requiredInverterCapacityW / 220, 0.0001),
    );
    expect(pv.status, ProtectionResultStatus.missingData);
    expect(pv.value, isNull);
  });

  test(
    'does not retain stale current values when load and panel inputs change',
    () {
      final first = repository.calculateSystem(
        [load(500)],
        gridVoltage: 220,
        systemVoltage: 48,
        panelCapacity: 540,
        panelIsc: 13.8,
        systemMode: SystemMode.offGrid,
        gridSchedule: offGridSchedule(),
      );
      final second = repository.calculateSystem(
        [load(1200)],
        gridVoltage: 220,
        systemVoltage: 48,
        panelCapacity: 600,
        panelIsc: 18.5,
        systemMode: SystemMode.offGrid,
        gridSchedule: offGridSchedule(),
      );

      expect(
        second.safetyAudit
            .resultFor(ProtectionResultKind.inverterDcBusCurrent)
            .value,
        greaterThan(
          first.safetyAudit
              .resultFor(ProtectionResultKind.inverterDcBusCurrent)
              .value!,
        ),
      );
      expect(
        second.safetyAudit
            .resultFor(ProtectionResultKind.inverterAcOutputCurrent)
            .value,
        greaterThan(
          first.safetyAudit
              .resultFor(ProtectionResultKind.inverterAcOutputCurrent)
              .value!,
        ),
      );
      expect(
        second.safetyAudit
            .resultFor(ProtectionResultKind.pvArrayCurrent)
            .trace
            .first
            .messageAr,
        contains('18.50 A'),
      );
    },
  );
}
