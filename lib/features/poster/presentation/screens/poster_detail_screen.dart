import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/catalog/release_region.dart';
import '../../../../core/catalog/size_format.dart';
import '../../../../core/design_system/app_dimens.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/error/catalog_exception.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/condition_grade_indicator.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../domain/entities/poster_detail.dart';
import '../../domain/entities/poster_status.dart';
import '../providers/poster_providers.dart';
import '../widgets/poster_authenticity_section.dart';
import '../widgets/poster_availability_status.dart';
import '../widgets/poster_details_accordion.dart';
import '../widgets/poster_detail_image_gallery.dart';
import '../widgets/poster_error_view.dart';
import '../widgets/poster_not_found_view.dart';
import '../widgets/poster_restoration_badge.dart';
import '../widgets/poster_sold_banner.dart';

/// SCR-05 — Product Detail. Read-only this round (ADR-0005 §D1): no Add to
/// Cart, no quantity selector — `/cart/reserve` is still `x-status: DRAFT`.
/// Answers US-01 only; US-16 (COA) is deferred (see `docs/screens.yaml`'s
/// `deferred_stories` for SCR-05 and ADR-0005 §D2).
///
/// Visual layer restyled per ADR-0012 (figma `7:959`) — **only** the eight
/// items in its §D1 table: `AppGradientBackground` behind everything, a
/// full-bleed image carousel with a translucent header floating on top of
/// it, an in-frame page indicator, a fit-content urgency badge, a
/// ringed-icon Authenticity section, and label/value accordion rows opened
/// by default. Everything ADR-0012 §D2–D8 refuses (heart/share buttons, the
/// sticky Add to Cart bar, Shipping & Returns, Paper Stock/Format rows,
/// measured inches, grade-in-accordion, price-on-title-row, an on-image zoom
/// button) is **not** in this file on purpose — see the ADR before adding
/// any of it back.
class PosterDetailScreen extends ConsumerStatefulWidget {
  const PosterDetailScreen({super.key, required this.posterId});

  final String posterId;

  @override
  ConsumerState<PosterDetailScreen> createState() => _PosterDetailScreenState();
}

class _PosterDetailScreenState extends ConsumerState<PosterDetailScreen>
    with WidgetsBindingObserver {
  /// Both owned here rather than by the body, because the app bar reads them
  /// and it outlives the body across loading/error states. The gallery
  /// detaches from the zoom controller on dispose, so neither can be left
  /// holding state whose widget is gone.
  final _scrollController = ScrollController();
  final _zoomController = PosterGalleryZoomController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// AC-5 / ADR-0005 §D5 — re-fetch on foreground resume rather than
  /// polling, since no reservation/payment is tied to this read-only
  /// screen yet. Picks up a poster having sold out while the app was
  /// backgrounded.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _notifier.refresh();
    }
  }

  PosterDetailViewModel get _notifier =>
      ref.read(posterDetailViewModelProvider(widget.posterId).notifier);

  @override
  Widget build(BuildContext context) {
    final asyncDetail = ref.watch(
      posterDetailViewModelProvider(widget.posterId),
    );
    final loaded = asyncDetail.value;
    final loadedTitle = loaded?.title;
    // The zoom control only makes sense when there is an image to zoom.
    final hasImage =
        loaded != null &&
        (loaded.images.isNotEmpty || loaded.primaryImageUrl != null);

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      // ADR-0012 §D1 (7:981) — the header floats *on top of* the image
      // rather than sitting in its own opaque strip above it, so the body
      // has to paint underneath the app bar's area too.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // Transparent by default so the full-bleed image (or the gradient,
        // in the loading/error states) shows straight through; the bar
        // solidifies as the list scrolls via `_AppBarBackdrop` below —
        // that's the "พื้นหลังแถบทึบขึ้นตาม scroll" half of 7:981, driven by
        // the same scroll-fade math `_CollapsingAppBarTitle` already used
        // for the title.
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: _AppBarBackdrop(controller: _scrollController),
        // `AppSpacing.lg` (16) left inset + the button's own 48px tap area
        // (code-critic round 1, Medium — see `_GlassCircleButton`) —
        // measured close to figma's `pl-16` rather than the default
        // `leadingWidth` (56) centering a smaller button with an
        // uncontrolled, narrower inset.
        leadingWidth: AppSpacing.lg + _GlassCircleButton.hitArea,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.lg),
          child: _GlassCircleButton(
            icon: Icons.arrow_back,
            tooltip: AppStrings.posterDetailBackButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        // Nothing to name until the poster has actually loaded — the bar is
        // deliberately bare over the image, and there is no scrollable at all
        // in the loading/error states.
        title: loadedTitle == null
            ? null
            : _CollapsingAppBarTitle(
                controller: _scrollController,
                title: loadedTitle,
              ),
        // In the bar rather than on the image: `BoxFit.contain` letterboxes a
        // poster whose ratio isn't 2:3, and a button pinned to the frame's
        // corner then floats in that empty band, reading as a control for the
        // whole screen instead of for the image. Here it is always present,
        // and shares the bar with the title rather than replacing it
        // (ADR-0012 §D5 — this stays exactly where it is, figma's on-image
        // 32px corner button is not followed).
        actions: [
          if (hasImage)
            Padding(
              // `AppSpacing.lg` (16) right inset, matching the leading
              // button — see its comment above.
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: _ZoomAction(controller: _zoomController),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ADR-0012 §D1 — SCR-05 was the one screen still on a flat
          // `ColoredBox`; every other screen already uses this.
          const AppGradientBackground(),
          asyncDetail.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (error, stackTrace) =>
                error is CatalogException && error.code == 'POSTER_NOT_FOUND'
                ? PosterNotFoundView(
                    message: error.message,
                    onGoBack: () => Navigator.of(context).pop(),
                  )
                : PosterErrorView(
                    message: error is CatalogException ? error.message : null,
                    onRetry: _notifier.refresh,
                  ),
            data: (poster) => RefreshIndicator(
              onRefresh: _notifier.refresh,
              color: AppColors.accent,
              child: _PosterDetailBody(
                poster: poster,
                scrollController: _scrollController,
                zoomController: _zoomController,
                onBrowseOthers: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared by [_CollapsingAppBarTitle] and [_AppBarBackdrop] — both fade in
/// over the same span as the full-bleed gallery scrolls past, so they have
/// to agree on when "past" is.
///
/// 0 while the poster still leads the screen, 1 once it has gone.
///
/// Keyed to the image's height — it leads the list and sizes itself off the
/// list's own width (now the *full* screen width, since the gallery is
/// full-bleed per ADR-0012 §D1 7:1061 — no more subtracting the list's
/// horizontal padding) — but **capped at `maxScrollExtent`**. Without that
/// cap a listing whose text is shorter than its image can never scroll far
/// enough to reveal the title/backdrop at all: a 2:3 image at full device
/// width is taller than most single-poster listings' total scroll extent.
double _headerFadeProgress(ScrollController controller, double imageHeight) {
  if (!controller.hasClients) return 0;

  final position = controller.position;
  // The bar builds before the list has laid out, and reading either extent
  // before then throws rather than returning a default.
  if (!position.hasContentDimensions || !position.hasPixels) return 0;
  // Nothing scrolls, so the poster never leaves and neither the title nor
  // the backdrop earns its place in the bar.
  if (position.maxScrollExtent <= 0) return 0;

  final end = math.min(imageHeight, position.maxScrollExtent);
  final start = math.max(0.0, end - kToolbarHeight);
  if (end <= start) return position.pixels >= end ? 1 : 0;
  return ((position.pixels - start) / (end - start)).clamp(0.0, 1.0);
}

/// The full-bleed gallery's height at this device width — see
/// [_headerFadeProgress]'s doc for why this is the full width now, not the
/// list's content width.
double _fullBleedImageHeight(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width / AppDimens.posterCardAspectRatio;
}

/// The bar keeps its height and its back button at every offset — only the
/// title crosses in, once the poster image has cleared the top of the
/// viewport. Fading a fixed-height bar rather than collapsing an expanded one
/// is what keeps the gallery inside the list, where the zoom lock in
/// [PosterDetailImageGallery] still owns the vertical drag; hosting the image
/// in a `FlexibleSpaceBar` instead would put it back in a scrollable that
/// moves under the finger mid-zoom.
class _CollapsingAppBarTitle extends StatelessWidget {
  const _CollapsingAppBarTitle({required this.controller, required this.title});

  final ScrollController controller;
  final String title;

  @override
  Widget build(BuildContext context) {
    final imageHeight = _fullBleedImageHeight(context);

    return AnimatedBuilder(
      animation: controller,
      // Built once and handed to the builder — only the opacity changes as
      // the list scrolls, so the text itself must not be rebuilt per frame.
      child: Text(
        title,
        style: AppTextStyles.appBarTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      builder: (context, child) => Opacity(
        opacity: _headerFadeProgress(controller, imageHeight),
        child: child,
      ),
    );
  }
}

/// ADR-0012 §D1 (7:981) — the app bar's own background, separate from the
/// glass buttons riding on top of it: starts fully transparent (so the
/// full-bleed image/gradient shows straight through) and solidifies to
/// `AppColors.surfaceDark` over the same scroll span
/// [_CollapsingAppBarTitle] uses for the title, via [flexibleSpace] rather
/// than `SliverAppBar`/`FlexibleSpaceBar` (forbidden by ADR-0012 A5 — the
/// gallery has to stay inside the plain `ListView`).
class _AppBarBackdrop extends StatelessWidget {
  const _AppBarBackdrop({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final imageHeight = _fullBleedImageHeight(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark.withValues(
            alpha: _headerFadeProgress(controller, imageHeight),
          ),
        ),
      ),
    );
  }
}

/// The 40px translucent glass button (ADR-0012 §D1 7:981) both the back
/// button and [_ZoomAction] render as — `rgba(0,0,0,0.4)` fill, blurred
/// backdrop, and a faint `rgba(255,255,255,0.1)` ring, floating directly on
/// the image rather than sitting in an opaque bar. Wraps a real `IconButton`
/// rather than a bare `GestureDetector` so the tooltip/semantics/ripple
/// behaviour every call site already relied on keeps working unchanged.
///
/// 🔴 code-critic round 1 (Medium) measured the first version of this
/// widget's actual tap target at 38×38 — the *whole* button (glass circle
/// **and** its `IconButton`) was sized to the 40px visual diameter, short of
/// both Material's 48dp and Apple's 44pt minimums, on a control that AC-1
/// gates inspecting condition before a non-refundable purchase (ADR-0002).
/// The visual stays exactly 40px (ADR-0012 §D1 is about the glass circle's
/// look, not the tap target); only `IconButton.constraints` grows to
/// [hitArea] now, via the `icon:` slot rather than the outer size — the
/// glass circle becomes the *content* `IconButton` centers inside its own
/// larger, invisible hit box, instead of being the box.
class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  static const _diameter = 40.0;

  /// Material's 48dp / Apple HIG's 44pt minimum touch target — see the
  /// class doc.
  static const hitArea = 48.0;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: hitArea,
        height: hitArea,
      ),
      onPressed: onPressed,
      tooltip: tooltip,
      icon: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: _diameter,
            height: _diameter,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.4),
              border: Border.all(color: AppColors.white.withValues(alpha: 0.1)),
            ),
            child: Icon(
              icon,
              size: AppDimens.iconMd,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The bar's zoom button. Mirrors the gallery's state rather than owning it,
/// so pinching, double-tapping, tapping the hint and pressing this all report
/// the same thing.
class _ZoomAction extends StatelessWidget {
  const _ZoomAction({required this.controller});

  final PosterGalleryZoomController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final zoomedIn = controller.isZoomed;
        return _GlassCircleButton(
          icon: zoomedIn ? Icons.zoom_out : Icons.zoom_in,
          // An icon-only control has no other source for an accessible name;
          // `IconButton` reuses the tooltip as one.
          tooltip: zoomedIn
              ? AppStrings.posterDetailZoomOutTooltip
              : AppStrings.posterDetailZoomInTooltip,
          onPressed: controller.toggle,
        );
      },
    );
  }
}

class _PosterDetailBody extends StatefulWidget {
  const _PosterDetailBody({
    required this.poster,
    required this.scrollController,
    required this.zoomController,
    required this.onBrowseOthers,
  });

  final PosterDetail poster;
  final ScrollController scrollController;
  final PosterGalleryZoomController zoomController;
  final VoidCallback onBrowseOthers;

  @override
  State<_PosterDetailBody> createState() => _PosterDetailBodyState();
}

class _PosterDetailBodyState extends State<_PosterDetailBody> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.zoomController,
      builder: (context, _) => _buildList(widget.zoomController.isZoomed),
    );
  }

  Widget _buildList(bool imageZoomed) {
    final poster = widget.poster;

    return ListView(
      controller: widget.scrollController,
      // Always scrollable, even when content is shorter than the viewport
      // — RefreshIndicator requires a scrollable child to trigger from.
      // Except while the gallery is zoomed: this list's vertical drag
      // recognizer would otherwise take the one-finger pan away from the
      // zoomed image (kTouchSlop 18lp beats kPanSlop 36lp — see
      // PosterDetailImageGallery) and scroll the page instead of moving
      // inside the image.
      physics: imageZoomed
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      // No horizontal padding at the list level any more — the gallery
      // below needs to be full-bleed (ADR-0012 §D1 7:1061), so every other
      // block supplies its own 24px horizontal padding instead of sharing
      // one list-wide value (§D1's "ระยะขอบบล็อกข้อมูล 16 → 24").
      padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
      children: [
        PosterDetailImageGallery(
          poster: poster,
          zoomController: widget.zoomController,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (poster.status == PosterStatus.sold)
                PosterSoldBanner(onBrowseOthers: widget.onBrowseOthers),
              Text(poster.title, style: AppTextStyles.authCardHeading),
              if (_subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(_subtitle!, style: AppTextStyles.cardSubtitle),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formattedPrice,
                    style: AppTextStyles.homeSectionHeading.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                  ConditionGradeIndicator(grade: poster.conditionGrade),
                ],
              ),
              // OD-1 (ข) / ADR-0011 §D2′ (GATE 3) — the restoration fact lives
              // on its own line under the price/grade row, not crammed into
              // that row's `spaceBetween` Row as a third item (overflow risk
              // on narrow screens). Renders only for RESTORED/LINEN_BACKED;
              // NONE, UNKNOWN, and null all render nothing (see
              // `PosterRestorationBadge.showsFor`). The spacing above it is
              // only added when it will actually show something, so there is
              // no stray gap otherwise.
              if (_showsRestorationBadge) ...[
                const SizedBox(height: AppSpacing.sm),
                PosterRestorationBadge(status: poster.restorationStatus),
              ],
              const SizedBox(height: AppSpacing.md),
              PosterAvailabilityStatus(status: poster.status),
              const SizedBox(height: AppSpacing.lg),
              PosterDetailsAccordion(
                posterType: poster.posterType,
                size: poster.size,
                releaseDateText: poster.releaseDateText,
                copyrightYear: poster.copyrightYear,
                provenance: poster.provenance,
                restorationNote: poster.restorationNote,
                description: poster.description,
                releaseRegion: poster.releaseRegion,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Asks PosterRestorationBadge itself, rather than repeating the
  // RESTORED/LINEN_BACKED condition here — code-critic round 1 (M1) found
  // the two copies could silently drift.
  bool get _showsRestorationBadge =>
      PosterRestorationBadge.showsFor(widget.poster.restorationStatus);

  /// ADR-0011 §D4′ (amends §D4) — `year • [region ]size_format • studio`.
  ///
  /// - `year` replaces `era_decade` the moment it has a value (`"1982"` not
  ///   `"1980s"`); falls back to the original `era_decade` behaviour when
  ///   `year` is `null` (§D4's original mandate, unchanged).
  /// - `size_format` is prefixed with `release_region`'s short code when the
  ///   region is a *real* value (`"US One-Sheet"`) — but never when it's
  ///   [ReleaseRegion.unknown] (`"UNKNOWN One-Sheet"` would read as broken;
  ///   §D9 routes that case to an accordion row instead) or `null` (no
  ///   prefix at all).
  /// - `studio` still shows, even though the linked Figma frame drops it —
  ///   removing content the user already sees today is out of scope for
  ///   this round (§D4′).
  ///
  /// Blank is not the same as absent on the wire: `studio` comes back as `""`
  /// on some rows, and a null-only check left the separator stranded ("2010s
  /// •"). Anything that trims to nothing is treated as missing — same rule,
  /// now applied to every part, not just `studio`.
  String? get _subtitle {
    final poster = widget.poster;
    final studio = poster.studio?.trim();

    final yearPart = poster.year != null
        ? '${poster.year}'
        : (poster.eraDecade != null ? '${poster.eraDecade}s' : null);

    final sizeFormat = poster.sizeFormat;
    String? formatPart;
    if (sizeFormat != null) {
      final region = poster.releaseRegion;
      final showsRegionPrefix =
          region != null && region != ReleaseRegion.unknown;
      formatPart = showsRegionPrefix
          ? '${region.label} ${sizeFormat.label}'
          : sizeFormat.label;
    }

    final parts = [
      ?yearPart,
      ?formatPart,
      if (studio != null && studio.isNotEmpty) studio,
    ];
    return parts.isEmpty ? null : parts.join(' • ');
  }

  String get _formattedPrice => formatThbPrice(widget.poster.price);
}
