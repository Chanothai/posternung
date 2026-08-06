import 'package:flutter/material.dart';

import '../../../../core/design_system/app_dimens.dart';
import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../poster/presentation/catalog_error_display.dart';
import '../state/home_posters_state.dart';

/// The pager under SCR-03's grid: how much of the catalog is on screen, and
/// the button that fetches the next page.
///
/// Renders nothing at all once everything is loaded — no "แสดง 7 จาก 7"
/// line, and no button that would fetch an empty page.
///
/// A failed page is reported *here*, inline, rather than through the
/// screen-level `HomePostersErrorView`: the rows already fetched are still
/// good, and replacing an intact grid with a full-screen error because an
/// optional extra page timed out costs the user everything they were
/// reading.
class HomeLoadMoreFooter extends StatelessWidget {
  const HomeLoadMoreFooter({
    super.key,
    required this.state,
    required this.onLoadMore,
  });

  final HomePostersState state;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (!state.hasMore) return const SizedBox.shrink();

    final counts = AppStrings.homeCatalogShownOfTotal
        .replaceFirst('{shown}', '${state.items.length}')
        .replaceFirst('{total}', '${state.total}');
    final error = state.loadMoreError;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        children: [
          Text(counts, style: AppTextStyles.homeLoadMoreLabel),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              // The backend's own Thai message when there is one — same
              // treatment the first-page error view gives it (ADR-0017 D9
              // shared mapper, not a hand-rolled `is CatalogException` check).
              catalogErrorMessageFor(
                    error,
                    fallback: AppStrings.homeLoadMoreErrorBody,
                  ) ??
                  AppStrings.homeLoadMoreErrorBody,
              style: AppTextStyles.statusBody,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _LoadMoreButton(
            isLoading: state.isLoadingMore,
            hasFailed: error != null,
            // Disabled while a page is in flight, so the button can't be
            // hammered into a queue of requests. `loadMore()` guards this
            // too — this is the part the user can see.
            onPressed: state.isLoadingMore ? null : onLoadMore,
          ),
        ],
      ),
    );
  }
}

/// Shaped like the app's other pill CTAs (`AppRadius.full`, `AppColors
/// .accent` border), for the same reason `AppStatusView` styles its own:
/// an unstyled `OutlinedButton` falls back to `ThemeData`'s seed-purple
/// Roboto, which is neither this app's font nor its palette.
class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({
    required this.isLoading,
    required this.hasFailed,
    required this.onPressed,
  });

  final bool isLoading;
  final bool hasFailed;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = isLoading
        ? AppStrings.homeLoadMoreLoading
        : hasFailed
        ? AppStrings.homePostersRetryCta
        : AppStrings.homeLoadMoreButton;

    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        disabledForegroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.accent),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      ),
      icon: isLoading
          ? const SizedBox(
              width: AppDimens.iconSm,
              height: AppDimens.iconSm,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            )
          : Icon(
              hasFailed ? Icons.refresh_rounded : Icons.expand_more_rounded,
              size: AppDimens.iconSm,
              color: AppColors.accent,
            ),
      label: Text(label, style: AppTextStyles.statusActionLabel),
    );
  }
}
