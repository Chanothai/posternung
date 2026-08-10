import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/features/auth/domain/entities/auth_user.dart';
import 'package:posternung/features/auth/presentation/providers/auth_providers.dart';
import 'package:posternung/features/auth/presentation/providers/backend_session_provider.dart';
import 'package:posternung/features/auth/presentation/providers/session_provider.dart';

/// Fake that skips the storage/network restore and just reports a fixed user.
class _FakeBackendSession extends BackendSessionNotifier {
  _FakeBackendSession(this._user);
  final AuthUser? _user;

  @override
  Future<AuthUser?> build() async => _user;
}

/// Fake whose `build()` never resolves on its own — for asserting the
/// AsyncLoading state deterministically without touching real secure storage.
class _PendingBackendSession extends BackendSessionNotifier {
  _PendingBackendSession(this._future);
  final Future<AuthUser?> _future;

  @override
  Future<AuthUser?> build() => _future;
}

void main() {
  Future<ProviderContainer> makeContainer({
    AuthUser? firebaseUser,
    required AuthUser? backendUser,
  }) async {
    final container = ProviderContainer(
      overrides: [
        // Overridden even where unused by `sessionProvider` any more — the
        // ADR-0021 D1 regression test below needs a Firebase-authenticated
        // stream to prove `sessionProvider` genuinely ignores it, not just
        // that it happens not to be watched.
        authStateChangesProvider.overrideWith(
          (ref) => Stream<AuthUser?>.value(firebaseUser),
        ),
        backendSessionProvider.overrideWith(
          () => _FakeBackendSession(backendUser),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(sessionProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(backendSessionProvider.future);
    return container;
  }

  const firebaseUser = AuthUser(uid: 'fb-1', email: 'fb@b.com');
  const backendUser = AuthUser(uid: 'be-1', email: 'be@b.com');

  test('authenticated via the backend session', () async {
    final container = await makeContainer(backendUser: backendUser);

    expect(container.read(sessionProvider).value, backendUser);
  });

  test('logged out when the backend session has no user', () async {
    final container = await makeContainer(backendUser: null);

    final session = container.read(sessionProvider);
    expect(session.hasValue, isTrue);
    expect(session.value, isNull);
  });

  test('ADR-0021 D1 regression — a Firebase session alone (no backend JWT '
      'session) must NOT read as authenticated. Every sign-in method '
      'establishes a Firebase session as an intermediate step on the way to '
      'exchanging a token at /auth/firebase; a Firebase-only session means the '
      "app can't call any of its own APIs, so it must not be treated as "
      '"logged in".', () async {
    final container = await makeContainer(
      firebaseUser: firebaseUser,
      backendUser: null,
    );

    final session = container.read(sessionProvider);
    expect(session.hasValue, isTrue);
    expect(
      session.value,
      isNull,
      reason:
          'a Firebase-only session (no backend JWT) must not be reported '
          'as authenticated — only backendSessionProvider is the source '
          'of truth now (ADR-0021 D1)',
    );
  });

  test('sessionProvider mirrors backendSessionProvider\'s AsyncLoading while '
      'restore is in flight, rather than reporting logged-out early — the '
      'login screen must not flash before a stored session is restored '
      '(ADR-0021 D1 §ข้อบังคับที่มากับ D1)', () async {
    final completer = Completer<AuthUser?>();
    addTearDown(() {
      if (!completer.isCompleted) completer.complete(null);
    });
    final container = ProviderContainer(
      overrides: [
        authStateChangesProvider.overrideWith(
          (ref) => Stream<AuthUser?>.value(null),
        ),
        backendSessionProvider.overrideWith(
          () => _PendingBackendSession(completer.future),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(sessionProvider), isA<AsyncLoading<AuthUser?>>());
  });
}
