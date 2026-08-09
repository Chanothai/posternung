import 'backend_envelope.dart';

/// Domain-level exception for auth failures. Data-layer repositories catch
/// SDK-specific exceptions (e.g. `FirebaseAuthException`) and rethrow this
/// instead, so nothing above the repository boundary depends on Firebase.
///
/// 🔴 One caveat to that, since Amendment 1: this file's sibling,
/// `backend_envelope.dart`, depends on `package:dio` — parsing a backend
/// envelope means parsing a `DioException` (A1-D2). That dependency stays
/// inside `core/error/` and never reaches `presentation/` through this
/// class's public surface (no `Dio` symbol is importable from here), but it
/// means the older, stronger claim — "nothing above the repository boundary
/// depends on Dio" — is no longer literally true at the *library-graph*
/// level, only at the *symbol* level. Don't repeat the stronger claim
/// elsewhere without this qualifier.
///
/// Three separate fields (ADR-0017 D1) — a single `message` used to do both
/// jobs at once, which is what let raw SDK/Dio text reach the screen:
///
/// - [code] — required, a fixed string written at the `throw` site. Never
///   composed from `runtimeType` (D6) — see `presentation/auth_error_display.dart`
///   for how it becomes a Thai line on screen.
/// - [displayMessage] — nullable. Not a parameter of the public constructor
///   at all (Amendment 1 A1-D1) — the only way to populate it is
///   [AuthException.fromEnvelope], which takes a [BackendErrorEnvelope] that
///   itself can only have come from [backendErrorEnvelopeOf]. Every other
///   guard leaves it `null` and lets the presentation-layer mapper fall
///   back to a static `AppStrings` constant instead.
/// - [debugDetail] — nullable, **never rendered** (D7). Where an SDK's own
///   message (`FirebaseAuthException.message`, `GoogleSignInException
///   .description`, ...) or a raw `e.toString()` goes instead. Reaches the
///   world only via a `kDebugMode`-guarded log line, never a widget. The
///   *caller* is still the one responsible for running it through
///   `debug_log.dart`'s helper before handing it to either constructor here
///   (Amendment 1 OD-A) — neither constructor does that wrapping itself.
class AuthException implements Exception {
  const AuthException({required this.code, this.debugDetail})
    : displayMessage = null;

  /// The only legal way to populate [displayMessage] (ADR-0017 D2, Amendment
  /// 1 A1-D1). [env] can only have come from [backendErrorEnvelopeOf], so
  /// there is no expression anywhere else that can fabricate one — the gate
  /// is the type, not a convention.
  AuthException.fromEnvelope(BackendErrorEnvelope env, {this.debugDetail})
    : code = env.code,
      displayMessage = env.displayMessage;

  final String code;
  final String? displayMessage;
  final String? debugDetail;

  @override
  String toString() => 'AuthException(code: $code)';
}
