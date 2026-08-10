import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_images.dart';
import '../../../../core/design_system/app_dimens.dart';
import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Shared chrome across onboarding screens: film-reel icon, "PosterNung"
/// title, and a skip action. Pass `onSkip: null` to hide/disable the skip
/// action while preserving its layout space (the last onboarding screen has
/// nothing left to skip to).
///
/// The brand cluster is `Flexible` because this `Row`'s children used to add
/// up to a **constant** main-axis extent — nothing in it could give — so the
/// header needed a screen at least that wide or it overflowed on the right at
/// every size below it. That is the shape behind SCR-01's recorded "19px at
/// 360 / 59px at 320", and those numbers were never the hero title on page 1,
/// they were this row.
///
/// 🔴 Those figures are **widget-test numbers, not device numbers**. `flutter
/// test` has no Kanit — `google_fonts` fetches it at runtime and `pubspec.yaml`
/// declares no `fonts:` block — so its glyphs run roughly twice as wide as the
/// real face (ADR-0023 §Consequences 6). On a device at 320 dp, verified
/// 2026-08-11, this row does **not** overflow and `scaleDown` never engages at
/// all. Read them as an upper bound on required width, which is what makes
/// them useful here: passing under a wider font is the stronger claim. What
/// they are not is a description of what a user sees.
///
/// `BoxFit.scaleDown` rather than `TextOverflow.ellipsis`, for the same
/// reason as `OnboardingPrimaryButton`: rendering the wordmark small beats
/// rendering it as "PosterNu…", and it does nothing at all until the text
/// would otherwise not fit. Screen-size floor and the text-scale axis it has
/// to survive: ADR-0023 D5.
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({super.key, this.onSkip});

  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  AppImages.headerIcon,
                  width: AppDimens.iconMd,
                  height: AppDimens.iconMd,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      AppStrings.appName,
                      style: AppTextStyles.appBarTitle,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Opacity(
            opacity: onSkip == null ? 0 : 1,
            child: InkWell(
              onTap: onSkip,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  AppStrings.onboardingSkipButton,
                  style: AppTextStyles.skipButton,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
