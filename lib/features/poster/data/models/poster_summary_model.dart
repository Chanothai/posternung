import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/catalog/poster_condition_grade.dart';
import '../../domain/entities/poster_status.dart';
import '../../domain/entities/poster_summary.dart';

part 'poster_summary_model.freezed.dart';
part 'poster_summary_model.g.dart';

/// DTO for the backend's `PosterListItem` (`GET /posters`).
///
/// Field set verified against `posternung-backend/openapi.json`'s
/// `PosterListItem`, not assumed from the detail response: there is **no**
/// `size`, `is_unique`, `images`, or film-year field on this shape. Only
/// `id/title/price/status/condition_grade/era_decade/studio` are `required`
/// server-side; `primary_image_url` may be absent as well as `null`, which
/// `String?` covers either way.
///
/// - `price` decodes as `String`, not `num`: Pydantic v2 serializes
///   `Decimal` to a JSON **string** (`"450.00"`), and the contract says so
///   explicitly (`type: string, format: decimal`). Typing it `double` here
///   would compile fine and blow up at runtime on the first response.
/// - `status` and `condition_grade` decode as raw strings — `status` as
///   `String` (required on the wire), `condition_grade` as `String?`
///   (nullable) — and are mapped in [toEntity] via
///   `posterStatusFromApi`/`posterConditionGradeFromApi` rather than
///   `@JsonEnum`, so an unrecognized value degrades to `null` instead of
///   crashing `fromJson` with a bare `TypeError`.
@freezed
abstract class PosterSummaryModel with _$PosterSummaryModel {
  const PosterSummaryModel._();

  const factory PosterSummaryModel({
    required String id,
    required String title,
    required String price,
    required String status,
    @JsonKey(name: 'condition_grade') String? conditionGrade,
    @JsonKey(name: 'era_decade') int? eraDecade,
    String? studio,
    @JsonKey(name: 'primary_image_url') String? primaryImageUrl,
  }) = _PosterSummaryModel;

  factory PosterSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$PosterSummaryModelFromJson(json);

  /// Unlike `PosterDetailModel.toEntity`, an unrecognized `status` is
  /// **not** thrown here. On the detail screen a bad status affects the one
  /// poster the user asked for, so failing loudly is right; on a list it
  /// would take down the entire page for every other poster too — the same
  /// blast radius as the backend's own G6 (one internal image key → `GET
  /// /posters` 500s wholesale). An unknown status therefore becomes `null`,
  /// which every UI must treat as "not available".
  PosterSummary toEntity() => PosterSummary(
    id: id,
    title: title,
    price: price,
    status: posterStatusFromApi(status),
    conditionGrade: posterConditionGradeFromApi(conditionGrade),
    eraDecade: eraDecade,
    studio: studio,
    primaryImageUrl: primaryImageUrl,
  );
}
