import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/design_system/app_dimens.dart';
import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Content for onboarding's third page ("Limited Stock — One of a Kind").
///
/// Figma: node 7:90, frame "Onboarding - limit stock".
class OnboardingLimitStockPageContent extends StatelessWidget {
  const OnboardingLimitStockPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CenterpieceIllustration(),
        SizedBox(height: 40),
        _CopyBlock(),
      ],
    );
  }
}

class _CenterpieceIllustration extends StatelessWidget {
  const _CenterpieceIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 192,
      height: 203,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 192,
            height: 192,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.15),
                  AppColors.accent.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            child: Transform.rotate(
              angle: -15 * math.pi / 180,
              child: const _FadedPosterCard(),
            ),
          ),
          Positioned(
            right: 0,
            child: Transform.rotate(
              angle: 15 * math.pi / 180,
              child: const _FadedPosterCard(),
            ),
          ),
          const _HighlightedPosterCard(),
        ],
      ),
    );
  }
}

class _FadedPosterCard extends StatelessWidget {
  const _FadedPosterCard();

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
      child: Opacity(
        opacity: 0.3,
        child: Container(
          width: 128,
          height: 176,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderMuted),
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
        ),
      ),
    );
  }
}

class _HighlightedPosterCard extends StatelessWidget {
  const _HighlightedPosterCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 144,
      height: 192,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border.all(color: AppColors.accent),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(58, 51, 44, 0.3),
            offset: Offset(2, 3),
            blurRadius: 2.5,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color.fromRGBO(0, 0, 0, 0.4),
          border: Border.all(color: AppColors.borderMuted, width: 1),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/images/poster_placeholder_icon.svg',
                width: AppDimens.iconLg,
                height: AppDimens.iconLg,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppStrings.onboardingStockBadge,
                style: AppTextStyles.stockBadgeLabel,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CopyBlock extends StatelessWidget {
  const _CopyBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: AppStrings.onboardingHeroTitlePage3Prefix,
                style: AppTextStyles.heroTitleSmall,
              ),
              TextSpan(
                text: AppStrings.onboardingHeroTitlePage3Emphasis,
                style: AppTextStyles.heroTitleSmallEmphasis,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 384),
          child: Text(
            AppStrings.onboardingBodyPage3,
            style: AppTextStyles.bodyDescription,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
