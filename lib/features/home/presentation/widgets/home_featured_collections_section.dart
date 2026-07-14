import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../models/home_mock_data.dart';
import 'home_collection_card.dart';

/// "Featured Collections" — a horizontal-scroll row of collection cards.
///
/// Figma: node 7:273.
class HomeFeaturedCollectionsSection extends StatelessWidget {
  const HomeFeaturedCollectionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 24, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Featured Collections', style: AppTextStyles.homeSectionHeading),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: featuredCollections.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) =>
                  HomeCollectionCard(collection: featuredCollections[index]),
            ),
          ),
        ],
      ),
    );
  }
}
