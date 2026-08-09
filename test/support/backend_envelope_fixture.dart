import 'package:dio/dio.dart';
import 'package:posternung/core/error/backend_envelope.dart';

/// Builds a [BackendErrorEnvelope] the same way production code does — by
/// round-tripping a fake backend `{error_code, message, details}` body
/// through a real [DioException] and the real [backendErrorEnvelopeOf]
/// parser (ADR-0017 Amendment 1, OD-A) — instead of hand-constructing the
/// envelope, which its private constructor forbids from outside
/// `lib/core/error/backend_envelope.dart` anyway (A1-D3).
///
/// Shared by every test that needs an `AuthException`/`CatalogException`
/// populated via the envelope path (`.fromEnvelope()`), so there is exactly
/// one place that assembles the fake `DioException`/`Response` plumbing
/// instead of one per test file.
///
/// [message] is omitted from the fake body entirely when `null` (not sent
/// as an explicit JSON `null`) — this is what lets a test exercise "the
/// envelope has no `message` key at all" (ADR-0017 Amendment 1 AC-9) by
/// simply not passing it.
BackendErrorEnvelope backendEnvelopeFixture({
  required String code,
  String? message,
  Object? details,
  int statusCode = 422,
}) {
  final requestOptions = RequestOptions(path: '/test');
  final response = Response<Map<String, dynamic>>(
    requestOptions: requestOptions,
    statusCode: statusCode,
    data: {'error_code': code, 'message': ?message, 'details': ?details},
  );
  final dioException = DioException(
    requestOptions: requestOptions,
    response: response,
  );

  final envelope = backendErrorEnvelopeOf(dioException);
  if (envelope == null) {
    // Would mean this fixture and the real parser's condition have drifted
    // apart — every call here sets `error_code` as a String, which is the
    // only thing `backendErrorEnvelopeOf` checks.
    throw StateError(
      'backendEnvelopeFixture built a body that backendErrorEnvelopeOf '
      "didn't recognize as an envelope — the fixture and the real parser "
      'have drifted apart.',
    );
  }
  return envelope;
}
