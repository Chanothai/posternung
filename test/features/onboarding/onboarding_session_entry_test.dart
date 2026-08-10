import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/core/router/app_router.dart';
import 'package:posternung/core/network/token_storage.dart';
import 'package:posternung/core/router/app_routes.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/core/widgets/app_loading_screen.dart';
import 'package:posternung/features/auth/data/datasources/backend_auth_data_source.dart';
import 'package:posternung/features/auth/domain/entities/auth_user.dart';
import 'package:posternung/features/auth/presentation/providers/auth_providers.dart';
import 'package:posternung/features/auth/presentation/providers/backend_session_provider.dart';
import 'package:posternung/features/auth/presentation/providers/session_provider.dart';
import 'package:posternung/features/auth/presentation/screens/login_screen.dart';
import 'package:posternung/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:posternung/features/home/presentation/screens/home_screen.dart';
import 'package:posternung/features/onboarding/presentation/onboarding_entry_gate.dart';
import 'package:posternung/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:posternung/features/onboarding/presentation/screens/onboarding_page_view_screen.dart';
import 'package:posternung/features/poster/domain/entities/paginated_posters.dart';
import 'package:posternung/features/poster/domain/repositories/poster_repository.dart';
import 'package:posternung/features/poster/presentation/providers/poster_providers.dart';

import '../../support/router_harness.dart';

/// SCR-01 AC-3 as ADR-0023 D1 rewrote it: *a user with a usable session must
/// not be walked through onboarding when they open the app*.
///
/// Everything here navigates by **path string through the real route table**
/// (`appRoutes`), never `MaterialApp(home: X)` — ADR-0018 D9 / ADR-0023
/// §Consequences 5. A test that pumped the gate widget directly would stay
/// green if `/` still built the bare screen, which is precisely the bug being
/// closed.
///
/// `backendSessionProvider` is what gets faked rather than `sessionProvider`,
/// so the real alias in between is exercised too (ADR-0021 D1) — same choice
/// `auth_gate_test.dart`'s D1 regression group made.
///
/// **What this file cannot prove.** Cold start on a real device also depends
/// on `_restore()` reaching `flutter_secure_storage` and `GET /auth/me`,
/// neither of which exists under `flutter test`; the fakes below stand in for
/// both. That the *timing* of a real restore is short enough not to feel like
/// a hang is a `run-and-verify-on-device` question (`test-quality` §5).
void main() {
  const AuthUser signedIn = AuthUser(uid: 'u1', email: 'a@b.co');

  late _MockPosterRepository repository;
  late _InMemoryTokenStorage storage;
  late _MockBackendAuthDataSource backendAuth;

  setUp(() {
    repository = _MockPosterRepository();

    // Seeded, because that is what a cold start that has anything to restore
    // looks like. It matters that this is a real, observable store rather
    // than a `signOut()` the fake notifier stubs out: the worst thing a wrong
    // deadline could do is wipe these two values, and a fixture that cannot
    // show that happening cannot fail when it does (`test-quality` §6).
    storage = _InMemoryTokenStorage(
      accessToken: 'stored-access',
      refreshToken: 'stored-refresh',
    );
    backendAuth = _MockBackendAuthDataSource();
    when(() => backendAuth.logout(any())).thenAnswer((_) async {});
    when(
      () => repository.listPosters(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer(
      (_) async =>
          const PaginatedPosters(items: [], total: 0, limit: 20, offset: 0),
    );
  });

  // Return type left to inference: Riverpod 3 does not export `Override`, so
  // it cannot be written down (same note as `app_router_test.dart`'s helper).
  overrides(Future<AuthUser?> Function() session) => [
    backendSessionProvider.overrideWith(() => _FakeBackendSession(session)),
    // `LoginScreen` (what `AuthGate` renders at `/home` when signed out) and
    // `HomeScreen` would otherwise reach for Firebase and the network at
    // build time.
    authViewModelProvider.overrideWith(_NoopAuthViewModel.new),
    posterRepositoryProvider.overrideWithValue(repository),
    // Not stubbed away at the notifier: `BackendSessionNotifier.signOut()`
    // runs for real in this file, all the way down to `storage.clear()`.
    tokenStorageProvider.overrideWithValue(storage),
    backendAuthDataSourceProvider.overrideWithValue(backendAuth),
  ];

  /// Cold-starts the app at `/` over the real table, exactly as `main.dart`
  /// enters it.
  Future<(GoRouter, _ProviderInitProbe)> coldStart(
    WidgetTester tester,
    Future<AuthUser?> Function() session,
  ) async {
    final probe = _ProviderInitProbe();
    late GoRouter router;
    await tester.pumpWidget(
      ProviderScope(
        observers: <ProviderObserver>[probe],
        overrides: overrides(session),
        child: routedApp(
          location: AppRoutes.onboardingPath,
          routes: appRoutes,
          onRouter: (GoRouter r) => router = r,
        ),
      ),
    );
    return (router, probe);
  }

  testWidgets(
    'signed out — the intro is what a cold start at / shows, and the gate '
    'gets out of the way entirely (no spinner left behind)',
    (WidgetTester tester) async {
      final (GoRouter router, _ProviderInitProbe probe) = await coldStart(
        tester,
        () async => null,
      );
      // Two zero-length frames, not `pumpAndSettle`: a user with no stored
      // token gets the intro on the spot, not after the D8 deadline. The
      // clock here has advanced by nothing at all, so a gate that waited on
      // the timer would still be showing the spinner.
      await tester.pump();
      await tester.pump();

      expect(find.byType(OnboardingPageViewScreen), findsOneWidget);
      expect(find.byType(AppLoadingScreen), findsNothing);
      expect(router.state.uri.toString(), AppRoutes.onboardingPath);

      // Harness self-check, not a claim about the app: this is the probe the
      // "never built" assertions below depend on, and a probe that never
      // fires would make every one of them pass for free.
      expect(
        probe.initialised,
        contains(onboardingControllerProvider),
        reason:
            'the probe did not see onboarding being built even though the '
            'screen is on screen — the negative assertions elsewhere in this '
            'file would then be vacuous',
      );
    },
  );

  testWidgets(
    'signed in — a restored session goes to /home and the intro is never '
    'built at all, not merely gone by the time the frames settle',
    (WidgetTester tester) async {
      final (GoRouter router, _ProviderInitProbe probe) = await coldStart(
        tester,
        () async => signedIn,
      );
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), AppRoutes.homePath);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(OnboardingPageViewScreen), findsNothing);
      expect(
        probe.initialised,
        isNot(contains(onboardingControllerProvider)),
        reason:
            'onboarding was constructed on the way past — that is the flash '
            'AC-3 is about, and it survives a findsNothing at the end',
      );
    },
  );

  testWidgets(
    'restoring — every frame while the session is still unknown shows the '
    'loading screen and no intro, so a signed-in user gets no flash of '
    'onboarding on a slow /auth/me (ADR-0023 D4)',
    (WidgetTester tester) async {
      final Completer<AuthUser?> restore = Completer<AuthUser?>();
      final (GoRouter router, _ProviderInitProbe probe) = await coldStart(
        tester,
        () => restore.future,
      );

      // Deliberately frame by frame rather than `pumpAndSettle`: settling
      // runs the frames without looking at them, which is exactly how a
      // one-frame flash gets missed.
      for (int frame = 0; frame < 10; frame++) {
        expect(
          find.byType(OnboardingPageViewScreen),
          findsNothing,
          reason: 'the intro was on screen at frame $frame, still restoring',
        );
        expect(find.byType(AppLoadingScreen), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 16));
      }

      restore.complete(signedIn);
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), AppRoutes.homePath);
      expect(
        probe.initialised,
        isNot(contains(onboardingControllerProvider)),
        reason: 'the intro was built at some point during the restore',
      );
    },
  );

  testWidgets(
    'still undecided at the deadline — the gate stops waiting and opens the '
    'intro, and it does so at 2 s: still a spinner just before, gone just '
    'after (ADR-0023 D8)',
    (WidgetTester tester) async {
      // 2 s is the decided number (ADR-0023 D8), so it is written here as a
      // literal and checked against the code — not read out of the code and
      // handed back to it, which would let any value at all pass.
      expect(
        OnboardingEntryGate.sessionDeadline,
        const Duration(seconds: 2),
        reason: 'D8 decided 2 s; changing it is an ADR amendment, not an edit',
      );

      // No real sleeping anywhere: `testWidgets` already runs in fake async,
      // so `pump(Duration)` moves the clock the gate's `Timer` reads (D8.3).
      final Completer<AuthUser?> undecided = Completer<AuthUser?>();
      final (GoRouter router, _) = await coldStart(
        tester,
        () => undecided.future,
      );

      await tester.pump(const Duration(milliseconds: 1900));
      expect(
        find.byType(AppLoadingScreen),
        findsOneWidget,
        reason: 'the gate gave up before its own deadline',
      );
      expect(find.byType(OnboardingPageViewScreen), findsNothing);

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(OnboardingPageViewScreen), findsOneWidget);
      expect(
        find.byType(AppLoadingScreen),
        findsNothing,
        reason:
            'still spinning after the deadline — the user is stuck, '
            'which is the whole failure D8 was added to stop',
      );
      expect(router.state.uri.toString(), AppRoutes.onboardingPath);
    },
  );

  testWidgets(
    'a valid token that answers *after* the deadline — the user gets the '
    'intro rather than being yanked out of it, and that session is still '
    'honoured at /home: giving up on waiting is not giving up the session '
    '(ADR-0023 D8.2)',
    (WidgetTester tester) async {
      final Completer<AuthUser?> slowButValid = Completer<AuthUser?>();

      // Only the *first* restore is the slow-but-valid one. A second call
      // means something re-ran `build()` — `invalidate`, `refresh` — i.e. the
      // in-flight restore was thrown away, and on the network this test
      // models the retry has no answer either. Without this the fake would
      // hand the same already-resolving future back to whoever restarted it,
      // and a deadline that logged the user out would look identical to one
      // that merely stopped waiting.
      int restores = 0;
      Future<AuthUser?> restore() {
        restores++;
        if (restores > 1) return Completer<AuthUser?>().future;
        return slowButValid.future;
      }

      final ProviderContainer container = ProviderContainer.test(
        overrides: overrides(restore),
      );
      late GoRouter router;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: routedApp(
            location: AppRoutes.onboardingPath,
            routes: appRoutes,
            onRouter: (GoRouter r) => router = r,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 2100));
      expect(find.byType(OnboardingPageViewScreen), findsOneWidget);

      // 🔴 These two go **here**, before the late answer arrives, and that
      // placement is the whole point. Once `slowButValid` completes, the
      // `build()` future that is still in flight publishes `signedIn` again —
      // so a deadline that had signed the user out a moment ago would look
      // perfectly healthy to any assertion made after this line. Asked at the
      // only moment it is answerable, the question is: at the deadline, did
      // anything decide the session instead of merely not waiting for it?
      expect(
        container.read(sessionProvider).isLoading,
        isTrue,
        reason:
            'the session was decided at the deadline — the gate ended it '
            '(signOut/invalidate) rather than leaving the restore alone',
      );
      expect(
        storage.cleared,
        isFalse,
        reason:
            'the stored tokens were wiped at the deadline: a slow network '
            'became a logout, which is exactly what D8.2 forbids',
      );

      // The token was good all along — `/auth/me` was just slow.
      slowButValid.complete(signedIn);
      await tester.pumpAndSettle();

      // Half one: the late answer does not snatch the page away mid-read.
      expect(find.byType(OnboardingPageViewScreen), findsOneWidget);
      expect(router.state.uri.toString(), AppRoutes.onboardingPath);

      // Half two — the claim D8.2 actually makes. The restore was never
      // restarted or discarded at the deadline...
      expect(
        restores,
        1,
        reason:
            'the deadline re-ran the session restore instead of simply not '
            'waiting for the one already in flight',
      );
      expect(
        container.read(sessionProvider).value,
        signedIn,
        reason:
            'the deadline threw the session away instead of merely not '
            'waiting for it — that turns a slow network into a logout',
      );
      // ...and it is honoured for real on the way out, walked with the
      // screen's own CTA rather than a direct `go`.
      await tester.tap(find.text(AppStrings.onboardingNextButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.onboardingNextButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.onboardingGetStartedButton));
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), AppRoutes.homePath);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        find.byType(LoginScreen),
        findsNothing,
        reason:
            'the user was asked to sign in again with a session that was '
            'valid the whole time',
      );
    },
  );

  testWidgets(
    'a session that has failed for good — the intro, immediately, and not a '
    "word about the failure here (ADR-0023 D4: that message is AuthGate's)",
    (WidgetTester tester) async {
      // The one place in this file that overrides `sessionProvider` itself.
      // Riverpod 3 retries a failed provider on its own, so a notifier whose
      // `build()` throws sits in `AsyncLoading(hasError)` for the whole
      // ladder and `.when` never reaches `error:` — the next test covers
      // that road. Handing the gate a terminal `AsyncError` is the only way
      // to exercise this branch deterministically.
      late GoRouter router;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWithValue(
              AsyncError<AuthUser?>(
                const AuthException(code: 'network_error'),
                StackTrace.current,
              ),
            ),
            authViewModelProvider.overrideWith(_NoopAuthViewModel.new),
            posterRepositoryProvider.overrideWithValue(repository),
          ],
          child: routedApp(
            location: AppRoutes.onboardingPath,
            routes: appRoutes,
            onRouter: (GoRouter r) => router = r,
          ),
        ),
      );
      // Two zero-length frames: this is the `error:` branch doing the work,
      // not the deadline arriving 2 s later and covering for it.
      await tester.pump();
      await tester.pump();

      expect(find.byType(OnboardingPageViewScreen), findsOneWidget);
      expect(find.byType(AppLoadingScreen), findsNothing);
      expect(router.state.uri.toString(), AppRoutes.onboardingPath);

      // The intro is genuinely usable, not a husk: its CTA is on screen.
      expect(find.text(AppStrings.onboardingNextButton), findsOneWidget);

      // And the failure is not restated here. `AuthGate` at /home is the one
      // door for it (ADR-0017 / INF-20) — a banner or a code label appearing
      // on the intro would mean a second one had been opened.
      expect(find.byType(AuthErrorBanner), findsNothing);
      expect(find.text(AppStrings.authErrorNetwork), findsNothing);
      expect(
        _visibleText(tester).where((String t) => t.contains('network_error')),
        isEmpty,
        reason: 'a raw error code leaked onto the onboarding screen',
      );
    },
  );

  testWidgets(
    'a restore that keeps failing (offline) — Riverpod 3 retries it in the '
    'background, so the session never even reaches `error`: it stays '
    'undecided, and what gets the user in is the D8 deadline',
    (WidgetTester tester) async {
      final (GoRouter router, _) = await coldStart(
        tester,
        () async => throw const AuthException(code: 'network_error'),
      );

      await tester.pump(const Duration(milliseconds: 1900));
      expect(
        find.byType(AppLoadingScreen),
        findsOneWidget,
        reason:
            'this is the state the retry ladder actually leaves the app in — '
            'if it is no longer a spinner here, the shape this test is about '
            'has changed and the gate needs re-reading, not this number',
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(OnboardingPageViewScreen), findsOneWidget);
      expect(
        find.byType(AppLoadingScreen),
        findsNothing,
        reason:
            'the user is still watching a spinner with no network — the '
            'complaint D8 was added to answer',
      );
      expect(router.state.uri.toString(), AppRoutes.onboardingPath);
    },
  );

  testWidgets(
    'after signing out, the next launch shows the intro again — the answer '
    'is derived from the session with nothing persisted (ADR-0023 D2), so '
    'this is the decided behavior and a "seen onboarding" flag would break '
    'it here',
    (WidgetTester tester) async {
      // One container across both launches = one installed app. A flag stashed
      // anywhere that outlives a launch (a static, a provider kept alive, a
      // storage key) would still be there for the second pump below.
      final ProviderContainer container = ProviderContainer.test(
        overrides: overrides(() async => signedIn),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: routedApp(
            location: AppRoutes.onboardingPath,
            routes: appRoutes,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(HomeScreen),
        findsOneWidget,
        reason: 'the signed-in leg of this test never got past the gate',
      );

      await container.read(backendSessionProvider.notifier).signOut();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      // The real `signOut()` ran, not a stub — which is what makes
      // `storage.cleared` meaningful as a negative assertion in the D8.2
      // test above. If this ever stops being true, that one goes quiet.
      expect(
        storage.cleared,
        isTrue,
        reason: 'signing out left the tokens on the device',
      );

      // Relaunch: a new router over the same app.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: routedApp(
            location: AppRoutes.onboardingPath,
            routes: appRoutes,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingPageViewScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    },
  );
}

class _MockPosterRepository extends Mock implements PosterRepository {}

/// A stand-in for the real view model — `LoginScreen` reads
/// `authViewModelProvider` and the real one talks to Firebase at build time.
class _NoopAuthViewModel extends AuthViewModel {
  @override
  FutureOr<void> build() {}
}

/// The session the app restores at launch, standing in for the one thing
/// `flutter_test` cannot run: `flutter_secure_storage` plus `GET /auth/me`.
///
/// 🔴 **Only `build` is faked.** `signOut()` deliberately is not — it is the
/// method a mis-written deadline would reach for, so it has to be the real
/// one, clearing the real (in-memory) `TokenStorage`, or the test cannot tell
/// "stopped waiting" from "signed the user out".
class _FakeBackendSession extends BackendSessionNotifier {
  _FakeBackendSession(this._restore);

  /// A callback, not a `Future`: a `Future.error` built at the call site is
  /// already live before Riverpod attaches to it, and the zone reports it as
  /// an unhandled async error even though the notifier goes on to catch it.
  final Future<AuthUser?> Function() _restore;

  @override
  Future<AuthUser?> build() => _restore();
}

class _MockBackendAuthDataSource extends Mock
    implements BackendAuthDataSource {}

/// `TokenStorage` without the keychain — same API, and it remembers whether
/// anything cleared it.
class _InMemoryTokenStorage implements TokenStorage {
  // Named parameters cannot be private in Dart, so these are plain public
  // fields — `prefer_initializing_formals` has no other shape to offer here.
  _InMemoryTokenStorage({
    required this.accessToken,
    required this.refreshToken,
  });

  String? accessToken;
  String? refreshToken;

  /// Whether [clear] was ever called — the fact a signed-out-by-mistake user
  /// would feel, and the one a state assertion can miss entirely because a
  /// still-running restore can write the session back afterwards.
  bool cleared = false;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    cleared = true;
    accessToken = null;
    refreshToken = null;
  }
}

/// Records every provider that was ever initialised in this scope.
///
/// `OnboardingPageViewScreen.build` watches `onboardingControllerProvider`,
/// so that provider appearing here means the screen was constructed —
/// permanently, even if it is torn down again a frame later. That is the
/// difference between "the intro is not on screen now" and "the intro was
/// never built", and only the second one is what "no flash" means.
final class _ProviderInitProbe extends ProviderObserver {
  final Set<Object> initialised = <Object>{};

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    initialised.add(context.provider);
  }
}

/// Every `Text` currently in the tree, as plain strings.
Set<String> _visibleText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .toSet();
