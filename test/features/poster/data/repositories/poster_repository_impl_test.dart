import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/catalog_exception.dart';
import 'package:posternung/features/poster/data/datasources/poster_remote_data_source.dart';
import 'package:posternung/features/poster/data/models/poster_detail_model.dart';
import 'package:posternung/features/poster/data/models/poster_image_model.dart';
import 'package:posternung/features/poster/data/repositories/poster_repository_impl.dart';

class MockPosterRemoteDataSource extends Mock
    implements PosterRemoteDataSource {}

PosterDetailModel _model() => PosterDetailModel(
  id: 'p1',
  title: 'Blade Runner',
  price: '450.00',
  status: 'available',
  conditionGrade: 'mint',
  eraDecade: 1980,
  studio: 'Warner Bros',
  primaryImageUrl: null,
  tmdbId: null,
  size: null,
  description: null,
  isAuthenticated: true,
  authenticityNote: null,
  provenance: null,
  images: const <PosterImageModel>[],
  createdAt: DateTime.utc(2024),
);

void main() {
  late MockPosterRemoteDataSource dataSource;
  late PosterRepositoryImpl repository;

  setUp(() {
    dataSource = MockPosterRemoteDataSource();
    repository = PosterRepositoryImpl(dataSource);
  });

  test('returns the mapped entity on success', () async {
    when(
      () => dataSource.getPosterDetail('p1'),
    ).thenAnswer((_) async => _model());

    final result = await repository.getPosterDetail('p1');

    expect(result.id, 'p1');
    expect(result.title, 'Blade Runner');
  });

  test(
    'propagates a CatalogException thrown by the datasource as-is',
    () async {
      when(() => dataSource.getPosterDetail('missing')).thenThrow(
        const CatalogException(
          code: 'POSTER_NOT_FOUND',
          message: 'ไม่พบโปสเตอร์นี้',
        ),
      );

      expect(
        () => repository.getPosterDetail('missing'),
        throwsA(
          isA<CatalogException>().having(
            (e) => e.code,
            'code',
            'POSTER_NOT_FOUND',
          ),
        ),
      );
    },
  );

  test('wraps an unexpected non-CatalogException failure so it never reaches '
      'the ViewModel bare/code-less', () async {
    when(() => dataSource.getPosterDetail('p1')).thenThrow(StateError('boom'));

    expect(
      () => repository.getPosterDetail('p1'),
      throwsA(
        isA<CatalogException>().having(
          (e) => e.code,
          'code',
          startsWith('unexpected_'),
        ),
      ),
    );
  });
}
