import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/auth_exception.dart';
import '../../../../core/error/debug_log.dart';

/// Owns the Firebase email/password flow and returns a **Firebase ID token**
/// for the backend to verify (`POST /auth/firebase` runs
/// `verify_firebase_token` and reads `sign_in_provider` from the token). Login
/// signs into an existing Firebase account; register creates a new one — the
/// backend find-or-creates its own user record from the token either way.
/// Firebase is the identity verifier; the backend issues its own JWT session
/// on top. Mirrors [GoogleSignInDataSource]: this producer maps its own
/// `FirebaseAuthException`s to a domain [AuthException].
///
/// **ADR-0021 D2** — the `password` provider requires `email_verified=true`
/// at the backend (ADR-0004 §4), so [register] alone is not enough to reach
/// a backend session: [sendEmailVerification], [reloadAndCheckEmailVerified]
/// and [currentIdToken] exist to drive the "wait for verification, then
/// exchange" flow `BackendSessionNotifier` runs.
abstract class EmailPasswordSignInDataSource {
  /// Signs into Firebase with [email]/[password] and returns the Firebase ID
  /// token. Throws [AuthException] on any Firebase failure.
  Future<String> signIn({required String email, required String password});

  /// Creates a Firebase account for [email]/[password] and returns the
  /// Firebase ID token. Throws [AuthException] on any Firebase failure. Does
  /// **not** exchange with the backend — the account's email is not verified
  /// yet, so that exchange would always 403 (ADR-0021 D2).
  Future<String> register({required String email, required String password});

  /// Sends a Firebase verification email to the currently signed-in user.
  /// Throws [AuthException] with code `no_current_user` if nobody is signed
  /// in — should not happen in the flow this exists for ([register] always
  /// leaves a signed-in user behind), but every guard in this class still
  /// has to hand back a code rather than let a null-check escape uncaught.
  Future<void> sendEmailVerification();

  /// Reloads the currently signed-in Firebase user from the server and
  /// returns whether their email is verified now. Throws [AuthException]
  /// with code `no_current_user` if nobody is signed in.
  Future<bool> reloadAndCheckEmailVerified();

  /// The current Firebase user's ID token, force-refreshed. Firebase caches
  /// ID token claims client-side; [reloadAndCheckEmailVerified] updates
  /// `User.emailVerified` locally but not the token itself, so exchanging a
  /// non-refreshed token right after verification would still carry the
  /// stale `email_verified: false` claim. Throws [AuthException] with code
  /// `no_current_user` if nobody is signed in.
  Future<String> currentIdToken();
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
  Future<void> sendEmailVerification() => _run(() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthException(code: 'no_current_user');
    await user.sendEmailVerification();
  });

  @override
  Future<bool> reloadAndCheckEmailVerified() => _run(() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthException(code: 'no_current_user');
    await user.reload();
    return _firebaseAuth.currentUser?.emailVerified ?? false;
  });

  @override
  Future<String> currentIdToken() => _run(() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthException(code: 'no_current_user');
    final idToken = await user.getIdToken(true);
    // Same empty-string trap `_idTokenFor` guards against below.
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException(code: 'missing_id_token');
    }
    return idToken;
  });

  /// Runs a Firebase credential action and returns the resulting user's ID
  /// token, via the same failure-mapping [_run] every other method here uses.
  Future<String> _idTokenFor(Future<UserCredential> Function() action) =>
      _run(() async {
        final credential = await action();
        final idToken = await credential.user?.getIdToken();
        // `getIdToken()` can resolve to `''`, not just null. An empty string
        // used to sail through and get POSTed as `{"id_token": ""}`, tripping
        // the backend's Pydantic `min_length=1` with a 422 that looked like any
        // other failure. Same trap already fixed in PhoneSignInDataSource.
        if (idToken == null || idToken.isEmpty) {
          throw const AuthException(code: 'missing_id_token');
        }
        return idToken;
      });

  /// Runs [action], mapping every `FirebaseAuthException` to a domain
  /// [AuthException] so nothing above this datasource depends on Firebase.
  /// Shared by every method here so each one only has to write its own
  /// happy-path logic.
  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      // `e.message` is Firebase's own English diagnostic text — never a
      // display string (ADR-0017 D2). `authErrorDisplay` maps `e.code` to
      // Thai; this is debug-only.
      throw AuthException(
        code: e.code,
        debugDetail: logDebugDetail(e.message, source: 'email_password_signin'),
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      // Anything that isn't a Firebase error still has to reach the UI with a
      // code attached — an unlabelled error renders as a generic Thai line
      // with no code, which is indistinguishable from "nothing is wrong".
      // `code` is a fixed string, never composed from `e.runtimeType`
      // (ADR-0017 D6) — the type still goes to `debugDetail` for diagnosis.
      throw AuthException(
        code: 'email_password_unexpected',
        debugDetail: logDebugDetail(
          e.toString(),
          source: 'email_password_signin',
        ),
      );
    }
  }
}
