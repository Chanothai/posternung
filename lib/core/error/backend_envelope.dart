import 'package:dio/dio.dart';

/// The one legal source of `AuthException`/`CatalogException.displayMessage`
/// (ADR-0017 D2, Amendment 1 A1-D1): the backend's own
/// `{error_code, message, details}` envelope, parsed from a real
/// [DioException]'s response — never assembled from an arbitrary string.
///
/// The constructor is deliberately private (`._`) and lives in this same
/// file as [backendErrorEnvelopeOf] (Amendment 1 A1-D3): a record shape like
/// `({String code, String? displayMessage})` would let anyone compose a
/// look-alike value and pass it to `.fromEnvelope()`, because Dart records
/// are structurally typed — there is no way to make a record's *shape*
/// itself the gate. A class with a private constructor *can* be gated:
/// Dart's library privacy means only code in this file can call `._`, so
/// the only way to produce a [BackendErrorEnvelope] anywhere else in the
/// app is to go through [backendErrorEnvelopeOf].
class BackendErrorEnvelope {
  const BackendErrorEnvelope._(this.code, this.displayMessage, this.details);

  /// The backend's `error_code` — SNAKE_CASE, machine-readable.
  final String code;

  /// The backend's `message` — Thai, safe to render (ADR-0017 D2). `null`
  /// when the envelope omits the key entirely.
  ///
  /// 🔴 **Not `null` when the key is present with a non-`String` value** —
  /// the cast below (`as String?`) throws a `TypeError` in that case rather
  /// than returning `null` (verified: `type 'int' is not a subtype of type
  /// 'String?'`). This is a pre-existing hazard carried over unchanged from
  /// the two datasources this file replaced — AC-1 of this refactor forbids
  /// changing behavior, so it is documented here rather than fixed; tracked
  /// as a new backlog item per ADR-0017 Amendment 1 AC-8(ซ).
  final String? displayMessage;

  /// The backend's `details`, stringified. Never rendered (D3) — the only
  /// legal destination for this is `debugDetail`, and only after the caller
  /// runs it through `debug_log.dart`'s helper themselves; this class does
  /// not do that wrapping on anyone's behalf (Amendment 1 OD-A).
  final String? details;
}

/// Parses [e]'s response as a backend `{error_code, message, details}`
/// envelope, or returns `null` if it isn't one (connection failure,
/// gateway/non-JSON 5xx, a 4xx with no body, ...). Identical condition to
/// the one every backend-facing datasource duplicated before Amendment 1 —
/// moved here so there is exactly one implementation instead of two that
/// could silently drift apart.
BackendErrorEnvelope? backendErrorEnvelopeOf(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['error_code'] is String) {
    return BackendErrorEnvelope._(
      data['error_code'] as String,
      data['message'] as String?,
      data['details']?.toString(),
    );
  }
  return null;
}
