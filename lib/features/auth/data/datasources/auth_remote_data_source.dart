import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around `FirebaseAuth`. Exists so `AuthRepositoryImpl` can be
/// unit-tested against a mock instead of the Firebase SDK directly. Does
/// NOT catch `FirebaseAuthException` — that mapping is the repository's job.
abstract class AuthRemoteDataSource {
  Future<User> signIn({required String email, required String password});

  Future<User> signUp({required String email, required String password});

  Stream<User?> get authStateChanges;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  @override
  Future<User> signIn({required String email, required String password}) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user!;
  }

  @override
  Future<User> signUp({required String email, required String password}) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user!;
  }

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
}
