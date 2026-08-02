import 'package:flutter/material.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/widgets/app_status_view.dart';

/// SCR-03's `error` required state. Always carries a retry button — the
/// automatic Riverpod retry is switched off for `homePostersProvider`
/// precisely so this, a user-triggered retry the user can see, is the only
/// one (see that provider's comment).
///
/// The presentation is `AppStatusView` (core/widgets/), shared with Home's
/// empty state and SCR-05's error/not-found states so all four are one
/// visual language instead of four near-copies.
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: AppStatusView(
        icon: Icons.wifi_off_rounded,
        tone: AppStatusTone.error,
        title: AppStrings.homePostersErrorTitle,
        body: message ?? AppStrings.homePostersErrorBody,
        actionLabel: AppStrings.homePostersRetryCta,
        actionIcon: Icons.refresh_rounded,
        onAction: onRetry,
      ),
    );
  }
}
