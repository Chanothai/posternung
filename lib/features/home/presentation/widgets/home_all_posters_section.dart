import 'package:flutter/material.dart';

import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../models/home_mock_data.dart';
import 'home_coming_soon.dart';
import 'home_poster_card.dart';

/// "All Posters" — a 2-column grid of poster cards, plus a "Load More
/// Titles" button.
///
/// Figma: node 7:361.
class HomeAllPostersSection extends StatelessWidget {
  const HomeAllPostersSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.homeSectionAllPosters,
            style: AppTextStyles.homeSectionHeading,
          ),
          const SizedBox(height: AppSpacing.lg),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allPosters.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.lg,
              mainAxisSpacing: AppSpacing.lg,
              mainAxisExtent: 321.25,
            ),
            itemBuilder: (context, index) => HomePosterCard(
              poster: allPosters[index],
              imageHeight: 243.25,
              priceColor: AppColors.textPrimary,
              showWishlistButton: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Center(
              child: OutlinedButton(
                onPressed: () => showComingSoonSnackBar(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.borderMuted),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
                child: Text(
                  AppStrings.homeLoadMoreButton,
                  style: AppTextStyles.homeLoadMoreLabel,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
