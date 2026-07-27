import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/auth_exception.dart';
import '../../../../core/strings/app_strings.dart';

/// Outcome of [PhoneSignInDataSource.sendCode].
sealed class PhoneVerificationResult {}

/// Firebase sent an SMS — the user needs to enter [verificationId]'s code.
class SmsCodeSent extends PhoneVerificationResult {
  SmsCodeSent(this.verificationId, {this.resendToken});

  final String verificationId;

  /// Firebase's own docs: "No duplicated SMS will be sent out unless a
  /// `forceResendingToken` is provided." Callers must feed this back into
  /// [PhoneSignInDataSource.sendCode]'s `resendToken` param on resend, or the
  /// SDK silently sends nothing.
  final int? resendToken;
}

/// Firebase silently verified the device (Android SMS Retriever / instant
/// verification) before any code was sent — there's nothing to enter.
/// [idToken] is already the signed-in user's Firebase ID token, ready to
/// exchange at `/auth/firebase`.
class PhoneAutoVerified extends PhoneVerificationResult {
  PhoneAutoVerified(this.idToken);

  final String idToken;
}

/// Owns the Firebase phone-number flow and returns a **Firebase ID token**
/// for the backend to verify (`POST /auth/firebase` reads `sign_in_provider`
/// from the token, so phone sign-in needs no dedicated backend endpoint).
/// Mirrors [GoogleSignInDataSource]/[EmailPasswordSignInDataSource] in
/// producing an ID token, but phone verification is inherently two calls —
/// [sendCode] then [confirmCode] — since Firebase has to send an SMS in
/// between.
abstract class PhoneSignInDataSource {
  /// Starts phone verification for [phoneNumber] (E.164, e.g. `+66812345678`).
  /// Pass the previous [SmsCodeSent.resendToken] as [resendToken] when this
  /// is a resend — Firebase requires it to actually send a second SMS.
  /// Throws [AuthException] if Firebase rejects the number outright.
  Future<PhoneVerificationResult> sendCode(
    String phoneNumber, {
    int? resendToken,
  });

  /// Confirms [smsCode] against [verificationId] and returns the Firebase ID
  /// token. Throws [AuthException] on an invalid/expired code.
  Future<String> confirmCode({
    required String verificationId,
    required String smsCode,
  });
}

class PhoneSignInDataSourceImpl implements PhoneSignInDataSource {
  PhoneSignInDataSourceImpl(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  @override
  Future<PhoneVerificationResult> sendCode(
    String phoneNumber, {
    int? resendToken,
  }) {
    final completer = Completer<PhoneVerificationResult>();

    void completeError(AuthException exception) {
      if (!completer.isCompleted) completer.completeError(exception);
    }

    _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android SMS Retriever / instant verification — Firebase already
        // has a usable credential before any code was sent. This can race
        // `codeSent` (both are legitimate outcomes of the same call, and a
        // Firebase Console *test* phone number in particular tends to
        // auto-verify instantly). If `codeSent` already won, bail out before
        // touching Firebase again — otherwise this still signs in in the
        // background while the OTP screen is showing, and any failure here
        // would vanish silently (`completeError` is a no-op once completed).
        if (completer.isCompleted) return;
        try {
          final userCredential = await _firebaseAuth.signInWithCredential(
            credential,
          );
          final idToken = await userCredential.user?.getIdToken();
          if (idToken == null || idToken.isEmpty) {
            completeError(
              const AuthException(
                code: 'missing_id_token',
                message: AppStrings.authErrorGeneric,
              ),
            );
            return;
          }
          if (!completer.isCompleted) {
            completer.complete(PhoneAutoVerified(idToken));
          }
        } on FirebaseAuthException catch (e) {
          completeError(
            AuthException(code: e.code, message: e.message ?? e.code),
          );
        } catch (e) {
          // Anything other than FirebaseAuthException (a PlatformException
          // from the plugin channel, etc.) used to escape uncaught — surface
          // it as an AuthException instead, with the real type in the code
          // so it doesn't read as a generic, undiagnosable failure.
          completeError(
            AuthException(
              code: 'phone_signin_${e.runtimeType}',
              message: e.toString(),
            ),
          );
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        completeError(
          AuthException(code: e.code, message: e.message ?? e.code),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!completer.isCompleted) {
          completer.complete(
            SmsCodeSent(verificationId, resendToken: resendToken),
          );
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Only matters if neither of the above fired first (rare) — let the
        // user type the code manually instead of hanging forever.
        if (!completer.isCompleted) {
          completer.complete(SmsCodeSent(verificationId));
        }
      },
    );

    return completer.future;
  }

  @override
  Future<String> confirmCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    try {
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      final idToken = await userCredential.user?.getIdToken();
      // Not just `== null` — `getIdToken()` can resolve to an empty string,
      // which would otherwise sail through this check and get POSTed as
      // `{"id_token": ""}`, failing the backend's `min_length=1` validation
      // with a 422 that's indistinguishable from any other bad request.
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
      rethrow; // the missing_id_token throw above — don't re-wrap it below.
    } catch (e) {
      // Anything else (PlatformException from the plugin channel, a
      // MissingPluginException, ...) used to escape this method uncaught,
      // reaching the UI as a bare object with no `code` to show — the exact
      // symptom of a wrong-verification-code report with no diagnostic line.
      throw AuthException(
        code: 'phone_signin_${e.runtimeType}',
        message: e.toString(),
      );
    }
  }
}
