import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_images.dart';
import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// The accent pill primary CTA shared across onboarding screens. Defaults to
/// "next" with a trailing arrow; the last screen passes a different [label]
/// and sets [showArrow] to false (e.g. "Get Started").
///
/// [label] is `Flexible` + `BoxFit.scaleDown` because the pill's own width is
/// `double.infinity` minus fixed padding, while the label's width is a
/// constant that does not shrink — so past a certain width-to-text-scale
/// ratio the row overflowed to the right.
///
/// 🔴 The widths behind that — page 3's longer label overflowing at every
/// width from 360 dp down, the short label overflowing at 280 dp with a 1.5
/// text scale — are **widget-test numbers, not device numbers**. `flutter
/// test` has no Kanit, so its glyphs run roughly twice as wide as the real
/// face (ADR-0023 §Consequences 6). On a device at 320 dp, verified
/// 2026-08-11, this row does **not** overflow and `scaleDown` never engages.
/// They are an upper bound on required width, not what a user sees. See
/// `OnboardingHeader` for the same note; the mechanism is identical.
///
/// `scaleDown` rather than `TextOverflow.ellipsis`: truncating the primary
/// action is worse than rendering it small, and it never shrinks anything
/// that already fits. Floor and text-scale axis: ADR-0023 D5.
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.lg,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, style: AppTextStyles.primaryButton),
                ),
              ),
              if (showArrow) ...[
                const SizedBox(width: AppSpacing.md),
                SvgPicture.asset(
                  AppImages.arrowRight,
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
