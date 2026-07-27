import '../../../core/error/auth_exception.dart';
import '../../../core/strings/app_strings.dart';

/// What the login screen shows for a failed sign-in: a friendly Thai
/// [message] plus the raw [code] (rendered on a second, muted line).
typedef AuthErrorDisplay = ({String message, String code});

/// Maps an [AuthException] to a user-facing display.
///
/// - Firebase (email/password + phone) codes are English (`wrong-password`,
///   `invalid-verification-code`, …) → mapped to Thai via [_firebaseMessages].
/// - Backend (Google) failures already carry a Thai `message` from the
///   `{error_code, message}` envelope → passed through as-is.
/// - Anything else falls back to a generic Thai line.
AuthErrorDisplay authErrorDisplay(AuthException e) =>
    (message: _messageFor(e), code: e.code);

/// Converts whatever landed in a view-model's `error` state into a display,
/// or `null` if there's nothing to show — the one place every auth screen
/// (login/register/OTP) should go through instead of repeating the
/// `is AuthException` branch inline.
///
/// Every non-null result carries a non-empty [AuthErrorDisplay.code]. A
/// domain [AuthException] not covered by [_firebaseMessages] still has its
/// own `code` from wherever it was thrown (see `authErrorDisplay`). Anything
/// that *isn't* an [AuthException] is itself a bug — every data-source guard
/// in this app is supposed to wrap failures into one before they reach
/// `state` — but should it happen anyway, this still shows the real
/// [Object.runtimeType] instead of a code-less "something went wrong" that
/// can't be diagnosed from the screen (see the OTP screen's CLAUDE.md note on
/// this exact failure mode).
AuthErrorDisplay? authErrorDisplayFor(Object? error) => switch (error) {
  null => null,
  AuthException e => authErrorDisplay(e),
  _ => (
    message: AppStrings.authErrorGeneric,
    code: error.runtimeType.toString(),
  ),
};

String _messageFor(AuthException e) {
  final mapped = _firebaseMessages[e.code];
  if (mapped != null) return mapped;
  // Backend envelope + our stable fallbacks already carry Thai messages.
  final message = e.message.trim();
  if (message.isNotEmpty && message != AppStrings.authGenericErrorMessage) {
    return message;
  }
  return AppStrings.authErrorGeneric;
}

const _firebaseMessages = <String, String>{
  'invalid-email': AppStrings.authErrorInvalidEmail,
  'user-disabled': AppStrings.authErrorUserDisabled,
  'user-not-found': AppStrings.authErrorUserNotFound,
  'wrong-password': AppStrings.authErrorWrongPassword,
  'invalid-credential': AppStrings.authErrorInvalidCredential,
  'too-many-requests': AppStrings.authErrorTooManyRequests,
  'network-request-failed': AppStrings.authErrorNetwork,
  'email-already-in-use': AppStrings.authErrorEmailAlreadyInUse,
  'weak-password': AppStrings.authErrorWeakPassword,
  'operation-not-allowed': AppStrings.authErrorOperationNotAllowed,
  // Phone (Firebase phone auth) codes.
  'invalid-phone-number': AppStrings.authErrorInvalidPhoneNumber,
  'invalid-verification-code': AppStrings.authErrorInvalidVerificationCode,
  'invalid-verification-id': AppStrings.authErrorInvalidVerificationId,
  'missing-verification-code': AppStrings.authErrorMissingVerificationCode,
  'session-expired': AppStrings.authErrorSessionExpired,
  'quota-exceeded': AppStrings.authErrorQuotaExceeded,
  'missing-client-identifier': AppStrings.authErrorMissingClientIdentifier,
  'captcha-check-failed': AppStrings.authErrorCaptchaCheckFailed,
  'credential-already-in-use': AppStrings.authErrorCredentialAlreadyInUse,
  // Social (Google/Apple) — fires only when the Firebase project is set to
  // "one account per email address".
  'account-exists-with-different-credential':
      AppStrings.authErrorAccountExistsWithDifferentCredential,
};
