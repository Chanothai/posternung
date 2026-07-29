import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/datasources/poster_remote_data_source.dart';
import '../../data/repositories/poster_repository_impl.dart';
import '../../domain/entities/poster_detail.dart';
import '../../domain/repositories/poster_repository.dart';
import '../../domain/usecases/get_poster_detail.dart';

final posterRemoteDataSourceProvider = Provider<PosterRemoteDataSource>(
  (ref) => PosterRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final posterRepositoryProvider = Provider<PosterRepository>(
  (ref) => PosterRepositoryImpl(ref.watch(posterRemoteDataSourceProvider)),
);

final getPosterDetailProvider = Provider(
  (ref) => GetPosterDetail(ref.watch(posterRepositoryProvider)),
);

/// Drives `PosterDetailScreen` — one instance per `posterId` (family).
/// `AsyncValue<PosterDetail>` already covers loading/data/error; no
/// hand-rolled sealed state needed (this screen has a simple async-fetch
/// shape, not the multi-state flow that would call for MVI — see root
/// `CLAUDE.md`'s Presentation section).
///
/// ADR-0005 §D5's AC-5 ("poster bought out from under the viewer") is
/// handled here by [refresh] — re-fetch on pull-to-refresh and on app
/// foreground resume (`PosterDetailScreen`'s `didChangeAppLifecycleState`)
/// — not polling, since no reservation/payment is tied to this read-only
/// screen yet.
class PosterDetailViewModel extends AsyncNotifier<PosterDetail> {
  PosterDetailViewModel(this._posterId);

  final String _posterId;

  // `async` (not a plain `=> _fetch();` forward) so a failure that happens
  // to throw *synchronously* underneath — e.g. a mocktail `thenThrow`,
  // which throws at call time rather than rejecting a Future — still
  // arrives as a proper `AsyncError` via Riverpod's lifecycle instead of
  // escaping as an uncaught synchronous exception during initialization.
  @override
  Future<PosterDetail> build() async => _fetch();

  Future<PosterDetail> _fetch() => ref.read(getPosterDetailProvider)(_posterId);

  /// Re-fetches without first flipping `state` to `AsyncLoading` —
  /// deliberately, so the screen keeps rendering whatever it already has
  /// (data or error) for the duration of the request instead of replacing
  /// the whole screen with a loading spinner on every pull-to-refresh or
  /// app-foreground resume. `RefreshIndicator` shows its own spinner for
  /// the pull-to-refresh case; the app-resume case just updates silently
  /// once the fetch resolves.
  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }
}

final posterDetailViewModelProvider =
    AsyncNotifierProvider.family<PosterDetailViewModel, PosterDetail, String>(
      PosterDetailViewModel.new,
      // Riverpod 3 auto-retries a failed `build()` up to 10x with
      // exponential backoff (200ms→6.4s — `ProviderContainer.defaultRetry`)
      // *by default*, for any error that isn't a `ProviderException`/`Error`
      // — a plain `CatalogException` (an `Exception`) qualifies, so without
      // this override a `POSTER_NOT_FOUND` 404 would silently retry the
      // same request up to 10 times (hammering the backend, and leaving the
      // user staring at a loading spinner for tens of seconds) before
      // finally showing `PosterNotFoundView`. This screen already has its
      // own explicit, user-triggered retry (`PosterErrorView`'s button) —
      // disable the automatic one so a failure surfaces immediately.
      retry: (retryCount, error) => null,
    );
