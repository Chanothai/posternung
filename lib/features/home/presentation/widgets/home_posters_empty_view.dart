import 'package:flutter/material.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// SCR-03's `empty` required state — `total == 0`, i.e. the catalog itself
/// has nothing, which is a legitimate answer and not a failure. No retry
/// button: retrying an empty catalog just returns the same empty catalog.
class HomePostersEmptyView extends StatelessWidget {
  const HomePostersEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            AppStrings.homePostersEmptyTitle,
            style: AppTextStyles.authCardHeading,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.homePostersEmptyBody,
            style: AppTextStyles.cardSubtitle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
