import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_images.dart';
import '../../../../core/design_system/app_dimens.dart';
import '../../../../core/design_system/app_radius.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/poster_detail.dart';

/// AC-1: a zoomable image carousel — `InteractiveViewer` (framework-native
/// pinch-to-zoom, no new dependency per ADR-0005) inside a `PageView`, plus
/// a dot page indicator. Falls back to the placeholder icon (matching
/// `HomePosterCard`'s empty-image treatment) when there are no images at
/// all — a poster with neither `images` nor `primary_image_url` is a real,
/// null-safe case per ADR-0005, not an error.
///
/// Pinch-to-zoom is invisible on its own, so the same zoom is reachable three
/// ways: the pinch, a double tap, and a visible button on the image. Device
/// verification of SCR-05 found buyers never discovering it at all, which
/// matters more here than on a normal gallery — zooming *is* how a buyer
/// inspects condition before committing (BR-05, ADR-0003).
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
class _PosterDetailImageGalleryState extends State<PosterDetailImageGallery>
    with SingleTickerProviderStateMixin {
  /// Above this scale the image is "zoomed". `minScale: 1` below pins an
  /// untouched page to exactly 1.0, so this only has to clear float noise.
  static const _zoomedAboveScale = 1.01;

  /// Where a double tap / the zoom button lands. Short of [_maxScale] on
  /// purpose: it should read edges and corners without stranding the buyer at
  /// the limit with nowhere left to go.
  static const _doubleTapScale = 2.5;
  static const _maxScale = 4.0;

  final _pageController = PageController();
  final _transformationController = TransformationController();
  final _viewportKey = GlobalKey();

  late final AnimationController _zoomAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  Animation<Matrix4>? _zoomTween;

  int _page = 0;
  bool _zoomed = false;
  Offset? _doubleTapPosition;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_handleTransformationChange);
    _zoomAnimation.addListener(_applyZoomAnimation);
  }

  /// Only rebuilds when the *boolean* flips, not on every frame of a pinch.
  void _handleTransformationChange() {
    final zoomed =
        _transformationController.value.getMaxScaleOnAxis() > _zoomedAboveScale;
    if (zoomed == _zoomed) return;
    setState(() => _zoomed = zoomed);
    widget.onZoomChanged?.call(zoomed);
  }

  void _applyZoomAnimation() {
    final tween = _zoomTween;
    if (tween != null) _transformationController.value = tween.value;
  }

  /// A matrix that scales by [scale] while holding [focus] (a point in
  /// viewport coordinates) still, then slides the result back inside the
  /// frame. The clamp is ours to do: `InteractiveViewer` only enforces its
  /// boundaries inside its own gesture handlers, so a matrix assigned
  /// directly would happily leave blank space along an edge.
  Matrix4 _zoomedInMatrix(Offset focus) {
    final size = _viewportSize;
    if (size == null) return Matrix4.identity();

    const scale = _doubleTapScale;
    var dx = focus.dx * (1 - scale);
    var dy = focus.dy * (1 - scale);
    dx = dx.clamp(-(scale - 1) * size.width, 0.0);
    dy = dy.clamp(-(scale - 1) * size.height, 0.0);

    // `translate`/`scale` are deprecated in vector_math 2.2.0 and would fail
    // `flutter analyze --fatal-infos`; the ...ByDouble forms are the
    // replacements.
    return Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  Size? get _viewportSize {
    final box = _viewportKey.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size : null;
  }

  void _animateZoomTo(Matrix4 target) {
    _zoomTween = Matrix4Tween(
      begin: _transformationController.value,
      end: target,
    ).animate(CurvedAnimation(parent: _zoomAnimation, curve: Curves.easeOut));
    _zoomAnimation.forward(from: 0);
  }

  /// Double tap and the button share one action so they can never disagree
  /// about what "zoomed" means. Toggling out always returns to identity,
  /// which is what re-arms the swipe (see [_zoomedAboveScale]).
  void _toggleZoom({Offset? focus}) {
    if (_zoomed) {
      _animateZoomTo(Matrix4.identity());
      return;
    }
    final size = _viewportSize;
    final centre = size == null
        ? Offset.zero
        : Offset(size.width / 2, size.height / 2);
    _animateZoomTo(_zoomedInMatrix(focus ?? centre));
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
    _zoomAnimation.removeListener(_applyZoomAnimation);
    _zoomAnimation.dispose();
    _transformationController.removeListener(_handleTransformationChange);
    _transformationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The clip lives here rather than around the whole widget: the caption
        // below is part of the gallery, but rounding *it* would leave the
        // image's own bottom corners square.
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AspectRatio(
            key: _viewportKey,
            aspectRatio: AppDimens.posterCardAspectRatio,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                if (urls.isEmpty)
                  const _ImagePlaceholder()
                else
                  PageView.builder(
                    controller: _pageController,
                    physics: _zoomed
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    itemCount: urls.length,
                    onPageChanged: (index) {
                      // Belt and braces — a page can only change at scale 1 now,
                      // so the matrix is already identity by the time this runs.
                      _transformationController.value = Matrix4.identity();
                      setState(() => _page = index);
                    },
                    itemBuilder: (context, index) => GestureDetector(
                      // A double tap needs no travel at all, so it never
                      // competes with the pan/scale recognizers that resolve on
                      // slop — this adds a second way in without touching the
                      // arena balance the zoom fix depends on.
                      onDoubleTapDown: (details) =>
                          _doubleTapPosition = details.localPosition,
                      onDoubleTap: () => _toggleZoom(focus: _doubleTapPosition),
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        // The default (0.8) lets the image settle *smaller* than
                        // its frame, so "zoomed all the way out" would stop short
                        // of identity and leave the swipe still locked. Exactly 1
                        // lands zoom-out back on the swipeable state.
                        minScale: 1,
                        maxScale: _maxScale,
                        // A finger beats an in-flight animation — otherwise the
                        // two fight over the same matrix and the image stutters.
                        onInteractionStart: (_) => _zoomAnimation.stop(),
                        child: Image.network(
                          urls[index],
                          // AC-1 wants close-up shots of edges/corners readable
                          // as authenticity evidence — `BoxFit.cover` would crop
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
                  ),
                if (urls.isNotEmpty)
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: _ZoomButton(
                      zoomedIn: _zoomed,
                      onPressed: _toggleZoom,
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
          ),
        ),
        if (urls.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          // Text only — the glyph already sits on the image, and repeating it
          // here would read as a second, separate control.
          Text(
            AppStrings.posterDetailZoomHint,
            style: AppTextStyles.imageHintLabel,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// The visible half of the zoom affordance. Sits on the image rather than
/// beside it so the thing it acts on is unambiguous, over a scrim light
/// enough to leave the artwork legible underneath.
class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.zoomedIn, required this.onPressed});

  final bool zoomedIn;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // `IconButton` rather than a hand-rolled `InkWell`: it already announces
    // itself as a button and reuses `tooltip` as the accessible label, which
    // an icon-only control has no other source for.
    return IconButton(
      onPressed: onPressed,
      tooltip: zoomedIn
          ? AppStrings.posterDetailZoomOutTooltip
          : AppStrings.posterDetailZoomInTooltip,
      icon: Icon(
        zoomedIn ? Icons.zoom_out : Icons.zoom_in,
        size: AppDimens.iconMd,
        color: AppColors.white,
      ),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.imageControlScrim,
        minimumSize: const Size(
          AppDimens.minTouchTarget,
          AppDimens.minTouchTarget,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
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
