import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/core/errors/app_exceptions.dart';
import 'package:solar_calculator/models/grid_schedule_model.dart';
import 'package:solar_calculator/models/load_model.dart';
import 'package:solar_calculator/models/system_mode.dart';
import 'package:solar_calculator/repositories/solar_calculation_repository.dart';

void main() {
  final engine = SolarCalculationRepository();

  LoadModel load({
    required String name,
    required double day,
    required double night,
    double power = 100,
  }) {
    return LoadModel(
      name: name,
      unit: PowerUnit.watt,
      powerValue: power,
      dailyUsageHours: day + night,
      daytimeHours: day,
      nighttimeHours: night,
    );
  }

  GridScheduleModel offGridSchedule() => const GridScheduleModel(
    gridOnHours: 0,
    gridOffHours: 24,
    gridChargeDependencyPercent: 0,
  );

  test(
    'uses explicit day/night hours and does not distribute 40/60 implicitly',
    () {
      final result = engine.calculateSystem(
        [
          load(name: 'Day', day: 4, night: 0),
          load(name: 'Night', day: 0, night: 3),
        ],
        gridVoltage: 220,
        systemMode: SystemMode.offGrid,
        gridSchedule: offGridSchedule(),
        panelCapacity: 500,
        peakSunHours: 4,
        energyLossPercentage: 20,
        daysOfAutonomy: 1,
      );

      expect(result.daytimeConsumptionWh, closeTo(400, 0.001));
      expect(result.nighttimeConsumptionWh, closeTo(300, 0.001));
      expect(result.totalDailyConsumptionWh, closeTo(700, 0.001));
      expect(result.requiredBatteryCapacityAh, greaterThan(0));
      expect(result.requiredPanels, greaterThan(0));
    },
  );

  test('grid contribution is applied to energy before panel rounding', () {
    final result = engine.calculateSystem(
      [load(name: 'Night', day: 0, night: 10, power: 1000)],
      gridVoltage: 220,
      systemMode: SystemMode.hybrid,
      gridSchedule: const GridScheduleModel(
        gridOnHours: 24,
        gridOffHours: 0,
        gridChargeDependencyPercent: 100,
      ),
      panelCapacity: 540,
      peakSunHours: 4.5,
      energyLossPercentage: 30,
    );

    expect(result.gridContributionPercent, 100);
    expect(result.panelsForBatteries, 0);
    expect(result.requiredPanels, result.panelsForDaytime);
  });

  test('applies a 50% grid fraction before battery panel rounding', () {
    final result = engine.calculateSystem(
      [load(name: 'Night load', day: 0, night: 8, power: 500)],
      gridVoltage: 220,
      systemMode: SystemMode.hybrid,
      gridSchedule: const GridScheduleModel(
        gridStartHour: 6,
        gridOnHours: 12,
        gridOffHours: 12,
        gridChargeDependencyPercent: 50,
      ),
      panelCapacity: 500,
      peakSunHours: 4,
      energyLossPercentage: 20,
    );

    expect(result.gridContributionPercent, closeTo(50, 0.001));
    expect(result.panelsForBatteries, greaterThan(0));
    expect(result.requiredGridChargingAmps, greaterThan(0));
    expect(result.hourlyGridPowerW[5], 0);
    expect(result.hourlyGridPowerW[6], greaterThan(0));
    expect(result.hourlyGridPowerW[17], greaterThan(0));
    expect(result.hourlyGridPowerW[18], 0);
  });

  test('direct-on-grid has no battery or battery-charging PV requirement', () {
    final result = engine.calculateSystem(
      [load(name: 'Day load', day: 6, night: 0, power: 400)],
      gridVoltage: 220,
      systemMode: SystemMode.directOnGrid,
      gridSchedule: const GridScheduleModel(
        gridStartHour: 6,
        gridOnHours: 12,
        gridOffHours: 12,
      ),
    );

    expect(result.requiredBatteryCapacityAh, 0);
    expect(result.requiredBatteryEnergyWh, 0);
    expect(result.panelsForBatteries, 0);
    expect(result.gridContributionPercent, 0);
    expect(result.requiredPanels, greaterThan(0));
  });

  test(
    'system modes do not leak PV or grid priority into UPS and off-grid',
    () {
      final ups = engine.calculateSystem(
        [load(name: 'UPS load', day: 2, night: 2)],
        gridVoltage: 220,
        systemMode: SystemMode.ups,
        gridSchedule: const GridScheduleModel(gridOnHours: 24, gridOffHours: 0),
      );
      final offGrid = engine.calculateSystem(
        [load(name: 'Off-grid load', day: 2, night: 2)],
        gridVoltage: 220,
        systemMode: SystemMode.offGrid,
        gridSchedule: offGridSchedule(),
      );

      expect(ups.requiredPanels, 0);
      expect(ups.requiredBatteryCapacityAh, greaterThan(0));
      expect(offGrid.gridContributionPercent, 0);
      expect(offGrid.suggestedChargePriority, isNot(contains('Utility First')));
    },
  );

  test(
    'losses near the upper bound remain finite and 100 percent is rejected',
    () {
      final result = engine.calculateSystem(
        [load(name: 'Load', day: 2, night: 2)],
        gridVoltage: 220,
        systemMode: SystemMode.offGrid,
        gridSchedule: offGridSchedule(),
        energyLossPercentage: 99,
      );
      expect(result.requiredPanels, greaterThan(0));
      expect(result.requiredPanels.isFinite, isTrue);

      expect(
        () => engine.calculateSystem(
          [load(name: 'Load', day: 2, night: 2)],
          gridVoltage: 220,
          systemMode: SystemMode.offGrid,
          gridSchedule: offGridSchedule(),
          energyLossPercentage: 100,
        ),
        throwsA(isA<InvalidEngineeringInput>()),
      );
    },
  );

  test('zero, negative and out-of-range engineering inputs are rejected', () {
    final inputs = <Map<String, double>>[
      {'panelCapacity': 0},
      {'peakSunHours': 0},
      {'gridVoltage': 0},
      {'systemVoltage': 0},
      {'daysOfAutonomy': -1},
    ];
    for (final input in inputs) {
      expect(
        () => engine.calculateSystem(
          [load(name: 'Load', day: 1, night: 1)],
          gridVoltage: input['gridVoltage'] ?? 220,
          systemVoltage: input['systemVoltage'] ?? 48,
          panelCapacity: input['panelCapacity'] ?? 540,
          peakSunHours: input['peakSunHours'] ?? 4.5,
          daysOfAutonomy: input['daysOfAutonomy'] ?? 1,
          gridSchedule: offGridSchedule(),
        ),
        throwsA(isA<InvalidEngineeringInput>()),
      );
    }
  });

  test('custom operating periods are used for peak and energy', () {
    final periodLoad = LoadModel(
      name: 'Timed',
      unit: PowerUnit.watt,
      powerValue: 200,
      dailyUsageHours: 4,
      daytimeHours: 0,
      nighttimeHours: 0,
      operatingPeriods: const [LoadOperatingPeriod(startHour: 8, endHour: 12)],
    );
    final result = engine.calculateSystem(
      [periodLoad],
      gridVoltage: 220,
      systemMode: SystemMode.offGrid,
      gridSchedule: offGridSchedule(),
    );
    expect(result.daytimeConsumptionWh, closeTo(800, 0.001));
    expect(result.nighttimeConsumptionWh, closeTo(0, 0.001));
    expect(result.peakLoadW, greaterThanOrEqualTo(200));

    final details = engine.calculateConsumptionDetails([periodLoad], 220);
    expect(details['total'], closeTo(800, 0.001));
    expect(details['daytime'], closeTo(800, 0.001));
    expect(details['nighttime'], closeTo(0, 0.001));
    expect(details['continuousDaytimeWatts'], closeTo(200, 0.001));
  });
}
