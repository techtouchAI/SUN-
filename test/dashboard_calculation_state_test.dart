import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_calculator/logic/providers.dart';
import 'package:solar_calculator/models/calculation_state.dart';
import 'package:solar_calculator/models/load_model.dart';
import 'package:solar_calculator/models/system_result_model.dart';
import 'package:solar_calculator/repositories/solar_calculation_repository.dart';
import 'package:solar_calculator/screens/dashboard_screen.dart';
import 'package:solar_calculator/widgets/reactive_text_field.dart';

void main() {
  final dayOnlyLoad = LoadModel(
    name: 'Day-only load',
    unit: PowerUnit.watt,
    powerValue: 300,
    dailyUsageHours: 4,
    daytimeHours: 4,
    nighttimeHours: 0,
  );
  final dayOnlyResult = SolarCalculationRepository().calculateSystem([
    dayOnlyLoad,
  ], gridVoltage: 220);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer containerFor(SystemResultModel result) => ProviderContainer(
    overrides: [
      calculationStateProvider.overrideWith((ref) => CalculationReady(result)),
    ],
  );

  Future<void> addDayOnlyLoad(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    container.read(loadListProvider);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    container.read(loadListProvider.notifier).addLoad(dayOnlyLoad);
  }

  testWidgets('shows no-night-load state instead of a zero battery bank', (
    tester,
  ) async {
    final container = containerFor(dayOnlyResult);
    addTearDown(container.dispose);
    await addDayOnlyLoad(tester, container);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    expect(find.text('غير مطلوب — لا يوجد استهلاك ليلي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps panel Isc synchronized when panel wattage changes', (
    tester,
  ) async {
    final container = containerFor(dayOnlyResult);
    addTearDown(container.dispose);
    await addDayOnlyLoad(tester, container);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    final panelCapacityInput = find.descendant(
      of: find.byType(ReactiveTextField).first,
      matching: find.byType(TextFormField),
    );
    await tester.enterText(panelCapacityInput, '600');
    await tester.pump();

    expect(container.read(panelCapacityProvider), 600);
    expect(container.read(panelIscProvider), 18.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens PV topology settings from unavailable PV protection', (
    tester,
  ) async {
    final container = containerFor(dayOnlyResult);
    addTearDown(container.dispose);
    await addDayOnlyLoad(tester, container);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('الحماية الكهربائية'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('الحماية الكهربائية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('يلزم حفظ التوالي/التوازي.'));
    await tester.pumpAndSettle();

    expect(find.text('توصيل الألواح'), findsOneWidget);
    expect(find.text('عدد الألواح على التوالي لكل مسار'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
