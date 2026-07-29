import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
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
            onBrowseOthers: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}

class _PosterDetailBody extends StatelessWidget {
  const _PosterDetailBody({required this.poster, required this.onBrowseOthers});

  final PosterDetail poster;
  final VoidCallback onBrowseOthers;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Always scrollable, even when content is shorter than the viewport
      // — RefreshIndicator requires a scrollable child to trigger from.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: PosterDetailImageGallery(poster: poster),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (poster.status == PosterStatus.sold)
          PosterSoldBanner(onBrowseOthers: onBrowseOthers),
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
      if (poster.eraDecade != null) '${poster.eraDecade}s',
      if (poster.studio != null) poster.studio!,
    ];
    return parts.isEmpty ? null : parts.join(' • ');
  }

  String get _formattedPrice => formatThbPrice(poster.price);
}
