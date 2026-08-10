import 'package:firebase_auth/firebase_auth.dart' as firebase;

import '../../../../core/error/auth_exception.dart';
import '../../../../core/error/debug_log.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remoteDataSource);

  final AuthRemoteDataSource _remoteDataSource;

  @override
  Future<void> signOut() async {
    try {
      await _remoteDataSource.signOut();
    } on firebase.FirebaseAuthException catch (e) {
      // `e.message` is Firebase's own English diagnostic text, never a
      // display string (ADR-0017 D2) — debug-only.
      throw AuthException(
        code: e.code,
        debugDetail: logDebugDetail(e.message, source: 'auth_repo_signout'),
      );
    } catch (_) {
      throw const AuthException(code: 'unknown');
    }
  }

  @override
  Stream<AuthUser?> get authStateChanges => _remoteDataSource.authStateChanges
      .map((user) => user == null ? null : _mapUser(user));

  AuthUser _mapUser(firebase.User user) =>
      AuthUser(uid: user.uid, email: user.email);
}
