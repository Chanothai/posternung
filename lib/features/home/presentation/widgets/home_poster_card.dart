import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_images.dart';
import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/condition_grade_indicator.dart';
import '../../../poster/domain/entities/poster_status.dart';
import '../../../poster/domain/entities/poster_summary.dart';
import 'home_coming_soon.dart';

/// One cell of SCR-03's catalog grid, backed by a real `PosterListItem`.
///
/// Layout notes that are load-bearing rather than cosmetic:
/// - The image is `Expanded`, so the card absorbs the grid's fixed
///   `mainAxisExtent` in the image rather than overflowing when the text
///   block below grows (the condition badge added a whole line).
/// - Price and condition sit on **separate lines**, not side by side.
///   BR-05 only requires the condition to be shown wherever the price is,
///   not on the same row, and a 2-up grid cell (~140–165 px) can't fit
///   "฿1,250.00" next to "Very Good (5/8)" without ellipsising one of them.
/// - The condition badge is `ConditionGradeIndicator` (core/widgets/) in its
///   `compact` variant — never a bare `Text(grade)`. ADR-0003: a lone label
///   misleads, because "Fine" outranks "Very Good".
class HomePosterCard extends StatelessWidget {
  const HomePosterCard({super.key, required this.poster, required this.onTap});

  final PosterSummary poster;

  /// Opens the detail screen. Cards stay tappable even when the poster is
  /// unavailable (ADR-0005 §D5 — the detail endpoint doesn't filter by
  /// status, and `PosterSoldBanner` is the richer explanation of what
  /// happened); the badge here just stops the card from *looking* buyable.
  final VoidCallback onTap;

  bool get _isAvailable => poster.status == PosterStatus.available;

  /// Era decade + studio. Deliberately **not** the old mock's
  /// "1982 • US Original": `GET /posters` returns neither a film year (no
  /// such column exists — SCR-03's G8) nor a `size`, so that subtitle was
  /// promising data the API cannot supply. Both parts are nullable, and the
  /// subtitle is omitted entirely when neither is present.
  String? get _subtitle {
    final parts = [
      if (poster.eraDecade != null) '${poster.eraDecade}s',
      if (poster.studio != null) poster.studio!,
    ];
    return parts.isEmpty ? null : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Image(poster: poster, isAvailable: _isAvailable),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              poster.title,
              style: AppTextStyles.homePosterTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_subtitle != null)
              Text(
                _subtitle!,
                style: AppTextStyles.homePosterSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              formatThbPrice(poster.price),
              style: AppTextStyles.homePosterPrice,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: ConditionGradeIndicator(
                grade: poster.conditionGrade,
                compact: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Image extends StatelessWidget {
  const _Image({required this.poster, required this.isAvailable});

  final PosterSummary poster;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    final url = poster.primaryImageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url == null)
            const _ImagePlaceholder()
          else
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const _ImagePlaceholder(),
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const _ImagePlaceholder(),
            ),
          if (!isAvailable) _UnavailableOverlay(status: poster.status),
          Positioned(
            right: AppSpacing.sm,
            top: AppSpacing.sm,
            child: _WishlistButton(
              // US-04 (wishlist) is a Could-have outside Phase 1 — the
              // affordance stays, honestly labelled as not built yet.
              onTap: () => showComingSoonSnackBar(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "no image" state, which is a normal outcome rather than an error:
/// `primary_image_url` is nullable in the contract, and the backend returns
/// `null` for a primary image held under an internal-only storage key. A
/// deliberate placeholder, not a broken-image frame.
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.posterPlaceholderFill,
        border: Border.all(color: AppColors.borderMuted),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Center(
        child: SvgPicture.asset(
          AppImages.posterPlaceholderIcon,
          width: 40,
          height: 40,
        ),
      ),
    );
  }
}

/// AC-4 — `status != available` has to read as unavailable at a glance.
/// A scrim over the artwork plus a word, so it survives being seen from
/// across the grid without reading any text.
class _UnavailableOverlay extends StatelessWidget {
  const _UnavailableOverlay({required this.status});

  final PosterStatus? status;

  @override
  Widget build(BuildContext context) {
    final label = status == PosterStatus.sold
        ? AppStrings.homePosterSoldBadge
        : AppStrings.homePosterUnavailableBadge;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.posterPlaceholderFill,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.accentRed,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Text(label, style: AppTextStyles.homeBadgeLabel),
        ),
      ),
    );
  }
}

class _WishlistButton extends StatelessWidget {
  const _WishlistButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      // Also the only stable handle on this button: it's an icon with no
      // text, sitting among several other InkWells inside the card.
      message: AppStrings.homeWishlistButtonTooltip,
      child: Material(
        color: AppColors.posterPlaceholderFill,
        shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: SvgPicture.asset(
                AppImages.heartIcon,
                width: 12,
                height: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
