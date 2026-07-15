import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/auth_cancelled_exception.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/sign_in_with_apple.dart';
import '../../domain/usecases/sign_in_with_email_password.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/sign_up_with_email_password.dart';

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

final signInWithEmailPasswordProvider = Provider(
  (ref) => SignInWithEmailPassword(ref.watch(authRepositoryProvider)),
);

final signUpWithEmailPasswordProvider = Provider(
  (ref) => SignUpWithEmailPassword(ref.watch(authRepositoryProvider)),
);

final signInWithGoogleProvider = Provider(
  (ref) => SignInWithGoogle(ref.watch(authRepositoryProvider)),
);

final signInWithAppleProvider = Provider(
  (ref) => SignInWithApple(ref.watch(authRepositoryProvider)),
);

final signOutProvider = Provider(
  (ref) => SignOut(ref.watch(authRepositoryProvider)),
);

/// Drives the login/register form's submit lifecycle. `state.isLoading` and
/// `state.hasError` cover what used to be local `_isSubmitting`/
/// `_errorMessage` fields. On success there's nothing to store — Firebase's
/// own auth-state stream (`authStateChangesProvider`) picks up the new user
/// and `AuthGate` reacts to that directly.
class AuthViewModel extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(signInWithEmailPasswordProvider)(
        email: email,
        password: password,
      ),
    );
  }

  Future<void> signUp({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(signUpWithEmailPasswordProvider)(
        email: email,
        password: password,
      ),
    );
  }

  Future<void> signInWithGoogle() =>
      _runSocial(() => ref.read(signInWithGoogleProvider)());

  Future<void> signInWithApple() =>
      _runSocial(() => ref.read(signInWithAppleProvider)());

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(signOutProvider)());
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
