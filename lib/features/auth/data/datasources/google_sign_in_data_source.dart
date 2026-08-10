import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/error/auth_cancelled_exception.dart';
import '../../../../core/error/auth_exception.dart';
import '../../../../core/error/debug_log.dart';

/// Owns the Google Sign-In flow and returns a **Firebase ID token** for the
/// backend to verify (`POST /auth/firebase` runs `verify_firebase_token`, so a
/// raw Google Sign-In token is rejected). Google Sign-In yields a Google
/// `id_token`, which is exchanged for a Firebase session via
/// `signInWithCredential`; the resulting Firebase ID token is what's sent to
/// the backend. Firebase is thus the identity verifier; the backend still
/// issues its own JWT session on top.
abstract class GoogleSignInDataSource {
  /// Runs the native account picker, signs into Firebase with the Google
  /// credential, and returns the Firebase ID token. Throws
  /// [AuthCancelledException] if the user dismisses the picker.
  Future<String> getIdToken();
}

class GoogleSignInDataSourceImpl implements GoogleSignInDataSource {
  GoogleSignInDataSourceImpl(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  bool _initialized = false;

  @override
  Future<String> getIdToken() async {
    await _ensureInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final googleIdToken = account.authentication.idToken;
      // Empty string, not just null — the same trap documented on every
      // other provider in this feature (`getIdToken()` can resolve to `''`,
      // which used to sail through and get POSTed as `{"id_token": ""}`,
      // tripping the backend's Pydantic `min_length=1` with a 422 that
      // looked like any other failure). This datasource used to check
      // `== null` only, on *both* the Google token below and the Firebase
      // one further down.
      if (googleIdToken == null || googleIdToken.isEmpty) {
        throw const AuthException(code: 'missing_id_token');
      }

      final credential = GoogleAuthProvider.credential(idToken: googleIdToken);
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      final firebaseIdToken = await userCredential.user?.getIdToken();
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        throw const AuthException(code: 'missing_id_token');
      }
      return firebaseIdToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelledException();
      }
      // `e.description` is the SDK's own English diagnostic text, never a
      // display string (ADR-0017 D2) — debug-only.
      throw AuthException(
        code: e.code.name,
        debugDetail: logDebugDetail(e.description, source: 'google_signin'),
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        code: e.code,
        debugDetail: logDebugDetail(e.message, source: 'google_signin'),
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      // Same trailing guard every other data source in this feature has
      // (`add-feature-slice` skill's "error with no code" gotcha) — this one
      // used to be missing it, so anything besides
      // GoogleSignInException/FirebaseAuthException (a plugin-channel
      // failure, say) escaped uncaught and reached the UI as a bare object
      // with no code to display. `code` is fixed, never composed from
      // `e.runtimeType` (ADR-0017 D6); the type still goes to `debugDetail`.
      throw AuthException(
        code: 'google_signin_unexpected',
        debugDetail: logDebugDetail(e.toString(), source: 'google_signin'),
      );
    }
  }

  /// google_sign_in v7 requires a one-time `initialize()` before use. On
  /// Android an `idToken` is only returned when a `serverClientId` (the
  /// project's *web* OAuth client ID) is supplied — provided at build time
  /// via `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` (see
  /// docs/social-login-setup.md). iOS reads its client ID from
  /// GoogleService-Info.plist automatically.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    await GoogleSignIn.instance.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
    _initialized = true;
  }
}
