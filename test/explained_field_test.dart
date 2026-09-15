import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_calculator/logic/field_help_content.dart';
import 'package:solar_calculator/widgets/explained_field.dart';

void main() {
  const explanation = FieldExplanation(
    title: 'كيف تحدد ساعات التوفر؟',
    points: ['اكتب مدة توفر الكهرباء بالساعات.'],
    examples: ['أربع ساعات يومياً: اكتب 4.'],
  );

  testWidgets('icon replaces the long sentence and still opens detailed help', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExplainedField(
            explanation: explanation,
            field: TextFormField(
              decoration: const InputDecoration(labelText: 'ساعات التوفر'),
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('إذا لم تعرف ماذا تكتب'), findsNothing);
    expect(find.textContaining('اضغط هنا لشرح'), findsNothing);
    expect(find.textContaining('المدة بالساعات'), findsNothing);
    expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    expect(find.byTooltip('شرح الحقل: ${explanation.title}'), findsOneWidget);
    expect(tester.getSize(find.byType(IconButton)), const Size(48, 48));

    await tester.tap(find.byIcon(Icons.help_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text(explanation.title), findsOneWidget);
    expect(find.text(explanation.points.single), findsOneWidget);
    expect(find.text(explanation.examples.single), findsOneWidget);
    await tester.tap(find.text(FieldHelpContent.understoodButton));
    await tester.pumpAndSettle();
    expect(find.text(explanation.title), findsNothing);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final direction in TextDirection.values) {
    testWidgets('help drops below the field in narrow $direction layouts', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: direction,
              child: SizedBox(
                width: 140,
                child: ExplainedField(
                  explanation: explanation,
                  field: TextFormField(
                    decoration: const InputDecoration(labelText: 'الساعات'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final fieldRect = tester.getRect(find.byType(TextFormField));
      final helpRect = tester.getRect(find.byType(IconButton));
      // Narrow columns keep the field full width so the label is never
      // truncated; the compact help button moves underneath the field.
      expect(fieldRect.width, 140);
      expect(tester.getSize(find.byType(IconButton)), const Size(36, 36));
      expect(helpRect.top, fieldRect.bottom);
      if (direction == TextDirection.rtl) {
        expect(helpRect.right, fieldRect.right);
      } else {
        expect(helpRect.left, fieldRect.left);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final direction in TextDirection.values) {
    testWidgets('help stays beside its field in wide $direction layouts', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: direction,
              child: SizedBox(
                width: 320,
                child: ExplainedField(
                  explanation: explanation,
                  field: TextFormField(
                    decoration: const InputDecoration(labelText: 'الساعات'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final fieldRect = tester.getRect(find.byType(TextFormField));
      final helpRect = tester.getRect(find.byType(IconButton));
      expect(tester.getSize(find.byType(IconButton)), const Size(48, 48));
      expect(helpRect.top, fieldRect.top);
      if (direction == TextDirection.rtl) {
        expect(helpRect.right, fieldRect.left);
      } else {
        expect(helpRect.left, fieldRect.right);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
