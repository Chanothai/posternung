import '../../../../core/catalog/poster_condition_grade.dart';
import 'poster_image.dart';
import 'poster_status.dart';

/// Full detail of a single poster listing (`GET /posters/{poster_id}` →
/// `PosterDetailResponse`). Plain, no Flutter/serialization imports — see
/// `data/models/poster_detail_model.dart` for the DTO and `toEntity()`.
class PosterDetail {
  const PosterDetail({
    required this.id,
    required this.title,
    required this.price,
    required this.status,
    required this.conditionGrade,
    required this.eraDecade,
    required this.studio,
    required this.primaryImageUrl,
    required this.tmdbId,
    required this.size,
    required this.description,
    required this.isAuthenticated,
    required this.authenticityNote,
    required this.provenance,
    required this.images,
    required this.createdAt,
  });

  final String id;
  final String title;

  /// Decimal-as-string, exactly as the backend sends it (e.g. `"450.00"`)
  /// — kept as a string rather than parsed to `double` to avoid floating
  /// point precision loss on a monetary value; format for display at the
  /// presentation layer.
  final String price;

  final PosterStatus status;

  /// Nullable — `condition_grade` has no backend guard against `NULL` yet
  /// (ADR-0003's open vulnerability). Never fabricate a grade when this is
  /// `null` — but never render *nothing* either: BR-05 requires a price to
  /// always be shown with its condition, so `ConditionGradeIndicator`
  /// renders an explicit "unspecified" badge for `null` rather than
  /// collapsing away and leaving the price bare.
  final PosterConditionGrade? conditionGrade;

  final int? eraDecade;
  final String? studio;
  final String? primaryImageUrl;
  final int? tmdbId;
  final String? size;
  final String? description;
  final bool isAuthenticated;
  final String? authenticityNote;
  final String? provenance;
  final List<PosterImage> images;
  final DateTime createdAt;
}
