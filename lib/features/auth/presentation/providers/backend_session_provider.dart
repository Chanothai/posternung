import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/auth_exception.dart';
import '../../../../core/network/api_client.dart';
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

/// The backend JWT session for every Firebase-mediated sign-in
/// (email/password, register, Google, phone) — each signs in with Firebase,
/// then exchanges the Firebase ID token at `/auth/firebase`. Holds the current
/// [AuthUser] or `null` when there's no backend session. Firebase also keeps
/// its own session as a side effect (used by Apple); `sessionProvider` merges
/// the two.
class BackendSessionNotifier extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() => _restore();

  /// On startup: validate any stored access token against `/auth/me`. A
  /// transient infra failure (`network_error`/`server_error`) leaves tokens
  /// intact (logged out for now, restore on a later launch); any other
  /// failure means the access token is bad → try a single `/auth/refresh`
  /// before clearing.
  Future<AuthUser?> _restore() async {
    final storage = ref.read(tokenStorageProvider);
    final backend = ref.read(backendAuthDataSourceProvider);

    final accessToken = await storage.readAccessToken();
    if (accessToken == null) return null;

    try {
      final user = await backend.getMe(accessToken);
      return user.toEntity();
    } on AuthException catch (e) {
      if (e.code == 'network_error' || e.code == 'server_error') return null;
      return _refreshAndRetry(storage, backend);
    }
  }

  Future<AuthUser?> _refreshAndRetry(
    TokenStorage storage,
    BackendAuthDataSource backend,
  ) async {
    final refreshToken = await storage.readRefreshToken();
    if (refreshToken == null) {
      await storage.clear();
      return null;
    }
    try {
      final tokens = await backend.refresh(refreshToken);
      await storage.save(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      final user = await backend.getMe(tokens.accessToken);
      return user.toEntity();
    } on AuthException {
      await storage.clear();
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

  /// Firebase account creation → Firebase ID token → `/auth/firebase`. The
  /// backend find-or-creates its own user record on first exchange.
  Future<void> registerWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final idToken = await ref
        .read(emailPasswordSignInDataSourceProvider)
        .register(email: email, password: password);
    await _exchangeAndPublish(idToken);
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

    final tokens = await backend.firebaseLogin(idToken);
    await storage.save(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    final user = await backend.getMe(tokens.accessToken);
    state = AsyncData(user.toEntity());
  }

  Future<void> signOut() async {
    await ref.read(tokenStorageProvider).clear();
    state = const AsyncData(null);
  }
}

final backendSessionProvider =
    AsyncNotifierProvider<BackendSessionNotifier, AuthUser?>(
      BackendSessionNotifier.new,
    );
