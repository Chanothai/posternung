import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Vintage hero gradient background for onboarding's first page.
///
/// Figma: node 6:2, frame "Onboarding - Vintage Hero".
class OnboardingHeroBackground extends StatelessWidget {
  const OnboardingHeroBackground({super.key});

  // TODO: swap for the vintage film poster collage once that image fill is
  // generated in Figma — the source frame currently has no image, only a
  // text prompt as the layer name.
  static const Color _baseTop = Color(0xFF6E5A45);
  static const Color _baseBottom = Color(0xFF3A2F27);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_baseTop, _baseBottom],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.5, 1],
              colors: [
                AppColors.surfaceDark.withValues(alpha: 0.8),
                AppColors.surfaceDark.withValues(alpha: 0.4),
                AppColors.surfaceDark,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
