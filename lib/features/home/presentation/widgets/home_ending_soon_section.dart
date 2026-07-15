import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../models/home_mock_data.dart';
import 'home_coming_soon.dart';
import 'home_poster_card.dart';

/// "Ending Soon" — a bordered section with a "View all" link and a
/// horizontal-scroll row of poster cards.
///
/// Figma: node 7:301.
class HomeEndingSoonSection extends StatelessWidget {
  const HomeEndingSoonSection({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.borderMuted),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 17, bottom: 17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppStrings.homeSectionEndingSoon,
                    style: AppTextStyles.homeSectionHeading,
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
                          'assets/images/chevron_right_icon.svg',
                          width: 6.25,
                          height: 10,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 278,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: endingSoonPosters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, index) => SizedBox(
                  width: 140,
                  child: HomePosterCard(
                    poster: endingSoonPosters[index],
                    imageHeight: 208,
                    priceColor: AppColors.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
