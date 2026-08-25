import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/screens/settings_screen.dart';

void main() {
  testWidgets('shows optional saved PV and DC cable protection inputs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );

    expect(find.text('تفاصيل الحماية الكهربائية (اختيارية)'), findsOneWidget);
    expect(find.text('عدد الألواح على التوالي لكل مسار'), findsOneWidget);
    expect(find.text('عدد المسارات على التوازي'), findsOneWidget);
    expect(find.text('طول مسار كابل DC باتجاه واحد'), findsOneWidget);
    expect(find.text('مادة الموصل'), findsOneWidget);
    expect(find.text('طريقة تمديد كابل DC'), findsOneWidget);
  });
}
