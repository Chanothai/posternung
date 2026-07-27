import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/auth_exception.dart';
import '../../../../core/strings/app_strings.dart';

/// Owns the Firebase email/password flow and returns a **Firebase ID token**
/// for the backend to verify (`POST /auth/firebase` runs
/// `verify_firebase_token` and reads `sign_in_provider` from the token). Login
/// signs into an existing Firebase account; register creates a new one — the
/// backend find-or-creates its own user record from the token either way.
/// Firebase is the identity verifier; the backend issues its own JWT session
/// on top. Mirrors [GoogleSignInDataSource]: this producer maps its own
/// `FirebaseAuthException`s to a domain [AuthException].
abstract class EmailPasswordSignInDataSource {
  /// Signs into Firebase with [email]/[password] and returns the Firebase ID
  /// token. Throws [AuthException] on any Firebase failure.
  Future<String> signIn({required String email, required String password});

  /// Creates a Firebase account for [email]/[password] and returns the
  /// Firebase ID token. Throws [AuthException] on any Firebase failure.
  Future<String> register({required String email, required String password});
}

class EmailPasswordSignInDataSourceImpl
    implements EmailPasswordSignInDataSource {
  EmailPasswordSignInDataSourceImpl(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  @override
  Future<String> signIn({required String email, required String password}) =>
      _idTokenFor(
        () => _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
      );

  @override
  Future<String> register({required String email, required String password}) =>
      _idTokenFor(
        () => _firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ),
      );

  /// Runs a Firebase credential action and returns the resulting user's ID
  /// token, mapping every `FirebaseAuthException` to a domain [AuthException]
  /// so nothing above the datasource depends on Firebase.
  Future<String> _idTokenFor(Future<UserCredential> Function() action) async {
    try {
      final credential = await action();
      final idToken = await credential.user?.getIdToken();
      if (idToken == null) {
        throw const AuthException(
          code: 'missing_id_token',
          message: AppStrings.authErrorGeneric,
        );
      }
      return idToken;
    } on FirebaseAuthException catch (e) {
      throw AuthException(code: e.code, message: e.message ?? e.code);
    }
  }
}
