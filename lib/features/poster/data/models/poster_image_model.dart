import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/poster_image.dart';
import '../../domain/entities/poster_image_kind.dart';

part 'poster_image_model.freezed.dart';
part 'poster_image_model.g.dart';

/// DTO for the backend's `PosterImageResponse` (nested in
/// `PosterDetailResponse.images`). `openapi.json` (generated from the live
/// FastAPI code, reflects the code as it runs today) marks all 5 fields —
/// including `kind` — required. The source-of-truth contract,
/// `../workspace/docs/api/openapi.yaml`, does **not** declare a `required:`
/// list for `PosterImage` at all (pre-existing gap in that doc, unrelated to
/// this DTO) — so `openapi.json` is the only place this DTO's
/// required/optional shape can be checked against, unlike `PosterDetailModel`'s
/// many-nullable shape.
///
/// 🔴 **`kind` is `required` on the wire (ADR-0026 §D1) but `String?` —
/// optional — here, on purpose.** ADR-0026 Amendment §A-D9 (3) records this
/// trade-off explicitly: decoding it as a genuinely required field would
/// make `fromJson` throw the moment the backend ever rolls back or ships a
/// row without it, and that throw takes down the *whole* poster-detail
/// screen (`PosterDetailModel.toEntity` fails loud on a bad `status` for
/// exactly this reason — but `kind` is not `status`; losing it degrades a
/// gallery ordering, not the ability to show the poster at all). Decoding
/// as raw `String?` here and mapping through [posterImageKindFromApi] in
/// [toEntity] means a missing/unrecognized `kind` degrades to `null`
/// instead of crashing the page — same pattern as every other
/// `<x>FromApi()` field on this model's sibling DTOs, and **never**
/// `@JsonEnum`, which would throw on an unrecognized value.
@freezed
abstract class PosterImageModel with _$PosterImageModel {
  const PosterImageModel._();

  const factory PosterImageModel({
    required String id,
    required String url,
    @JsonKey(name: 'is_primary') required bool isPrimary,
    @JsonKey(name: 'sort_order') required int sortOrder,
    String? kind,
  }) = _PosterImageModel;

  factory PosterImageModel.fromJson(Map<String, dynamic> json) =>
      _$PosterImageModelFromJson(json);

  PosterImage toEntity() => PosterImage(
    id: id,
    url: url,
    isPrimary: isPrimary,
    sortOrder: sortOrder,
    kind: posterImageKindFromApi(kind),
  );
}
