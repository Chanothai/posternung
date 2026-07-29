import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/poster_image.dart';

part 'poster_image_model.freezed.dart';
part 'poster_image_model.g.dart';

/// DTO for the backend's `PosterImageResponse` (nested in
/// `PosterDetailResponse.images`). All fields are non-nullable/required on
/// the wire (`openapi.json`'s `PosterImageResponse.required`), unlike
/// `PosterDetailModel`'s many-nullable shape.
@freezed
abstract class PosterImageModel with _$PosterImageModel {
  const PosterImageModel._();

  const factory PosterImageModel({
    required String id,
    required String url,
    @JsonKey(name: 'is_primary') required bool isPrimary,
    @JsonKey(name: 'sort_order') required int sortOrder,
  }) = _PosterImageModel;

  factory PosterImageModel.fromJson(Map<String, dynamic> json) =>
      _$PosterImageModelFromJson(json);

  PosterImage toEntity() =>
      PosterImage(id: id, url: url, isPrimary: isPrimary, sortOrder: sortOrder);
}
