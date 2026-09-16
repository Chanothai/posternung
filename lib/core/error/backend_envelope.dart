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
  const BackendErrorEnvelope._(
    this.code,
    this.displayMessage,
    this.details,
    this.typedDetails,
    this.retryAfterSeconds,
  );

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
  ///
  /// 🔴 **Still true for the raw string, unchanged (ADR-0017 Amendment 2)** —
  /// what changed is that the *parsed* form of the same data is now also
  /// available as [typedDetails], for the codes `ADR-0037` A2-D2 guarantees
  /// carry machine values rather than prose in `details[].message`. Reading
  /// [typedDetails] is not rendering it; see [OrderException] (`order_
  /// exception.dart`) for the one place that turns specific rows into typed
  /// fields a screen may show.
  final String? details;

  /// `details[]` split into `(field, message)` rows, both still `String`
  /// (ADR-0017 Amendment 2 A2-D2) — `field` is the row's key, `message` is
  /// the row's raw value (prose on `VALIDATION_ERROR`, a machine value on
  /// every other code per `ADR-0037` A2-D2). Empty (never `null`) when
  /// `details` is absent, not a JSON array, or `null`; an entry whose shape
  /// doesn't match (missing `field`/`message`, or either not a `String`) is
  /// skipped rather than making parsing throw.
  final List<({String field, String message})> typedDetails;

  /// Parsed from the `Retry-After` response header, in seconds — a 429
  /// sends this instead of a `details` row (`ADR-0037` A2-D2: `details` is
  /// `null` on a rate-limit response). `null` when the header is absent or
  /// isn't a plain integer.
  final int? retryAfterSeconds;
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
      _typedDetailsOf(data['details']),
      _retryAfterSecondsOf(e),
    );
  }
  return null;
}

/// See [BackendErrorEnvelope.typedDetails] — malformed rows are skipped, a
/// non-list/`null` `details` yields `const []`, never a throw.
List<({String field, String message})> _typedDetailsOf(Object? details) {
  if (details is! List) return const [];
  final rows = <({String field, String message})>[];
  for (final entry in details) {
    if (entry is Map &&
        entry['field'] is String &&
        entry['message'] is String) {
      rows.add((
        field: entry['field'] as String,
        message: entry['message'] as String,
      ));
    }
  }
  return rows;
}

/// See [BackendErrorEnvelope.retryAfterSeconds]. Reads the header's raw
/// value list rather than `Headers.value()` — the latter throws if a
/// header ever has more than one value, which would turn a header-shape
/// surprise into a crash instead of the `null` this function promises.
int? _retryAfterSecondsOf(DioException e) {
  final values = e.response?.headers['Retry-After'];
  if (values == null || values.isEmpty) return null;
  return int.tryParse(values.first);
}
