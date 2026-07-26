import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/auth_cancelled_exception.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/datasources/phone_sign_in_data_source.dart';
import '../../domain/usecases/sign_in_with_apple.dart';
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

final signInWithAppleProvider = Provider(
  (ref) => SignInWithApple(ref.watch(authRepositoryProvider)),
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

  Future<void> signInWithApple() =>
      _runSocial(() => ref.read(signInWithAppleProvider)());

  /// Clears both sessions — the active one signs the user out, the other is
  /// already empty and clears harmlessly.
  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(signOutProvider)();
      await ref.read(backendSessionProvider.notifier).signOut();
    });
  }

  /// Social sign-in can be aborted by the user (native account picker /
  /// Apple sheet). That surfaces as `AuthCancelledException`, which is not a
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
