import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/core/errors/app_exceptions.dart';
import 'package:solar_calculator/core/validation/input_validator.dart';
import 'package:solar_calculator/models/load_model.dart';

void main() {
  LoadModel validLoad({double hours = 2}) => LoadModel(
    name: 'Valid',
    unit: PowerUnit.watt,
    powerValue: 100,
    dailyUsageHours: hours,
    daytimeHours: hours,
    nighttimeHours: 0,
  );

  test('accepts 0 and 24 hours as boundary values', () {
    expect(
      () => InputValidator.validateLoads([validLoad(hours: 0)]),
      returnsNormally,
    );
    expect(
      () => InputValidator.validateLoads([validLoad(hours: 24)]),
      returnsNormally,
    );
  });

  test('rejects negative and over-24 load hours', () {
    expect(
      () => InputValidator.validateLoads([validLoad(hours: -0.1)]),
      throwsA(isA<InvalidLoadInput>()),
    );
    expect(
      () => InputValidator.validateLoads([validLoad(hours: 24.1)]),
      throwsA(isA<InvalidLoadInput>()),
    );
  });

  test('rejects invalid load power and startup multiplier', () {
    expect(
      () => InputValidator.validateLoads([validLoad().copyWith(powerValue: 0)]),
      throwsA(isA<InvalidLoadInput>()),
    );
    expect(
      () => InputValidator.validateLoads([
        validLoad().copyWith(startingCurrentMultiplier: 11),
      ]),
      throwsA(isA<InvalidLoadInput>()),
    );
  });

  test('rejects NaN and infinite engineering values', () {
    expect(
      () => InputValidator.validateSystemParameters(
        panelCapacity: double.nan,
        panelIsc: 10,
        peakSunHours: 4,
        systemVoltage: 48,
        gridVoltage: 220,
        energyLossPercentage: 30,
        daysOfAutonomy: 1,
        solarWattPrice: 0,
        batteryAmperePrice: 0,
        breakerPrice: 0,
        wiringCost: 0,
      ),
      throwsA(isA<InvalidEngineeringInput>()),
    );
  });

  test('requires a complete 24-hour grid schedule', () {
    expect(
      () => InputValidator.validateGridSchedule(
        gridStartHour: 0,
        gridOnHours: 10,
        gridOffHours: 13,
        gridChargeDependencyPercent: 50,
      ),
      throwsA(isA<InvalidEngineeringInput>()),
    );
    expect(
      () => InputValidator.validateGridSchedule(
        gridStartHour: 0,
        gridOnHours: 10,
        gridOffHours: 14,
        gridChargeDependencyPercent: 100,
      ),
      returnsNormally,
    );
    expect(
      () => InputValidator.validateGridSchedule(
        gridStartHour: 24,
        gridOnHours: 0,
        gridOffHours: 24,
        gridChargeDependencyPercent: 0,
      ),
      throwsA(isA<InvalidEngineeringInput>()),
    );
    expect(
      () => InputValidator.validateGridSchedule(
        gridStartHour: 20,
        gridOnHours: 5,
        gridOffHours: 19,
        gridChargeDependencyPercent: 0,
      ),
      throwsA(isA<InvalidEngineeringInput>()),
    );
  });
}
