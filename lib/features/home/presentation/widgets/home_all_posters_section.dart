import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('All Posters', style: AppTextStyles.homeSectionHeading),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allPosters.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
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
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: OutlinedButton(
                onPressed: () => showComingSoonSnackBar(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.borderMuted),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
                child: Text(
                  'Load More Titles',
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
