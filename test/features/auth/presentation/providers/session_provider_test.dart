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

void main() {
  Future<ProviderContainer> makeContainer({
    required AuthUser? firebaseUser,
    required AuthUser? backendUser,
  }) async {
    final container = ProviderContainer(
      overrides: [
        authStateChangesProvider.overrideWith(
          (ref) => Stream<AuthUser?>.value(firebaseUser),
        ),
        backendSessionProvider.overrideWith(
          () => _FakeBackendSession(backendUser),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Keep the merged provider (and its two sources) alive so the stream
    // isn't auto-disposed before it emits, then resolve both sources.
    final sub = container.listen(sessionProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(authStateChangesProvider.future);
    await container.read(backendSessionProvider.future);
    return container;
  }

  const firebaseUser = AuthUser(uid: 'fb-1', email: 'fb@b.com');
  const backendUser = AuthUser(uid: 'be-1', email: 'be@b.com');

  test('authenticated via the Firebase session', () async {
    final container = await makeContainer(
      firebaseUser: firebaseUser,
      backendUser: null,
    );

    expect(container.read(sessionProvider).value, firebaseUser);
  });

  test('authenticated via the backend session', () async {
    final container = await makeContainer(
      firebaseUser: null,
      backendUser: backendUser,
    );

    expect(container.read(sessionProvider).value, backendUser);
  });

  test('logged out when neither session has a user', () async {
    final container = await makeContainer(
      firebaseUser: null,
      backendUser: null,
    );

    final session = container.read(sessionProvider);
    expect(session.hasValue, isTrue);
    expect(session.value, isNull);
  });
}
