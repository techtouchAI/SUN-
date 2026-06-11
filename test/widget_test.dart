import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App starts with Load Input Screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    expect(find.text('Add Electrical Loads'), findsOneWidget);
  });
}
