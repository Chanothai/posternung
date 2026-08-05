import 'package:flutter/material.dart';

import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/poster_status.dart';

/// AC-4 (quantity max 1 / BR-04) as a status message, not a quantity
/// selector — ADR-0005 §D1 forbids any control that implies a purchase
/// flow this round. Also covers `reserved`/`sold` so a status change picked
/// up by `PosterDetailViewModel.refresh()` (AC-5) renders in place, without
/// a separate screen swap.
///
/// `available` renders as ADR-0012 §D1's urgency badge (figma 7:1002) — a
/// fit-content, `AppColors.accentRed` box with a 16px icon. `reserved` keeps
/// its pre-existing full-width notice: the figma frame this round follows
/// only ever shows the `available` state, so there is nothing to restyle it
/// against. Both branches keep their own copy from `AppStrings` — the figma
/// text ("Only 1 Available") is never hardcoded here (ADR-0012 §D1).
class PosterAvailabilityStatus extends StatelessWidget {
  const PosterAvailabilityStatus({super.key, required this.status});

  final PosterStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      PosterStatus.available => const _UrgencyBadge(
        text: AppStrings.posterDetailSingleStockNotice,
      ),
      PosterStatus.reserved => _Notice(
        text: AppStrings.posterDetailReservedNotice,
        color: AppColors.accent,
      ),
      PosterStatus.sold => const SizedBox.shrink(),
    };
  }
}

/// ADR-0012 §D1 (7:1002) — a box sized to its own content (not
/// `double.infinity` like [_Notice]), radius 4, a 16px icon, and
/// `AppColors.accentRed` throughout. `Flexible` around the text rather than
/// an unconstrained `Row` — the Thai copy is a full sentence, not a short
/// label, and has to wrap onto a second line instead of overflowing when it
/// doesn't fit on one.
class _UrgencyBadge extends StatelessWidget {
  const _UrgencyBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderMuted),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: AppColors.accentRed,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.homePosterSubtitle.copyWith(
                color: AppColors.accentRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        style: AppTextStyles.homePosterSubtitle.copyWith(color: color),
      ),
    );
  }
}
