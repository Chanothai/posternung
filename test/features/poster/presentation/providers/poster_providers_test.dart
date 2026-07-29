import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/catalog_exception.dart';
import 'package:posternung/features/poster/domain/entities/poster_detail.dart';
import 'package:posternung/features/poster/domain/entities/poster_status.dart';
import 'package:posternung/features/poster/domain/repositories/poster_repository.dart';
import 'package:posternung/features/poster/presentation/providers/poster_providers.dart';

class MockPosterRepository extends Mock implements PosterRepository {}

PosterDetail _poster({PosterStatus status = PosterStatus.available}) =>
    PosterDetail(
      id: 'p1',
      title: 'Blade Runner',
      price: '450.00',
      status: status,
      conditionGrade: null,
      eraDecade: 1980,
      studio: 'Warner Bros',
      primaryImageUrl: null,
      tmdbId: null,
      size: null,
      description: null,
      isAuthenticated: true,
      authenticityNote: null,
      provenance: null,
      images: const [],
      createdAt: DateTime.utc(2024),
    );

void main() {
  late MockPosterRepository repository;

  setUp(() {
    repository = MockPosterRepository();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [posterRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'build() fetches the poster for the given id and publishes it',
    () async {
      when(
        () => repository.getPosterDetail('p1'),
      ).thenAnswer((_) async => _poster());
      final container = makeContainer();

      final result = await container.read(
        posterDetailViewModelProvider('p1').future,
      );

      expect(result.id, 'p1');
      verify(() => repository.getPosterDetail('p1')).called(1);
    },
  );

  test('build() surfaces a CatalogException as AsyncError', () async {
    when(() => repository.getPosterDetail('missing')).thenThrow(
      const CatalogException(
        code: 'POSTER_NOT_FOUND',
        message: 'ไม่พบโปสเตอร์นี้',
      ),
    );
    final container = makeContainer();

    await expectLater(
      container.read(posterDetailViewModelProvider('missing').future),
      throwsA(isA<CatalogException>()),
    );
    final state = container.read(posterDetailViewModelProvider('missing'));
    expect(state.hasError, isTrue);
  });

  test('refresh() re-fetches and updates state, picking up a status change '
      '(AC-5 — sold while viewing)', () async {
    when(
      () => repository.getPosterDetail('p1'),
    ).thenAnswer((_) async => _poster(status: PosterStatus.available));
    final container = makeContainer();
    await container.read(posterDetailViewModelProvider('p1').future);
    expect(
      container.read(posterDetailViewModelProvider('p1')).value?.status,
      PosterStatus.available,
    );

    when(
      () => repository.getPosterDetail('p1'),
    ).thenAnswer((_) async => _poster(status: PosterStatus.sold));
    await container
        .read(posterDetailViewModelProvider('p1').notifier)
        .refresh();

    expect(
      container.read(posterDetailViewModelProvider('p1')).value?.status,
      PosterStatus.sold,
    );
    verify(() => repository.getPosterDetail('p1')).called(2);
  });

  test('refresh() keeps the last-known data visible instead of flipping to '
      'AsyncLoading while the request is in flight', () async {
    when(
      () => repository.getPosterDetail('p1'),
    ).thenAnswer((_) async => _poster());
    final container = makeContainer();
    await container.read(posterDetailViewModelProvider('p1').future);

    when(() => repository.getPosterDetail('p1')).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return _poster(status: PosterStatus.sold);
    });
    final refreshFuture = container
        .read(posterDetailViewModelProvider('p1').notifier)
        .refresh();

    // Mid-flight: state must still hold the previous data, not loading.
    final midFlight = container.read(posterDetailViewModelProvider('p1'));
    expect(midFlight.hasValue, isTrue);
    expect(midFlight.isLoading, isFalse);

    await refreshFuture;
  });
}
