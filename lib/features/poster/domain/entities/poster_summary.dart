import '../../../../core/catalog/poster_condition_grade.dart';
import 'poster_status.dart';

/// One row of the catalog list (`GET /posters` → `PosterListItem`).
///
/// **This is deliberately not a trimmed-down `PosterDetail`.** The list
/// endpoint returns strictly fewer fields than the detail endpoint, and the
/// gap is not obvious from the UI: there is no `size`, no `is_unique`, no
/// `images` array, and no film year at all on this wire shape (verified
/// field-by-field against `posternung-backend/openapi.json`'s
/// `PosterListItem`, whose `required` list is
/// `id/title/price/status/condition_grade/era_decade/studio` —
/// `primary_image_url` isn't even required, so it can be absent as well as
/// `null`). Never add a field here "because the detail screen has it";
/// widen the contract first.
///
/// `era_decade` is a *decade* (`1980`), not a release year — the `posters`
/// table has no year column at all (see `docs/screens.yaml` SCR-03's G8).
class PosterSummary {
  const PosterSummary({
    required this.id,
    required this.title,
    required this.price,
    required this.status,
    required this.conditionGrade,
    required this.eraDecade,
    required this.studio,
    required this.primaryImageUrl,
  });

  /// Real backend UUID — the only thing a caller may use to open
  /// `PosterDetailScreen`. (An earlier round wired that screen to
  /// placeholder mock ids and 404'd on every tap; see
  /// `lib/features/poster/CLAUDE.md`.)
  final String id;

  final String title;

  /// Decimal-as-string exactly as sent (e.g. `"450.00"`) — same rationale
  /// as `PosterDetail.price`: never round-trip money through a `double`.
  /// Format for display with `formatThbPrice` (`core/utils/`).
  final String price;

  /// Nullable **here but not on `PosterDetail`** — on a list, one row
  /// carrying a status value this client doesn't recognize must not take
  /// the whole page down with it, so an unrecognized value degrades to
  /// `null` instead of throwing (`PosterSummaryModel.toEntity`). `null`
  /// means "can't confirm this is buyable", and every UI treats it exactly
  /// like `reserved`: shown as unavailable, never as available.
  final PosterStatus? status;

  /// Nullable — `condition_grade` still has no backend guard (ADR-0003's
  /// open vulnerability). BR-05 forbids showing a price with no condition
  /// beside it, so render this through `ConditionGradeIndicator`
  /// (core/widgets/), which shows an explicit "unspecified" badge rather
  /// than collapsing away. Never fabricate a grade.
  final PosterConditionGrade? conditionGrade;

  final int? eraDecade;
  final String? studio;

  /// Nullable, and genuinely `null` more often than it looks: the backend
  /// filters out primary images stored under an internal-only key rather
  /// than exposing them, so a real listing can legitimately have no image
  /// URL. Every call site needs a deliberate placeholder.
  final String? primaryImageUrl;
}
