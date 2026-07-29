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
  const PosterDetailImageGallery({super.key, required this.poster});

  final PosterDetail poster;

  @override
  State<PosterDetailImageGallery> createState() =>
      _PosterDetailImageGalleryState();
}

class _PosterDetailImageGalleryState extends State<PosterDetailImageGallery> {
  final _pageController = PageController();
  int _page = 0;

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
              itemCount: urls.length,
              onPageChanged: (index) => setState(() => _page = index),
              itemBuilder: (context, index) => InteractiveViewer(
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
