import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/onboarding_providers.dart';

/// The row of `onboardingPageCount` dots shared across onboarding screens;
/// the dot at [currentPage] renders as the active pill.
class OnboardingProgressIndicator extends StatelessWidget {
  const OnboardingProgressIndicator({super.key, required this.currentPage});

  final int currentPage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(onboardingPageCount, (index) {
        final isActive = index == currentPage;
        return Padding(
          padding: EdgeInsets.only(
            right: index == onboardingPageCount - 1 ? 0 : 12,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isActive ? 32 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.accent
                  : AppColors.textSecondary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
        );
      }),
    );
  }
}
