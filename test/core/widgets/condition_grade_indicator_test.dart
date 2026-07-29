import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/catalog/poster_condition_grade.dart';
import 'package:posternung/core/widgets/condition_grade_indicator.dart';

void main() {
  Widget wrap(PosterConditionGrade? grade) => MaterialApp(
    home: Scaffold(body: ConditionGradeIndicator(grade: grade)),
  );

  testWidgets(
    'null grade shows an "unspecified" status, not a fake grade and not '
    'nothing at all (BR-05 — a price must never be shown without a '
    'condition next to it)',
    (tester) async {
      await tester.pumpWidget(wrap(null));

      expect(find.text('ไม่ระบุสภาพ'), findsOneWidget);
      // Never a fake grade, and never a bare "x/8" scale fragment either.
      expect(find.textContaining('/'), findsNothing);
    },
  );

  testWidgets('null grade is not tappable — no scale-guide content to open', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(null));

    await tester.tap(find.text('ไม่ระบุสภาพ'));
    await tester.pumpAndSettle();

    expect(find.text('คู่มือระดับสภาพสินค้า'), findsNothing);
  });

  testWidgets('shows the label with its scale position — never a bare label '
      '(ADR-0003)', (tester) async {
    await tester.pumpWidget(wrap(PosterConditionGrade.veryGood));

    expect(find.text('Very Good (5/8)'), findsOneWidget);
  });

  testWidgets('tapping opens the condition guide sheet with all 8 grades', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(PosterConditionGrade.fine));

    await tester.tap(find.byType(ConditionGradeIndicator));
    await tester.pumpAndSettle();

    expect(find.text('คู่มือระดับสภาพสินค้า'), findsOneWidget);
    for (final grade in PosterConditionGrade.values) {
      expect(find.textContaining(grade.label), findsAtLeastNWidgets(1));
    }
    // The current grade is marked distinctly from the other 7.
    expect(find.text('สภาพชิ้นนี้'), findsOneWidget);
  });
}
