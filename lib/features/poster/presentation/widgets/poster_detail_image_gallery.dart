import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_images.dart';
import '../../../../core/design_system/app_dimens.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/poster_detail.dart';

/// AC-1: a zoomable image carousel — `InteractiveViewer` (framework-native
/// pinch-to-zoom, no new dependency per ADR-0005) inside a `PageView`, plus
/// a dot page indicator. Falls back to the placeholder icon (matching
/// `HomePosterCard`'s empty-image treatment) when there are no images at
/// all — a poster with neither `images` nor `primary_image_url` is a real,
/// null-safe case per ADR-0005, not an error.
class PosterDetailImageGallery extends StatefulWidget {
  const PosterDetailImageGallery({
    super.key,
    required this.poster,
    this.onZoomChanged,
  });

  final PosterDetail poster;

  /// Fires when the current image crosses in or out of a zoomed state. The
  /// caller is expected to stop its own vertical scrollable while this is
  /// `true` — see the gesture-arena note on [_PosterDetailImageGalleryState].
  final ValueChanged<bool>? onZoomChanged;

  @override
  State<PosterDetailImageGallery> createState() =>
      _PosterDetailImageGalleryState();
}

/// A zoomed [InteractiveViewer] only receives a one-finger pan if no ancestor
/// scrollable competes for it. `InteractiveViewer` drives a single
/// `ScaleGestureRecognizer` (`interactive_viewer.dart` builds a `GestureDetector`
/// with only `onScale*`), which claims the gesture arena once the focal point
/// travels `kPanSlop` (36lp) — but a `Scrollable`'s drag recognizer claims at
/// `kTouchSlop` (18lp) and therefore always wins first, at every zoom level.
/// Pinching was never affected: a second pointer makes the mono-drag recognizer
/// reject itself, leaving the scale recognizer alone in the arena.
///
/// So both competing scrollables have to stand down while zoomed — the
/// [PageView] here (via [NeverScrollableScrollPhysics], which makes `Scrollable`
/// install no drag recognizer at all) and the screen's outer `ListView` (via
/// [PosterDetailImageGallery.onZoomChanged]). Neither half is catchable by a
/// widget test; see this feature's `CLAUDE.md`.
class _PosterDetailImageGalleryState extends State<PosterDetailImageGallery> {
  /// Above this scale the image is "zoomed". `minScale: 1` below pins an
  /// untouched page to exactly 1.0, so this only has to clear float noise.
  static const _zoomedAboveScale = 1.01;

  final _pageController = PageController();
  final _transformationController = TransformationController();
  int _page = 0;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_handleTransformationChange);
  }

  /// Only rebuilds when the *boolean* flips, not on every frame of a pinch.
  void _handleTransformationChange() {
    final zoomed =
        _transformationController.value.getMaxScaleOnAxis() > _zoomedAboveScale;
    if (zoomed == _zoomed) return;
    setState(() => _zoomed = zoomed);
    widget.onZoomChanged?.call(zoomed);
  }

  /// Sorted by `sort_order`, primary first when `sort_order` ties — falls
  /// back to a single-item list built from `primary_image_url` when
  /// `images` is empty but that field is set (both being empty/null is the
  /// "no image at all" case handled by [build]).
  List<String> get _urls {
    final images = [...widget.poster.images]
      ..sort((a, b) {
        if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
        return a.sortOrder.compareTo(b.sortOrder);
      });
    if (images.isNotEmpty) return images.map((i) => i.url).toList();
    final primary = widget.poster.primaryImageUrl;
    return primary == null ? const [] : [primary];
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleTransformationChange);
    _transformationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;

    return AspectRatio(
      aspectRatio: AppDimens.posterCardAspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (urls.isEmpty)
            const _ImagePlaceholder()
          else
            PageView.builder(
              controller: _pageController,
              physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
              itemCount: urls.length,
              onPageChanged: (index) {
                // Belt and braces — a page can only change at scale 1 now, so
                // the matrix is already identity by the time this runs.
                _transformationController.value = Matrix4.identity();
                setState(() => _page = index);
              },
              itemBuilder: (context, index) => InteractiveViewer(
                transformationController: _transformationController,
                // The default (0.8) lets the image settle *smaller* than its
                // frame, so "zoomed all the way out" would stop short of
                // identity and leave the swipe still locked. Exactly 1 lands
                // zoom-out back on the swipeable state.
                minScale: 1,
                maxScale: 4,
                child: Image.network(
                  urls[index],
                  // AC-1 wants close-up shots of edges/corners readable as
                  // authenticity evidence — `BoxFit.cover` would crop
                  // exactly that content to fill the frame, so this uses
                  // `contain` instead even though it can letterbox
                  // non-matching aspect ratios.
                  fit: BoxFit.contain,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) =>
                      const _ImagePlaceholder(),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const _ImagePlaceholder();
                  },
                ),
              ),
            ),
          if (urls.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  urls.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs / 2,
                    ),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _page
                          ? AppColors.accent
                          : AppColors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.posterPlaceholderFill,
      child: Center(
        child: SvgPicture.asset(
          AppImages.posterPlaceholderIcon,
          width: 64,
          height: 64,
        ),
      ),
    );
  }
}
