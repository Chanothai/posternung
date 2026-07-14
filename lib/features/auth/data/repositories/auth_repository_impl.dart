import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../core/error/auth_cancelled_exception.dart';
import '../../../../core/error/auth_exception.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remoteDataSource);

  final AuthRemoteDataSource _remoteDataSource;

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) =>
      _guard(() => _remoteDataSource.signIn(email: email, password: password));

  @override
  Future<AuthUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) =>
      _guard(() => _remoteDataSource.signUp(email: email, password: password));

  @override
  Future<AuthUser> signInWithGoogle() =>
      _guard(_remoteDataSource.signInWithGoogle);

  @override
  Future<AuthUser> signInWithApple() =>
      _guard(_remoteDataSource.signInWithApple);

  @override
  Future<void> signOut() async {
    try {
      await _remoteDataSource.signOut();
    } on firebase.FirebaseAuthException catch (e) {
      throw AuthException(code: e.code, message: e.message ?? e.code);
    } catch (_) {
      throw const AuthException(
        code: 'unknown',
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  @override
  Stream<AuthUser?> get authStateChanges => _remoteDataSource.authStateChanges
      .map((user) => user == null ? null : _mapUser(user));

  /// Runs [action] and maps every SDK-specific failure to a domain-level
  /// exception: user-initiated cancellations become `AuthCancelledException`
  /// (silent), everything else becomes `AuthException`.
  Future<AuthUser> _guard(Future<firebase.User> Function() action) async {
    try {
      return _mapUser(await action());
    } on AuthCancelledException {
      rethrow;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelledException();
      }
      throw AuthException(
        code: e.code.name,
        message: e.description ?? e.code.name,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AuthCancelledException();
      }
      throw AuthException(code: e.code.name, message: e.message);
    } on firebase.FirebaseAuthException catch (e) {
      throw AuthException(code: e.code, message: e.message ?? e.code);
    } catch (_) {
      throw const AuthException(
        code: 'unknown',
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  AuthUser _mapUser(firebase.User user) =>
      AuthUser(uid: user.uid, email: user.email);
}
