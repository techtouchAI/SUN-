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

  test('connects existing SUN settings and results to protection outputs', () {
    final result = repository.calculateSystem(
      [load(1000)],
      gridVoltage: 220,
      systemVoltage: 48,
      panelCapacity: 540,
      panelIsc: 13.8,
      systemMode: SystemMode.offGrid,
      gridSchedule: const GridScheduleModel(
        gridOnHours: 0,
        gridOffHours: 24,
        gridChargeDependencyPercent: 0,
      ),
    );

    final battery = result.safetyAudit.resultFor(
      ProtectionResultKind.batteryDcBreaker,
    );
    final ac = result.safetyAudit.resultFor(ProtectionResultKind.acBreaker);
    final pv = result.safetyAudit.resultFor(ProtectionResultKind.pvDcBreaker);

    expect(battery.status, ProtectionResultStatus.calculated);
    expect(
      battery.value,
      closeTo(result.requiredInverterCapacityW / result.systemVoltage, 0.0001),
    );
    expect(ac.status, ProtectionResultStatus.calculated);
    expect(ac.value, closeTo(result.requiredInverterCapacityW / 220, 0.0001));
    expect(pv.status, ProtectionResultStatus.missingData);
    expect(pv.value, isNull);
  });

  test(
    'does not retain stale protection values when load and panel inputs change',
    () {
      final first = repository.calculateSystem(
        [load(500)],
        gridVoltage: 220,
        systemVoltage: 48,
        panelCapacity: 540,
        panelIsc: 13.8,
        systemMode: SystemMode.offGrid,
        gridSchedule: const GridScheduleModel(
          gridOnHours: 0,
          gridOffHours: 24,
          gridChargeDependencyPercent: 0,
        ),
      );
      final second = repository.calculateSystem(
        [load(1200)],
        gridVoltage: 220,
        systemVoltage: 48,
        panelCapacity: 600,
        panelIsc: 18.5,
        systemMode: SystemMode.offGrid,
        gridSchedule: const GridScheduleModel(
          gridOnHours: 0,
          gridOffHours: 24,
          gridChargeDependencyPercent: 0,
        ),
      );

      expect(
        second.safetyAudit
            .resultFor(ProtectionResultKind.batteryDcBreaker)
            .value,
        greaterThan(
          first.safetyAudit
              .resultFor(ProtectionResultKind.batteryDcBreaker)
              .value!,
        ),
      );
      expect(
        second.safetyAudit.resultFor(ProtectionResultKind.acBreaker).value,
        greaterThan(
          first.safetyAudit.resultFor(ProtectionResultKind.acBreaker).value!,
        ),
      );
      expect(
        second.safetyAudit
            .resultFor(ProtectionResultKind.pvDcBreaker)
            .trace
            .first
            .messageAr,
        contains('18.50 A'),
      );
    },
  );
}
