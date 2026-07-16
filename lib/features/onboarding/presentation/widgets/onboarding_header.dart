import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_images.dart';
import '../../../../core/design_system/app_dimens.dart';
import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Shared chrome across onboarding screens: film-reel icon, "PosterNung"
/// title, and a skip action. Pass `onSkip: null` to hide/disable the skip
/// action while preserving its layout space (the last onboarding screen has
/// nothing left to skip to).
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({super.key, this.onSkip});

  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                AppImages.headerIcon,
                width: AppDimens.iconMd,
                height: AppDimens.iconMd,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(AppStrings.appName, style: AppTextStyles.appBarTitle),
            ],
          ),
          Opacity(
            opacity: onSkip == null ? 0 : 1,
            child: InkWell(
              onTap: onSkip,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  AppStrings.onboardingSkipButton,
                  style: AppTextStyles.skipButton,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
