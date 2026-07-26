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
        // has a usable credential before any code was sent.
        try {
          final userCredential = await _firebaseAuth.signInWithCredential(
            credential,
          );
          final idToken = await userCredential.user?.getIdToken();
          if (idToken == null) {
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
