import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/catalog/poster_condition_grade.dart';
import 'package:posternung/core/theme/app_colors.dart';
import 'package:posternung/core/widgets/condition_grade_indicator.dart';

void main() {
  Widget wrap(PosterConditionGrade? grade, {bool compact = false}) =>
      MaterialApp(
        home: Scaffold(
          body: ConditionGradeIndicator(grade: grade, compact: compact),
        ),
      );

  /// The pill's border color — reaches into the `Container` the private
  /// `_Pill` widget builds, since `_Pill` itself isn't importable from a
  /// test file. Used to pin ADR-0016 D6 (the border must be the grade's
  /// `scaleColor`, not the neutral default) without needing `_Pill` to be
  /// public just for testing.
  Color? pillBorderColor(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(ConditionGradeIndicator),
            matching: find.byWidgetPredicate(
              (widget) => widget is Container && widget.decoration != null,
            ),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    final border = decoration.border;
    return border is Border ? border.top.color : null;
  }

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

  testWidgets('the pill border shows the grade\'s scale color, paired with the '
      'x/8 fraction already in its label text (ADR-0016 D6) — must fail if '
      'the border reverts to the neutral default', (tester) async {
    await tester.pumpWidget(wrap(PosterConditionGrade.veryGood));

    expect(pillBorderColor(tester), PosterConditionGrade.veryGood.scaleColor);
    expect(pillBorderColor(tester), isNot(AppColors.borderMuted));
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

    testWidgets('still shows the scale color as the border too — D6 names this '
        'mode explicitly as having no exception (ADR-0016 D6)', (tester) async {
      await tester.pumpWidget(
        wrap(PosterConditionGrade.veryGood, compact: true),
      );

      expect(pillBorderColor(tester), PosterConditionGrade.veryGood.scaleColor);
      expect(pillBorderColor(tester), isNot(AppColors.borderMuted));
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
