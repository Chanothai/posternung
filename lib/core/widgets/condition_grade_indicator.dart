import 'package:flutter/material.dart';

import '../catalog/poster_condition_grade.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import '../strings/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'condition_grade_guide_sheet.dart';

/// Shared condition-grade badge — used by every screen that shows a
/// poster's condition (SCR-03/04/05/11 per ADR-0005 §D4). Renders
/// `"$label ($position/$total)"` (ADR-0003's mandated position-on-scale
/// format — never a bare label) and opens the full scale guide
/// (`showConditionGradeGuideSheet`) on tap, per ADR-0003 §ข้อบังคับด้าน UI
/// ข้อ 3.
///
/// [grade] is nullable because `condition_grade` is nullable on the wire
/// with no backend guard yet (ADR-0003's open vulnerability). A `null`
/// grade must still render *something* here rather than `SizedBox.shrink()`
/// — every call site pairs this widget with the price in the same row
/// (see `PosterDetailScreen`), so rendering nothing would leave the price
/// floating with no condition next to it at all, violating BR-05 (a poster
/// price must never be shown without its condition — see skill
/// `business-rules`). A missing grade therefore renders a plain "unspecified"
/// status label instead — not a fake grade (ADR-0003 forbids fabricating
/// one), and not tappable (there's no scale-guide content to open for a
/// grade that doesn't exist).
///
/// [compact] is for dense call sites — the SCR-03 catalog grid card is only
/// ~140–165 logical px wide, where the default padding plus the trailing
/// info icon overflows the row. Compact tightens the padding and drops the
/// icon; **the text is identical either way** (`"Very Good (5/8)"`), and it
/// stays tappable. Shrinking the badge must never become an excuse to show
/// a bare label — that's precisely what ADR-0003 forbids, which is also why
/// there is one widget with a variant here rather than a second, smaller
/// widget somewhere else that would have to be kept honest separately.
class ConditionGradeIndicator extends StatelessWidget {
  const ConditionGradeIndicator({
    super.key,
    required this.grade,
    this.compact = false,
  });

  final PosterConditionGrade? grade;
  final bool compact;

  EdgeInsets get _padding => compact
      ? const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        )
      : const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        );

  @override
  Widget build(BuildContext context) {
    final grade = this.grade;
    if (grade == null) {
      return _Pill(
        padding: _padding,
        child: Text(
          AppStrings.conditionGradeUnspecifiedLabel,
          style: AppTextStyles.homeConditionTag.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: () => showConditionGradeGuideSheet(context, current: grade),
        child: _Pill(
          padding: _padding,
          // ADR-0016 D6 — the grade's scale color is the pill border,
          // never a fill the label text would need to contrast against.
          // It costs zero extra layout width (unlike a leading color dot),
          // which matters here: the `compact` variant already runs tight
          // inside a 140px grid cell (see the "fits a 140px-wide cell"
          // test). The text right inside this same pill already carries
          // "x/8" (see below), so the color is never shown unlabeled.
          borderColor: grade.scaleColor,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '${grade.label} (${grade.scaleFractionLabel})',
                  style: AppTextStyles.homeConditionTag.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  // No ellipsis: truncating this string could turn
                  // "Very Good (5/8)" into "Very Good…", i.e. the bare label
                  // ADR-0003 forbids. Fading keeps the scale fragment
                  // partially visible instead of silently deleting it, and
                  // the compact variant is sized so it doesn't come up in
                  // practice.
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.padding,
    required this.child,
    this.borderColor = AppColors.borderMuted,
  });

  final EdgeInsets padding;
  final Widget child;

  /// Defaults to the neutral border used for the `grade == null` case,
  /// where there's no grade color to show at all.
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: child,
    );
  }
}
