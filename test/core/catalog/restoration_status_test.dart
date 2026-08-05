import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/catalog/restoration_status.dart';

void main() {
  test(
    'apiValue round-trips through restorationStatusFromApi for every value',
    () {
      for (final status in RestorationStatus.values) {
        expect(restorationStatusFromApi(status.apiValue), status);
      }
    },
  );

  test('apiValue is the exact backend UPPERCASE wire value', () {
    expect(RestorationStatus.none.apiValue, 'NONE');
    expect(RestorationStatus.restored.apiValue, 'RESTORED');
    expect(RestorationStatus.linenBacked.apiValue, 'LINEN_BACKED');
    expect(RestorationStatus.unknown.apiValue, 'UNKNOWN');
  });

  test('restorationStatusFromApi returns null for a null input', () {
    expect(restorationStatusFromApi(null), isNull);
  });

  test('restorationStatusFromApi returns null (not a throw) for an '
      'unrecognized value', () {
    expect(restorationStatusFromApi('REFRAMED'), isNull);
  });

  // ADR-0011 §D2 — the badge widget renders `label` verbatim for these two
  // values; they must actually say something, not be blank.
  test('RESTORED and LINEN_BACKED both have a non-empty fact-only label', () {
    expect(RestorationStatus.restored.label, isNotEmpty);
    expect(RestorationStatus.linenBacked.label, isNotEmpty);
  });

  test('NONE has an empty label — nothing is meant to render for it', () {
    expect(RestorationStatus.none.label, isEmpty);
  });
}
