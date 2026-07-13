import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// The accent pill "next" CTA shared across onboarding screens.
class OnboardingNextButton extends StatelessWidget {
  const OnboardingNextButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9999),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ถัดไป', style: AppTextStyles.primaryButton),
              const SizedBox(width: 12),
              SvgPicture.asset(
                'assets/images/arrow_right.svg',
                width: 12.25,
                height: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
