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

DioException _dioError(int status, {Object? data}) => DioException(
  requestOptions: RequestOptions(path: '/'),
  response: Response(
    statusCode: status,
    data: data,
    requestOptions: RequestOptions(path: '/'),
  ),
);

DioException _dioNoResponse() =>
    DioException(requestOptions: RequestOptions(path: '/'));

void main() {
  late MockDio dio;
  late BackendAuthDataSourceImpl dataSource;

  setUpAll(() => registerFallbackValue(Options()));

  setUp(() {
    dio = MockDio();
    dataSource = BackendAuthDataSourceImpl(dio);
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
              ),
        ),
      );
    });

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
          isA<AuthException>().having((e) => e.code, 'code', 'network_error'),
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
          isA<AuthException>().having((e) => e.code, 'code', 'server_error'),
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
          isA<AuthException>().having((e) => e.code, 'code', 'unknown_error'),
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
              .having((e) => e.debugDetail, 'debugDetail', isNotNull),
        ),
      );
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
