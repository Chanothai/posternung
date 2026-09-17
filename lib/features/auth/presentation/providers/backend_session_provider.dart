import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/diagnostics/startup_trace.dart';
import '../../../../core/error/auth_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/session_expiry.dart';
import '../../../../core/network/token_storage.dart';
import '../../data/datasources/backend_auth_data_source.dart';
import '../../data/datasources/email_password_sign_in_data_source.dart';
import '../../data/datasources/google_sign_in_data_source.dart';
import '../../data/datasources/phone_sign_in_data_source.dart';
import '../../domain/entities/auth_user.dart';

final googleSignInDataSourceProvider = Provider<GoogleSignInDataSource>(
  // `FirebaseAuth.instance` directly (not via `firebaseAuthProvider` in
  // auth_providers.dart) to avoid a circular import — it's the same singleton.
  (ref) => GoogleSignInDataSourceImpl(FirebaseAuth.instance),
);

final emailPasswordSignInDataSourceProvider =
    Provider<EmailPasswordSignInDataSource>(
      // Same direct-`FirebaseAuth.instance` pattern as the Google provider.
      (ref) => EmailPasswordSignInDataSourceImpl(FirebaseAuth.instance),
    );

final phoneSignInDataSourceProvider = Provider<PhoneSignInDataSource>(
  // Same direct-`FirebaseAuth.instance` pattern as the other two providers.
  (ref) => PhoneSignInDataSourceImpl(FirebaseAuth.instance),
);

final backendAuthDataSourceProvider = Provider<BackendAuthDataSource>(
  (ref) => BackendAuthDataSourceImpl(ref.watch(dioProvider)),
);

/// The backend JWT session for every sign-in method (email/password,
/// register, Google, phone) — each signs in with Firebase first, then
/// exchanges the Firebase ID token at `/auth/firebase`. Holds the current
/// [AuthUser] or `null` when there's no backend session. This is the app's
/// only definition of "logged in" (ADR-0021 D1) — `sessionProvider` is a
/// thin alias over this notifier, not a merge with anything else. Firebase
/// also keeps its own session as a side effect of every sign-in call here,
/// but it is an intermediate step toward the exchange below, not a second
/// source of truth.
class BackendSessionNotifier extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() {
    // AuthInterceptor bumps this on some later authenticated call when the
    // session can't be recovered client-side — see its class doc comment
    // (core/network/auth_interceptor.dart) for the closed table of exactly
    // which three situations that is; not repeated here (one rule, one
    // place to read it). React the same way an explicit sign-out does, so
    // sessionProvider/AuthGate drop back to the login screen without a
    // manual signOut() call.
    ref.listen(sessionExpiryProvider, (previous, next) {
      if (previous != null && next != previous) {
        // INF-40 step 1: trace only — fired on the same branch that flips
        // state, not on every provider tick.
        StartupTrace.sessionExpiryFired();
        state = const AsyncData(null);
      }
    });
    return _restore();
  }

  /// On startup: validate any stored access token against `/auth/me`. A
  /// transient infra failure (`network_error`/`server_error`) leaves tokens
  /// intact (logged out for now, restore on a later launch); any other
  /// failure means the access token is bad → try a single `/auth/refresh`
  /// before clearing.
  Future<AuthUser?> _restore() async {
    // INF-40 step 1: trace only, from here to every `return` below — see
    // `StartupTrace.restoreEnd`'s doc comment for why there is no `status=`
    // field (round 2 correction — a field that could only ever be `null`
    // was worse than no field at all).
    final startMs = StartupTrace.restoreStart();
    final storage = ref.read(tokenStorageProvider);
    final backend = ref.read(backendAuthDataSourceProvider);

    final accessToken = await storage.readAccessToken();
    if (accessToken == null) {
      StartupTrace.restoreEnd(
        outcome: RestoreOutcome.nullNoToken,
        elapsed: Duration(milliseconds: StartupTrace.elapsedMs() - startMs),
      );
      return null;
    }

    try {
      StartupTrace.authMeSent(attempt: AuthMeAttempt.first);
      final user = await backend.getMe(accessToken);
      StartupTrace.restoreEnd(
        outcome: RestoreOutcome.user,
        elapsed: Duration(milliseconds: StartupTrace.elapsedMs() - startMs),
      );
      return user.toEntity();
    } on AuthException catch (e) {
      if (e.code == 'network_error' || e.code == 'server_error') {
        StartupTrace.restoreEnd(
          outcome: RestoreOutcome.nullInfra,
          elapsed: Duration(milliseconds: StartupTrace.elapsedMs() - startMs),
        );
        return null;
      }
      return _refreshAndRetry(storage, backend, startMs);
    }
  }

  Future<AuthUser?> _refreshAndRetry(
    TokenStorage storage,
    BackendAuthDataSource backend,
    int startMs,
  ) async {
    final refreshToken = await storage.readRefreshToken();
    if (refreshToken == null) {
      await storage.clear();
      StartupTrace.restoreEnd(
        outcome: RestoreOutcome.nullCleared,
        elapsed: Duration(milliseconds: StartupTrace.elapsedMs() - startMs),
      );
      return null;
    }
    try {
      final tokens = await backend.refresh(refreshToken);
      await storage.save(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      StartupTrace.authMeSent(attempt: AuthMeAttempt.retry);
      final user = await backend.getMe(tokens.accessToken);
      StartupTrace.restoreEnd(
        outcome: RestoreOutcome.user,
        elapsed: Duration(milliseconds: StartupTrace.elapsedMs() - startMs),
      );
      return user.toEntity();
    } on AuthException catch (e) {
      // INF-45 AC-5 — same guard as `_restore()` above: a transient infra
      // failure (`network_error`/`server_error`) on either `refresh()` or
      // the retried `getMe()` is not proof the refresh token was rejected.
      // Before this guard, a token expiring right as the network dropped
      // (refresh itself times out, or the retried `/auth/me` does) cleared
      // a perfectly good refresh token — the same class of bug `INF-45`
      // fixed in `AuthInterceptor`, just on this feature's own hand-rolled
      // startup path (the two are independent: this method predates and
      // does not go through the interceptor at all — see this class's own
      // doc comment).
      if (e.code == 'network_error' || e.code == 'server_error') {
        StartupTrace.restoreEnd(
          outcome: RestoreOutcome.nullInfra,
          elapsed: Duration(milliseconds: StartupTrace.elapsedMs() - startMs),
        );
        return null;
      }
      await storage.clear();
      StartupTrace.restoreEnd(
        outcome: RestoreOutcome.nullCleared,
        elapsed: Duration(milliseconds: StartupTrace.elapsedMs() - startMs),
      );
      return null;
    }
  }

  /// Google account picker → Firebase ID token → `/auth/firebase`. Throws
  /// `AuthCancelledException` if the user dismisses the picker (handled
  /// silently by `AuthViewModel._runSocial`); on success the new user is
  /// published and `AuthGate` advances.
  Future<void> signInWithGoogle() async {
    final idToken = await ref.read(googleSignInDataSourceProvider).getIdToken();
    await _exchangeAndPublish(idToken);
  }

  /// Firebase email/password sign-in → Firebase ID token → `/auth/firebase`.
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final idToken = await ref
        .read(emailPasswordSignInDataSourceProvider)
        .signIn(email: email, password: password);
    await _exchangeAndPublish(idToken);
  }

  /// Firebase account creation, followed by a verification email
  /// (ADR-0021 D2). Deliberately does **not** exchange with the backend —
  /// the `password` provider requires `email_verified=true`
  /// (ADR-0004 §4), so exchanging right after creation would always 403.
  /// The exchange happens later, from [checkEmailVerifiedAndContinue], once
  /// the user has actually verified.
  ///
  /// 🔴 No rollback on failure any more (ADR-0021 D2, reversing the previous
  /// behavior documented below): an unverified Firebase account left behind
  /// mid-flow is a normal, expected state now, not orphaned garbage — the
  /// backend find-or-creates on the eventual exchange either way (ADR-0004
  /// §3 layer 4), and deleting it out from under a user who is mid-way
  /// through checking their inbox would silently invalidate the
  /// verification link `sendEmailVerification` just sent.
  Future<void> registerWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final emailPassword = ref.read(emailPasswordSignInDataSourceProvider);
    await emailPassword.register(email: email, password: password);
    await emailPassword.sendEmailVerification();
  }

  /// Resends the verification email to the currently signed-in (but not yet
  /// verified) Firebase user (ADR-0021 D2). The 60-second app-side cooldown
  /// is the UI's job (`EmailVerificationScreen`) — Firebase throttles resend
  /// requests silently, so without a cooldown a tap here can look like
  /// nothing happened with no way to tell why.
  Future<void> resendVerificationEmail() =>
      ref.read(emailPasswordSignInDataSourceProvider).sendEmailVerification();

  /// Reloads the Firebase user and, if their email is verified now,
  /// exchanges a fresh (force-refreshed) ID token at `/auth/firebase` to
  /// establish the backend session — the step ADR-0021 D2 gates on
  /// `email_verified`. Returns whether the email is verified: `false` means
  /// "not yet", which the caller must not treat as an error.
  Future<bool> checkEmailVerifiedAndContinue() async {
    final emailPassword = ref.read(emailPasswordSignInDataSourceProvider);
    final verified = await emailPassword.reloadAndCheckEmailVerified();
    if (!verified) return false;
    final idToken = await emailPassword.currentIdToken();
    await _exchangeAndPublish(idToken);
    return true;
  }

  /// Starts phone verification. Returns the result so the caller (e.g.
  /// `LoginScreen`) can decide whether to show the OTP entry screen
  /// ([SmsCodeSent]) or the session is already established
  /// ([PhoneAutoVerified] — Android silently verified the device). Pass
  /// [resendToken] (from a previous [SmsCodeSent]) on resend, or Firebase
  /// sends no second SMS.
  Future<PhoneVerificationResult> sendPhoneCode(
    String phoneNumber, {
    int? resendToken,
  }) async {
    final result = await ref
        .read(phoneSignInDataSourceProvider)
        .sendCode(phoneNumber, resendToken: resendToken);
    if (result is PhoneAutoVerified) {
      await _exchangeAndPublish(result.idToken);
    }
    return result;
  }

  /// Confirms the SMS code → Firebase ID token → `/auth/firebase`.
  Future<void> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final idToken = await ref
        .read(phoneSignInDataSourceProvider)
        .confirmCode(verificationId: verificationId, smsCode: smsCode);
    await _exchangeAndPublish(idToken);
  }

  /// Exchange a Firebase ID token at `/auth/firebase`, persist the returned
  /// backend tokens, load the user via `/auth/me`, and publish the session.
  /// Shared by Google / email-password / register.
  Future<void> _exchangeAndPublish(String idToken) async {
    final backend = ref.read(backendAuthDataSourceProvider);
    final storage = ref.read(tokenStorageProvider);

    // No token logging here, debug build or not — `security-baseline` §2 /
    // ADR-0017 OD-2 forbid it even under a `kDebugMode` guard. (This used to
    // print the raw Firebase ID token for pasting into Postman/curl; that
    // convenience is gone on purpose.)

    final tokens = await backend.firebaseLogin(idToken);
    await storage.save(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    final user = await backend.getMe(tokens.accessToken);
    state = AsyncData(user.toEntity());
  }

  /// Best-effort revoke, then an unconditional local clear. The revoke can
  /// only fail from offline/server trouble — the endpoint is idempotent by
  /// contract (unknown/expired/already-revoked tokens still answer 204) — so
  /// a failure here must never block the local sign-out; worst case the
  /// refresh token just lives out its natural expiry server-side instead of
  /// dying immediately. Read the refresh token *before* clearing: once
  /// storage is cleared there's nothing left to identify the session with.
  Future<void> signOut() async {
    final storage = ref.read(tokenStorageProvider);
    final refreshToken = await storage.readRefreshToken();
    if (refreshToken != null) {
      try {
        await ref.read(backendAuthDataSourceProvider).logout(refreshToken);
      } on AuthException {
        // Offline sign-out is normal — fall through to the local clear.
      }
    }
    await storage.clear();
    state = const AsyncData(null);
  }
}

final backendSessionProvider =
    AsyncNotifierProvider<BackendSessionNotifier, AuthUser?>(
      BackendSessionNotifier.new,
      // 🔴 ADR-0036 **D2** — no automatic retry.
      //
      // Riverpod 3 retries a `build()` that throws on its own, with a
      // backoff ladder that reached **~38 seconds** on the failing session
      // path. Through the whole ladder the state is
      // `AsyncLoading(error: …, retrying: true)` — **not** `AsyncError` — so
      // any `.when()` that checks `isLoading` first keeps returning the
      // spinner. The user sits in front of a spinner for over half a minute
      // while the app already knows the session failed.
      //
      // This is the convention this repo already set, not a new policy:
      // `poster_providers.dart:84` and `home_posters_provider.dart:167` both
      // disable it, for this same reason.
      //
      // Wanted consequence, not a side effect: a `PlatformException` out of
      // `flutter_secure_storage` now reaches the screen directly instead of
      // vanishing into the ladder. Whether storage-unreadable *should* read
      // as "error" or as "not signed in" is deliberately still open
      // (ADR-0036 **OD-3**) — seeing it beats losing it either way.
      //
      // 🔴 This is **not** an app-wide `retry:` policy. `ProviderScope(retry:)`
      // stays unset; that one belongs to INF-05/BL-58 per ADR-0023 D8.1, and
      // INF-05 may absorb this line when it lands.
      retry: (retryCount, error) => null,
    );
