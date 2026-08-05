import '../../../../core/catalog/poster_condition_grade.dart';
import '../../../../core/catalog/poster_type.dart';
import '../../../../core/catalog/release_region.dart';
import '../../../../core/catalog/restoration_status.dart';
import '../../../../core/catalog/size_format.dart';
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
    required this.posterType,
    required this.releaseRegion,
    required this.releaseDateText,
    required this.releaseDate,
    required this.copyrightYear,
    required this.sizeFormat,
    required this.year,
    required this.restorationStatus,
    required this.restorationNote,
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

  // --- ADR-0009 / ADR-0011 (SCR-05 "แสดงฟิลด์ใหม่") — every field below is
  // `NULL` for all 117 rows on SIT today except `release_date_text` (41
  // rows) and `release_date` (9 rows); see ADR-0011 §D8/OD-4. ---

  /// Which kind of theatrical run this sheet was printed for. `null` means
  /// nobody has classified it yet; [PosterType.unknown] does not apply here
  /// the way it does for [releaseRegion] — see `core/catalog/poster_type.dart`.
  final PosterType? posterType;

  /// The region this sheet was released for (not necessarily where it was
  /// physically printed — ADR-0009 §D7). `null` = nobody has checked yet;
  /// [ReleaseRegion.unknown] = checked and couldn't tell — the two are
  /// never the same thing on screen (ADR-0009 §D2, ADR-0011 §D7).
  final ReleaseRegion? releaseRegion;

  /// **Observed** — the release date exactly as printed on the sheet
  /// (`"SUMMER 2021"`, `"COMING SOON"`, a full date — whatever is legible),
  /// not parsed or interpreted. This is the only one of the two release-date
  /// fields shown on screen (ADR-0011 §D3).
  final String? releaseDateText;

  /// **Derived** — parsed from [releaseDateText] when it resolves to a
  /// complete day/month/year (ADR-0009 §D13); `null` whenever
  /// [releaseDateText] is `null` or doesn't parse that fully. Parsed into
  /// the entity for a future US-02 sort/filter, but ADR-0011 §D3 forbids
  /// showing it on screen — [releaseDateText] is the only one displayed.
  final DateTime? releaseDate;

  /// The year printed in the sheet's billing block — distinct from [year]
  /// (the film's release year) and from `eraDecade` (the film's decade).
  /// See ADR-0009 §D3 — these four "year" concepts are never collapsed.
  final int? copyrightYear;

  /// The standard size format mapped from a *confirmed* measurement —
  /// never inferred from a photo (ADR-0009 §D4). Distinct from the
  /// pre-existing [size] free-text field, which is an unverified guess —
  /// both are shown, in different places (ADR-0011 §OD-2/§D9).
  final SizeFormat? sizeFormat;

  /// The film's release year — distinct from `eraDecade` (the film's
  /// decade, already on this entity), [releaseDate] (the date printed on
  /// this sheet) and [copyrightYear] (the billing-block year). See
  /// ADR-0009 §D3.
  final int? year;

  /// Whether this sheet has been restored and/or linen-backed — changes how
  /// the [conditionGrade] should be read (an "apparent grade"), but never
  /// changes the grade itself (ADR-0011 §D2, owned by ADR-0003).
  final RestorationStatus? restorationStatus;

  /// Free-text detail for [restorationStatus] — e.g. what was restored.
  final String? restorationNote;
}
