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
class ConditionGradeIndicator extends StatelessWidget {
  const ConditionGradeIndicator({super.key, required this.grade});

  final PosterConditionGrade? grade;

  @override
  Widget build(BuildContext context) {
    final grade = this.grade;
    if (grade == null) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderMuted),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
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
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderMuted),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${grade.label} (${grade.scalePosition}/${grade.scaleLength})',
                style: AppTextStyles.homeConditionTag.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.info_outline,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
