import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/onboarding_providers.dart';

/// The row of `onboardingPageCount` dots shared across onboarding screens.
///
/// Tracks [pageController]'s live scroll position directly via
/// [AnimatedBuilder] so the dots interpolate smoothly as the user swipes,
/// instead of snapping between whole-number page states.
class OnboardingProgressIndicator extends StatelessWidget {
  const OnboardingProgressIndicator({super.key, required this.pageController});

  final PageController pageController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pageController,
      builder: (context, _) {
        final page = pageController.hasClients
            ? (pageController.page ?? pageController.initialPage.toDouble())
            : pageController.initialPage.toDouble();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(onboardingPageCount, (index) {
            final proximity = (1 - (page - index).abs()).clamp(0.0, 1.0);
            return Padding(
              padding: EdgeInsets.only(
                right: index == onboardingPageCount - 1 ? 0 : AppSpacing.md,
              ),
              child: Container(
                width: lerpDouble(8, 32, proximity),
                height: 8,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    AppColors.textSecondary.withValues(alpha: 0.5),
                    AppColors.accent,
                    proximity,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
