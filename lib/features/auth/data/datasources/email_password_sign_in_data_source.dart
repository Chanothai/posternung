import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

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

  /// Deletes the currently signed-in Firebase account, undoing a [register]
  /// whose backend exchange then failed. **Never throws** — it only runs while
  /// another failure is already propagating and must not replace it.
  Future<void> deleteCurrentUser();
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

  @override
  Future<void> deleteCurrentUser() async {
    try {
      await _firebaseAuth.currentUser?.delete();
    } catch (e) {
      // Swallowed on purpose: the caller is already unwinding a failure, and
      // replacing that error with this one would hide why registration failed
      // in the first place. Logged so an orphaned Firebase account — the exact
      // state this method exists to prevent — is still traceable.
      if (kDebugMode) {
        developer.log(
          'rollback delete failed: $e',
          name: 'email-password-register',
        );
      }
    }
  }

  /// Runs a Firebase credential action and returns the resulting user's ID
  /// token, mapping every `FirebaseAuthException` to a domain [AuthException]
  /// so nothing above the datasource depends on Firebase.
  Future<String> _idTokenFor(Future<UserCredential> Function() action) async {
    try {
      final credential = await action();
      final idToken = await credential.user?.getIdToken();
      // `getIdToken()` can resolve to `''`, not just null. An empty string
      // used to sail through and get POSTed as `{"id_token": ""}`, tripping
      // the backend's Pydantic `min_length=1` with a 422 that looked like any
      // other failure. Same trap already fixed in PhoneSignInDataSource.
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException(
          code: 'missing_id_token',
          message: AppStrings.authErrorGeneric,
        );
      }
      return idToken;
    } on FirebaseAuthException catch (e) {
      throw AuthException(code: e.code, message: e.message ?? e.code);
    } on AuthException {
      rethrow;
    } catch (e) {
      // Anything that isn't a Firebase error still has to reach the UI with a
      // code attached — an unlabelled error renders as a generic Thai line
      // with no code, which is indistinguishable from "nothing is wrong".
      throw AuthException(
        code: 'email_password_${e.runtimeType}',
        message: AppStrings.authErrorGeneric,
      );
    }
  }
}
