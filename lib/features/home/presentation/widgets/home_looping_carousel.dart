import 'package:flutter/material.dart';

/// A horizontally-scrolling, seamlessly-looping carousel of fixed-width
/// [items]: scroll left or right indefinitely and the list wraps around
/// without ever visibly hitting an edge.
///
/// Hand-rolled rather than pulled from a package (no carousel dependency
/// exists in this project) using the standard technique for bidirectional
/// infinite scroll: [ListView.builder] is given a very large `itemCount`
/// (a large repeat count of [items], not a literal "infinite" sentinel —
/// the builder is lazy, so this costs nothing at runtime) and each built
/// index is mapped back to a real item via `index % items.length`. The
/// owned [ScrollController] starts at an `initialScrollOffset` computed to
/// land exactly on a repeat boundary, so at first paint this looks
/// identical to a plain bounded list starting at real index 0 — it only
/// becomes "loopable" once the user actually scrolls.
///
/// [itemExtent] (not manual per-item sizing) drives layout: fixed-size
/// horizontal cards make this the cheap [SliverFixedExtentList] path, and
/// it's what makes the `initialScrollOffset` math exact rather than
/// estimated.
class HomeLoopingCarousel<T> extends StatefulWidget {
  const HomeLoopingCarousel({
    super.key,
    required this.items,
    required this.itemWidth,
    required this.spacing,
    required this.height,
    required this.itemBuilder,
  }) : assert(
         items.length > 0,
         'HomeLoopingCarousel requires at least one item',
       );

  /// The real, small backing list — e.g. 3 featured collections. Repeated
  /// many times under the hood to simulate infinite scroll.
  final List<T> items;

  /// Fixed width of a single rendered item, in logical pixels.
  final double itemWidth;

  /// Gap after each item, in logical pixels — applied after every item,
  /// including the wrap from the last real item back to the first, so the
  /// loop boundary is visually indistinguishable from any other gap.
  final double spacing;

  /// Height of the carousel's scrollable area.
  final double height;

  /// Builds the visual for a single real item (already resolved via
  /// modulo — no index/looping concerns leak into the caller).
  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  State<HomeLoopingCarousel<T>> createState() => _HomeLoopingCarouselState<T>();
}

class _HomeLoopingCarouselState<T> extends State<HomeLoopingCarousel<T>> {
  /// Repeats of [HomeLoopingCarousel.items] spanned by the builder's
  /// `itemCount`. `ListView.builder` is lazy, so this is free at runtime;
  /// it just needs to be large enough that no realistic drag session could
  /// reach either edge, while keeping max scroll offset far under the
  /// double-precision exact-integer ceiling (2^53).
  static const int _loopMultiplier = 100000;

  late final double _itemExtent = widget.itemWidth + widget.spacing;
  late final int _itemCount = widget.items.length * _loopMultiplier;

  /// First builder index of the middle repeat — always an exact multiple
  /// of `items.length` (so it aligns with real index 0) and roughly
  /// halfway through `_itemCount` (so there's equal headroom to scroll
  /// either direction).
  late final int _initialIndex = (_loopMultiplier ~/ 2) * widget.items.length;

  late final ScrollController _controller = ScrollController(
    initialScrollOffset: _initialIndex * _itemExtent,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ListView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemExtent: _itemExtent,
        itemCount: _itemCount,
        itemBuilder: (context, index) {
          final item = widget.items[index % widget.items.length];
          return Padding(
            padding: EdgeInsets.only(right: widget.spacing),
            child: widget.itemBuilder(context, item),
          );
        },
      ),
    );
  }
}
