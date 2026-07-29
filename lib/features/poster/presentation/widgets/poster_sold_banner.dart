import 'package:flutter/material.dart';

import '../../../../core/design_system/app_dimens.dart';
import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// AC-5 / ADR-0005 §D5 — the "bought out from under you while viewing"
/// state. Shown when `PosterDetailViewModel.refresh()` (pull-to-refresh or
/// app-foreground resume) picks up `status: sold`. Deliberately not a
/// full-screen replacement: the rest of the listing (images, condition,
/// authenticity) stays visible below this banner — there's real value in
/// letting a collector still see what they missed — but the banner is the
/// first thing in the scroll view and offers a way forward (per the
/// stock-integrity skill's mobile requirement: "แสดงผลอย่างสุภาพ ไม่ crash
/// ไม่ค้าง และเสนอทางไปต่อ").
class PosterSoldBanner extends StatelessWidget {
  const PosterSoldBanner({super.key, required this.onBrowseOthers});

  final VoidCallback onBrowseOthers;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accentRed.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.accentRed),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppColors.accentRed,
                size: AppDimens.iconSm,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  AppStrings.posterDetailSoldTitle,
                  style: AppTextStyles.homePosterTitle.copyWith(
                    color: AppColors.accentRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppStrings.posterDetailSoldBody,
            style: AppTextStyles.homePosterSubtitle,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onBrowseOthers,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.accentRed),
              foregroundColor: AppColors.accentRed,
            ),
            child: Text(AppStrings.posterDetailSoldCta),
          ),
        ],
      ),
    );
  }
}
