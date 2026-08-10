import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/auth_cancelled_exception.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/datasources/phone_sign_in_data_source.dart';
import '../../domain/usecases/sign_out.dart';
import 'backend_session_provider.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSourceImpl(ref.watch(firebaseAuthProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider)),
);

final authStateChangesProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

final signOutProvider = Provider(
  (ref) => SignOut(ref.watch(authRepositoryProvider)),
);

/// Drives the login/register form's submit lifecycle. `state.isLoading` and
/// `state.hasError` cover what used to be local `_isSubmitting`/
/// `_errorMessage` fields. On success there's nothing to store — the backend
/// JWT session (established for email/password + Google via `/auth/firebase`)
/// is published by `backendSessionProvider` and picked up by `sessionProvider`,
/// which `AuthGate` reacts to directly.
class AuthViewModel extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(backendSessionProvider.notifier)
          .signInWithEmailPassword(email: email, password: password),
    );
  }

  Future<void> signUp({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(backendSessionProvider.notifier)
          .registerWithEmailPassword(email: email, password: password),
    );
  }

  Future<void> signInWithGoogle() => _runSocial(
    () => ref.read(backendSessionProvider.notifier).signInWithGoogle(),
  );

  /// Starts phone verification. Returns `null` on failure (check
  /// `state.hasError`, same idiom as `signIn`/`signUp`) — otherwise the
  /// result tells the caller whether to show the OTP screen
  /// ([SmsCodeSent]) or the session is already established
  /// ([PhoneAutoVerified]). Pass [resendToken] on resend, or Firebase sends
  /// no second SMS.
  Future<PhoneVerificationResult?> sendPhoneCode(
    String phoneNumber, {
    int? resendToken,
  }) async {
    state = const AsyncLoading();
    PhoneVerificationResult? result;
    state = await AsyncValue.guard(() async {
      result = await ref
          .read(backendSessionProvider.notifier)
          .sendPhoneCode(phoneNumber, resendToken: resendToken);
    });
    return result;
  }

  Future<void> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(backendSessionProvider.notifier)
          .confirmPhoneCode(verificationId: verificationId, smsCode: smsCode),
    );
  }

  /// Resends the verification email to the currently pending Firebase
  /// account (ADR-0021 D2). `state.hasError` after this means the resend
  /// itself failed — the caller must not treat that as "not verified yet".
  Future<void> resendVerificationEmail() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(backendSessionProvider.notifier).resendVerificationEmail(),
    );
  }

  /// Checks whether the pending account's email is verified now, and — if
  /// so — completes the deferred `/auth/firebase` exchange
  /// (ADR-0021 D2). Returns `false` for "not verified yet", which is not an
  /// error; check `state.hasError` separately for an actual failure (e.g.
  /// the reload or the exchange itself failing).
  Future<bool> checkEmailVerifiedAndContinue() async {
    state = const AsyncLoading();
    bool verified = false;
    state = await AsyncValue.guard(() async {
      verified = await ref
          .read(backendSessionProvider.notifier)
          .checkEmailVerifiedAndContinue();
    });
    return verified;
  }

  /// Drops a stale error left in `state` — e.g. a failed OTP attempt whose
  /// banner must not still be showing once the user backs out to
  /// `LoginScreen`, which watches this same provider. A no-op when there's
  /// nothing to clear, so it's safe to call unconditionally on return.
  void clearError() {
    if (state.hasError) state = const AsyncData(null);
  }

  /// Clears both sessions — the active one signs the user out, the other is
  /// already empty and clears harmlessly. The backend clear runs in `finally`
  /// so a Firebase sign-out failure can never leave backend JWTs on disk
  /// with `sessionProvider` still reporting authenticated; the original
  /// error still propagates to `state` via `AsyncValue.guard`.
  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        await ref.read(signOutProvider)();
      } finally {
        await ref.read(backendSessionProvider.notifier).signOut();
      }
    });
  }

  /// Social sign-in can be aborted by the user (the native account picker).
  /// That surfaces as `AuthCancelledException`, which is not a
  /// failure — reset to idle silently rather than showing an error. Can't
  /// use `AsyncValue.guard` here because it would capture the cancellation
  /// as an error state.
  Future<void> _runSocial(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
    } on AuthCancelledException {
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

final authViewModelProvider = AsyncNotifierProvider<AuthViewModel, void>(
  AuthViewModel.new,
);
