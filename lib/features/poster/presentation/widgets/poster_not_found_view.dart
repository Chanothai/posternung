import 'package:flutter/material.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// AC-6 — `404 POSTER_NOT_FOUND`: there is no such poster at all, a
/// different case from "exists but sold" (`PosterSoldBanner`). No retry
/// button — the ID genuinely doesn't exist, retrying the same ID cannot
/// succeed — only a way back.
class PosterNotFoundView extends StatelessWidget {
  const PosterNotFoundView({super.key, this.message, required this.onGoBack});

  /// The backend's own `CatalogException.message` (already Thai — see
  /// `PosterRemoteDataSource._guard`), shown in place of the static
  /// [AppStrings.posterDetailNotFoundBody] copy when available. `null`
  /// falls back to the static copy.
  final String? message;

  final VoidCallback onGoBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppStrings.posterDetailNotFoundTitle,
              style: AppTextStyles.authCardHeading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message ?? AppStrings.posterDetailNotFoundBody,
              style: AppTextStyles.cardSubtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(
              onPressed: onGoBack,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.borderMuted),
              ),
              child: Text(AppStrings.posterDetailNotFoundCta),
            ),
          ],
        ),
      ),
    );
  }
}
