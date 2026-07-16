import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_images.dart';
import '../../../../core/design_system/app_dimens.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../models/home_mock_data.dart';
import 'home_coming_soon.dart';
import 'home_looping_carousel.dart';
import 'home_poster_card.dart';

/// "Ending Soon" — a bordered section with a "View all" link and a
/// horizontal-scroll row of poster cards.
///
/// Figma: node 7:301.
class HomeEndingSoonSection extends StatelessWidget {
  const HomeEndingSoonSection({super.key});

  static const double _itemWidth = 140;

  /// Space `HomePosterCard` needs below its image for title, subtitle, and
  /// price row — plus a little breathing room so the card never clips.
  static const double _cardTextBlockHeight = 72;

  static const double _itemHeight =
      _itemWidth / AppDimens.posterCardAspectRatio +
      _cardTextBlockHeight +
      AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.borderMuted),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.lg,
          bottom: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.lg),
                    child: Text(
                      AppStrings.homeSectionEndingSoon,
                      style: AppTextStyles.homeSectionHeading,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => showComingSoonSnackBar(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppStrings.homeViewAllLink,
                          style: AppTextStyles.linkSmall,
                        ),
                        SvgPicture.asset(
                          AppImages.chevronRightIcon,
                          width: 6.25,
                          height: 10,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            HomeLoopingCarousel<HomePoster>(
              items: endingSoonPosters,
              itemWidth: _itemWidth,
              spacing: AppSpacing.lg,
              height: _itemHeight,
              itemBuilder: (context, poster) => HomePosterCard(
                poster: poster,
                imageHeight: _itemWidth / AppDimens.posterCardAspectRatio,
                priceColor: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
