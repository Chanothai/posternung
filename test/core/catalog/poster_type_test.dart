import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/catalog/poster_type.dart';

void main() {
  test('apiValue round-trips through posterTypeFromApi for every value', () {
    for (final type in PosterType.values) {
      expect(posterTypeFromApi(type.apiValue), type);
    }
  });

  test('apiValue is the exact backend UPPERCASE wire value', () {
    expect(PosterType.teaser.apiValue, 'TEASER');
    expect(PosterType.advance.apiValue, 'ADVANCE');
    expect(PosterType.theatrical.apiValue, 'THEATRICAL');
    expect(PosterType.rerelease.apiValue, 'RERELEASE');
    expect(PosterType.unknown.apiValue, 'UNKNOWN');
  });

  test('posterTypeFromApi returns null for a null input', () {
    expect(posterTypeFromApi(null), isNull);
  });

  test('posterTypeFromApi returns null (not a throw) for an unrecognized '
      'value — a descriptive field must never crash the screen', () {
    expect(posterTypeFromApi('DIRECTORS_CUT'), isNull);
  });
}
