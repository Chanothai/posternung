/// The `release_region` classification — the region a sheet was printed
/// for theatrical release (not the region it was physically *printed in*;
/// see ADR-0009 §D7, which reserves a separate `print_origin` concept for
/// that). Pure Dart, no Flutter import — same shape as
/// `poster_condition_grade.dart`.
///
/// Lives in `core/catalog/` rather than under `features/poster/` because
/// SCR-04 (US-02's filter, not yet built) will use this exact type —
/// ADR-0011 §D5.
enum ReleaseRegion { th, us, jp, uk, intl, unknown }

/// Display/interop metadata for [ReleaseRegion].
extension ReleaseRegionX on ReleaseRegion {
  /// Short region code, as shown appended to `size_format` in the poster
  /// detail subtitle (ADR-0011 §D4′ — e.g. `"US One-Sheet"`). Deliberately
  /// not spelled out to a full country name — collectors already read these
  /// short forms.
  ///
  /// 🔴 [ReleaseRegion.unknown]'s label is **never** used in the subtitle
  /// (ADR-0011 §D9 — `"UNKNOWN One-Sheet"` would read as broken) — it only
  /// ever appears as its own row in the details accordion, distinct from a
  /// `null` region, which is omitted everywhere (ADR-0009 §D2/§D7).
  String get label => switch (this) {
    ReleaseRegion.th => 'TH',
    ReleaseRegion.us => 'US',
    ReleaseRegion.jp => 'JP',
    ReleaseRegion.uk => 'UK',
    ReleaseRegion.intl => 'INTL',
    ReleaseRegion.unknown => 'ตรวจแล้วระบุไม่ได้',
  };

  /// The wire value used by `posternung-backend`'s `ReleaseRegion` enum
  /// (`GET /posters/{poster_id}`'s `release_region` field) — UPPERCASE, per
  /// ADR-0009 §D1.
  String get apiValue => switch (this) {
    ReleaseRegion.th => 'TH',
    ReleaseRegion.us => 'US',
    ReleaseRegion.jp => 'JP',
    ReleaseRegion.uk => 'UK',
    ReleaseRegion.intl => 'INTL',
    ReleaseRegion.unknown => 'UNKNOWN',
  };
}

/// Parses the backend's `release_region` wire value.
///
/// 🔴 Returns [ReleaseRegion.unknown] — **not** `null` — for the wire value
/// `"UNKNOWN"` (ADR-0009 §D2: `NULL` means "nobody has checked yet",
/// `UNKNOWN` means "a human checked and couldn't tell" — collapsing the two
/// on this client would erase a distinction the schema deliberately keeps).
/// Returns `null` for a genuinely `null` input and for any other value this
/// client doesn't recognize (ADR-0011 §D6 — a descriptive field degrades
/// instead of crashing the screen).
ReleaseRegion? releaseRegionFromApi(String? value) {
  if (value == null) return null;
  for (final region in ReleaseRegion.values) {
    if (region.apiValue == value) return region;
  }
  return null;
}
