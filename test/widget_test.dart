import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_calculator/logic/app_strings.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('App starts with Load Input Screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.addElectricalLoads), findsOneWidget);
    expect(find.text(AppStrings.unitWatt), findsOneWidget);
    expect(find.text(AppStrings.unitAmpere), findsNothing);
    expect(find.text(AppStrings.daytimeUsageHours), findsOneWidget);
    expect(find.text(AppStrings.nighttimeUsageHours), findsOneWidget);
    expect(find.text('ساعة بدء التوفر'), findsOneWidget);
  });
}
