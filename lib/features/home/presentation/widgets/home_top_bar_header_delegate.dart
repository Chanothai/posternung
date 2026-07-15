import 'package:flutter/material.dart';

import 'home_top_bar.dart';

/// [SliverPersistentHeaderDelegate] hosting the unmodified [HomeTopBar] as a
/// floating, fully-collapsible sliver header.
///
/// [HomeTopBar] always lays out at its own natural (unconstrained) height via
/// [OverflowBox] — the sliver framework only resizes the OUTER box returned by
/// [build] (to `maxExtent - shrinkOffset`), and [ClipRect] trims [HomeTopBar]
/// from the bottom (search bar disappears first, logo/title row persists
/// longest). Because the [BoxConstraints] fed to [HomeTopBar] never change
/// between scroll frames, `RenderObject.layout`'s unchanged-constraints fast
/// path skips re-laying-out its subtree each frame; the [RepaintBoundary]
/// additionally isolates its paint from the per-frame clip-bounds change.
class HomeTopBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  HomeTopBarHeaderDelegate({required this.maxExtent, required this.contentKey});

  @override
  final double maxExtent;

  /// Attached to the rendered [HomeTopBar] so [HomeScreen] can measure its
  /// true natural height once, after the first frame.
  final GlobalKey contentKey;

  @override
  double get minExtent => 0.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: 0,
        maxHeight: double.infinity,
        child: RepaintBoundary(
          child: KeyedSubtree(key: contentKey, child: const HomeTopBar()),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant HomeTopBarHeaderDelegate oldDelegate) {
    return oldDelegate.maxExtent != maxExtent;
  }
}
