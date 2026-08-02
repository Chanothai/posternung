import 'package:flutter/material.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// SCR-03's `error` required state. Always carries a retry button — the
/// automatic Riverpod retry is switched off for `homePostersProvider`
/// precisely so this, a user-triggered retry the user can see, is the only
/// one (see that provider's comment).
class HomePostersErrorView extends StatelessWidget {
  const HomePostersErrorView({super.key, this.message, required this.onRetry});

  /// The backend's own `CatalogException.message` (already Thai — see
  /// `PosterRemoteDataSource._guard`) when there is one, so the user sees
  /// what actually failed instead of one generic line for every cause.
  final String? message;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.accentRed),
          const SizedBox(height: AppSpacing.lg),
          Text(
            AppStrings.homePostersErrorTitle,
            style: AppTextStyles.authCardHeading,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message ?? AppStrings.homePostersErrorBody,
            style: AppTextStyles.cardSubtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.borderMuted),
            ),
            child: Text(AppStrings.homePostersRetryCta),
          ),
        ],
      ),
    );
  }
}
