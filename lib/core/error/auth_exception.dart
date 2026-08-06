/// Domain-level exception for auth failures. Data-layer repositories catch
/// SDK-specific exceptions (e.g. `FirebaseAuthException`) and rethrow this
/// instead, so nothing above the repository boundary depends on Firebase.
///
/// Three separate fields (ADR-0017 D1) — a single `message` used to do both
/// jobs at once, which is what let raw SDK/Dio text reach the screen:
///
/// - [code] — required, a fixed string written at the `throw` site. Never
///   composed from `runtimeType` (D6) — see `presentation/auth_error_display.dart`
///   for how it becomes a Thai line on screen.
/// - [displayMessage] — nullable. The **only** legal source is the backend's
///   `{error_code, message}` envelope (D2); every other guard must leave it
///   `null` and let the presentation-layer mapper fall back to a static
///   `AppStrings` constant instead.
/// - [debugDetail] — nullable, **never rendered** (D7). Where an SDK's own
///   message (`FirebaseAuthException.message`, `GoogleSignInException
///   .description`, ...) or a raw `e.toString()` goes instead. Reaches the
///   world only via a `kDebugMode`-guarded log line, never a widget.
class AuthException implements Exception {
  const AuthException({
    required this.code,
    this.displayMessage,
    this.debugDetail,
  });

  final String code;
  final String? displayMessage;
  final String? debugDetail;

  @override
  String toString() => 'AuthException(code: $code)';
}
