import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/features/poster/domain/entities/poster_image_kind.dart';

void main() {
  group('posterImageKindFromApi', () {
    test('parses all three known wire values', () {
      expect(posterImageKindFromApi('FRONT'), PosterImageKind.front);
      expect(posterImageKindFromApi('BACK'), PosterImageKind.back);
      expect(posterImageKindFromApi('DEFECT'), PosterImageKind.defect);
    });

    // ADR-0026 §D1 already announces a 4th value (RAKING) is coming without
    // a new ADR — just a new enum value — so this client must already
    // tolerate a value it has never seen, not throw.
    test('an unrecognized future kind (RAKING) degrades to null, no throw', () {
      expect(() => posterImageKindFromApi('RAKING'), returnsNormally);
      expect(posterImageKindFromApi('RAKING'), isNull);
    });

    // ADR-0026 §D2 — the only casing conversion in the system lives at the
    // backend's filename reader; every other layer sees UPPERCASE only.
    // Accepting lowercase here would make this a second place deciding what
    // casing means.
    test('lowercase is rejected, not tolerated — D2 casing rule', () {
      expect(posterImageKindFromApi('front'), isNull);
    });

    test('an empty string and garbage both degrade to null, no throw', () {
      expect(posterImageKindFromApi(''), isNull);
      expect(posterImageKindFromApi('nonsense-value'), isNull);
    });

    test('a null value degrades to null, no throw', () {
      expect(() => posterImageKindFromApi(null), returnsNormally);
      expect(posterImageKindFromApi(null), isNull);
    });
  });
}
