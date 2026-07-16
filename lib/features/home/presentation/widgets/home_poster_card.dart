import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_images.dart';
import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../models/home_mock_data.dart';
import 'home_coming_soon.dart';

/// Poster card shared by the Ending Soon (horizontal) and All Posters (grid)
/// sections — [imageHeight] and [priceColor] absorb the two sections' only
/// styling differences; [showWishlistButton] enables the grid-only heart
/// button.
///
/// Figma: nodes 7:310 (Ending Soon item), 7:365 (All Posters grid item).
class HomePosterCard extends StatelessWidget {
  const HomePosterCard({
    super.key,
    required this.poster,
    required this.imageHeight,
    required this.priceColor,
    this.showWishlistButton = false,
  });

  final HomePoster poster;
  final double imageHeight;
  final Color priceColor;
  final bool showWishlistButton;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: imageHeight,
          width: double.infinity,
          child: Stack(
            children: [
              Container(
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
              ),
              if (poster.badgeLabel != null)
                Positioned(
                  left: 0,
                  top: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    color: AppColors.accentRed,
                    child: Text(
                      poster.badgeLabel!,
                      style: AppTextStyles.homeBadgeLabel,
                    ),
                  ),
                ),
              if (showWishlistButton)
                Positioned(
                  right: AppSpacing.sm,
                  top: AppSpacing.sm,
                  child: _WishlistButton(
                    onTap: () => showComingSoonSnackBar(context),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          poster.title,
          style: AppTextStyles.homePosterTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          poster.subtitle,
          style: AppTextStyles.homePosterSubtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  poster.price,
                  style: AppTextStyles.homePosterPrice.copyWith(
                    color: priceColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderMuted),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  poster.condition,
                  style: AppTextStyles.homeConditionTag,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WishlistButton extends StatelessWidget {
  const _WishlistButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.posterPlaceholderFill,
      shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: SvgPicture.asset(AppImages.heartIcon, width: 12, height: 12),
          ),
        ),
      ),
    );
  }
}
