import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// The accent pill primary CTA shared across onboarding screens. Defaults to
/// "next" with a trailing arrow; the last screen passes a different [label]
/// and sets [showArrow] to false (e.g. "Get Started").
class OnboardingPrimaryButton extends StatelessWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.onPressed,
    this.label = AppStrings.onboardingNextButton,
    this.showArrow = true,
  });

  final VoidCallback onPressed;
  final String label;
  final bool showArrow;

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
              Text(label, style: AppTextStyles.primaryButton),
              if (showArrow) ...[
                const SizedBox(width: 12),
                SvgPicture.asset(
                  'assets/images/arrow_right.svg',
                  width: 12.25,
                  height: 14,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
