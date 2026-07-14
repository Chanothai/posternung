import '../entities/auth_user.dart';

/// Auth operations the app needs. Implementations must throw
/// `AuthException` (from `core/error/`) on failure — never a
/// package-specific exception type — or `AuthCancelledException` when the
/// user aborts an interactive (social) sign-in flow.
abstract class AuthRepository {
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<AuthUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<AuthUser> signInWithGoogle();

  Future<AuthUser> signInWithApple();

  Stream<AuthUser?> get authStateChanges;
}
