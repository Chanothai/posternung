import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'onboarding_primary_button.dart';
import 'onboarding_progress_indicator.dart';

/// Shared footer chrome across onboarding screens: gradient wash, progress
/// dots, and the primary CTA.
class OnboardingFooter extends StatelessWidget {
  const OnboardingFooter({
    super.key,
    required this.currentPage,
    required this.onNext,
    this.buttonLabel = 'ถัดไป',
    this.showArrowIcon = true,
  });

  final int currentPage;
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OnboardingProgressIndicator(currentPage: currentPage),
            const SizedBox(height: 32),
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
