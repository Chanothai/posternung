import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/features/auth/data/datasources/backend_auth_data_source.dart';

class MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _resp(Map<String, dynamic> data) => Response(
  data: data,
  requestOptions: RequestOptions(path: '/'),
);

// /auth/logout answers 204 with an empty body — nothing to decode.
Response<void> _voidResp() =>
    Response(statusCode: 204, requestOptions: RequestOptions(path: '/'));

// Built through Dio's own `.badResponse`/`.connectionError` factories, not
// the bare `DioException(...)` constructor — those factories are what
// production code actually goes through, and they're the only thing that
// sets `.message` to a realistic (non-null) SDK string. A bare constructor
// leaves `.message` at its default of `null`, which used to make every
// negative `displayMessage == null` assertion in this file vacuous: it
// would have passed even if a mutant piped `e.message` straight into
// `displayMessage`, because there was never a non-null `e.message` for that
// mutant to leak in the first place (code-critic, INF-20 round 1 — M9).
// Going through the real factory also means this fixture can't drift from
// what Dio actually sends when the SDK's own message wording changes across
// versions.
DioException _dioError(int status, {Object? data}) {
  final requestOptions = RequestOptions(path: '/');
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

DioException _dioNoResponse() => DioException.connectionError(
  requestOptions: RequestOptions(path: '/'),
  reason: 'Connection refused',
);

void main() {
  late MockDio dio;
  late BackendAuthDataSourceImpl dataSource;

  setUpAll(() => registerFallbackValue(Options()));

  setUp(() {
    dio = MockDio();
    dataSource = BackendAuthDataSourceImpl(dio);
  });

  // Closed-world check on the fixtures above (test-quality §4) — every
  // `displayMessage`/`debugDetail == null` negative assertion in this file
  // only has teeth because `_dioError`/`_dioNoResponse` carry a real,
  // non-null `.message` for a leaking mutant to actually leak. Nothing else
  // in this file re-verifies that; if `DioException.badResponse`/
  // `.connectionError` ever stopped setting `.message`, or someone reverted
  // either helper back to the bare `DioException(...)` constructor, every
  // negative assertion below would silently go vacuous again exactly like
  // the round-1 defect (code-critic, INF-20 round 2) — this is the one test
  // that would say so out loud instead of staying green by accident.
  test('fixture sanity: _dioError and _dioNoResponse both carry a non-null, '
      'non-empty .message, as real DioExceptions from these factories '
      'always do', () {
    expect(_dioError(404).message, isNotNull);
    expect(_dioError(404).message, isNotEmpty);
    expect(_dioNoResponse().message, isNotNull);
    expect(_dioNoResponse().message, isNotEmpty);
  });

  group('firebaseLogin', () {
    test(
      'POSTs the id_token to /auth/firebase and parses TokenResponse',
      () async {
        when(
          () => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => _resp({'access_token': 'a', 'refresh_token': 'r'}),
        );

        final result = await dataSource.firebaseLogin('id-tok');

        expect(result.accessToken, 'a');
        expect(result.refreshToken, 'r');
        final captured = verify(
          () => dio.post<Map<String, dynamic>>(
            captureAny(),
            data: captureAny(named: 'data'),
            options: any(named: 'options'),
          ),
        ).captured;
        expect(captured[0], '/api/v1/auth/firebase');
        expect(captured[1], {'id_token': 'id-tok'});
      },
    );

    test('surfaces the backend {error_code, message} envelope', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        _dioError(
          401,
          data: {
            'error_code': 'OAUTH_TOKEN_INVALID',
            'message': 'ไม่สามารถยืนยันตัวตนกับ Google ได้ กรุณาลองใหม่',
          },
        ),
      );

      expect(
        () => dataSource.firebaseLogin('x'),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', 'OAUTH_TOKEN_INVALID')
              .having(
                (e) => e.displayMessage,
                'displayMessage',
                'ไม่สามารถยืนยันตัวตนกับ Google ได้ กรุณาลองใหม่',
              )
              // ADR-0017 Amendment 1 AC-10, third direction — an envelope
              // with no `details` key must give a null debugDetail, not
              // silently fall back to something else (e.g. `e.message`,
              // which is now realistic/non-null in this fixture and would
              // be an easy thing to leak in by accident).
              .having((e) => e.debugDetail, 'debugDetail', isNull),
        ),
      );
    });

    // SCR-02 AC-4 — every error_code openapi.yaml documents for
    // POST /auth/firebase, verified end-to-end through this datasource
    // (not just OAUTH_TOKEN_INVALID above). All five arrive through the
    // same {error_code, message} envelope regardless of HTTP status, so
    // this also proves the envelope path is not accidentally special-cased
    // to only the status this file's other tests happen to use.
    for (final testCase in [
      (
        status: 403,
        code: 'OAUTH_EMAIL_NOT_VERIFIED',
        message: 'บัญชีนี้ยังไม่ได้ยืนยันอีเมล',
      ),
      (
        status: 409,
        code: 'OAUTH_LOGIN_CONFLICT',
        message: 'เกิดข้อขัดแย้งระหว่างเข้าสู่ระบบ กรุณาลองใหม่อีกครั้ง',
      ),
      (
        status: 429,
        code: 'LOGIN_RATE_LIMITED',
        message: 'พยายามเข้าสู่ระบบบ่อยเกินไป กรุณาลองใหม่ภายหลัง',
      ),
      (
        status: 503,
        code: 'OAUTH_PROVIDER_NOT_CONFIGURED',
        message: 'ระบบยังไม่ได้ตั้งค่า Firebase login กรุณาติดต่อผู้ดูแลระบบ',
      ),
    ]) {
      test('AC-4: HTTP ${testCase.status} surfaces error_code '
          '${testCase.code} with its Thai message as displayMessage', () async {
        when(
          () => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenThrow(
          _dioError(
            testCase.status,
            data: {'error_code': testCase.code, 'message': testCase.message},
          ),
        );

        expect(
          () => dataSource.firebaseLogin('x'),
          throwsA(
            isA<AuthException>()
                .having((e) => e.code, 'code', testCase.code)
                .having(
                  (e) => e.displayMessage,
                  'displayMessage',
                  testCase.message,
                ),
          ),
        );
      });
    }

    test('maps a no-response failure to code network_error', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(_dioNoResponse());

      expect(
        () => dataSource.firebaseLogin('x'),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', 'network_error')
              // ADR-0017 Amendment 1 A1-D6 — this branch never sees a
              // backend envelope at all, so displayMessage must stay null;
              // this is the assertion that would catch a regression where
              // someone starts populating it from `e.message` (Dio's own
              // English connection-failure text).
              .having((e) => e.displayMessage, 'displayMessage', isNull),
        ),
      );
    });

    test('maps a 5xx without an envelope to code server_error', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(_dioError(502));

      expect(
        () => dataSource.firebaseLogin('x'),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', 'server_error')
              .having((e) => e.displayMessage, 'displayMessage', isNull),
        ),
      );
    });

    test('a validation failure (e.g. an empty id_token — the real regression: '
        'getIdToken() resolving to "" instead of null) arrives through the '
        'same {error_code, message} envelope as every other AppError — '
        'app/main.py wraps RequestValidationError into it before this '
        'datasource ever sees a raw FastAPI {detail: [...]} shape', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        _dioError(
          422,
          data: {
            'error_code': 'VALIDATION_ERROR',
            'message': 'id_token ต้องไม่ว่างเปล่า',
          },
        ),
      );

      expect(
        () => dataSource.firebaseLogin(''),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', 'VALIDATION_ERROR')
              .having(
                (e) => e.displayMessage,
                'displayMessage',
                'id_token ต้องไม่ว่างเปล่า',
              ),
        ),
      );
    });

    test('a raw FastAPI {detail: [...]} shape — the pre-ADR-0017 form this '
        "datasource used to hand-parse into Pydantic's own field names, "
        'proven dead code because the real backend never sends it to this '
        'endpoint (ADR-0017 D8) — now falls through to the generic '
        'unknown_error code instead of rendering internal field names on '
        'screen if it ever somehow arrived', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        _dioError(
          422,
          data: {
            'detail': [
              {
                'type': 'string_too_short',
                'loc': ['body', 'id_token'],
                'msg': 'String should have at least 1 character',
              },
            ],
          },
        ),
      );

      expect(
        () => dataSource.firebaseLogin(''),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', 'unknown_error')
              // ADR-0017 Amendment 1 A1-D6 — no branch that falls through to
              // this generic code may carry a displayMessage; there is no
              // envelope here at all (just the un-recognized {detail: [...]}
              // shape), so nothing safe to show exists.
              .having((e) => e.displayMessage, 'displayMessage', isNull),
        ),
      );
    });

    test('a non-DioException failure (a 200 response with no body, so '
        "response.data! hits null) still reaches the caller as an "
        'AuthException with a fixed code (ADR-0017 D6 — never composed from '
        "the object's Dart type), not a raw TypeError with nothing to show "
        'on screen', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: null,
          requestOptions: RequestOptions(path: '/'),
        ),
      );

      expect(
        () => dataSource.firebaseLogin('x'),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', 'backend_guard_unexpected')
              .having((e) => e.debugDetail, 'debugDetail', isNotNull)
              // ADR-0017 Amendment 1 A1-D6 — this is a bare TypeError from
              // `response.data!`, never a backend envelope; nothing here is
              // safe to show on screen.
              .having((e) => e.displayMessage, 'displayMessage', isNull),
        ),
      );
    });

    test("the envelope's `details` reaches debugDetail, never displayMessage "
        '(ADR-0017 Amendment 1 AC-10) — the two must never collapse into the '
        'same value even when a single envelope carries both', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        _dioError(
          422,
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

      try {
        await dataSource.firebaseLogin('');
        fail('expected an AuthException');
      } on AuthException catch (e) {
        expect(e.displayMessage, 'ข้อมูลไม่ถูกต้อง');
        expect(e.debugDetail, isNotNull);
        expect(e.debugDetail, isNot(e.displayMessage));
        expect(e.debugDetail, contains('id_token'));
      }
    });
  });

  group('getMe', () {
    test('sends the Bearer header to /auth/me and parses the user', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _resp({
          'id': 'u1',
          'email': 'a@b.com',
          'phone': null,
          'is_verified': true,
          'created_at': '2024-01-01T00:00:00Z',
        }),
      );

      final user = await dataSource.getMe('access-1');

      expect(user.id, 'u1');
      expect(user.toEntity().email, 'a@b.com');
      final captured = verify(
        () => dio.get<Map<String, dynamic>>(
          captureAny(),
          options: captureAny(named: 'options'),
        ),
      ).captured;
      expect(captured[0], '/api/v1/auth/me');
      expect(
        (captured[1] as Options).headers?['Authorization'],
        'Bearer access-1',
      );
    });

    test('parses a phone-only user whose email is null — the backend genuinely '
        'sends `"email": null` for a signup with no email claim on the '
        'Firebase token, and this used to crash BackendUser.fromJson with a '
        "bare TypeError ('Null' is not a subtype of 'String') the moment a "
        'phone-only user hit this endpoint', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _resp({
          'id': 'u2',
          'email': null,
          'phone': '+66949948249',
          'is_verified': true,
          'created_at': '2024-01-01T00:00:00Z',
        }),
      );

      final user = await dataSource.getMe('access-2');

      expect(user.email, isNull);
      expect(user.phone, '+66949948249');
      expect(user.toEntity().email, isNull);
    });

    test('surfaces the backend UNAUTHORIZED envelope', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        _dioError(
          401,
          data: {'error_code': 'UNAUTHORIZED', 'message': 'กรุณาเข้าสู่ระบบ'},
        ),
      );

      expect(
        () => dataSource.getMe('expired'),
        throwsA(
          isA<AuthException>().having((e) => e.code, 'code', 'UNAUTHORIZED'),
        ),
      );
    });
  });

  group('refresh', () {
    test('POSTs the refresh_token to /auth/refresh', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _resp({'access_token': 'a2', 'refresh_token': 'r2'}),
      );

      final result = await dataSource.refresh('r1');

      expect(result.accessToken, 'a2');
      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;
      expect(captured[0], '/api/v1/auth/refresh');
      expect(captured[1], {'refresh_token': 'r1'});
    });
  });

  group('logout', () {
    test('POSTs the refresh_token to /auth/logout with skipAuth set', () async {
      when(
        () => dio.post<void>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => _voidResp());

      await dataSource.logout('r1');

      final captured = verify(
        () => dio.post<void>(
          captureAny(),
          data: captureAny(named: 'data'),
          options: captureAny(named: 'options'),
        ),
      ).captured;
      expect(captured[0], '/api/v1/auth/logout');
      expect(captured[1], {'refresh_token': 'r1'});
      expect((captured[2] as Options).extra?['skipAuth'], isTrue);
    });

    test('maps a transport failure to code network_error', () async {
      when(
        () => dio.post<void>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(_dioNoResponse());

      expect(
        () => dataSource.logout('r1'),
        throwsA(
          isA<AuthException>().having((e) => e.code, 'code', 'network_error'),
        ),
      );
    });
  });
}
