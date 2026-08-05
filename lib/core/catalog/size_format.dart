/// The `size_format` classification — a standard poster size *format*
/// mapped from a confirmed measurement (ADR-0009 §D4). Pure Dart, no
/// Flutter import — same shape as `poster_condition_grade.dart`.
///
/// Lives in `core/catalog/` rather than under `features/poster/` because
/// SCR-04 (US-02's filter, not yet built) will use this exact type —
/// ADR-0011 §D5.
enum SizeFormat { oneSheet, halfSheet, insert, quad, other, unknown }

/// Display/interop metadata for [SizeFormat].
extension SizeFormatX on SizeFormat {
  /// Collector vocabulary, English — deliberately not translated, same
  /// reasoning as `PosterConditionGrade.label` (ADR-0011 §D5).
  ///
  /// 🔴 **Never append an inch measurement to this label** (e.g.
  /// `"One-Sheet (27x40 นิ้ว)"`) — ADR-0009 §D4 states there is no measured
  /// size backing this field yet (`width_in`/`height_in` are reserved but
  /// not built), so printing a number here would claim a measurement that
  /// never happened.
  String get label => switch (this) {
    SizeFormat.oneSheet => 'One-Sheet',
    SizeFormat.halfSheet => 'Half-Sheet',
    SizeFormat.insert => 'Insert',
    SizeFormat.quad => 'Quad',
    SizeFormat.other => 'Other',
    SizeFormat.unknown => 'ตรวจแล้วระบุไม่ได้',
  };

  /// The wire value used by `posternung-backend`'s `SizeFormat` enum
  /// (`GET /posters/{poster_id}`'s `size_format` field) — UPPERCASE, per
  /// ADR-0009 §D1.
  String get apiValue => switch (this) {
    SizeFormat.oneSheet => 'ONE_SHEET',
    SizeFormat.halfSheet => 'HALF_SHEET',
    SizeFormat.insert => 'INSERT',
    SizeFormat.quad => 'QUAD',
    SizeFormat.other => 'OTHER',
    SizeFormat.unknown => 'UNKNOWN',
  };
}

/// Parses the backend's `size_format` wire value. Returns `null` for a
/// `null` input **and** for any value this client doesn't recognize
/// (ADR-0011 §D6) — a descriptive field degrades to "row hidden" instead
/// of crashing the whole screen.
SizeFormat? sizeFormatFromApi(String? value) {
  if (value == null) return null;
  for (final format in SizeFormat.values) {
    if (format.apiValue == value) return format;
  }
  return null;
}
