import 'package:flutter/material.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Generic failure state — network/server errors and any other
/// `CatalogException` that isn't `POSTER_NOT_FOUND` (see
/// `PosterNotFoundView` for that specific case). Unlike the not-found view,
/// this one offers retry since the same request can plausibly succeed on a
/// second try.
class PosterErrorView extends StatelessWidget {
  const PosterErrorView({super.key, this.message, required this.onRetry});

  /// The backend's own `CatalogException.message` (already Thai — see
  /// `PosterRemoteDataSource._guard`), shown in place of the static
  /// [AppStrings.posterDetailErrorBody] copy when available, so the user
  /// sees what actually went wrong rather than a generic message for every
  /// failure. `null` (e.g. a non-`CatalogException` error) falls back to
  /// the static copy.
  final String? message;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.accentRed,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppStrings.posterDetailErrorTitle,
              style: AppTextStyles.authCardHeading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message ?? AppStrings.posterDetailErrorBody,
              style: AppTextStyles.cardSubtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.borderMuted),
              ),
              child: Text(AppStrings.posterDetailErrorRetryCta),
            ),
          ],
        ),
      ),
    );
  }
}
