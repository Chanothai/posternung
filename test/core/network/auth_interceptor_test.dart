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

  /// Runs `dio.get('/posters')` and returns the [DioException] it throws —
  /// every `onError` test below needs the thrown exception itself, not just
  /// `throwsA(isA<DioException>())`, to assert on its status/type/requestOptions.
  Future<DioException> captureError() async {
    try {
      await dio.get<void>('/posters');
    } on DioException catch (e) {
      return e;
    }
    fail('expected dio.get to throw a DioException');
  }

  void stubExpiredAccessTokenAndRefreshToken() {
    when(
      () => storage.readAccessToken(),
    ).thenAnswer((_) async => 'expired-token');
    when(
      () => storage.readRefreshToken(),
    ).thenAnswer((_) async => 'refresh-token');
  }

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
      stubExpiredAccessTokenAndRefreshToken();
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

    test('refresh answering 401 clears storage, marks the session expired, '
        'and the *original* 401 still propagates (test #6)', () async {
      stubExpiredAccessTokenAndRefreshToken();
      when(() => storage.clear()).thenAnswer((_) async {});

      when(
        () => mainAdapter.fetch(any(), any(), any()),
      ).thenAnswer(answerWith(_jsonBody({'error': 'unauthorized'}, 401)));
      when(() => refreshAdapter.fetch(any(), any(), any())).thenAnswer(
        (_) async => _jsonBody({'error': 'invalid_refresh_token'}, 401),
      );

      final error = await captureError();

      verify(() => storage.clear()).called(1);
      expect(sessionExpiredCalls, 1);
      // The error that reaches the caller must be the *original* 401 on
      // '/posters' — not the refresh call's own error (AC-3).
      expect(error.requestOptions.path, '/posters');
      expect(error.response?.statusCode, 401);
    });

    test('code-critic M10 — refresh answering 422 (any other 4xx, not just '
        '401) also clears storage, marks the session expired, and the '
        '*original* 401 still propagates — same as the refresh-401 case '
        'above, just a different rejected status', () async {
      stubExpiredAccessTokenAndRefreshToken();
      when(() => storage.clear()).thenAnswer((_) async {});

      when(
        () => mainAdapter.fetch(any(), any(), any()),
      ).thenAnswer(answerWith(_jsonBody({'error': 'unauthorized'}, 401)));
      when(() => refreshAdapter.fetch(any(), any(), any())).thenAnswer(
        (_) async => _jsonBody({'error': 'invalid_refresh_token'}, 422),
      );

      final error = await captureError();

      verify(() => storage.clear()).called(1);
      expect(sessionExpiredCalls, 1);
      expect(error.requestOptions.path, '/posters');
      expect(error.response?.statusCode, 401);
    });

    test('no refresh token stored: clears session without calling refresh, and '
        'the *original* 401 propagates (test #6)', () async {
      when(
        () => storage.readAccessToken(),
      ).thenAnswer((_) async => 'expired-token');
      when(() => storage.readRefreshToken()).thenAnswer((_) async => null);
      when(() => storage.clear()).thenAnswer((_) async {});

      when(
        () => mainAdapter.fetch(any(), any(), any()),
      ).thenAnswer(answerWith(_jsonBody({'error': 'unauthorized'}, 401)));

      final error = await captureError();

      verify(() => storage.clear()).called(1);
      expect(sessionExpiredCalls, 1);
      verifyNever(() => refreshAdapter.fetch(any(), any(), any()));
      expect(error.requestOptions.path, '/posters');
      expect(error.response?.statusCode, 401);
    });

    test(
      '🔴 INF-45 test #1 (mandatory) — refresh 200 then retry 409 (a normal '
      'business error, e.g. BUYER_HAS_LIVE_ORDER) must NOT be treated as a '
      'dead session: the fresh token is kept, no clear, no session-expiry',
      () async {
        stubExpiredAccessTokenAndRefreshToken();
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
          return _jsonBody({
            'error_code': 'BUYER_HAS_LIVE_ORDER',
            'message': 'มีคำสั่งซื้อค้างอยู่แล้ว',
          }, 409);
        });

        final error = await captureError();

        expect(error.response?.statusCode, 409);
        verify(
          () => storage.save(
            accessToken: 'fresh-token',
            refreshToken: 'new-refresh-token',
          ),
        ).called(1);
        verifyNever(() => storage.clear());
        expect(sessionExpiredCalls, 0);
      },
    );

    test('code-critic M9 — refresh 200 then retry 500 must NOT be treated as a '
        'dead session either: same shape as the 409 test above but for a '
        'server error on the retry, not a business 4xx', () async {
      stubExpiredAccessTokenAndRefreshToken();
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
        return _jsonBody({'error': 'internal'}, 500);
      });

      final error = await captureError();

      expect(error.response?.statusCode, 500);
      verify(
        () => storage.save(
          accessToken: 'fresh-token',
          refreshToken: 'new-refresh-token',
        ),
      ).called(1);
      verifyNever(() => storage.clear());
      expect(sessionExpiredCalls, 0);
    });

    test(
      '🔴 INF-45 test #2 (mandatory) — refresh 200 then retry 401 again IS a '
      'dead session: clears storage, marks expired, and the error that '
      'propagates is the *retry\'s* (extra[retried] == true), not the '
      'original 401',
      () async {
        stubExpiredAccessTokenAndRefreshToken();
        when(
          () => storage.save(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ),
        ).thenAnswer((_) async {});
        when(() => storage.clear()).thenAnswer((_) async {});

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
          return _jsonBody({'error': 'unauthorized'}, 401);
        });

        final error = await captureError();

        verify(() => storage.clear()).called(1);
        expect(sessionExpiredCalls, 1);
        expect(error.response?.statusCode, 401);
        expect(
          error.requestOptions.extra['retried'],
          isTrue,
          reason:
              'the propagated error must be the retry\'s own, not the '
              'original request\'s (which never set this flag)',
        );
      },
    );

    test('INF-45 test #3 — refresh call itself times out: no clear, no '
        'session-expiry, the propagated error has no response and is the '
        'connection-timeout', () async {
      stubExpiredAccessTokenAndRefreshToken();
      when(
        () => mainAdapter.fetch(any(), any(), any()),
      ).thenAnswer(answerWith(_jsonBody({'error': 'unauthorized'}, 401)));
      when(() => refreshAdapter.fetch(any(), any(), any())).thenAnswer((
        invocation,
      ) async {
        final options = invocation.positionalArguments[0] as RequestOptions;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );
      });

      final error = await captureError();

      verifyNever(() => storage.clear());
      expect(sessionExpiredCalls, 0);
      expect(error.response, isNull);
      expect(error.type, DioExceptionType.connectionTimeout);
    });

    test('INF-45 test #4 — refresh call answers 500: no clear, no '
        'session-expiry, the propagated error carries the 500', () async {
      stubExpiredAccessTokenAndRefreshToken();
      when(
        () => mainAdapter.fetch(any(), any(), any()),
      ).thenAnswer(answerWith(_jsonBody({'error': 'unauthorized'}, 401)));
      when(
        () => refreshAdapter.fetch(any(), any(), any()),
      ).thenAnswer((_) async => _jsonBody({'error': 'internal'}, 500));

      final error = await captureError();

      verifyNever(() => storage.clear());
      expect(sessionExpiredCalls, 0);
      expect(error.response?.statusCode, 500);
    });

    test('INF-45 test #5 — refresh succeeds but the retry itself hits a '
        'connection error: no clear, no session-expiry, fresh token still '
        'saved', () async {
      stubExpiredAccessTokenAndRefreshToken();
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
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });

      final error = await captureError();

      verifyNever(() => storage.clear());
      expect(sessionExpiredCalls, 0);
      expect(error.type, DioExceptionType.connectionError);
      verify(
        () => storage.save(
          accessToken: 'fresh-token',
          refreshToken: 'new-refresh-token',
        ),
      ).called(1);
    });
  });
}
