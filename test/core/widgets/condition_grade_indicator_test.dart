import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/catalog/poster_condition_grade.dart';
import 'package:posternung/core/widgets/condition_grade_indicator.dart';

void main() {
  Widget wrap(PosterConditionGrade? grade, {bool compact = false}) =>
      MaterialApp(
        home: Scaffold(
          body: ConditionGradeIndicator(grade: grade, compact: compact),
        ),
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

  group('compact variant (SCR-03 grid cells)', () {
    testWidgets('still shows the scale position — shrinking the badge is '
        'never an excuse for a bare label (ADR-0003)', (tester) async {
      await tester.pumpWidget(
        wrap(PosterConditionGrade.veryGood, compact: true),
      );

      expect(find.text('Very Good (5/8)'), findsOneWidget);
      expect(find.text('Very Good'), findsNothing);
    });

    testWidgets('drops the info icon but stays tappable', (tester) async {
      await tester.pumpWidget(wrap(PosterConditionGrade.fine, compact: true));

      expect(find.byIcon(Icons.info_outline), findsNothing);

      await tester.tap(find.byType(ConditionGradeIndicator));
      await tester.pumpAndSettle();

      expect(find.text('คู่มือระดับสภาพสินค้า'), findsOneWidget);
    });

    testWidgets('fits a 140px-wide cell without overflowing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 140,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConditionGradeIndicator(
                    grade: PosterConditionGrade.veryGood,
                    compact: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // A RenderFlex overflow would have been reported as a test exception
      // by now; assert the text is genuinely laid out inside the 140px too.
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(ConditionGradeIndicator)).width,
        lessThanOrEqualTo(140),
      );
    });

    testWidgets('a null grade in compact form still says "unspecified"', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(null, compact: true));

      expect(find.text('ไม่ระบุสภาพ'), findsOneWidget);
    });
  });
}
