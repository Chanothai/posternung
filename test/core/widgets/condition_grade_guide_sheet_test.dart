import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/catalog/poster_condition_grade.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/core/theme/app_colors.dart';
import 'package:posternung/core/widgets/condition_grade_guide_sheet.dart';

/// Sheet-level coverage for ADR-0016 (SCR-11 Condition Guide, AC-2 + AC-3a).
/// `condition_grade_indicator_test.dart` covers the tappable badge that
/// opens this sheet (including the `compact` variant, and ADR-0016 D6's
/// border-color pin); this file covers what the sheet itself renders once
/// open.
void main() {
  Future<void> openSheet(
    WidgetTester tester, {
    PosterConditionGrade? current,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showConditionGradeGuideSheet(context, current: current),
              child: const Text('open guide'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open guide'));
    await tester.pumpAndSettle();
  }

  Finder gradeRow(PosterConditionGrade grade) =>
      find.byKey(ValueKey('grade-row-${grade.name}'));

  // Independent copy of `PosterConditionGradeX.wearTraces`' content —
  // written out here rather than read back from the getter under test, so a
  // mutation that deletes entries from the production list is actually
  // caught (code-critic 2026-08-06 round 1: reconstructing the expectation
  // by calling `grade.wearTraces` meant deleting items 2-5 of `poor` still
  // passed, because both sides of the assertion moved together). Keep in
  // sync with `poster_condition_grade.dart`'s `wearTraces` getter by hand —
  // this is a content pin, not a computed derivation, same as the indicator
  // test's literal `'Very Good (5/8)'`.
  //
  // Updated GATE 3 round 2 (2026-08-06): `ฉีก` added (fair/poor only,
  // `ยับ` stays rejected) and `good`/`fair`/`poor` reworded so every
  // repeated dimension (รอยพับ/ขอบ/คราบ/สีซีด) reads strictly
  // non-decreasing in severity toward `poor` — see the getter's own doc
  // comment for the full per-dimension ladder.
  const expectedWearTraces = {
    PosterConditionGrade.mint: <String>[],
    PosterConditionGrade.nearMint: ['รอยพับที่มุมเล็กน้อยมาก'],
    PosterConditionGrade.veryFine: ['รอยพับเบา ๆ', 'ขอบมีรอยเล็กน้อย'],
    PosterConditionGrade.fine: ['รอยพับที่สังเกตเห็นได้', 'ขอบสึกบาง ๆ'],
    PosterConditionGrade.veryGood: [
      'รอยพับหลายจุด',
      'ขอบสึกชัดขึ้น',
      'มีคราบจาง ๆ',
    ],
    PosterConditionGrade.good: [
      'รอยพับชัดเจนหลายจุด',
      'ขอบสึกชัดเจน',
      'มีคราบที่สังเกตเห็นได้',
      'มีสีซีดเล็กน้อย',
    ],
    PosterConditionGrade.fair: [
      'รอยพับชัดเจนทั่วใบ',
      'มีรูหมุด',
      'ขอบสึกและมีรอยฉีกเล็กน้อย',
      'มีคราบชัดเจน',
      'มีสีซีดที่สังเกตเห็นได้',
    ],
    PosterConditionGrade.poor: [
      'รอยพับหนาแน่นทั่วทั้งใบ',
      'มีรูหมุดชัดเจน',
      'ขอบสึกและฉีกขาด',
      'มีคราบชัดเจนหลายจุด',
      'สีซีดชัดเจน',
      'มีรอยเทปซ่อม',
    ],
  };

  testWidgets('Fine renders above Very Good on screen — asserted from actual '
      'on-screen position, not enum declaration order (ADR-0016 D3: the old '
      'numeric-prefix-only layout forced reading the whole list to learn '
      'this)', (tester) async {
    await openSheet(tester);

    final fineDy = tester.getTopLeft(find.text('Fine (4/8)')).dy;
    final veryGoodDy = tester.getTopLeft(find.text('Very Good (5/8)')).dy;

    expect(fineDy, lessThan(veryGoodDy));
  });

  testWidgets(
    'all 8 grades show every one of their wear-trace phrases on screen, '
    'not just the first one (ADR-0016 AC-3a) — expectation is an '
    'independent copy of the production content, so deleting entries from '
    'the real list is actually caught (code-critic 2026-08-06 round 1)',
    (tester) async {
      await openSheet(tester);

      for (final grade in PosterConditionGrade.values) {
        final row = gradeRow(grade);
        final traces = expectedWearTraces[grade]!;

        if (traces.isEmpty) {
          // mint today — the empty-list case must still render a
          // dedicated non-blank line, never nothing.
          expect(
            find.descendant(
              of: row,
              matching: find.text(AppStrings.conditionGuideNoTracesLabel),
            ),
            findsOneWidget,
            reason:
                'grade ${grade.name} has no traces and must show the '
                'dedicated "no traces" line',
          );
          continue;
        }

        final expectedLine =
            '${AppStrings.conditionGuideTracesLabel}${traces.join(' · ')}';
        expect(
          find.descendant(of: row, matching: find.text(expectedLine)),
          findsOneWidget,
          reason:
              'grade ${grade.name} must show all ${traces.length} of its '
              'wear traces, not just the first',
        );
      }
    },
  );

  testWidgets(
    "every grade's scale color is co-located with its x/8 fraction text — "
    'inside the same row, not merely present somewhere on the sheet '
    '(ADR-0016 D6 requires the color be *labelled*, i.e. co-located — '
    'code-critic 2026-08-06 round 1: a version of this check that only '
    'looked for "color exists" and "x/8 text exists" separately anywhere '
    'on the sheet stayed green even after moving the color swatch to a '
    'different row)',
    (tester) async {
      await openSheet(tester);

      for (final grade in PosterConditionGrade.values) {
        final row = gradeRow(grade);
        expect(row, findsOneWidget);

        expect(
          find.descendant(
            of: row,
            matching: find.text('${grade.label} (${grade.scaleFractionLabel})'),
          ),
          findsOneWidget,
          reason: 'grade ${grade.name} row must show its label with position',
        );

        // The specific color-dot widget for this grade — pinned by key, not
        // just "some colored container somewhere" — must itself live inside
        // this row. (Just checking "a colored container exists in the row"
        // would still pass if only the dot moved out, because the position
        // track below also colors one of its segments inside the same
        // row — that's item 3's test. This assertion is what actually goes
        // red if `_ColorDot` specifically is relocated outside its row.)
        expect(
          find.descendant(
            of: row,
            matching: find.byKey(ValueKey('color-dot-${grade.name}')),
          ),
          findsOneWidget,
          reason:
              'grade ${grade.name}\'s color dot must be inside its own row, '
              'next to the fraction text — not moved elsewhere on the sheet',
        );

        final colorSwatchInRow = find.descendant(
          of: row,
          matching: find.byWidgetPredicate((widget) {
            if (widget is! Container) return false;
            final decoration = widget.decoration;
            return decoration is BoxDecoration &&
                decoration.color == grade.scaleColor;
          }),
        );
        expect(
          colorSwatchInRow,
          findsAtLeastNWidgets(1),
          reason:
              'grade ${grade.name} row must render its scale color inside '
              'the same row as the fraction text, not elsewhere on the '
              'sheet',
        );
      }
    },
  );

  testWidgets(
    'the position track exists per grade and highlights exactly its own '
    'segment out of 8 — the self-contained "where on the scale" structure '
    'AC-2(ก) requires (code-critic 2026-08-06 round 1: removing the track '
    'entirely left the earlier version of this suite fully green)',
    (tester) async {
      await openSheet(tester);

      for (final grade in PosterConditionGrade.values) {
        final track = find.byKey(ValueKey('position-track-${grade.name}'));
        expect(
          track,
          findsOneWidget,
          reason: 'grade ${grade.name} must render its position track',
        );

        for (var i = 1; i <= grade.scaleLength; i++) {
          final segment = tester.widget<Container>(
            find.byKey(ValueKey('position-track-segment-${grade.name}-$i')),
          );
          final decoration = segment.decoration! as BoxDecoration;
          if (i == grade.scalePosition) {
            expect(
              decoration.color,
              grade.scaleColor,
              reason:
                  'grade ${grade.name} segment $i is its own position and '
                  'must be filled with its scale color',
            );
          } else {
            expect(
              decoration.color,
              isNot(grade.scaleColor),
              reason:
                  'grade ${grade.name} segment $i is not its position and '
                  'must not carry its scale color',
            );
          }
        }
      }
    },
  );

  testWidgets(
    'opening with current == null shows all 8 grades with none highlighted '
    '— never guesses a grade to highlight (ADR-0016 D7)',
    (tester) async {
      await openSheet(tester, current: null);

      expect(find.text(AppStrings.conditionGuideCurrentBadge), findsNothing);
      for (final grade in PosterConditionGrade.values) {
        expect(
          find.text('${grade.label} (${grade.scaleFractionLabel})'),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets(
    'the Fine <-> Very Good boundary callout exists and sits between the '
    'two rows on screen — the one emphasis ADR-0016 D3(ข) makes '
    'non-optional',
    (tester) async {
      await openSheet(tester);

      expect(
        find.text(AppStrings.conditionGuideFineVeryGoodCalloutTitle),
        findsOneWidget,
      );

      final fineDy = tester.getTopLeft(find.text('Fine (4/8)')).dy;
      final calloutDy = tester
          .getTopLeft(
            find.text(AppStrings.conditionGuideFineVeryGoodCalloutTitle),
          )
          .dy;
      final veryGoodDy = tester.getTopLeft(find.text('Very Good (5/8)')).dy;

      expect(fineDy, lessThan(calloutDy));
      expect(calloutDy, lessThan(veryGoodDy));
    },
  );
}
