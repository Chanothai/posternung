import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Thin wrapper around the Apple sign-in SDK + `FirebaseAuth` session
/// lifecycle. Exists so `AuthRepositoryImpl` can be unit-tested against a mock
/// instead of the SDKs directly. Does NOT catch SDK exceptions
/// (`FirebaseAuthException`, `SignInWithAppleAuthorizationException`) — mapping
/// those to domain exceptions is the repository's job.
///
/// Email/password and Google are deliberately NOT here — both are
/// backend-mediated now via `/auth/firebase` (see
/// `EmailPasswordSignInDataSource` / `GoogleSignInDataSource` +
/// `BackendAuthDataSource`); Firebase backs only Apple directly.
abstract class AuthRemoteDataSource {
  Future<User> signInWithApple();

  Future<void> signOut();

  Stream<User?> get authStateChanges;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  @override
  Future<User> signInWithApple() async {
    final rawNonce = _generateNonce();
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: _sha256(rawNonce),
    );
    final oauthCredential = OAuthProvider(
      'apple.com',
    ).credential(idToken: appleCredential.identityToken, rawNonce: rawNonce);
    final userCredential = await _firebaseAuth.signInWithCredential(
      oauthCredential,
    );
    return userCredential.user!;
  }

  @override
  Future<void> signOut() => _firebaseAuth.signOut();

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256(String input) => sha256.convert(utf8.encode(input)).toString();
}
