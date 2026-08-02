/// A poster's lifecycle status (`posternung-backend`'s `PosterStatus` enum).
///
/// The backend does **not** filter `GET /posters/{poster_id}` by status —
/// a sold poster still answers `200` with `status: sold` (ADR-0005 §D5).
/// `404 POSTER_NOT_FOUND` means "no such poster," a different case entirely
/// from "this poster exists but is unavailable."
enum PosterStatus { available, reserved, sold }

/// Parses the backend's `status` wire value, returning `null` for anything
/// this client doesn't recognize. There is no legitimate `null` status on
/// the wire — the field is always present and required — so a `null` result
/// always means a contract mismatch. **What the data layer does with that
/// mismatch differs by endpoint, on purpose:**
///
/// - `PosterDetailModel.toEntity` throws a `CatalogException`. The bad
///   status belongs to the single poster the user asked for, so failing
///   loudly is the honest answer.
/// - `PosterSummaryModel.toEntity` keeps the `null` and lets it through as
///   `PosterSummary.status`. On a list, throwing would take the whole page
///   down for every other poster too. Every UI must treat a `null` status
///   exactly like `reserved` — unavailable, never buyable.
PosterStatus? posterStatusFromApi(String value) => switch (value) {
  'available' => PosterStatus.available,
  'reserved' => PosterStatus.reserved,
  'sold' => PosterStatus.sold,
  _ => null,
};
