import '../domain/entities/poster_image.dart';
import '../domain/entities/poster_image_kind.dart';

/// Orders a poster detail's images for the gallery (ADR-0026 Amendment
/// §A-D9 (2) — the exact rules below are that section's, not reinvented
/// here).
///
/// 1. Sort by `sort_order` ascending, **stable**: images that tie on
///    `sort_order` keep their original relative order rather than whatever
///    order the underlying sort happens to produce (`List.sort` is not
///    documented as stable in Dart, so this sorts on `(sortOrder,
///    originalIndex)` explicitly rather than relying on it).
/// 2. Hoist **one** image to the front, in this priority:
///    a. the image with `isPrimary == true` **and** `kind == front`,
///    b. else the first `kind == front` image by `sort_order`,
///    c. else nothing is hoisted — the `sort_order` order stands as-is.
/// 3. **Every image is always returned** — including images with `kind ==
///    null` (unrecognized/missing `kind`) and `back`/`defect` images. A
///    primary image whose `kind` is not `front` is *demoted*, never
///    dropped: it just falls back into its normal `sort_order` position
///    instead of being hoisted. ADR-0026 §D6 forbids hiding `DEFECT`
///    images — they are evidence of `condition_grade` (BR-05) and a
///    dispute shield in a system that cannot auto-refund (ADR-0002) — and
///    Amendment §A-D9 (2) settles that **D6 wins over D9** here: when there
///    is no `FRONT` image at all, this still returns every image in
///    `sort_order` order rather than an empty list or a placeholder.
///
/// **Why rule 4 (the kind-rank rule that was rejected) matters**: sorting
/// by `kind` itself (`FRONT` → `BACK` → `DEFECT`) instead of by
/// `sort_order` alone would make this function a second source of truth for
/// group order — ADR-0026 §D5 deliberately put group order into the
/// `sort_order` *bands* themselves (`FRONT` 0–99, `BACK` 100–199, `DEFECT`
/// 200–299) precisely so the app never has to know about kinds to get
/// grouping right. This function must never branch on `kind` for ordering,
/// only for the hoist decision above.
///
/// **Why this is a no-op on real data:** the DB-level CHECK
/// `ck_poster_images_primary_is_front` guarantees `is_primary` is always
/// paired with `kind = FRONT`, and the `sort_order` bands guarantee `FRONT`
/// always sorts lowest. So rule 2a always agrees with a plain `sort_order`
/// sort on real rows — this function only ever changes the result when the
/// backend sends something the CHECK should have prevented (a wrong
/// primary, or no `FRONT` at all). That is the fail-closed behaviour AC-14
/// (ค) asks for: correct data is unaffected, and only broken data changes
/// what renders.
///
/// That "no-op on real data" claim was measured, not assumed — but the
/// numbers deliberately do not live here. `../workspace/docs/BACKLOG.md`
/// §0 is the one place this project keeps DB counts, with the query next to
/// them so anyone can re-run it; see its `poster_images.kind` row. Copying
/// them into this comment would create a second home for a measurement that
/// goes stale the moment BL-40 lands the first `BACK`/`DEFECT` photo, and
/// nobody would have a reason to reopen a Dart file to fix it.
List<PosterImage> orderPosterGalleryImages(List<PosterImage> images) {
  final indexed = List<MapEntry<int, PosterImage>>.generate(
    images.length,
    (i) => MapEntry(i, images[i]),
  );
  indexed.sort((a, b) {
    final bySortOrder = a.value.sortOrder.compareTo(b.value.sortOrder);
    return bySortOrder != 0 ? bySortOrder : a.key.compareTo(b.key);
  });
  final ordered = indexed.map((e) => e.value).toList(growable: true);

  var hoistIndex = ordered.indexWhere(
    (image) => image.isPrimary && image.kind == PosterImageKind.front,
  );
  if (hoistIndex == -1) {
    hoistIndex = ordered.indexWhere(
      (image) => image.kind == PosterImageKind.front,
    );
  }
  // -1: no FRONT image anywhere — rule 2c, leave sort_order order as-is.
  // 0: the would-be-hoisted image is already first — nothing to move.
  if (hoistIndex <= 0) return ordered;

  final hoisted = ordered.removeAt(hoistIndex);
  return [hoisted, ...ordered];
}
