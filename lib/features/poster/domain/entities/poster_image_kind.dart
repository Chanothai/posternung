/// What a poster image shows (`posternung-backend`'s `PosterImageKind`
/// enum, ADR-0026 §D1).
///
/// Only three values exist on the wire today. `ADR-0026` §D1 says outright
/// that a fourth (`RAKING`, raking-light shots of the paper surface) is
/// coming later without a new ADR — just a new enum value and a new
/// `sort_order` band (§D5) — so this client has to tolerate an unknown
/// value indefinitely, not just today.
enum PosterImageKind { front, back, defect }

/// Parses the backend's `kind` wire value, returning `null` for anything
/// this client doesn't recognize (including the field being absent —
/// [PosterImageModel] decodes `kind` as `String?`, never `@JsonEnum`, so a
/// missing field never throws in `fromJson`).
///
/// 🔴 **`null` here is not an error state to surface** — same pattern as
/// [posterTypeFromApi]/[sizeFormatFromApi] (ADR-0011 §D6): a poster image
/// this client can't classify still has to render, just without the
/// `FRONT`-hoist eligibility a recognized `kind` would carry (ADR-0026
/// Amendment §A-D9 (3)).
///
/// 🔴 **Case-sensitive on purpose — `UPPERCASE` only, never lowercased
/// before comparing.** ADR-0026 §D2 puts the *only* casing conversion in
/// the whole system at the ingest-time filename reader on the backend
/// (lowercase `front.jpg`/`back.jpg`/`defect-01.jpg` → `UPPERCASE` enum
/// value); every other layer, this one included, only ever sees
/// `UPPERCASE`. Accepting `'front'` here as well as `'FRONT'` would make
/// this the second place in the system that decides what casing means,
/// which is exactly what §D2 forbids.
PosterImageKind? posterImageKindFromApi(String? value) => switch (value) {
  'FRONT' => PosterImageKind.front,
  'BACK' => PosterImageKind.back,
  'DEFECT' => PosterImageKind.defect,
  _ => null,
};
