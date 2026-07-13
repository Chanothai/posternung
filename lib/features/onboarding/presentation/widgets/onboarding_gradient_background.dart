import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The diagonal gradient wash used as the background on onboarding screens
/// that don't have a hero image (shared by the authenticate and
/// limited-stock screens).
class OnboardingGradientBackground extends StatelessWidget {
  const OnboardingGradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.surfaceDark),
        Opacity(
          opacity: 0.9,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.9, -0.4),
                end: Alignment(0.9, 0.4),
                stops: [0, 0.5, 1],
                colors: [
                  AppColors.surfaceDark,
                  AppColors.surfaceDark,
                  Colors.black,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
