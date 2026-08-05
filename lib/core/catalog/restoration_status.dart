/// The `restoration_status` classification — whether a sheet has been
/// restored or mounted, both of which change how its condition grade
/// should be read (ADR-0009 §D5). Pure Dart, no Flutter import — same shape
/// as `poster_condition_grade.dart`.
///
/// Lives in `core/catalog/` rather than under `features/poster/` because
/// SCR-04 (US-02's filter, not yet built) will use this exact type —
/// ADR-0011 §D5.
///
/// 🔴 This enum only records the *fact*; it never changes how a condition
/// grade is computed or displayed — that is owned entirely by ADR-0003 /
/// `ConditionGradeIndicator`. See ADR-0011 §D2.
enum RestorationStatus { none, restored, linenBacked, unknown }

/// Display/interop metadata for [RestorationStatus].
extension RestorationStatusX on RestorationStatus {
  /// Fact-only wording, Thai. `PosterRestorationBadge` renders this text
  /// next to the condition grade — but **only** for
  /// [RestorationStatus.restored] / [RestorationStatus.linenBacked]
  /// (ADR-0011 §D2/§D2′, decided at GATE 3). Deliberately not a claim about
  /// condition itself ("ผ่านการบูรณะ" states a fact, not a verdict).
  ///
  /// [RestorationStatus.none] and [RestorationStatus.unknown] both have no
  /// call site that renders their label today — `PosterRestorationBadge`
  /// stays silent for both, same as `null` (see `showsFor`). `none`'s is an
  /// empty string because declaring a sheet "not restored" is a positive
  /// claim this app can't back up in Phase 1 (ADR-0011 §D2); `unknown`'s is
  /// a real, non-empty label kept for parity with the other 3 catalog
  /// enums' `UNKNOWN` — it simply has no place on screen yet (ADR-0011
  /// §Amendment (2)/D2′ — an explicit, narrow exception to §D7's general
  /// "`UNKNOWN` must be visible" rule, scoped to this one badge).
  String get label => switch (this) {
    RestorationStatus.none => '',
    RestorationStatus.restored => 'ผ่านการบูรณะ',
    RestorationStatus.linenBacked => 'ติดผ้าใบ (linen-backed)',
    RestorationStatus.unknown => 'ตรวจแล้วระบุไม่ได้',
  };

  /// The wire value used by `posternung-backend`'s `RestorationStatus` enum
  /// (`GET /posters/{poster_id}`'s `restoration_status` field) —
  /// UPPERCASE, per ADR-0009 §D1.
  String get apiValue => switch (this) {
    RestorationStatus.none => 'NONE',
    RestorationStatus.restored => 'RESTORED',
    RestorationStatus.linenBacked => 'LINEN_BACKED',
    RestorationStatus.unknown => 'UNKNOWN',
  };
}

/// Parses the backend's `restoration_status` wire value. Returns `null` for
/// a `null` input **and** for any value this client doesn't recognize
/// (ADR-0011 §D6) — a descriptive field degrades to "row hidden" instead
/// of crashing the whole screen.
RestorationStatus? restorationStatusFromApi(String? value) {
  if (value == null) return null;
  for (final status in RestorationStatus.values) {
    if (status.apiValue == value) return status;
  }
  return null;
}
