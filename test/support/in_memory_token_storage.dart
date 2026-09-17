import 'package:posternung/core/network/token_storage.dart';

/// `TokenStorage` without the keychain — same API, and it remembers whether
/// anything cleared it.
///
/// Moved here from `test/features/onboarding/onboarding_session_entry_test
/// .dart` (INF-45) so `test/features/poster/presentation/widgets/poster_buy_
/// now_button_test.dart` can share it instead of hand-rolling a second copy
/// — both need a real (not mocked) `TokenStorage` that a real `dioProvider`
/// chain can read from and write to, backed by plain fields rather than
/// `mocktail` stubs.
class InMemoryTokenStorage implements TokenStorage {
  // Named parameters cannot be private in Dart, so these are plain public
  // fields — `prefer_initializing_formals` has no other shape to offer here.
  InMemoryTokenStorage({required this.accessToken, required this.refreshToken});

  String? accessToken;
  String? refreshToken;

  /// Whether [clear] was ever called — the fact a signed-out-by-mistake user
  /// would feel, and the one a state assertion can miss entirely because a
  /// still-running restore can write the session back afterwards.
  bool cleared = false;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    cleared = true;
    accessToken = null;
    refreshToken = null;
  }
}
