import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/diagnostics/startup_trace.dart';
import 'package:posternung/core/network/api_client.dart';
import 'package:posternung/core/network/auth_interceptor.dart';
import 'package:posternung/core/network/session_expiry.dart';
import 'package:posternung/core/network/token_storage.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/core/theme/app_theme.dart';
import 'package:posternung/features/auth/data/datasources/backend_auth_data_source.dart';
import 'package:posternung/features/auth/data/models/backend_user.dart';
import 'package:posternung/features/auth/presentation/providers/backend_session_provider.dart';
import 'package:posternung/features/auth/presentation/providers/session_provider.dart';
import 'package:posternung/features/poster/domain/entities/poster_detail.dart';
import 'package:posternung/features/poster/domain/entities/poster_status.dart';
import 'package:posternung/features/poster/domain/repositories/poster_repository.dart';
import 'package:posternung/features/poster/presentation/providers/poster_providers.dart';
import 'package:posternung/features/poster/presentation/widgets/poster_buy_now_button.dart';

import '../../../../support/in_memory_token_storage.dart';

class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

class MockBackendAuthDataSource extends Mock implements BackendAuthDataSource {}

class MockPosterRepository extends Mock implements PosterRepository {}

ResponseBody _jsonBody(Map<String, dynamic> data, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// Must match `BackendAuthDataSourceImpl._refresh` / `api_client.dart`'s
/// `_refreshPath` — duplicated literally, same reason both of those do:
/// `core/` cannot import `features/auth/`, and this test file cannot import
/// either private constant.
const _refreshPath = '/api/v1/auth/refresh';

PosterDetail _poster({
  PosterStatus status = PosterStatus.available,
  String id = 'p1',
}) => PosterDetail(
  id: id,
  title: 'Blade Runner',
  price: '450.00',
  status: status,
  conditionGrade: null,
  eraDecade: 1980,
  studio: 'Warner Bros',
  primaryImageUrl: null,
  tmdbId: null,
  size: null,
  description: null,
  isAuthenticated: true,
  authenticityNote: null,
  provenance: null,
  images: const [],
  createdAt: DateTime.utc(2024),
  posterType: null,
  releaseRegion: null,
  releaseDateText: null,
  releaseDate: null,
  copyrightYear: null,
  sizeFormat: null,
  year: null,
  restorationStatus: null,
  restorationNote: null,
);

BackendUser _user() => BackendUser(
  id: 'u1',
  email: 'a@b.com',
  phone: null,
  isVerified: true,
  createdAt: DateTime(2024),
);

/// AC-4 of `INF-45` — 401 → refresh 200 → retry 409 `BUYER_HAS_LIVE_ORDER`
/// end to end, through the **real** `AuthInterceptor`, the **real**
/// `checkoutRepositoryProvider` chain, and the **real** `backendSessionProvider`
/// — not a mocked `CheckoutRepository`. That is the whole point: a mocked
/// repository can never exercise `AuthInterceptor`'s onError branch at all,
/// which is exactly the branch `INF-45`'s bug (and fix) live in.
///
/// `sessionProvider`/`backendSessionProvider` are deliberately **not**
/// overridden — asserting the button's error notice alone would not prove
/// the bug is fixed, since the pre-fix defect's whole symptom is a session
/// that silently dies *behind* the button, not a wrong message on it. The
/// only way to see that is to let the real session notifier run and check
/// its state after.
///
/// No route/`AuthGate` involved here on purpose: `/poster/:id` sits *outside*
/// `AuthGate` (GATE 1 §1 of `INF-45-gate1.md` — `PosterDetailScreen` is
/// reachable from a bottom-nav tab that is itself behind `AuthGate` higher
/// up the tree, but nothing on this screen re-checks session on every
/// rebuild). "Got kicked to login" in the real incident this ticket fixes
/// was never a navigation this button caused — it was `sessionProvider`
/// silently going to `AsyncData(null)`, which only shows up the *next* time
/// something reads it. So the assertions below check `sessionProvider`'s
/// state directly, not `find.byType(LoginScreen)`.
void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
  });

  tearDown(StartupTrace.debugReset);

  late InMemoryTokenStorage storage;
  late MockHttpClientAdapter mainAdapter;
  late MockHttpClientAdapter refreshAdapter;
  late MockBackendAuthDataSource backendAuth;
  late MockPosterRepository posterRepository;
  late List<String> traceLines;

  setUp(() {
    storage = InMemoryTokenStorage(
      accessToken: 'seed-access',
      refreshToken: 'seed-refresh',
    );
    mainAdapter = MockHttpClientAdapter();
    refreshAdapter = MockHttpClientAdapter();
    backendAuth = MockBackendAuthDataSource();
    posterRepository = MockPosterRepository();
    traceLines = [];
    StartupTrace.debugSink = traceLines.add;

    when(() => backendAuth.getMe(any())).thenAnswer((_) async => _user());
  });

  ProviderScope buildApp() {
    return ProviderScope(
      overrides: [
        // The whole point of this test — the real Dio + AuthInterceptor +
        // mock transport, same shape as `api_client.dart:48-56`'s
        // `dioProvider`, not a mocked `CheckoutRepository`.
        dioProvider.overrideWith((ref) {
          final refreshClient = Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = refreshAdapter;
          final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = mainAdapter;
          dio.interceptors.add(
            AuthInterceptor(
              storage: ref.watch(tokenStorageProvider),
              refreshClient: refreshClient,
              refreshPath: _refreshPath,
              onSessionExpired: () =>
                  ref.read(sessionExpiryProvider.notifier).markExpired(),
            ),
          );
          return dio;
        }),
        tokenStorageProvider.overrideWithValue(storage),
        backendAuthDataSourceProvider.overrideWithValue(backendAuth),
        posterRepositoryProvider.overrideWithValue(posterRepository),
        // checkoutRepositoryProvider deliberately NOT overridden — it must
        // run for real, on top of the overridden dioProvider above.
        // sessionProvider/backendSessionProvider deliberately NOT
        // overridden either — see the file doc comment.
      ],
      child: MaterialApp(
        // `test-quality`/CLAUDE.md §Testing — widget tests run under the
        // app's real theme, since a screen's rendered decoration can differ
        // from `ThemeData`'s bare default (SCR-07 B9's `InputDecorationTheme`
        // incident). This test doesn't assert on colors itself, but nothing
        // here rules out a future change to `AppTheme` silently altering
        // what `PosterBuyNowButton`/`_LiveOrderNotice` render, so it stays
        // consistent with every other screen-level test rather than being a
        // themeless exception.
        theme: AppTheme.dark(),
        home: Scaffold(body: PosterBuyNowButton(poster: _poster())),
      ),
    );
  }

  testWidgets('INF-45 AC-4 — 401 on reserve, refresh 200, retry 409 '
      'BUYER_HAS_LIVE_ORDER: shows the live-order notice and leaves the '
      'session, tokens, and expiry counter untouched. 🔴 mutation-locking: '
      'reverting AuthInterceptor to one combined catch around refresh+retry '
      'turns this red (session goes to null)', (tester) async {
    when(
      () => mainAdapter.fetch(any(), any(), any()),
    ).thenAnswer((_) async => _jsonBody({'error': 'unauthorized'}, 401));
    when(() => refreshAdapter.fetch(any(), any(), any())).thenAnswer((
      invocation,
    ) async {
      final options = invocation.positionalArguments[0] as RequestOptions;
      if (options.path == _refreshPath) {
        return _jsonBody({
          'access_token': 'fresh-token',
          'refresh_token': 'new-refresh-token',
        }, 200);
      }
      // The retried reserve call.
      return _jsonBody({
        'error_code': 'BUYER_HAS_LIVE_ORDER',
        'message': 'มีคำสั่งซื้อค้างอยู่แล้ว',
        'details': [
          {'field': 'order_no', 'message': 'PN-260916-0001'},
        ],
      }, 409);
    });

    await tester.pumpWidget(buildApp());
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
      listen: false,
    );

    // Establish the session with the *seed* tokens first — same as a real
    // cold start — before the reserve tap rotates them via the
    // interceptor. This is what lets the post-tap assertions tell "the
    // session held" apart from "a session was never built at all".
    final initialUser = await container.read(backendSessionProvider.future);
    expect(initialUser?.uid, 'u1');

    expect(find.text(AppStrings.posterDetailBuyNowButtonLabel), findsOneWidget);
    await tester.tap(find.text(AppStrings.posterDetailBuyNowButtonLabel));
    await tester.pumpAndSettle();

    // The 409 notice is shown, with the order number from `details[]`.
    expect(
      find.text(AppStrings.checkoutErrorBuyerHasLiveOrder('PN-260916-0001')),
      findsOneWidget,
    );
    // The button itself is gone (replaced by the notice — same widget
    // slot, `PosterBuyNowButton.build`'s early return).
    expect(find.text(AppStrings.posterDetailBuyNowButtonLabel), findsNothing);
    // Negative — no trace of a 401/session-dead reading anywhere on
    // screen: neither the raw status, nor the generic-failure fallback
    // text a cleared session would show instead of the 409 notice.
    expect(find.textContaining('401'), findsNothing);
    expect(find.text(AppStrings.authErrorServer), findsNothing);

    // The session itself must still be the signed-in user.
    final AsyncValue<dynamic> session = container.read(sessionProvider);
    expect(session.hasValue, isTrue);
    expect(session.value?.uid, 'u1');

    // The bug this fixes bumps this counter and clears storage.
    expect(container.read(sessionExpiryProvider), 0);
    expect(storage.cleared, isFalse);
    expect(storage.accessToken, 'fresh-token');
    expect(storage.refreshToken, 'new-refresh-token');

    expect(
      traceLines.any((l) => l.contains('session_expiry_fired')),
      isFalse,
      reason: 'got: $traceLines',
    );
  });
}
