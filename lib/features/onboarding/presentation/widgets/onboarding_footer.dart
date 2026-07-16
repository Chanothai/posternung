import 'package:flutter/material.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import 'onboarding_primary_button.dart';
import 'onboarding_progress_indicator.dart';

/// Shared footer chrome across onboarding screens: gradient wash, progress
/// dots, and the primary CTA.
class OnboardingFooter extends StatelessWidget {
  const OnboardingFooter({
    super.key,
    required this.pageController,
    required this.onNext,
    this.buttonLabel = AppStrings.onboardingNextButton,
    this.showArrowIcon = true,
  });

  final PageController pageController;
  final VoidCallback onNext;
  final String buttonLabel;
  final bool showArrowIcon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surfaceDark.withValues(alpha: 0),
            AppColors.surfaceDark,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OnboardingProgressIndicator(pageController: pageController),
            const SizedBox(height: AppSpacing.xxl),
            OnboardingPrimaryButton(
              onPressed: onNext,
              label: buttonLabel,
              showArrow: showArrowIcon,
            ),
          ],
        ),
      ),
    );
  }
}
