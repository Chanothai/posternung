import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/paginated_posters.dart';
import 'poster_summary_model.dart';

part 'paginated_posters_model.freezed.dart';
part 'paginated_posters_model.g.dart';

/// DTO for the backend's `PaginatedPosterList` (`GET /posters`). All four
/// fields are `required` server-side.
@freezed
abstract class PaginatedPostersModel with _$PaginatedPostersModel {
  const PaginatedPostersModel._();

  const factory PaginatedPostersModel({
    required List<PosterSummaryModel> items,
    required int total,
    required int limit,
    required int offset,
  }) = _PaginatedPostersModel;

  factory PaginatedPostersModel.fromJson(Map<String, dynamic> json) =>
      _$PaginatedPostersModelFromJson(json);

  /// Preserves the server's ordering (`created_at DESC`) — never re-sort
  /// here; see `PosterRepository.listPosters` on BR-05.
  PaginatedPosters toEntity() => PaginatedPosters(
    items: items.map((item) => item.toEntity()).toList(),
    total: total,
    limit: limit,
    offset: offset,
  );
}
