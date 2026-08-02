import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../providers/home_posters_provider.dart';
import '../widgets/home_all_posters_section.dart';
import '../widgets/home_bottom_nav_bar.dart';
import '../widgets/home_top_bar_header_delegate.dart';

/// SCR-03 — Home / Discover. The catalog grid off the real `GET /posters`
/// (US-01).
///
/// Featured Collections and Ending Soon were cut from this round, not
/// postponed inside the code: neither has a schema behind it (no curation
/// table, no tag/genre column, no expiry timestamp), so the sections and
/// their mock content were removed rather than left rendering invented
/// data.
///
/// **This screen calls the backend only when the user asks it to** —
/// pull-to-refresh, the load-more pager, and the retry button. There is
/// deliberately no `WidgetsBindingObserver` re-fetching on
/// `AppLifecycleState.resumed`: every foreground switch re-read the whole
/// loaded span (up to N requests once the user has paged down), which is a
/// lot of traffic for a read-only catalog. The trade-off is that a poster
/// sold while the app sat in the background keeps its old badge until the
/// user pulls to refresh or opens it — `PosterDetailScreen` still
/// re-fetches on resume and shows `PosterSoldBanner`, so nothing can be
/// bought off a stale card.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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
            child: RefreshIndicator(
              onRefresh: () => ref.read(homePostersProvider.notifier).refresh(),
              color: AppColors.accent,
              child: CustomScrollView(
                // Always scrollable so pull-to-refresh still works while the
                // grid is empty or showing an error — the two states where a
                // user is most likely to try it.
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    floating: true,
                    delegate: HomeTopBarHeaderDelegate(
                      maxExtent: _topBarHeight,
                      contentKey: _topBarContentKey,
                    ),
                  ),
                  const SliverToBoxAdapter(child: HomeAllPostersSection()),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const HomeBottomNavBar(),
    );
  }
}
