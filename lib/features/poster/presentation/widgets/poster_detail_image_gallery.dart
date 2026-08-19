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
import '../poster_gallery_order.dart';

/// AC-1: a zoomable image carousel — `InteractiveViewer` (framework-native
/// pinch-to-zoom, no new dependency per ADR-0005) inside a `PageView`, plus
/// a dot page indicator. Falls back to the placeholder icon (matching
/// `HomePosterCard`'s empty-image treatment) when there are no images at
/// all — a poster with neither `images` nor `primary_image_url` is a real,
/// null-safe case per ADR-0005, not an error.
///
/// ADR-0012 §D1 (figma 7:1061/7:1067) restyled this to full-bleed (the
/// screen no longer pads its sides) with an `rgba(0,0,0,0.5)` backdrop
/// behind the frame — which doubles as cover for `BoxFit.contain`'s
/// letterbox band on a non-2:3 poster — and moved the page-dot indicator to
/// float inside the image frame instead of sitting below it. The zoom hint
/// stays exactly where it was (ADR-0012 §D5): directly under the image
/// block, above nothing now that the dots have moved inside it.
///
/// Pinch-to-zoom is invisible on its own, so the same zoom is reachable three
/// ways: the pinch, a double tap, and a visible button on the image. Device
/// verification of SCR-05 found buyers never discovering it at all, which
/// matters more here than on a normal gallery — zooming *is* how a buyer
/// inspects condition before committing (BR-05, ADR-0003).
/// Lets the screen drive and observe the gallery's zoom from outside it — the
/// app bar's zoom button and the list's scroll physics both need this, and
/// neither can reach into the gallery's own state.
///
/// The gallery attaches itself while mounted and clears out on dispose, so a
/// screen that leaves its data state cannot be left holding a zoom flag whose
/// image is gone — that stale flag would make its list permanently
/// unscrollable.
class PosterGalleryZoomController extends ChangeNotifier {
  bool _isZoomed = false;
  VoidCallback? _toggle;

  bool get isZoomed => _isZoomed;

  /// Whether a gallery is currently listening. False between screen states.
  bool get isAttached => _toggle != null;

  /// Zooms in on the image's centre, or all the way back out.
  void toggle() => _toggle?.call();

  void _attach(VoidCallback toggle) => _toggle = toggle;

  /// Deliberately silent: this runs from the gallery's `dispose()`, i.e.
  /// during an unmount, where notifying would rebuild widgets mid-teardown.
  /// Whatever removed the gallery is already rebuilding the screen.
  void _detach() {
    _toggle = null;
    _isZoomed = false;
  }

  void _setZoomed(bool value) {
    if (value == _isZoomed) return;
    _isZoomed = value;
    notifyListeners();
  }
}

class PosterDetailImageGallery extends StatefulWidget {
  const PosterDetailImageGallery({
    super.key,
    required this.poster,
    required this.zoomController,
  });

  final PosterDetail poster;

  /// Published so the app bar can offer a zoom button that never scrolls away,
  /// and so the screen's list can stop scrolling while zoomed — see the
  /// gesture-arena note on [_PosterDetailImageGalleryState].
  final PosterGalleryZoomController zoomController;

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
    widget.zoomController._attach(() => _toggleZoom());
  }

  /// Only rebuilds when the *boolean* flips, not on every frame of a pinch.
  void _handleTransformationChange() {
    final zoomed =
        _transformationController.value.getMaxScaleOnAxis() > _zoomedAboveScale;
    if (zoomed == _zoomed) return;
    setState(() => _zoomed = zoomed);
    widget.zoomController._setZoomed(zoomed);
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

  /// Ordered by [orderPosterGalleryImages] (ADR-0026 Amendment §A-D9 (2)) —
  /// falls back to a single-item list built from `primary_image_url` when
  /// `images` is empty but that field is set (both being empty/null is the
  /// "no image at all" case handled by [build]). On real data this is
  /// identical to the old plain `(isPrimary, sortOrder)` sort it replaced —
  /// see that function's doc comment for why.
  List<String> get _urls {
    final images = orderPosterGalleryImages(widget.poster.images);
    if (images.isNotEmpty) return images.map((i) => i.url).toList();
    final primary = widget.poster.primaryImageUrl;
    return primary == null ? const [] : [primary];
  }

  @override
  void dispose() {
    widget.zoomController._detach();
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
        Stack(
          children: [
            // ADR-0012 §D1 (7:1061) — full-bleed, no rounding: the frame now
            // runs edge-to-edge with the screen, so a rounded corner would
            // just clip against a straight edge. The rgba(0,0,0,0.5) backdrop
            // reuses `posterPlaceholderFill` (the same value the no-image
            // placeholder already renders) rather than a new color, and
            // covers `BoxFit.contain`'s letterbox band on a non-2:3 poster.
            Container(
              color: AppColors.posterPlaceholderFill,
              child: AspectRatio(
                key: _viewportKey,
                aspectRatio: AppDimens.posterCardAspectRatio,
                child: urls.isEmpty
                    ? const _ImagePlaceholder()
                    : PageView.builder(
                        controller: _pageController,
                        physics: _zoomed
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        itemCount: urls.length,
                        onPageChanged: (index) {
                          // Belt and braces — a page can only change at scale
                          // 1 now, so the matrix is already identity by the
                          // time this runs.
                          _transformationController.value = Matrix4.identity();
                          setState(() => _page = index);
                        },
                        itemBuilder: (context, index) => GestureDetector(
                          // A double tap needs no travel at all, so it never
                          // competes with the pan/scale recognizers that
                          // resolve on slop — this adds a second way in
                          // without touching the arena balance the zoom fix
                          // depends on.
                          onDoubleTapDown: (details) =>
                              _doubleTapPosition = details.localPosition,
                          onDoubleTap: () =>
                              _toggleZoom(focus: _doubleTapPosition),
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            // The default (0.8) lets the image settle
                            // *smaller* than its frame, so "zoomed all the
                            // way out" would stop short of identity and
                            // leave the swipe still locked. Exactly 1 lands
                            // zoom-out back on the swipeable state.
                            minScale: 1,
                            maxScale: _maxScale,
                            // A finger beats an in-flight animation —
                            // otherwise the two fight over the same matrix
                            // and the image stutters.
                            onInteractionStart: (_) => _zoomAnimation.stop(),
                            child: Image.network(
                              urls[index],
                              // AC-1 wants close-up shots of edges/corners
                              // readable as authenticity evidence —
                              // `BoxFit.cover` would crop exactly that
                              // content to fill the frame, so this uses
                              // `contain` instead even though it can
                              // letterbox non-matching aspect ratios.
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
              ),
            ),
            // ADR-0012 §D1 (7:1067) — an overlay inside the frame now, not a
            // row below it. Still gated on more than one image: the design
            // draws a fixed 4 dots, but a single-image poster must not fake
            // a page count it doesn't have (docs/screens.yaml SCR-05).
            if (urls.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpacing.lg,
                child: Center(
                  child: _PageIndicator(count: urls.length, page: _page),
                ),
              ),
          ],
        ),
        // The hint sits directly under the image frame, same as before
        // (ADR-0012 §D5 — neither its position nor its existence changed).
        if (urls.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: InkWell(
              // Tappable for the same reason the app bar button exists: the
              // pinch is invisible, and a hint you can't act on only tells
              // half the story.
              onTap: () => _toggleZoom(),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xs,
                  horizontal: AppSpacing.sm,
                ),
                child: Text(
                  AppStrings.posterDetailZoomHint,
                  style: AppTextStyles.imageHintLabel,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The in-frame page-dot pill (ADR-0012 §D1 7:1067) — `rgba(0,0,0,0.4)`
/// background, 6px dots, active dot in `AppColors.textPrimary`.
class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.page});

  final int count;
  final int page;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          count,
          (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs / 2),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index == page
                  ? AppColors.textPrimary
                  : AppColors.white.withValues(alpha: 0.4),
            ),
          ),
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
