import '../entities/auth_user.dart';

/// Firebase sign-out plus the raw Firebase auth-state stream. Implementations
/// must throw `AuthException` (from `core/error/`) on failure — never a
/// package-specific exception type.
///
/// Sign-in is deliberately NOT here — every sign-in method (email/password,
/// register, Google, phone) is backend-mediated via `/auth/firebase` (see
/// `BackendSessionNotifier`). Apple used to be the one exception, signing in
/// through Firebase directly; it was removed under ADR-0021 D4 (the backend
/// returns `401` for every non-`password`/`google.com`/`phone` provider —
/// ADR-0004 §1 — so a client-side Apple button could only ever fail).
abstract class AuthRepository {
  Future<void> signOut();

  Stream<AuthUser?> get authStateChanges;
}
