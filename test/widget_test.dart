import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_calculator/main.dart';
import 'package:solar_calculator/models/grid_schedule_model.dart';
import 'package:solar_calculator/models/load_model.dart';
import 'package:solar_calculator/models/system_settings_model.dart';
import 'package:solar_calculator/repositories/load_persistence_repository.dart';
import 'package:solar_calculator/repositories/settings_persistence_repository.dart';
import 'package:solar_calculator/screens/dashboard_screen.dart';
import 'package:solar_calculator/screens/load_input_screen.dart';
import 'package:solar_calculator/logic/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLoadRepository extends LoadPersistenceRepository {
  final LoadModel load = LoadModel(
    name: 'مروحة',
    unit: PowerUnit.watt,
    powerValue: 100,
    dailyUsageHours: 4,
    daytimeHours: 4,
  );

  @override
  Future<List<LoadModel>> loadLoads() async => [load];
}

class _FakeEmptyLoadRepository extends LoadPersistenceRepository {
  @override
  Future<List<LoadModel>> loadLoads() async => const [];

  @override
  Future<void> saveLoads(List<LoadModel> loads) async {}
}

class _FakeSettingsRepository extends SettingsPersistenceRepository {
  @override
  Future<SystemSettingsModel> loadSettings() async => const SystemSettingsModel(
    gridSchedule: GridScheduleModel(
      gridOnHours: 0,
      gridOffHours: 24,
      gridChargeDependencyPercent: 0,
    ),
  );
}

void main() {
  testWidgets('app starts with load input screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();
    expect(find.text('إضافة الأحمال الكهربائية'), findsOneWidget);
  });

  testWidgets('load input supports add, edit and delete', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loadPersistenceRepositoryProvider.overrideWithValue(
            _FakeEmptyLoadRepository(),
          ),
          settingsPersistenceRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
        ],
        child: const MaterialApp(home: LoadInputScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(6));
    await tester.enterText(fields.at(0), 'حمل اختبار');
    await tester.enterText(fields.at(1), '100');
    await tester.enterText(fields.at(2), '1');
    await tester.enterText(fields.at(3), '2');
    await tester.enterText(fields.at(4), '1');
    await tester.enterText(fields.at(5), '1');
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('add-detailed-load')),
      find.byKey(const ValueKey('detailed-load-list')),
      const Offset(0, -200),
      maxIteration: 10,
    );
    await tester.tap(find.byKey(const ValueKey('add-detailed-load')));
    await tester.pumpAndSettle();
    expect(find.text('حمل اختبار'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();
    final editFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(editFields.first, 'حمل معدل');
    await tester.tap(find.text('حفظ التعديلات').last);
    await tester.pumpAndSettle();
    expect(find.text('حمل معدل'), findsOneWidget);
    expect(find.text('حمل اختبار'), findsNothing);

    await tester.tap(find.byIcon(Icons.delete).first);
    await tester.pumpAndSettle();
    expect(find.text('حمل معدل'), findsNothing);
    expect(find.text('لم تتم إضافة أي أحمال بعد.'), findsOneWidget);
  });

  testWidgets(
    'dashboard renders a valid calculation without layout exception',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loadPersistenceRepositoryProvider.overrideWithValue(
              _FakeLoadRepository(),
            ),
            settingsPersistenceRepositoryProvider.overrideWithValue(
              _FakeSettingsRepository(),
            ),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('نتائج الحساب'), findsOneWidget);
      expect(find.text('الاستهلاك اليومي'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
