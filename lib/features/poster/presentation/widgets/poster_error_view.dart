import 'package:flutter/material.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/widgets/app_status_view.dart';

/// Generic failure state — network/server errors and any other
/// `CatalogException` that isn't `POSTER_NOT_FOUND` (see
/// `PosterNotFoundView` for that specific case). Unlike the not-found view,
/// this one offers retry since the same request can plausibly succeed on a
/// second try.
///
/// Rendered by the shared `AppStatusView` (core/widgets/) — same block Home
/// uses for its error/empty states.
class PosterErrorView extends StatelessWidget {
  const PosterErrorView({super.key, this.message, required this.onRetry});

  /// Resolved via `catalogErrorDisplayMessage`/`catalogErrorMessageFor`
  /// (ADR-0017 D4/D9) — the backend's own Thai `displayMessage` when there
  /// is one (see `PosterRemoteDataSource._guard`), shown in place of the
  /// static [AppStrings.posterDetailErrorBody] copy when available, so the
  /// user sees what actually went wrong rather than a generic message for
  /// every failure. `null` (e.g. a non-`CatalogException` error) falls back
  /// to the static copy.
  final String? message;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: AppStatusView(
          icon: Icons.wifi_off_rounded,
          tone: AppStatusTone.error,
          title: AppStrings.posterDetailErrorTitle,
          body: message ?? AppStrings.posterDetailErrorBody,
          actionLabel: AppStrings.posterDetailErrorRetryCta,
          actionIcon: Icons.refresh_rounded,
          onAction: onRetry,
        ),
      ),
    );
  }
}
