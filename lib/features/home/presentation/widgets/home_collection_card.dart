import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../models/home_mock_data.dart';

/// 280x160 featured-collection card: a placeholder-fill background standing
/// in for the collection photo, a bottom gradient wash, and eyebrow/title
/// text pinned to the bottom-left.
///
/// Figma: node 7:277, "Collection Card 1" (and its 2 siblings).
class HomeCollectionCard extends StatelessWidget {
  const HomeCollectionCard({super.key, required this.collection});

  final HomeCollection collection;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 160,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.posterPlaceholderFill,
        border: Border.all(color: AppColors.borderMuted),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Stack(
        children: [
          Center(
            child: SvgPicture.asset(
              'assets/images/poster_placeholder_icon.svg',
              width: 48,
              height: 48,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: [0, 0.5, 1],
                colors: [
                  Color(0xCC000000),
                  Color(0x4D000000),
                  Color(0x00000000),
                ],
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  collection.eyebrow,
                  style: AppTextStyles.homeCollectionEyebrow,
                ),
                Text(
                  collection.title,
                  style: AppTextStyles.homeCollectionTitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
