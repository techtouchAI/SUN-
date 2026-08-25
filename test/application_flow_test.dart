import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_calculator/logic/providers.dart';
import 'package:solar_calculator/models/calculation_state.dart';
import 'package:solar_calculator/models/load_model.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'create, calculate, save, restart and reload use one consistent flow',
    () async {
      final container = ProviderContainer();
      final firstState = container.read(loadListProvider);
      expect(firstState.isLoading, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(container.read(loadListProvider).isLoading, isFalse);

      container
          .read(loadListProvider.notifier)
          .addLoad(
            LoadModel(
              name: 'Integration load',
              unit: PowerUnit.watt,
              powerValue: 250,
              dailyUsageHours: 6,
              daytimeHours: 4,
              nighttimeHours: 2,
            ),
          );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final calculation = container.read(calculationStateProvider);
      expect(calculation, isA<CalculationReady>());
      expect(
        (calculation as CalculationReady).result.totalDailyConsumptionWh,
        1500,
      );

      container.dispose();
      final restarted = ProviderContainer();
      addTearDown(restarted.dispose);
      restarted.read(loadListProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final reloaded = restarted.read(loadListProvider);
      expect(reloaded.isLoading, isFalse);
      expect(reloaded.loads.single.name, 'Integration load');
    },
  );

  test('failed calculation has no zero-valued system result fallback', () {
    final container = ProviderContainer(
      overrides: [
        calculationStateProvider.overrideWith(
          (ref) => const CalculationFailed('invalid engineering input'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(systemResultProvider), isNull);
  });
}
