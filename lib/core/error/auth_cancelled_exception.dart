/// Signals that the user aborted a sign-in flow (e.g. dismissed the Google
/// account picker or the Apple sheet). This is a normal outcome, not a
/// failure — the presentation layer treats it silently and shows no error.
/// Kept distinct from `AuthException`, which is reserved for real,
/// user-showable failures.
class AuthCancelledException implements Exception {
  const AuthCancelledException();

  @override
  String toString() => 'AuthCancelledException';
}
