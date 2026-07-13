import '../entities/auth_user.dart';

/// Auth operations the app needs. Implementations must throw
/// `AuthException` (from `core/error/`) on failure — never a
/// package-specific exception type.
abstract class AuthRepository {
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<AuthUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
  });

  Stream<AuthUser?> get authStateChanges;
}
