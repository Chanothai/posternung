import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/catalog/poster_condition_grade.dart';

void main() {
  test('declaration order matches ADR-0003 exactly (best to worst) — this is '
      'the one thing this whole file exists to protect', () {
    expect(PosterConditionGrade.values, [
      PosterConditionGrade.mint,
      PosterConditionGrade.nearMint,
      PosterConditionGrade.veryFine,
      PosterConditionGrade.fine,
      PosterConditionGrade.veryGood,
      PosterConditionGrade.good,
      PosterConditionGrade.fair,
      PosterConditionGrade.poor,
    ]);
  });

  test(
    'scalePosition is 1-based, mint=1, poor=8 — "Fine" beats "Very Good"',
    () {
      expect(PosterConditionGrade.mint.scalePosition, 1);
      expect(PosterConditionGrade.fine.scalePosition, 4);
      expect(PosterConditionGrade.veryGood.scalePosition, 5);
      expect(PosterConditionGrade.poor.scalePosition, 8);
      expect(
        PosterConditionGrade.fine.scalePosition,
        lessThan(PosterConditionGrade.veryGood.scalePosition),
      );
    },
  );

  test('scaleLength is always 8', () {
    for (final grade in PosterConditionGrade.values) {
      expect(grade.scaleLength, 8);
    }
  });

  test(
    'apiValue round-trips through posterConditionGradeFromApi for every value',
    () {
      for (final grade in PosterConditionGrade.values) {
        expect(posterConditionGradeFromApi(grade.apiValue), grade);
      }
    },
  );

  test('posterConditionGradeFromApi returns null for a null input', () {
    expect(posterConditionGradeFromApi(null), isNull);
  });

  test('posterConditionGradeFromApi returns null (not a throw) for an '
      'unrecognized value — degrade gracefully rather than crash on a future '
      'backend addition', () {
    expect(posterConditionGradeFromApi('mint_plus'), isNull);
  });

  test('apiValue is the exact backend snake_case wire value', () {
    expect(PosterConditionGrade.nearMint.apiValue, 'near_mint');
    expect(PosterConditionGrade.veryFine.apiValue, 'very_fine');
    expect(PosterConditionGrade.veryGood.apiValue, 'very_good');
  });
}
