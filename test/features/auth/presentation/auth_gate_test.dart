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

  group('INF-40 step 5 (skipped until step 4 — ADR-0036 D1/D3/D3.1)', () {
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
      },
      // `testWidgets`'s `skip` is `bool?`, not a message — the reason:
      // INF-40 ขั้น 3/4 ยังไม่ทำ — ปลด skip พร้อมกับการแก้.
      skip: true,
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
        // resolves to a real user. `ADR-0036`'s own literal, 5 s, is
        // deliberately not referenced as `AuthGate.sessionErrorDeadline`
        // here — that constant does not exist in code yet, and referencing
        // it directly would be a compile error breaking every test in this
        // file, not just this skipped one.
        container
            .read(backendSessionProvider.notifier)
            .state = AsyncError<AuthUser?>(
          const AuthException(code: 'network_error'),
          StackTrace.current,
        );
        await tester.pump(const Duration(milliseconds: 5000));

        container.read(backendSessionProvider.notifier).state =
            const AsyncData<AuthUser?>(AuthUser(uid: 'u1', email: 'a@b.co'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();

        expect(find.text('AUTHENTICATED-DESTINATION'), findsOneWidget);
        expect(find.byType(AuthErrorBanner), findsNothing);
      },
      skip: true,
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
