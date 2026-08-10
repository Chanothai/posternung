import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the `posternung-backend` JWT session (access + refresh tokens)
/// in the platform keychain/keystore via `flutter_secure_storage`.
///
/// Written by **every** sign-in path — Google, email/password, and phone all
/// exchange their Firebase ID token at `/auth/firebase` and land here. Since
/// ADR-0021 D1 this session is also the only thing `sessionProvider` counts as
/// being signed in, so an empty store means signed out no matter what Firebase
/// thinks. `ApiClient` reads the access token here to authorize backend calls.
class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'backend_access_token';
  static const _refreshTokenKey = 'backend_refresh_token';

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(const FlutterSecureStorage()),
);
