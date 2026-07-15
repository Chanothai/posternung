import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../widgets/home_all_posters_section.dart';
import '../widgets/home_bottom_nav_bar.dart';
import '../widgets/home_ending_soon_section.dart';
import '../widgets/home_featured_collections_section.dart';
import '../widgets/home_top_bar_header_delegate.dart';

/// The post-login home screen: a movie-poster marketplace listing —
/// featured collections, items ending soon, and the full catalog.
///
/// Figma: node 7:206, frame "Home".
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _fallbackTopBarHeight = 130.0;

  final GlobalKey _topBarContentKey = GlobalKey();
  double _topBarHeight = _fallbackTopBarHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTopBarHeight());
  }

  void _measureTopBarHeight() {
    final renderObject = _topBarContentKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final measuredHeight = renderObject.size.height;
    if (!mounted || (measuredHeight - _topBarHeight).abs() < 0.5) return;
    setState(() => _topBarHeight = measuredHeight);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppGradientBackground(),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  floating: true,
                  delegate: HomeTopBarHeaderDelegate(
                    maxExtent: _topBarHeight,
                    contentKey: _topBarContentKey,
                  ),
                ),
                const SliverToBoxAdapter(
                  child: HomeFeaturedCollectionsSection(),
                ),
                const SliverToBoxAdapter(child: HomeEndingSoonSection()),
                const SliverToBoxAdapter(child: HomeAllPostersSection()),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const HomeBottomNavBar(),
    );
  }
}
