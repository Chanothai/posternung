import 'package:flutter/material.dart';

import '../catalog/poster_condition_grade.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import '../strings/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Opens the condition-scale guide as a modal bottom sheet, listing all 8
/// [PosterConditionGrade] levels (best to worst) with [current] highlighted.
///
/// ADR-0003 §ข้อบังคับด้าน UI ข้อ 3 makes this reachable from every place a
/// condition grade is shown — see `ConditionGradeIndicator`, the tappable
/// widget that calls this. Kept as a standalone function (rather than
/// folded into the indicator widget) so a future full `SCR-11` page can
/// call it too, or embed `_ConditionGradeGuideSheet`'s `_GradeRow` children
/// directly.
///
/// [current] is optional (ADR-0016 D7) — this guide is reachable from
/// places with no poster in view (`screens.yaml`'s `depends_on: []` for
/// SCR-11), and there is no grade to guess at when that's true. `null`
/// renders all 8 levels with none highlighted; the caller must never pass
/// a guessed grade to work around this.
Future<void> showConditionGradeGuideSheet(
  BuildContext context, {
  PosterConditionGrade? current,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceDark,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    isScrollControlled: true,
    builder: (context) => _ConditionGradeGuideSheet(current: current),
  );
}

class _ConditionGradeGuideSheet extends StatelessWidget {
  const _ConditionGradeGuideSheet({required this.current});

  final PosterConditionGrade? current;

  /// Builds the 8 [_GradeRow]s in scale order, with [_FineVeryGoodCallout]
  /// inserted right at the `fine` → `very_good` seam (ADR-0016 D3(ข)) — the
  /// one pair collectors' English naming reads backwards on, and the whole
  /// reason SCR-11 exists per ADR-0003. The callout's position here, not
  /// its existence, is what D3 calls non-optional: it must sit *between*
  /// those two rows, not floating elsewhere on the sheet.
  List<Widget> _buildGradeRows() {
    final rows = <Widget>[];
    for (final grade in PosterConditionGrade.values) {
      rows.add(_GradeRow(grade: grade, isCurrent: grade == current));
      if (grade == PosterConditionGrade.fine) {
        rows.add(const _FineVeryGoodCallout());
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    // All 8 grades' descriptions routinely exceed a modal sheet's available
    // height on smaller screens — scrollable rather than
    // `mainAxisSize: MainAxisSize.min` alone, which only sizes the Column to
    // its content and does nothing to keep that content within the sheet's
    // own height constraint.
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.conditionGuideTitle,
              style: AppTextStyles.homeSectionHeading,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppStrings.conditionGuideSubtitle,
              style: AppTextStyles.cardSubtitle,
            ),
            const SizedBox(height: AppSpacing.lg),
            ..._buildGradeRows(),
          ],
        ),
      ),
    );
  }
}

class _GradeRow extends StatelessWidget {
  const _GradeRow({required this.grade, required this.isCurrent});

  final PosterConditionGrade grade;
  final bool isCurrent;

  /// Joined [PosterConditionGradeX.wearTraces], or the dedicated "no
  /// traces" line when the list is empty (`mint`). Never blank — the guide
  /// sheet's test suite pins this.
  String get _traceLine {
    final traces = grade.wearTraces;
    if (traces.isEmpty) return AppStrings.conditionGuideNoTracesLabel;
    return '${AppStrings.conditionGuideTracesLabel}${traces.join(' · ')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Scopes a row for tests — lets the guide sheet's test suite assert
      // that a grade's color swatch and its "x/8" text live in the *same*
      // row (D6 is about pairing/co-location, not mere presence somewhere
      // on the sheet), rather than reaching into private widget internals.
      key: ValueKey('grade-row-${grade.name}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.glassCardFill : null,
        border: Border.all(
          // ADR-0016 D6 — every non-current row's border is that grade's
          // scale color (a supplementary cue, never the only signal of
          // rank: the "x/8" text right below is what actually says where
          // this sits). The current row keeps the existing accent
          // highlight instead — that's a different signal ("this is the
          // poster you're looking at"), and must stay the most visually
          // prominent one on the row.
          color: isCurrent ? AppColors.accent : grade.scaleColor,
          width: isCurrent ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ColorDot(
                key: ValueKey('color-dot-${grade.name}'),
                color: grade.scaleColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  '${grade.label} (${grade.scaleFractionLabel})',
                  style: AppTextStyles.homePosterTitle.copyWith(
                    color: isCurrent ? AppColors.accent : AppColors.textPrimary,
                  ),
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  AppStrings.conditionGuideCurrentBadge,
                  style: AppTextStyles.homeBadgeLabel.copyWith(
                    color: AppColors.accent,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // ADR-0016 AC-2/D3(ก) — a structure that says where this grade
          // sits among all 8 *by itself*, without the reader having to scan
          // the rest of the list first: one filled segment out of 8, at
          // this grade's own position.
          _PositionTrack(grade: grade, color: grade.scaleColor),
          const SizedBox(height: AppSpacing.sm),
          Text(grade.thaiDescription, style: AppTextStyles.homePosterSubtitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _traceLine,
            style: AppTextStyles.cardSubtitle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small filled circle carrying a grade's scale color — always rendered
/// directly beside that row's `"label (x/8)"` text, never on its own
/// (ADR-0016 D6). Takes an explicit `key` (`color-dot-${grade.name}`, set
/// at the call site in [_GradeRow]) so the guide sheet's test suite can
/// confirm this specific widget — not just *some* color-bearing widget —
/// stays inside its own row.
class _ColorDot extends StatelessWidget {
  const _ColorDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// An 8-segment horizontal track with a single filled segment at [grade]'s
/// own [PosterConditionGradeX.scalePosition] — the self-contained "where on
/// the scale" visual each [_GradeRow] carries (ADR-0016 D3(ก)). Only the
/// filled segment carries [color]; the rest use a fixed neutral tone, so
/// this widget introduces exactly one color-bearing point per row — the
/// same one the row's `"x/8"` text already labels (D6).
///
/// Keyed per-segment (`position-track-${grade.name}-$i`) and as a whole
/// (`position-track-${grade.name}`) so the guide sheet's test suite can
/// assert this widget is actually present and that exactly one of its 8
/// segments is colored — removing this widget, or de-fanging it into
/// something that doesn't actually highlight a position, must fail a test
/// (code-critic 2026-08-06 round 1: a prior version of the test suite
/// stayed green under both mutations).
class _PositionTrack extends StatelessWidget {
  const _PositionTrack({required this.grade, required this.color});

  final PosterConditionGrade grade;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final position = grade.scalePosition;
    final total = grade.scaleLength;
    return Row(
      key: ValueKey('position-track-${grade.name}'),
      children: [
        for (var i = 1; i <= total; i++)
          Expanded(
            child: Container(
              key: ValueKey('position-track-segment-${grade.name}-$i'),
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: i == position
                    ? color
                    : AppColors.borderMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppRadius.xs / 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// The one required (ADR-0016 D3(ข)) emphasis at the `fine` ↔ `very_good`
/// seam — the single pair of adjacent grades collectors' English naming
/// reads backwards on ("Fine" outranks "Very Good"), and the reason
/// ADR-0003 moved this whole guide from Phase 2 into Phase 1. Its position
/// in the sheet (see `_ConditionGradeGuideSheet._buildGradeRows`), not its
/// wording, is what's non-negotiable.
class _FineVeryGoodCallout extends StatelessWidget {
  const _FineVeryGoodCallout();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        border: Border.all(color: AppColors.accent),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.priority_high, size: 18, color: AppColors.accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.conditionGuideFineVeryGoodCalloutTitle,
                  style: AppTextStyles.homeBadgeLabel.copyWith(
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.conditionGuideFineVeryGoodCalloutBody,
                  style: AppTextStyles.homePosterSubtitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
