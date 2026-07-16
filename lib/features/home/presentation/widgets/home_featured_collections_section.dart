import 'package:flutter/material.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../models/home_mock_data.dart';
import 'home_collection_card.dart';
import 'home_looping_carousel.dart';

/// "Featured Collections" — a horizontal-scroll row of collection cards.
///
/// Figma: node 7:273.
class HomeFeaturedCollectionsSection extends StatelessWidget {
  const HomeFeaturedCollectionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.lg),
            child: Text(
              AppStrings.homeSectionFeaturedCollections,
              style: AppTextStyles.homeSectionHeading,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          HomeLoopingCarousel<HomeCollection>(
            items: featuredCollections,
            itemWidth: 280,
            spacing: AppSpacing.lg,
            height: 160,
            itemBuilder: (context, collection) =>
                HomeCollectionCard(collection: collection),
          ),
        ],
      ),
    );
  }
}
