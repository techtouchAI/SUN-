import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/core/validation/load_form_validation.dart';

void main() {
  testWidgets('invalid load form values render errors and block submission', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    var submitCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: [
                TextFormField(
                  key: const Key('power'),
                  validator: LoadFormValidation.powerValue,
                ),
                TextFormField(
                  key: const Key('hours'),
                  validator: LoadFormValidation.dailyHours,
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      submitCount++;
                    }
                  },
                  child: const Text('إضافة الحمل'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('power')), '0');
    await tester.enterText(find.byKey(const Key('hours')), '25');
    await tester.tap(find.text('إضافة الحمل'));
    await tester.pump();

    expect(find.text('أدخل رقماً أكبر من صفر.'), findsOneWidget);
    expect(find.text('يجب أن تكون الساعات بين 0 و24.'), findsOneWidget);
    expect(submitCount, 0);
  });
}
