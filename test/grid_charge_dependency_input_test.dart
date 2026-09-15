import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_calculator/logic/app_strings.dart';
import 'package:solar_calculator/logic/providers.dart';
import 'package:solar_calculator/models/calculation_state.dart';
import 'package:solar_calculator/models/grid_schedule_model.dart';
import 'package:solar_calculator/models/load_model.dart';
import 'package:solar_calculator/models/system_mode.dart';
import 'package:solar_calculator/models/system_settings_model.dart';
import 'package:solar_calculator/repositories/settings_persistence_repository.dart';
import 'package:solar_calculator/screens/load_input_screen.dart';

void main() {
  const sliderKey = ValueKey('grid-charge-dependency');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> mount(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoadInputScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('waits for saved settings before accepting grid edits', (
    tester,
  ) async {
    final repository = _DelayedSettingsRepository();
    final container = ProviderContainer(
      overrides: [
        settingsPersistenceRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoadInputScreen()),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(sliderKey), findsNothing);

    repository.loaded.complete(
      const SystemSettingsModel(
        gridSchedule: GridScheduleModel(
          gridOnHours: 8,
          gridOffHours: 16,
          gridChargeDependencyPercent: 37,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<Slider>(find.byKey(sliderKey)).value, 37);
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, AppStrings.gridOnHours),
          )
          .initialValue,
      '8.0',
    );
  });

  testWidgets('grid hours can be edited in sequence without reverting input', (
    tester,
  ) async {
    final container = await mount(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.gridOnHours),
      '8',
    );
    await tester.pump();
    expect(container.read(gridScheduleProvider).gridOnHours, 8);
    expect(container.read(systemSettingsProvider).gridSchedule.gridOnHours, 8);
    expect(container.read(systemSettingsErrorProvider), isNotNull);
    // An incomplete schedule must not replace the last valid saved settings.
    final saved = await SettingsPersistenceRepository().loadSettings();
    expect(saved.gridSchedule.gridOnHours, 0);

    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.gridOffHours),
      '16',
    );
    await tester.pumpAndSettle();
    expect(container.read(gridScheduleProvider).gridOnHours, 8);
    expect(container.read(gridScheduleProvider).gridOffHours, 16);
    expect(container.read(systemSettingsErrorProvider), isNull);
  });

  testWidgets('grid percentage is discoverable before entering grid hours', (
    tester,
  ) async {
    final container = await mount(tester);
    final slider = tester.widget<Slider>(find.byKey(sliderKey));
    expect(slider.divisions, 100);
    expect(slider.onChanged, isNotNull);
    // Long campaign sentence must stay gone; only the ? help icon remains.
    expect(find.textContaining('أدخل ساعات توفر الوطنية'), findsNothing);
    expect(find.textContaining('اضغط هنا لشرح'), findsNothing);
    expect(find.byIcon(Icons.help_outline_rounded), findsWidgets);

    slider.onChanged!(37);
    await tester.pump();
    expect(
      container.read(gridScheduleProvider).gridChargeDependencyPercent,
      37,
    );
    expect(tester.widget<Slider>(find.byKey(sliderKey)).value, 37);
    expect(
      find.text('نسبة الاعتماد على الوطنية لشحن البطاريات: 37%'),
      findsOneWidget,
    );
  });

  testWidgets('100% grid dependency zeroes battery panels without grid hours', (
    tester,
  ) async {
    final container = await mount(tester);
    container
        .read(loadListProvider.notifier)
        .addLoad(
          LoadModel(
            name: 'Night load',
            unit: PowerUnit.watt,
            powerValue: 1000,
            dailyUsageHours: 8,
            daytimeHours: 0,
            nighttimeHours: 8,
          ),
        );
    await tester.pumpAndSettle();

    // Default schedule has 0 grid hours and 100% dependency.
    expect(container.read(gridScheduleProvider).gridOnHours, 0);
    expect(
      container.read(gridScheduleProvider).gridChargeDependencyPercent,
      100,
    );
    final result =
        (container.read(calculationStateProvider) as CalculationReady).result;
    expect(result.panelsForBatteries, 0);
    expect(result.gridContributionPercent, 100);
    expect(result.requiredGridChargingAmps, 0);
  });

  testWidgets('changing grid percentage recalculates battery panels only', (
    tester,
  ) async {
    final container = await mount(tester);
    container
        .read(gridScheduleProvider.notifier)
        .state = const GridScheduleModel(
      gridStartHour: 20,
      gridOnHours: 2,
      gridOffHours: 22,
      gridChargeDependencyPercent: 0,
    );
    container
        .read(loadListProvider.notifier)
        .addLoad(
          LoadModel(
            name: 'Day and night load',
            unit: PowerUnit.watt,
            powerValue: 500,
            dailyUsageHours: 12,
            daytimeHours: 4,
            nighttimeHours: 8,
          ),
        );
    await tester.pumpAndSettle();
    final before =
        (container.read(calculationStateProvider) as CalculationReady).result;
    expect(before.panelsForBatteries, greaterThan(0));

    tester.widget<Slider>(find.byKey(sliderKey)).onChanged!(100);
    await tester.pumpAndSettle();
    final after =
        (container.read(calculationStateProvider) as CalculationReady).result;
    expect(after.panelsForBatteries, 0);
    expect(after.panelsForDaytime, before.panelsForDaytime);
    expect(after.requiredPanels, after.panelsForDaytime);
    expect(after.requiredBatteryCapacityAh, before.requiredBatteryCapacityAh);
    expect(after.gridContributionPercent, 100);
    expect(after.breakdown.warningsAr.join(' '), contains('عجز شحن'));
  });

  testWidgets('UPS locks the percentage and non-battery/grid modes hide it', (
    tester,
  ) async {
    final container = await mount(tester);
    tester.widget<Slider>(find.byKey(sliderKey)).onChanged!(37);
    await tester.pump();
    final upsSwitch = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, AppStrings.upsMode),
    );
    upsSwitch.onChanged!(true);
    await tester.pump();
    expect(
      container.read(gridScheduleProvider).gridChargeDependencyPercent,
      100,
    );
    expect(tester.widget<Slider>(find.byKey(sliderKey)).value, 100);
    expect(tester.widget<Slider>(find.byKey(sliderKey)).onChanged, isNull);

    for (final mode in [SystemMode.offGrid, SystemMode.directOnGrid]) {
      container.read(systemModeProvider.notifier).state = mode;
      await tester.pump();
      expect(find.byKey(sliderKey), findsNothing);
    }
  });
}

class _DelayedSettingsRepository extends SettingsPersistenceRepository {
  final loaded = Completer<SystemSettingsModel>();

  @override
  Future<SystemSettingsModel> loadSettings() => loaded.future;
}
