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
          () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
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
          ),
        ).captured;
        expect(captured[0], '/api/v1/auth/firebase');
        expect(captured[1], {'id_token': 'id-tok'});
      },
    );

    test('surfaces the backend {error_code, message} envelope', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
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
                (e) => e.message,
                'message',
                'ไม่สามารถยืนยันตัวตนกับ Google ได้ กรุณาลองใหม่',
              ),
        ),
      );
    });

    test('maps a no-response failure to code network_error', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
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
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(_dioError(502));

      expect(
        () => dataSource.firebaseLogin('x'),
        throwsA(
          isA<AuthException>().having((e) => e.code, 'code', 'server_error'),
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
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => _resp({'access_token': 'a2', 'refresh_token': 'r2'}),
      );

      final result = await dataSource.refresh('r1');

      expect(result.accessToken, 'a2');
      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured[0], '/api/v1/auth/refresh');
      expect(captured[1], {'refresh_token': 'r1'});
    });
  });
}
