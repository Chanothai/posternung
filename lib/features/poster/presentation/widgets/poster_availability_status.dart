import 'package:flutter/material.dart';

import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/poster_status.dart';

/// AC-4 (quantity max 1 / BR-04) as a status message, not a quantity
/// selector — ADR-0005 §D1 forbids any control that implies a purchase
/// flow this round. Also covers `reserved`/`sold` so a status change picked
/// up by `PosterDetailViewModel.refresh()` (AC-5) renders in place, without
/// a separate screen swap.
class PosterAvailabilityStatus extends StatelessWidget {
  const PosterAvailabilityStatus({super.key, required this.status});

  final PosterStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      PosterStatus.available => _Notice(
        text: AppStrings.posterDetailSingleStockNotice,
        color: AppColors.textSecondary,
      ),
      PosterStatus.reserved => _Notice(
        text: AppStrings.posterDetailReservedNotice,
        color: AppColors.accent,
      ),
      PosterStatus.sold => const SizedBox.shrink(),
    };
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        style: AppTextStyles.homePosterSubtitle.copyWith(color: color),
      ),
    );
  }
}
