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
DioException _dioError({
  required int status,
  Object? data,
  Map<String, List<String>>? headers,
}) {
  final requestOptions = RequestOptions(path: '/test');
  return DioException.badResponse(
    statusCode: status,
    requestOptions: requestOptions,
    response: Response(
      statusCode: status,
      data: data,
      requestOptions: requestOptions,
      headers: headers == null ? null : Headers.fromMap(headers),
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

  // ADR-0017 Amendment 2 A2-D2 / ADR-0037 Amendment 2 A2-D2.
  group('typedDetails', () {
    test('splits a well-formed details[] into (field, message) rows, '
        'preserving message as a raw, unparsed String', () {
      final envelope = backendErrorEnvelopeOf(
        _dioError(
          status: 409,
          data: {
            'error_code': 'POSTER_NOT_AVAILABLE',
            'message': 'มีคนจองใบนี้อยู่แล้ว',
            'details': [
              {'field': 'reserved_until', 'message': '2026-09-16T15:30:00Z'},
            ],
          },
        ),
      );

      expect(envelope, isNotNull);
      expect(envelope!.typedDetails, hasLength(1));
      expect(envelope.typedDetails.single.field, 'reserved_until');
      expect(envelope.typedDetails.single.message, '2026-09-16T15:30:00Z');
    });

    test('keeps well-formed rows and skips malformed ones in the same '
        'array, rather than discarding the whole list or throwing', () {
      final envelope = backendErrorEnvelopeOf(
        _dioError(
          status: 409,
          data: {
            'error_code': 'RESERVATION_LIMIT_EXCEEDED',
            'message': 'จองครบจำนวนที่กำหนดแล้ว',
            'details': [
              {'field': 'limit', 'message': '3'}, // well-formed
              {'field': 'no_message'}, // missing message
              {'message': 'no_field'}, // missing field
              {'field': 'wrong_type', 'message': 42}, // message not a String
              {'field': 7, 'message': 'field not a String'},
              'not a map at all',
            ],
          },
        ),
      );

      expect(envelope, isNotNull);
      expect(envelope!.typedDetails, hasLength(1));
      expect(envelope.typedDetails.single.field, 'limit');
      expect(envelope.typedDetails.single.message, '3');
    });

    test('is an empty list — not null — when details is absent', () {
      final envelope = backendErrorEnvelopeOf(
        _dioError(
          status: 404,
          data: {'error_code': 'POSTER_NOT_FOUND', 'message': 'ไม่พบ'},
        ),
      );

      expect(envelope, isNotNull);
      expect(envelope!.typedDetails, isEmpty);
    });

    test('is an empty list when details is present but not a JSON array '
        '(e.g. a bare string or map)', () {
      final envelope = backendErrorEnvelopeOf(
        _dioError(
          status: 500,
          data: {
            'error_code': 'SERVER_ERROR',
            'message': 'เกิดข้อผิดพลาด',
            'details': 'not a list',
          },
        ),
      );

      expect(envelope, isNotNull);
      expect(envelope!.typedDetails, isEmpty);
      // Regression — the pre-existing stringified `details` field must
      // still be populated exactly as before this field was added.
      expect(envelope.details, 'not a list');
    });

    test('regression — the pre-existing `details: String?` field is still '
        'populated the same way as before typedDetails existed', () {
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
      expect(envelope!.details, isNotNull);
      expect(envelope.details, contains('loc'));
    });
  });

  // ADR-0017 Amendment 2 A2-D2 / ADR-0037 Amendment 2 A2-D2 — 429s carry
  // this in the response header instead of a `details` row.
  group('retryAfterSeconds', () {
    test('parses a plain-integer Retry-After header', () {
      final envelope = backendErrorEnvelopeOf(
        _dioError(
          status: 429,
          data: {'error_code': 'RESERVE_RATE_LIMITED', 'message': 'รัวเกินไป'},
          headers: {
            'Retry-After': ['42'],
          },
        ),
      );

      expect(envelope, isNotNull);
      expect(envelope!.retryAfterSeconds, 42);
    });

    test('is null when the Retry-After header is absent', () {
      final envelope = backendErrorEnvelopeOf(
        _dioError(
          status: 429,
          data: {'error_code': 'RESERVE_RATE_LIMITED', 'message': 'รัวเกินไป'},
        ),
      );

      expect(envelope, isNotNull);
      expect(envelope!.retryAfterSeconds, isNull);
    });

    test('is null when the Retry-After header is not a plain integer '
        '(e.g. an HTTP-date form) rather than throwing', () {
      final envelope = backendErrorEnvelopeOf(
        _dioError(
          status: 429,
          data: {'error_code': 'RESERVE_RATE_LIMITED', 'message': 'รัวเกินไป'},
          headers: {
            'Retry-After': ['Wed, 16 Sep 2026 15:30:00 GMT'],
          },
        ),
      );

      expect(envelope, isNotNull);
      expect(envelope!.retryAfterSeconds, isNull);
    });
  });
}
