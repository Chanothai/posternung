import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/error/catalog_exception.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/poster/presentation/catalog_error_display.dart';

import '../../../support/backend_envelope_fixture.dart';

void main() {
  group('catalogErrorDisplayMessage', () {
    test('maps network_error to this feature\'s Thai text, ignoring any '
        'fallback', () {
      final message = catalogErrorDisplayMessage(
        const CatalogException(code: 'network_error'),
        fallback: 'ตัวสำรองของหน้านี้',
      );

      expect(message, AppStrings.authErrorNetwork);
    });

    test('maps server_error to this feature\'s Thai text', () {
      final message = catalogErrorDisplayMessage(
        const CatalogException(code: 'server_error'),
        fallback: 'ตัวสำรองของหน้านี้',
      );

      expect(message, AppStrings.authErrorServer);
    });

    test('a backend error_code not in the table (e.g. POSTER_NOT_FOUND) uses '
        "the exception's own displayMessage from the envelope (D2), not the "
        'fallback', () {
      final message = catalogErrorDisplayMessage(
        CatalogException.fromEnvelope(
          backendEnvelopeFixture(
            code: 'POSTER_NOT_FOUND',
            message: 'ไม่พบโปสเตอร์นี้',
          ),
        ),
        fallback: 'ตัวสำรองของหน้านี้',
      );

      expect(message, 'ไม่พบโปสเตอร์นี้');
    });

    test('an unmapped code with no displayMessage (e.g. unknown_error) falls '
        "back to the caller's own static copy — each screen's copy, not a "
        'single shared one (ADR-0017 §Alternatives A4 was rejected)', () {
      final message = catalogErrorDisplayMessage(
        const CatalogException(code: 'unknown_error'),
        fallback: 'ตัวสำรองของหน้านี้',
      );

      expect(message, 'ตัวสำรองของหน้านี้');
    });

    test('unknown_error resolves to each real screen\'s own fallback constant '
        '— proves the three call sites (poster detail / home grid / home '
        'load-more) each keep their own copy rather than sharing one baked '
        'into the exception, the behavior change from before ADR-0017', () {
      expect(
        catalogErrorDisplayMessage(
          const CatalogException(code: 'unknown_error'),
          fallback: AppStrings.posterDetailErrorBody,
        ),
        AppStrings.posterDetailErrorBody,
      );
      expect(
        catalogErrorDisplayMessage(
          const CatalogException(code: 'unknown_error'),
          fallback: AppStrings.homePostersErrorBody,
        ),
        AppStrings.homePostersErrorBody,
      );
      expect(
        catalogErrorDisplayMessage(
          const CatalogException(code: 'unknown_error'),
          fallback: AppStrings.homeLoadMoreErrorBody,
        ),
        AppStrings.homeLoadMoreErrorBody,
      );
    });
  });

  group('catalogErrorMessageFor', () {
    test('returns null for a non-CatalogException error — callers fall back '
        'to their own static copy directly', () {
      expect(catalogErrorMessageFor(StateError('boom'), fallback: 'x'), isNull);
    });

    test('returns null for null', () {
      expect(catalogErrorMessageFor(null, fallback: 'x'), isNull);
    });

    test('delegates to catalogErrorDisplayMessage for a CatalogException', () {
      final message = catalogErrorMessageFor(
        const CatalogException(code: 'network_error'),
        fallback: 'x',
      );

      expect(message, AppStrings.authErrorNetwork);
    });
  });
}
