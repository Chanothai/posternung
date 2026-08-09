import 'backend_envelope.dart';

/// Domain-level exception for catalog (poster) failures. Data-layer
/// datasources/repositories catch SDK-specific exceptions (e.g.
/// `DioException`) and rethrow this instead, so nothing above the
/// repository boundary depends on Dio — same pattern as `AuthException`,
/// including the three-field split (ADR-0017 D1) and the Amendment 1 gate on
/// [displayMessage]; see that class's doc comment for what each field is for
/// and why `message` was removed rather than kept as a fourth field, and for
/// the one caveat Amendment 1 puts on the "nothing depends on Dio" claim.
class CatalogException implements Exception {
  const CatalogException({required this.code, this.debugDetail})
    : displayMessage = null;

  /// The only legal way to populate [displayMessage] (ADR-0017 D2, Amendment
  /// 1 A1-D1) — see `AuthException.fromEnvelope`'s doc comment; identical
  /// mechanism.
  CatalogException.fromEnvelope(BackendErrorEnvelope env, {this.debugDetail})
    : code = env.code,
      displayMessage = env.displayMessage;

  final String code;
  final String? displayMessage;
  final String? debugDetail;

  @override
  String toString() => 'CatalogException(code: $code)';
}
