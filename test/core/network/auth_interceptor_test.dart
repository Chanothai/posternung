import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/network/auth_interceptor.dart';
import 'package:posternung/core/network/token_storage.dart';

class MockTokenStorage extends Mock implements TokenStorage {}

class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

ResponseBody _jsonBody(Map<String, dynamic> data, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  late MockTokenStorage storage;
  late MockHttpClientAdapter mainAdapter;
  late MockHttpClientAdapter refreshAdapter;
  late Dio dio;
  late Dio refreshClient;
  late int sessionExpiredCalls;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
  });

  setUp(() {
    storage = MockTokenStorage();
    mainAdapter = MockHttpClientAdapter();
    refreshAdapter = MockHttpClientAdapter();
    sessionExpiredCalls = 0;

    refreshClient = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = refreshAdapter;

    dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = mainAdapter
      ..interceptors.add(
        AuthInterceptor(
          storage: storage,
          refreshClient: refreshClient,
          refreshPath: '/auth/refresh',
          onSessionExpired: () => sessionExpiredCalls++,
        ),
      );
  });

  Future<ResponseBody> Function(Invocation) answerWith(ResponseBody body) =>
      (_) async => body;

  group('onRequest', () {
    test(
      'attaches Bearer from storage when no header is already set',
      () async {
        when(() => storage.readAccessToken()).thenAnswer((_) async => 'tok-1');
        when(
          () => mainAdapter.fetch(any(), any(), any()),
        ).thenAnswer(answerWith(_jsonBody({'ok': 'true'}, 200)));

        await dio.get<void>('/posters');

        final captured = verify(
          () => mainAdapter.fetch(captureAny(), any(), any()),
        ).captured;
        final sent = captured.single as RequestOptions;
        expect(sent.headers['Authorization'], 'Bearer tok-1');
      },
    );

    test('does not overwrite a pre-set Authorization header', () async {
      // storage.readAccessToken() deliberately NOT stubbed to answer — if
      // onRequest called it, the test would throw on the missing stub.
      when(
        () => mainAdapter.fetch(any(), any(), any()),
      ).thenAnswer(answerWith(_jsonBody({'ok': 'true'}, 200)));

      await dio.get<void>(
        '/auth/me',
        options: Options(headers: {'Authorization': 'Bearer manual-token'}),
      );

      final captured = verify(
        () => mainAdapter.fetch(captureAny(), any(), any()),
      ).captured;
      final sent = captured.single as RequestOptions;
      expect(sent.headers['Authorization'], 'Bearer manual-token');
      verifyNever(() => storage.readAccessToken());
    });

    test('skips attaching a token when skipAuth is set', () async {
      when(
        () => mainAdapter.fetch(any(), any(), any()),
      ).thenAnswer(answerWith(_jsonBody({'ok': 'true'}, 200)));

      await dio.post<void>(
        '/auth/firebase',
        options: Options(extra: {'skipAuth': true}),
      );

      final captured = verify(
        () => mainAdapter.fetch(captureAny(), any(), any()),
      ).captured;
      final sent = captured.single as RequestOptions;
      expect(sent.headers.containsKey('Authorization'), isFalse);
      verifyNever(() => storage.readAccessToken());
    });
  });

  group('onError — 401 refresh + retry', () {
    test('refreshes once, retries the original request, and the caller sees '
        'the retried response', () async {
      when(
        () => storage.readAccessToken(),
      ).thenAnswer((_) async => 'expired-token');
      when(
        () => storage.readRefreshToken(),
      ).thenAnswer((_) async => 'refresh-token');
      when(
        () => storage.save(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mainAdapter.fetch(any(), any(), any()),
      ).thenAnswer(answerWith(_jsonBody({'error': 'unauthorized'}, 401)));
      when(() => refreshAdapter.fetch(any(), any(), any())).thenAnswer((
        invocation,
      ) async {
        final options = invocation.positionalArguments[0] as RequestOptions;
        if (options.path == '/auth/refresh') {
          return _jsonBody({
            'access_token': 'fresh-token',
            'refresh_token': 'new-refresh-token',
          }, 200);
        }
        // The retried original request.
        return _jsonBody({'poster': 'ok'}, 200);
      });

      final response = await dio.get<void>('/posters');

      expect(response.statusCode, 200);
      verify(
        () => storage.save(
          accessToken: 'fresh-token',
          refreshToken: 'new-refresh-token',
        ),
      ).called(1);

      final retried = verify(
        () => refreshAdapter.fetch(captureAny(), any(), any()),
      ).captured;
      final retryOptions =
          retried.firstWhere(
                (o) => (o as RequestOptions).path != '/auth/refresh',
              )
              as RequestOptions;
      expect(retryOptions.headers['Authorization'], 'Bearer fresh-token');
    });

    test('three concurrent 401s hit /auth/refresh exactly once and all '
        'three retries succeed', () async {
      // A real (in-memory) keychain would reflect request 1's save() by
      // the time requests 2/3 read it — a fixed stub wouldn't, since it
      // ignores save() entirely. Back it with a variable so the
      // interceptor's "did someone already refresh?" check in onError has
      // something real to compare against.
      var currentAccessToken = 'expired-token';
      when(
        () => storage.readAccessToken(),
      ).thenAnswer((_) async => currentAccessToken);
      when(
        () => storage.readRefreshToken(),
      ).thenAnswer((_) async => 'refresh-token');
      when(
        () => storage.save(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ),
      ).thenAnswer((invocation) async {
        currentAccessToken = invocation.namedArguments[#accessToken] as String;
      });

      // A fresh ResponseBody per call — each carries a single-subscription
      // Stream, so reusing one instance across the 3 concurrent requests
      // would throw "Stream has already been listened to" on the 2nd/3rd.
      when(
        () => mainAdapter.fetch(any(), any(), any()),
      ).thenAnswer((_) async => _jsonBody({'error': 'unauthorized'}, 401));

      var refreshCallCount = 0;
      when(() => refreshAdapter.fetch(any(), any(), any())).thenAnswer((
        invocation,
      ) async {
        final options = invocation.positionalArguments[0] as RequestOptions;
        if (options.path == '/auth/refresh') {
          refreshCallCount++;
          return _jsonBody({
            'access_token': 'fresh-token',
            'refresh_token': 'new-refresh-token',
          }, 200);
        }
        return _jsonBody({'poster': 'ok'}, 200);
      });

      final results = await Future.wait([
        dio.get<void>('/posters/1'),
        dio.get<void>('/posters/2'),
        dio.get<void>('/posters/3'),
      ]);

      expect(results.every((r) => r.statusCode == 200), isTrue);
      expect(
        refreshCallCount,
        1,
        reason:
            'the queued error interceptor must serialize the 3 concurrent '
            '401s so only the first one actually calls /auth/refresh',
      );
    });

    test('refresh failing clears storage, marks the session expired, and the '
        'original error still propagates', () async {
      when(
        () => storage.readAccessToken(),
      ).thenAnswer((_) async => 'expired-token');
      when(
        () => storage.readRefreshToken(),
      ).thenAnswer((_) async => 'refresh-token');
      when(() => storage.clear()).thenAnswer((_) async {});

      when(
        () => mainAdapter.fetch(any(), any(), any()),
      ).thenAnswer(answerWith(_jsonBody({'error': 'unauthorized'}, 401)));
      when(() => refreshAdapter.fetch(any(), any(), any())).thenAnswer(
        (_) async => _jsonBody({'error': 'invalid_refresh_token'}, 401),
      );

      await expectLater(
        dio.get<void>('/posters'),
        throwsA(isA<DioException>()),
      );

      verify(() => storage.clear()).called(1);
      expect(sessionExpiredCalls, 1);
    });

    test(
      'no refresh token stored: clears session without calling refresh',
      () async {
        when(
          () => storage.readAccessToken(),
        ).thenAnswer((_) async => 'expired-token');
        when(() => storage.readRefreshToken()).thenAnswer((_) async => null);
        when(() => storage.clear()).thenAnswer((_) async {});

        when(
          () => mainAdapter.fetch(any(), any(), any()),
        ).thenAnswer(answerWith(_jsonBody({'error': 'unauthorized'}, 401)));

        await expectLater(
          dio.get<void>('/posters'),
          throwsA(isA<DioException>()),
        );

        verify(() => storage.clear()).called(1);
        expect(sessionExpiredCalls, 1);
        verifyNever(() => refreshAdapter.fetch(any(), any(), any()));
      },
    );
  });
}
