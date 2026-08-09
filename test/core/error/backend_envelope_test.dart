import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/error/backend_envelope.dart';

// Built through Dio's own `.badResponse` factory, not the bare
// `DioException(...)` constructor — the factory is what production code
// actually goes through, and it's the only thing that sets `.message` to a
// realistic (non-null) SDK string. A bare constructor leaves `.message` at
// its default of `null`, which would make the AC-9 test below vacuously
// pass against a mutant that falls back to `e.message` when `data['message']`
// is absent — there would never be a non-null `e.message` for that mutant to
// leak (code-critic, INF-20 round 2 — same class of bug as M9/M5, this time
// in this file's own fixture rather than the datasource tests').
DioException _dioError({required int status, Object? data}) {
  final requestOptions = RequestOptions(path: '/test');
  return DioException.badResponse(
    statusCode: status,
    requestOptions: requestOptions,
    response: Response(
      statusCode: status,
      data: data,
      requestOptions: requestOptions,
    ),
  );
}

void main() {
  group('backendErrorEnvelopeOf', () {
    test('parses code + message + details from a well-formed envelope', () {
      final envelope = backendErrorEnvelopeOf(
        _dioError(
          status: 422,
          data: {
            'error_code': 'VALIDATION_ERROR',
            'message': 'ข้อมูลไม่ถูกต้อง',
            'details': [
              {
                'loc': ['body', 'id_token'],
                'msg': 'field required',
              },
            ],
          },
        ),
      );

      expect(envelope, isNotNull);
      expect(envelope!.code, 'VALIDATION_ERROR');
      expect(envelope.displayMessage, 'ข้อมูลไม่ถูกต้อง');
      expect(envelope.details, isNotNull);
      // ADR-0017 Amendment 1 AC-10 — details must never equal displayMessage:
      // they carry different content (structured/English vs Thai prose) and
      // conflating them is exactly what D3 forbids ever rendering.
      expect(envelope.details, isNot(envelope.displayMessage));
    });

    test('displayMessage is null when the envelope omits the `message` key '
        'entirely (ADR-0017 Amendment 1 AC-9) — not every AppError sends '
        'one, and this must not crash or invent a placeholder, in '
        'particular must not fall back to the DioException\'s own SDK '
        'message (M5 at GATE 3, round 2)', () {
      final dioException = _dioError(
        status: 404,
        data: {'error_code': 'POSTER_NOT_FOUND'},
      );
      // Precondition — proves this test isn't vacuous: if `e.message` were
      // null here (a bare-constructor fixture, the round-1 defect), a
      // mutant that falls back to it on a missing `message` key would be
      // indistinguishable from correct code, because there'd be nothing
      // non-null for it to leak.
      expect(dioException.message, isNotNull);
      expect(dioException.message, isNotEmpty);

      final envelope = backendErrorEnvelopeOf(dioException);

      expect(envelope, isNotNull);
      expect(envelope!.code, 'POSTER_NOT_FOUND');
      expect(envelope.displayMessage, isNull);
    });

    test('details is null when the envelope omits `details`', () {
      final envelope = backendErrorEnvelopeOf(
        _dioError(
          status: 404,
          data: {'error_code': 'POSTER_NOT_FOUND', 'message': 'ไม่พบ'},
        ),
      );

      expect(envelope, isNotNull);
      expect(envelope!.details, isNull);
    });

    test('returns null for a response with no error_code — not an envelope '
        'at all (connection failure, gateway/non-JSON 5xx, ...)', () {
      expect(
        backendErrorEnvelopeOf(_dioError(status: 502, data: null)),
        isNull,
      );
      expect(
        backendErrorEnvelopeOf(
          _dioError(status: 422, data: {'detail': 'not an envelope shape'}),
        ),
        isNull,
      );
    });

    test('returns null when error_code is present but not a String — same '
        'defensive condition every backend-facing datasource used before '
        'this was centralized', () {
      expect(
        backendErrorEnvelopeOf(
          _dioError(status: 400, data: {'error_code': 404}),
        ),
        isNull,
      );
    });

    test('returns null when there is no response at all (e.g. a connection '
        'timeout — DioException.response is null)', () {
      expect(
        backendErrorEnvelopeOf(
          DioException(requestOptions: RequestOptions(path: '/test')),
        ),
        isNull,
      );
    });
  });
}
