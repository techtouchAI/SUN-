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

  testWidgets('grid percentage is discoverable before entering grid hours', (
    tester,
  ) async {
    final container = await mount(tester);
    final slider = tester.widget<Slider>(find.byKey(sliderKey));
    expect(slider.divisions, 100);
    expect(slider.onChanged, isNotNull);
    expect(find.textContaining('أدخل ساعات توفر الوطنية'), findsOneWidget);

    slider.onChanged!(37);
    await tester.pump();
    expect(container.read(gridScheduleProvider).gridChargeDependencyPercent, 37);
    expect(tester.widget<Slider>(find.byKey(sliderKey)).value, 37);
    expect(
      find.text('نسبة الاعتماد على الوطنية لشحن البطاريات: 37%'),
      findsOneWidget,
    );
  });

  testWidgets('changing grid percentage recalculates battery panels only', (
    tester,
  ) async {
    final container = await mount(tester);
    container.read(gridScheduleProvider.notifier).state =
        const GridScheduleModel(
          gridStartHour: 20,
          gridOnHours: 2,
          gridOffHours: 22,
          gridChargeDependencyPercent: 0,
        );
    container.read(loadListProvider.notifier).addLoad(
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
    expect(container.read(gridScheduleProvider).gridChargeDependencyPercent, 100);
    expect(tester.widget<Slider>(find.byKey(sliderKey)).value, 100);
    expect(tester.widget<Slider>(find.byKey(sliderKey)).onChanged, isNull);

    for (final mode in [SystemMode.offGrid, SystemMode.directOnGrid]) {
      container.read(systemModeProvider.notifier).state = mode;
      await tester.pump();
      expect(find.byKey(sliderKey), findsNothing);
    }
  });
}
