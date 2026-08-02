import 'package:flutter/material.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/widgets/app_status_view.dart';

/// AC-6 — `404 POSTER_NOT_FOUND`: there is no such poster at all, a
/// different case from "exists but sold" (`PosterSoldBanner`). No retry
/// button — the ID genuinely doesn't exist, retrying the same ID cannot
/// succeed — only a way back, and [AppStatusTone.neutral] rather than the
/// error tint, since nothing malfunctioned.
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: AppStatusView(
          icon: Icons.search_off_rounded,
          title: AppStrings.posterDetailNotFoundTitle,
          body: message ?? AppStrings.posterDetailNotFoundBody,
          actionLabel: AppStrings.posterDetailNotFoundCta,
          actionIcon: Icons.arrow_back_rounded,
          onAction: onGoBack,
        ),
      ),
    );
  }
}
