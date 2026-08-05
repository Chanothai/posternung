import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/catalog/release_region.dart';

void main() {
  test('apiValue round-trips through releaseRegionFromApi for every value', () {
    for (final region in ReleaseRegion.values) {
      expect(releaseRegionFromApi(region.apiValue), region);
    }
  });

  test('apiValue is the exact backend UPPERCASE wire value', () {
    expect(ReleaseRegion.th.apiValue, 'TH');
    expect(ReleaseRegion.us.apiValue, 'US');
    expect(ReleaseRegion.jp.apiValue, 'JP');
    expect(ReleaseRegion.uk.apiValue, 'UK');
    expect(ReleaseRegion.intl.apiValue, 'INTL');
    expect(ReleaseRegion.unknown.apiValue, 'UNKNOWN');
  });

  test('releaseRegionFromApi returns null for a null input', () {
    expect(releaseRegionFromApi(null), isNull);
  });

  test('releaseRegionFromApi returns null (not a throw) for an unrecognized '
      'value', () {
    expect(releaseRegionFromApi('CANADA'), isNull);
  });

  // ADR-0009 §D2 / ADR-0011 §D7 — the one thing this file most exists to
  // protect: `UNKNOWN` on the wire must parse to a real enum member, never
  // collapse to `null`.
  test('the wire value "UNKNOWN" parses to ReleaseRegion.unknown, not null — '
      'NULL and UNKNOWN are never the same thing', () {
    expect(releaseRegionFromApi('UNKNOWN'), ReleaseRegion.unknown);
    expect(releaseRegionFromApi('UNKNOWN'), isNot(isNull));
  });

  test('ReleaseRegion.unknown.label is never a short region code — it must '
      'never end up looking like a real region in the subtitle', () {
    expect(ReleaseRegion.unknown.label, isNot('TH'));
    expect(ReleaseRegion.unknown.label, isNot('US'));
    expect(ReleaseRegion.unknown.label, isNot('JP'));
    expect(ReleaseRegion.unknown.label, isNot('UK'));
    expect(ReleaseRegion.unknown.label, isNot('INTL'));
  });
}
