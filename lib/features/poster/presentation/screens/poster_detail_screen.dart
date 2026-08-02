import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/app_dimens.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/error/catalog_exception.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/condition_grade_indicator.dart';
import '../../domain/entities/poster_detail.dart';
import '../../domain/entities/poster_status.dart';
import '../providers/poster_providers.dart';
import '../widgets/poster_authenticity_section.dart';
import '../widgets/poster_availability_status.dart';
import '../widgets/poster_details_accordion.dart';
import '../widgets/poster_detail_image_gallery.dart';
import '../widgets/poster_error_view.dart';
import '../widgets/poster_not_found_view.dart';
import '../widgets/poster_sold_banner.dart';

/// SCR-05 — Product Detail. Read-only this round (ADR-0005 §D1): no Add to
/// Cart, no quantity selector — `/cart/reserve` is still `x-status: DRAFT`.
/// Answers US-01 only; US-16 (COA) is deferred (see `docs/screens.yaml`'s
/// `deferred_stories` for SCR-05 and ADR-0005 §D2).
class PosterDetailScreen extends ConsumerStatefulWidget {
  const PosterDetailScreen({super.key, required this.posterId});

  final String posterId;

  @override
  ConsumerState<PosterDetailScreen> createState() => _PosterDetailScreenState();
}

class _PosterDetailScreenState extends ConsumerState<PosterDetailScreen>
    with WidgetsBindingObserver {
  /// Owned here rather than by the body because the app bar reads it, and the
  /// bar outlives the body across loading/error states.
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
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
    final loadedTitle = asyncDetail.value?.title;

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          tooltip: AppStrings.posterDetailBackButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
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
      ),
      body: asyncDetail.when(
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
            onBrowseOthers: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
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

  /// 0 while the poster still leads the screen, 1 once it has gone.
  ///
  /// Keyed to the image's height — it leads the list and sizes itself off the
  /// list's own width, so the offset where it clears the top is derivable
  /// rather than measured — but **capped at `maxScrollExtent`**. Without that
  /// cap a listing whose text is shorter than its image can never scroll far
  /// enough to reveal the title at all: a 2:3 image on a phone is ~537pt tall
  /// against ~500pt of total scroll, so the plain image-height threshold is
  /// unreachable in exactly the common case.
  double _fadeProgress(double imageHeight) {
    if (!controller.hasClients) return 0;

    final position = controller.position;
    // The bar builds before the list has laid out, and reading either extent
    // before then throws rather than returning a default.
    if (!position.hasContentDimensions || !position.hasPixels) return 0;
    // Nothing scrolls, so the poster never leaves and the title never earns
    // its place in the bar.
    if (position.maxScrollExtent <= 0) return 0;

    final end = math.min(imageHeight, position.maxScrollExtent);
    final start = math.max(0.0, end - kToolbarHeight);
    if (end <= start) return position.pixels >= end ? 1 : 0;
    return ((position.pixels - start) / (end - start)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final contentWidth = MediaQuery.sizeOf(context).width - AppSpacing.lg * 2;
    final imageHeight = contentWidth / AppDimens.posterCardAspectRatio;

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
      builder: (context, child) =>
          Opacity(opacity: _fadeProgress(imageHeight), child: child),
    );
  }
}

class _PosterDetailBody extends StatefulWidget {
  const _PosterDetailBody({
    required this.poster,
    required this.scrollController,
    required this.onBrowseOthers,
  });

  final PosterDetail poster;
  final ScrollController scrollController;
  final VoidCallback onBrowseOthers;

  @override
  State<_PosterDetailBody> createState() => _PosterDetailBodyState();
}

class _PosterDetailBodyState extends State<_PosterDetailBody> {
  /// Set while the gallery's current image is zoomed in. The flag lives here
  /// rather than on the screen so it is discarded together with the gallery
  /// whenever the screen leaves its data state — a flag that outlived the
  /// gallery would leave this list permanently unscrollable.
  bool _imageZoomed = false;

  @override
  Widget build(BuildContext context) {
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
      physics: _imageZoomed
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: [
        // The rounded clip moved inside the gallery — it now ends with a
        // caption that must not be rounded along with the image.
        PosterDetailImageGallery(
          poster: poster,
          onZoomChanged: (zoomed) => setState(() => _imageZoomed = zoomed),
        ),
        const SizedBox(height: AppSpacing.lg),
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
        const SizedBox(height: AppSpacing.md),
        PosterAvailabilityStatus(status: poster.status),
        const SizedBox(height: AppSpacing.xl),
        PosterAuthenticitySection(
          isAuthenticated: poster.isAuthenticated,
          authenticityNote: poster.authenticityNote,
        ),
        const SizedBox(height: AppSpacing.lg),
        PosterDetailsAccordion(
          provenance: poster.provenance,
          size: poster.size,
          description: poster.description,
        ),
      ],
    );
  }

  String? get _subtitle {
    final parts = [
      if (widget.poster.eraDecade != null) '${widget.poster.eraDecade}s',
      if (widget.poster.studio != null) widget.poster.studio!,
    ];
    return parts.isEmpty ? null : parts.join(' • ');
  }

  String get _formattedPrice => formatThbPrice(widget.poster.price);
}
