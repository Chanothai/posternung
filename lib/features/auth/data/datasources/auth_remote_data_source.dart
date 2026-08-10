import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around `FirebaseAuth`'s sign-out call and its auth-state
/// stream. Exists so `AuthRepositoryImpl` can be unit-tested against a mock
/// instead of the SDK directly.
///
/// Sign-in is deliberately NOT here — every sign-in method is
/// backend-mediated now via `/auth/firebase` (see
/// `EmailPasswordSignInDataSource` / `GoogleSignInDataSource` /
/// `PhoneSignInDataSource` + `BackendAuthDataSource`). Apple used to be the
/// one exception, signing in through Firebase directly; it was removed
/// under ADR-0021 D4.
abstract class AuthRemoteDataSource {
  Future<void> signOut();

  Stream<User?> get authStateChanges;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  @override
  Future<void> signOut() => _firebaseAuth.signOut();

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
}
