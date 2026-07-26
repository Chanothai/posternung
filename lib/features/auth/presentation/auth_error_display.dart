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
};
