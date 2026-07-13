import 'package:firebase_auth/firebase_auth.dart' as firebase;

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
  }) async {
    try {
      final user = await _remoteDataSource.signIn(
        email: email,
        password: password,
      );
      return _mapUser(user);
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
  Future<AuthUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _remoteDataSource.signUp(
        email: email,
        password: password,
      );
      return _mapUser(user);
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

  AuthUser _mapUser(firebase.User user) =>
      AuthUser(uid: user.uid, email: user.email);
}
