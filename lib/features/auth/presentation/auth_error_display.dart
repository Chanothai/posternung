import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kDebugMode;

import '../../../core/error/auth_exception.dart';
import '../../../core/error/error_display.dart';
import '../../../core/strings/app_strings.dart';

/// What the login screen shows for a failed sign-in: a friendly Thai
/// [message] plus the raw [code] (rendered on a second, muted line).
typedef AuthErrorDisplay = ErrorDisplay;

/// Maps an [AuthException] to a user-facing display via the shared
/// three-step algorithm (ADR-0017 D4/D9 — see `core/error/error_display.dart`
/// for the algorithm itself; this file owns only the auth-specific table
/// step 1 reads from).
///
/// - Firebase (email/password + phone) codes are English (`wrong-password`,
///   `invalid-verification-code`, …) → mapped to Thai via [_authMessages].
/// - Backend failures (Google, and any `BackendAuthDataSource` envelope
///   error) carry a Thai `displayMessage` from the `{error_code, message}`
///   envelope → used when step 1 misses.
/// - Anything else falls back to a generic Thai line.
AuthErrorDisplay authErrorDisplay(AuthException e) => resolveErrorDisplay(
  e.displayMessage,
  code: e.code,
  codeMessages: _authMessages,
  fallback: AppStrings.authErrorGeneric,
);

/// Converts whatever landed in a view-model's `error` state into a display,
/// or `null` if there's nothing to show — the one place every auth screen
/// (login/register/OTP) should go through instead of repeating the
/// `is AuthException` branch inline.
///
/// Every non-null result carries a non-empty [AuthErrorDisplay.code]. A
/// domain [AuthException] not covered by [_authMessages] still has its own
/// `code` from wherever it was thrown (see [authErrorDisplay]). Anything
/// that *isn't* an [AuthException] is itself a bug — every data-source guard
/// in this app is supposed to wrap failures into one before they reach
/// `state` — but should it happen anyway, this shows a fixed `unhandled_error`
/// code (ADR-0017 OD-1 — **not** a string built at runtime from the object's
/// own Dart type; that is exactly the class of on-screen leak D6 forbids,
/// full stop, including in this fallback path) and logs the object itself
/// to the debug console instead, so the diagnostic detail still exists
/// somewhere, just not on the glass the user is looking at.
///
/// 🔴 Nothing in this file (not even a debug-only log line) may read the
/// object's own Dart-type reflection field — the ADR-0017 D10 source scan
/// bans that specific token everywhere under `presentation/`, with no
/// debug-only carve-out, precisely so no one re-adds a variant of the
/// on-screen leak this function replaces. Log `error` itself (its
/// `toString()`), not that.
AuthErrorDisplay? authErrorDisplayFor(Object? error) => switch (error) {
  null => null,
  AuthException e => authErrorDisplay(e),
  _ => _unhandled(error),
};

AuthErrorDisplay _unhandled(Object error) {
  if (kDebugMode) {
    developer.log(
      'unhandled error reached authErrorDisplayFor: $error',
      name: 'auth-error-display',
    );
  }
  return (message: AppStrings.authErrorGeneric, code: 'unhandled_error');
}

const _authMessages = <String, String>{
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
  // Transport/server codes thrown by BackendAuthDataSource._guard and
  // AuthRepositoryImpl — not Firebase codes, but this feature's table is the
  // one place all of this feature's `code`s map to Thai (D9).
  'network_error': AppStrings.authErrorNetwork,
  'server_error': AppStrings.authErrorServer,
};
