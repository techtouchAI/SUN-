import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_calculator/core/errors/app_exceptions.dart';
import 'package:solar_calculator/models/load_model.dart';
import 'package:solar_calculator/repositories/load_persistence_repository.dart';

void main() {
  LoadModel load(String name) => LoadModel(
    name: name,
    unit: PowerUnit.watt,
    powerValue: 100,
    dailyUsageHours: 2,
    daytimeHours: 2,
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saves and loads versioned data', () async {
    final repository = LoadPersistenceRepository();
    await repository.saveLoads([load('A')]);
    final loaded = await repository.loadLoads();
    expect(loaded, hasLength(1));
    expect(loaded.single.name, 'A');
  });

  test(
    'serializes concurrent saves without overwriting the newest snapshot',
    () async {
      final repository = LoadPersistenceRepository();
      await Future.wait([
        repository.saveLoads([load('first')]),
        repository.saveLoads([load('second')]),
      ]);
      final loaded = await repository.loadLoads();
      expect(loaded.single.name, 'second');
    },
  );

  test('recovers from corrupted primary using backup', () async {
    final repository = LoadPersistenceRepository();
    await repository.saveLoads([load('valid')]);
    await repository.saveLoads([load('new')]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_loads_v1', '{corrupted');
    final loaded = await repository.loadLoads();
    expect(loaded.single.name, 'valid');
  });

  test('reports corruption when no backup is available', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_loads_v1', '{corrupted');
    expect(
      () => LoadPersistenceRepository().loadLoads(),
      throwsA(isA<PersistenceFailure>()),
    );
  });
}
