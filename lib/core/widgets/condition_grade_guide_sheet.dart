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
/// call it too, or embed `_ConditionGradeGuideList` directly.
Future<void> showConditionGradeGuideSheet(
  BuildContext context, {
  required PosterConditionGrade current,
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

  final PosterConditionGrade current;

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
            ...PosterConditionGrade.values.map(
              (grade) => _GradeRow(grade: grade, isCurrent: grade == current),
            ),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.glassCardFill : null,
        border: Border.all(
          color: isCurrent ? AppColors.accent : AppColors.borderMuted,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${grade.scalePosition}. ${grade.label}',
                style: AppTextStyles.homePosterTitle.copyWith(
                  color: isCurrent ? AppColors.accent : AppColors.textPrimary,
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
          Text(grade.thaiDescription, style: AppTextStyles.homePosterSubtitle),
        ],
      ),
    );
  }
}
