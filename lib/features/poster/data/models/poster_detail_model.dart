import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/catalog/poster_condition_grade.dart';
import '../../../../core/error/catalog_exception.dart';
import '../../domain/entities/poster_detail.dart';
import '../../domain/entities/poster_status.dart';
import 'poster_image_model.dart';

part 'poster_detail_model.freezed.dart';
part 'poster_detail_model.g.dart';

/// DTO for the backend's `PosterDetailResponse` (`GET
/// /posters/{poster_id}`). `status` and `condition_grade` are decoded as
/// raw strings here (not `@JsonEnum`s) — [toEntity] maps them via
/// `posterStatusFromApi`/`posterConditionGradeFromApi` so an
/// unrecognized/future backend value degrades gracefully instead of
/// crashing `fromJson` with a bare `TypeError`.
///
/// Every optional field below is `String?`/`int?`, matching
/// `openapi.json`'s `anyOf: [..., null]` for each — verified field-by-field
/// against the real generated schema per ADR-0005's Verification section,
/// not assumed from `docs/openapi.yaml` alone (see `add-feature-slice`'s
/// "`fromJson` throws `TypeError` on null" trap).
@freezed
abstract class PosterDetailModel with _$PosterDetailModel {
  const PosterDetailModel._();

  const factory PosterDetailModel({
    required String id,
    required String title,
    // Decimal-as-string on the wire (`openapi.json`: `"pattern":
    // "^(?!^[-+.]*$)[+-]?0*\\d*\\.?\\d*$"`) — kept as `String` end-to-end,
    // see `PosterDetail.price`.
    required String price,
    required String status,
    @JsonKey(name: 'condition_grade') String? conditionGrade,
    @JsonKey(name: 'era_decade') int? eraDecade,
    String? studio,
    @JsonKey(name: 'primary_image_url') String? primaryImageUrl,
    @JsonKey(name: 'tmdb_id') int? tmdbId,
    String? size,
    String? description,
    @JsonKey(name: 'is_authenticated') required bool isAuthenticated,
    @JsonKey(name: 'authenticity_note') String? authenticityNote,
    String? provenance,
    required List<PosterImageModel> images,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _PosterDetailModel;

  factory PosterDetailModel.fromJson(Map<String, dynamic> json) =>
      _$PosterDetailModelFromJson(json);

  PosterDetail toEntity() {
    final parsedStatus = posterStatusFromApi(status);
    if (parsedStatus == null) {
      throw CatalogException(
        code: 'unknown_poster_status',
        message: 'Unrecognized poster status: $status',
      );
    }
    return PosterDetail(
      id: id,
      title: title,
      price: price,
      status: parsedStatus,
      conditionGrade: posterConditionGradeFromApi(conditionGrade),
      eraDecade: eraDecade,
      studio: studio,
      primaryImageUrl: primaryImageUrl,
      tmdbId: tmdbId,
      size: size,
      description: description,
      isAuthenticated: isAuthenticated,
      authenticityNote: authenticityNote,
      provenance: provenance,
      images: images.map((image) => image.toEntity()).toList(),
      createdAt: createdAt,
    );
  }
}
