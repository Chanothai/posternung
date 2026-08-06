import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../poster/presentation/catalog_error_display.dart';
import '../../../poster/presentation/screens/poster_detail_screen.dart';
import '../providers/home_posters_provider.dart';
import '../state/home_posters_state.dart';
import 'home_load_more_footer.dart';
import 'home_poster_card.dart';
import 'home_posters_empty_view.dart';
import 'home_posters_error_view.dart';

/// SCR-03's catalog grid, fed by the real `GET /posters`.
///
/// This is where all four `required_states` land: `loading`, `error` (with
/// retry), `empty` (`total == 0`), and — per row rather than per screen —
/// `sold_out`, which `HomePosterCard` renders from `PosterSummary.status`.
class HomeAllPostersSection extends ConsumerWidget {
  const HomeAllPostersSection({super.key});

  /// Fixed cell height. The card gives its image whatever is left after the
  /// title/subtitle/price/condition block, so this only needs to be
  /// comfortably larger than that block — it can't overflow.
  static const double _cellExtent = 340;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPosters = ref.watch(homePostersProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.homeSectionAllPosters,
            style: AppTextStyles.homeSectionHeading,
          ),
          const SizedBox(height: AppSpacing.lg),
          asyncPosters.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ),
            error: (error, stackTrace) => HomePostersErrorView(
              message: catalogErrorMessageFor(
                error,
                fallback: AppStrings.homePostersErrorBody,
              ),
              // `retry()`, not `refresh()`: this path has no data underneath
              // to preserve, so it shows a spinner instead of leaving the
              // error view looking untouched.
              onRetry: () => ref.read(homePostersProvider.notifier).retry(),
            ),
            data: (posters) => posters.total == 0
                ? const HomePostersEmptyView()
                : _Grid(
                    posters: posters,
                    onLoadMore: () =>
                        ref.read(homePostersProvider.notifier).loadMore(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.posters, required this.onLoadMore});

  final HomePostersState posters;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: posters.items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.lg,
            mainAxisSpacing: AppSpacing.lg,
            mainAxisExtent: HomeAllPostersSection._cellExtent,
          ),
          // Rendered in the order the backend sent them (`created_at DESC`).
          // Never sort by price here — BR-05 (see
          // `PosterRepository.listPosters`).
          itemBuilder: (context, index) {
            final poster = posters.items[index];
            return HomePosterCard(
              poster: poster,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  // The real backend UUID — never a synthesized id. Wiring
                  // this to placeholder ids 404'd on every tap once already
                  // (`lib/features/poster/CLAUDE.md`). No `go_router`: there
                  // is no route table yet, and adding one is SCR-06's call.
                  builder: (_) => PosterDetailScreen(posterId: poster.id),
                ),
              ),
            );
          },
        ),
        HomeLoadMoreFooter(state: posters, onLoadMore: onLoadMore),
      ],
    );
  }
}
