import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'dashed_circle_border.dart';

/// Content for onboarding's second page ("100% Authenticated Originals").
///
/// Figma: node 7:2, frame "Onboarding - Authenticate".
class OnboardingAuthenticatePageContent extends StatelessWidget {
  const OnboardingAuthenticatePageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [_CenterpieceBadge(), SizedBox(height: 40), _CopyBlock()],
    );
  }
}

class _CenterpieceBadge extends StatelessWidget {
  const _CenterpieceBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 256,
      height: 256,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0.2,
            child: SvgPicture.asset(
              'assets/images/header_icon.svg',
              width: 256,
              height: 256,
            ),
          ),
          Container(
            width: 192,
            height: 192,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderMuted, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.4),
                  blurRadius: 40,
                ),
              ],
            ),
            child: ClipOval(
              child: DashedCircleBorder(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.6),
                              blurRadius: 7.5,
                            ),
                          ],
                        ),
                        child: SvgPicture.asset(
                          'assets/images/verified_badge_icon.svg',
                        ),
                      ),
                      const SizedBox(height: 11),
                      Text(
                        AppStrings.onboardingVerifiedBadge,
                        style: AppTextStyles.badgeLabel,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
                text: AppStrings.onboardingHeroTitlePage2Prefix,
                style: AppTextStyles.heroTitleSmall,
              ),
              TextSpan(
                text: AppStrings.onboardingHeroTitlePage2Emphasis,
                style: AppTextStyles.heroTitleSmallEmphasis,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 384),
          child: Text(
            AppStrings.onboardingBodyPage2,
            style: AppTextStyles.bodyDescription,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
