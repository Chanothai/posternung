import '../entities/auth_user.dart';

/// Firebase-backed auth operations (Apple + session lifecycle).
/// Implementations must throw `AuthException` (from `core/error/`) on failure
/// — never a package-specific exception type — or `AuthCancelledException`
/// when the user aborts an interactive sign-in flow.
///
/// Email/password and Google are NOT here — they're backend-mediated via
/// `/auth/firebase` (see `BackendSessionNotifier`), not part of this Firebase
/// chain. Only Apple still signs in through Firebase directly.
abstract class AuthRepository {
  Future<AuthUser> signInWithApple();

  Future<void> signOut();

  Stream<AuthUser?> get authStateChanges;
}
