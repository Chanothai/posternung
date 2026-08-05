/// The `poster_type` classification — which kind of theatrical run a sheet
/// was printed for (teaser/advance/theatrical/re-release). Pure Dart, no
/// Flutter import, so both `features/poster/domain/` and the shared
/// `core/catalog/` layer can depend on it without domain importing Flutter
/// — same shape as `poster_condition_grade.dart`.
///
/// Lives in `core/catalog/` rather than under `features/poster/` because
/// SCR-04 (US-02's filter, not yet built) will use this exact type —
/// ADR-0011 §D5.
///
/// 🔴 ADR-0009 D14: values that will arrive from real data are *not*
/// reliable for streaming-release posters (81/116 rows in the AI-suggested
/// backfill are unverified `THEATRICAL` guesses) — that risk is accepted
/// upstream of this file (a human reviews before import), not something
/// this enum can encode.
enum PosterType { teaser, advance, theatrical, rerelease, unknown }

/// Display/interop metadata for [PosterType] — kept as an extension per the
/// `poster_condition_grade.dart` precedent.
extension PosterTypeX on PosterType {
  /// Collector vocabulary, English — deliberately not translated, same
  /// reasoning as `PosterConditionGrade.label` (ADR-0011 §D5).
  ///
  /// [PosterType.unknown]'s label is Thai and only ever surfaces in the
  /// details accordion (never silently dropped) — ADR-0009 §D2 requires
  /// `UNKNOWN` to read as "a human looked and couldn't tell", distinct from
  /// a `null` row, which is simply omitted.
  String get label => switch (this) {
    PosterType.teaser => 'Teaser',
    PosterType.advance => 'Advance',
    PosterType.theatrical => 'Theatrical',
    PosterType.rerelease => 'Re-release',
    PosterType.unknown => 'ตรวจแล้วระบุไม่ได้',
  };

  /// The wire value used by `posternung-backend`'s `PosterType` enum
  /// (`GET /posters/{poster_id}`'s `poster_type` field) — UPPERCASE, per
  /// ADR-0009 §D1.
  String get apiValue => switch (this) {
    PosterType.teaser => 'TEASER',
    PosterType.advance => 'ADVANCE',
    PosterType.theatrical => 'THEATRICAL',
    PosterType.rerelease => 'RERELEASE',
    PosterType.unknown => 'UNKNOWN',
  };
}

/// Parses the backend's `poster_type` wire value. Returns `null` for a
/// `null` input **and** for any value this client doesn't recognize
/// (ADR-0011 §D6) — unlike `status`, this is a purely descriptive field, so
/// a future backend-side addition (or a bad value slipping past review,
/// per ADR-0009 D14) degrades to "row hidden" instead of crashing the
/// whole screen.
PosterType? posterTypeFromApi(String? value) {
  if (value == null) return null;
  for (final type in PosterType.values) {
    if (type.apiValue == value) return type;
  }
  return null;
}
