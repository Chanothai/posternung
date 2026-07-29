/// A poster's lifecycle status (`posternung-backend`'s `PosterStatus` enum).
///
/// The backend does **not** filter `GET /posters/{poster_id}` by status —
/// a sold poster still answers `200` with `status: sold` (ADR-0005 §D5).
/// `404 POSTER_NOT_FOUND` means "no such poster," a different case entirely
/// from "this poster exists but is unavailable."
enum PosterStatus { available, reserved, sold }

/// Parses the backend's `status` wire value. Unlike
/// `posterConditionGradeFromApi`, there is no legitimate `null` here — the
/// field is always present and required — so an unrecognized value is a
/// genuine contract mismatch, surfaced by the data layer as a
/// `CatalogException` rather than silently defaulting.
PosterStatus? posterStatusFromApi(String value) => switch (value) {
  'available' => PosterStatus.available,
  'reserved' => PosterStatus.reserved,
  'sold' => PosterStatus.sold,
  _ => null,
};
