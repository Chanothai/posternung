import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/auth/domain/entities/auth_user.dart';
import 'package:posternung/features/auth/presentation/auth_gate.dart';
import 'package:posternung/features/auth/presentation/providers/auth_providers.dart';
import 'package:posternung/features/auth/presentation/providers/backend_session_provider.dart';
import 'package:posternung/features/auth/presentation/providers/session_provider.dart';
import 'package:posternung/features/auth/presentation/screens/login_screen.dart';
import 'package:posternung/features/auth/presentation/widgets/auth_error_banner.dart';

/// A no-op stand-in for the real `AuthViewModel` — `LoginScreen` (rendered by
/// `AuthGate`'s `data: null` branch) reads `authViewModelProvider`, and the
/// real one would try to touch Firebase/the backend at build time. Mirrors
/// the same pattern `login_screen_test.dart` uses.
class _NoopAuthViewModel extends AuthViewModel {
  @override
  FutureOr<void> build() {}
}

void main() {
  Widget wrap({
    required AsyncValue<AuthUser?> session,
    WidgetBuilder? builder,
  }) {
    return ProviderScope(
      overrides: [
        sessionProvider.overrideWithValue(session),
        authViewModelProvider.overrideWith(_NoopAuthViewModel.new),
      ],
      child: MaterialApp(
        home: AuthGate(
          builder: builder ?? (_) => const Text('AUTHENTICATED-DESTINATION'),
        ),
      ),
    );
  }

  testWidgets('loading — shows a spinner, not the login screen or the '
      'destination', (tester) async {
    await tester.pumpWidget(wrap(session: const AsyncLoading()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('AUTHENTICATED-DESTINATION'), findsNothing);
  });

  testWidgets('data(null) — signed out shows LoginScreen', (tester) async {
    await tester.pumpWidget(wrap(session: const AsyncData(null)));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('AUTHENTICATED-DESTINATION'), findsNothing);
  });

  testWidgets('data(user) — signed in builds the caller\'s destination, not '
      'LoginScreen', (tester) async {
    await tester.pumpWidget(
      wrap(
        session: const AsyncData(
          AuthUser(uid: 'u1', email: 'user@example.com'),
        ),
      ),
    );

    expect(find.text('AUTHENTICATED-DESTINATION'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets(
    'error — an AuthException routes through authErrorDisplayFor like every '
    'other auth screen, so the common case (e.g. network_error on startup) '
    'shows a specific Thai line + code, not a bare generic one',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          session: AsyncError(
            const AuthException(code: 'network_error'),
            StackTrace.current,
          ),
        ),
      );

      expect(find.text(AppStrings.authErrorNetwork), findsOneWidget);
      expect(
        find.text('${AppStrings.authErrorCodeLabel}network_error'),
        findsOneWidget,
      );
      // Not the bare generic line with no code — that's the exact AC-4
      // violation ("a generic line with no code") this screen used to have.
      expect(find.text(AppStrings.authErrorGeneric), findsNothing);
    },
  );

  testWidgets(
    'error — a non-AuthException still shows *some* code (AC-4 — never a '
    'generic line with nothing to diagnose from), via the same fixed '
    'unhandled_error path every other auth screen falls back to',
    (tester) async {
      await tester.pumpWidget(
        wrap(session: AsyncError(StateError('boom'), StackTrace.current)),
      );

      expect(find.text(AppStrings.authErrorGeneric), findsOneWidget);
      expect(
        find.text('${AppStrings.authErrorCodeLabel}unhandled_error'),
        findsOneWidget,
      );
    },
  );

  group('INF-40 step 5 — ADR-0036 D1/D3/D3.1/D4', () {
    testWidgets(
      'INF-40 step 5 (ข) — AC-4(ข)/ADR-0036 D1: AuthGate must not read '
      'riverpod\'s own AsyncLoading(error:, retrying: true) ladder as a '
      'plain spinner — it must show the error banner instead',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            sessionProvider.overrideWith(
              (ref) => ref.watch(_retryingSessionProvider),
            ),
            authViewModelProvider.overrideWith(_NoopAuthViewModel.new),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: AuthGate(
                builder: (_) => const Text('AUTHENTICATED-DESTINATION'),
              ),
            ),
          ),
        );
        // Let the throwing build() reject and riverpod's own retry ladder
        // pick it up — this produces the *real*
        // `AsyncLoading(error:, retrying: true)` (element.dart:758-789),
        // not a hand-built one: `AsyncLoading._` is private and
        // `AsyncError(retrying:)`/`copyWithPrevious` are `@internal`, so
        // constructing that shape by hand does not compile at all (GATE 1
        // plan §3(ข)).
        await tester.pump();
        await tester.pump();

        expect(find.byType(AuthErrorBanner), findsOneWidget);
        expect(
          find.text('${AppStrings.authErrorCodeLabel}unhandled_error'),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // 🔴 Tear this fixture down inside the test, not in `addTearDown`.
        // Retry is left **on** here on purpose — that is the whole point of
        // `_retryingSessionProvider` — so riverpod has a backoff timer armed
        // at all times, and `testWidgets` asserts no timer outlives the tree
        // *before* `addTearDown` callbacks run. Disposing the container here
        // cancels it. Pumping the timer out instead would only arm the next
        // rung of the ladder, forever.
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      },
    );

    testWidgets(
      'INF-40 step 5 (ค) — ADR-0036 D3.1: a session that resolves after '
      'the gate\'s own error deadline must still land on the destination, '
      'not stay latched on the error page (a latch here would recreate '
      'the BL-130 shape at a second gate)',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            backendSessionProvider.overrideWith(_NeverResolvingSession.new),
            authViewModelProvider.overrideWith(_NoopAuthViewModel.new),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: AuthGate(
                builder: (_) => const Text('AUTHENTICATED-DESTINATION'),
              ),
            ),
          ),
        );
        await tester.pump();

        // Manually driving `.state` (not `build()` throwing) sidesteps
        // riverpod's own retry ladder entirely, so this test isolates the
        // one variable ADR-0036 D3.1 is actually about: a session that
        // shows an error, sits past the gate's own deadline, and *then*
        // resolves to a real user.
        container
            .read(backendSessionProvider.notifier)
            .state = AsyncError<AuthUser?>(
          const AuthException(code: 'network_error'),
          StackTrace.current,
        );
        await tester.pump(
          AuthGate.sessionErrorDeadline + const Duration(milliseconds: 500),
        );

        container.read(backendSessionProvider.notifier).state =
            const AsyncData<AuthUser?>(AuthUser(uid: 'u1', email: 'a@b.co'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();

        expect(find.text('AUTHENTICATED-DESTINATION'), findsOneWidget);
        expect(find.byType(AuthErrorBanner), findsNothing);
      },
    );
    testWidgets(
      'ADR-0036 D3 — a session that is still pending past the gate\'s own '
      'deadline stops being a spinner and says so, with a way out',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            backendSessionProvider.overrideWith(_CountingNeverSession.new),
            authViewModelProvider.overrideWith(_NoopAuthViewModel.new),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: AuthGate(
                builder: (_) => const Text('AUTHENTICATED-DESTINATION'),
              ),
            ),
          ),
        );
        await tester.pump();

        // Nothing has failed and nothing will — this is the "hangs but never
        // throws" case, which `hasError` (D1) cannot see at all. Until the
        // deadline the spinner is the honest answer.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text(AppStrings.authSessionSlowMessage), findsNothing);

        await tester.pump(
          AuthGate.sessionErrorDeadline + const Duration(milliseconds: 1),
        );

        expect(find.text(AppStrings.authSessionSlowMessage), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.widgetWithText(FilledButton, AppStrings.authSubmitLogin),
          findsOneWidget,
          reason: 'D4 — the way out is a way to sign in, and it must be there',
        );

        // 🔴 D3.1 — non-destructive. The deadline may show a message and
        // nothing else: no signOut, no invalidate, no token clear, and the
        // request still in flight. A rebuilt notifier would mean the gate
        // threw the session away and started over, which is precisely the
        // "slow network quietly becomes a logout" failure D3.1 forbids.
        expect(
          (container.read(backendSessionProvider.notifier)
                  as _CountingNeverSession)
              .buildCount,
          1,
          reason:
              'the session notifier must not have been rebuilt — the deadline '
              'changes what is on screen, never the session itself',
        );
      },
    );

    testWidgets(
      'ADR-0036 D4 — the way out goes to LoginScreen, and the banner still '
      'has no retry button (ADR-0021 D3 is untouched, not amended)',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            session: AsyncError<AuthUser?>(
              const AuthException(code: 'network_error'),
              StackTrace.current,
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(AuthErrorBanner), findsOneWidget);
        expect(
          find.widgetWithText(TextButton, AppStrings.authRetryButton),
          findsNothing,
          reason:
              'ADR-0021 D3 ties the retry button to the 409 code; a session '
              'error carries no HTTP code, so the rule never covered it and '
              'nothing here may grow one (see ADR-0036 OD-2)',
        );

        await tester.tap(
          find.widgetWithText(FilledButton, AppStrings.authSubmitLogin),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(AuthErrorBanner), findsNothing);
      },
    );

    testWidgets(
      'ADR-0036 D3.1 — taking the way out does not strand a session that '
      'arrives afterwards: the destination still wins',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            backendSessionProvider.overrideWith(_CountingNeverSession.new),
            authViewModelProvider.overrideWith(_NoopAuthViewModel.new),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: AuthGate(
                builder: (_) => const Text('AUTHENTICATED-DESTINATION'),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(
          AuthGate.sessionErrorDeadline + const Duration(milliseconds: 1),
        );
        await tester.tap(
          find.widgetWithText(FilledButton, AppStrings.authSubmitLogin),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);

        container.read(backendSessionProvider.notifier).state =
            const AsyncData<AuthUser?>(AuthUser(uid: 'u1', email: 'a@b.co'));
        await tester.pumpAndSettle();

        expect(
          find.text('AUTHENTICATED-DESTINATION'),
          findsOneWidget,
          reason:
              'the reader pressed "sign in" because they could not get in; '
              'the moment they can, keeping them on the login screen is the '
              'same failure D3.1 describes, just reached by a different door',
        );
      },
    );
  });

  group('ADR-0021 D1 regression — Firebase-only must not advance the gate', () {
    /// Fake `BackendSessionNotifier` reporting a fixed user without touching
    /// storage/network — same pattern as `session_provider_test.dart`.
    testWidgets(
      'a Firebase session with no backend session shows LoginScreen, not the '
      "caller's destination — this exercises the real sessionProvider (not "
      'an override of it), proving the composition end-to-end rather than '
      "just sessionProvider's own unit test",
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateChangesProvider.overrideWith(
                (ref) => Stream.value(
                  const AuthUser(uid: 'fb-1', email: 'fb@b.com'),
                ),
              ),
              backendSessionProvider.overrideWith(
                () => _FixedBackendSession(null),
              ),
              authViewModelProvider.overrideWith(_NoopAuthViewModel.new),
            ],
            child: MaterialApp(
              home: AuthGate(
                builder: (_) => const Text('AUTHENTICATED-DESTINATION'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('AUTHENTICATED-DESTINATION'), findsNothing);
      },
    );
  });
}

class _FixedBackendSession extends BackendSessionNotifier {
  _FixedBackendSession(this._user);
  final AuthUser? _user;

  @override
  Future<AuthUser?> build() async => _user;
}

// --- INF-40 step 5 (ข) fixtures ---

/// A tiny provider whose `build()` throws, with retry left at riverpod's
/// default (on) — the one way to produce a *real*
/// `AsyncLoading(error:, retrying: true)` for `AuthGate` to react to (GATE 1
/// plan §3(ข): the shape cannot be constructed by hand).
final _retryingSessionProvider =
    AsyncNotifierProvider<_RetryingSessionNotifier, AuthUser?>(
      _RetryingSessionNotifier.new,
    );

class _RetryingSessionNotifier extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async {
    throw Exception('boom');
  }
}

// --- INF-40 step 5 (ค) fixture ---

/// `build()` never resolves or throws — this test drives `state` by hand
/// (via `container.read(backendSessionProvider.notifier).state = ...`) so
/// the scenario is isolated from riverpod's own retry ladder entirely,
/// which is what test (ข) above exercises instead.
class _NeverResolvingSession extends BackendSessionNotifier {
  @override
  Future<AuthUser?> build() => Completer<AuthUser?>().future;
}

/// Same "never answers" shape, plus a count of how many times `build()` ran.
///
/// The count is what makes ADR-0036 **D3.1** testable at all: "the deadline
/// did not sign anyone out" is hard to assert directly, but every destructive
/// option D3.1 forbids — `invalidate()`, `signOut()`, dropping the listener —
/// ends in the notifier being rebuilt. A count that stays at 1 rules the whole
/// family out at once.
class _CountingNeverSession extends BackendSessionNotifier {
  int buildCount = 0;

  @override
  Future<AuthUser?> build() {
    buildCount++;
    return Completer<AuthUser?>().future;
  }
}
