import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Thin wrapper around `FirebaseAuth` (and the Google/Apple sign-in SDKs).
/// Exists so `AuthRepositoryImpl` can be unit-tested against a mock instead
/// of the SDKs directly. Does NOT catch SDK exceptions
/// (`FirebaseAuthException`, `GoogleSignInException`,
/// `SignInWithAppleAuthorizationException`) — mapping those to domain
/// exceptions is the repository's job.
abstract class AuthRemoteDataSource {
  Future<User> signIn({required String email, required String password});

  Future<User> signUp({required String email, required String password});

  Future<User> signInWithGoogle();

  Future<User> signInWithApple();

  Future<void> signOut();

  Stream<User?> get authStateChanges;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  bool _googleInitialized = false;

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
  Future<User> signInWithGoogle() async {
    await _ensureGoogleInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    final credential = GoogleAuthProvider.credential(
      idToken: account.authentication.idToken,
    );
    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    return userCredential.user!;
  }

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

  /// google_sign_in v7 requires a one-time `initialize()` before use. On
  /// Android an `idToken` is only returned when a `serverClientId` (the
  /// project's *web* OAuth client ID) is supplied — provided at build time
  /// via `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` (see
  /// docs/social-login-setup.md). iOS reads its client ID from
  /// GoogleService-Info.plist automatically.
  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    await GoogleSignIn.instance.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
    _googleInitialized = true;
  }

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
