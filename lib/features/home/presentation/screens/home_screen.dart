import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../widgets/home_all_posters_section.dart';
import '../widgets/home_bottom_nav_bar.dart';
import '../widgets/home_ending_soon_section.dart';
import '../widgets/home_featured_collections_section.dart';
import '../widgets/home_top_bar.dart';

/// The post-login home screen: a movie-poster marketplace listing —
/// featured collections, items ending soon, and the full catalog.
///
/// Figma: node 7:206, frame "Home".
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: const Stack(
        fit: StackFit.expand,
        children: [
          AppGradientBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                HomeTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        HomeFeaturedCollectionsSection(),
                        HomeEndingSoonSection(),
                        HomeAllPostersSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const HomeBottomNavBar(),
    );
  }
}
