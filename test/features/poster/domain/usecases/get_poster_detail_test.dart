import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/catalog_exception.dart';
import 'package:posternung/features/poster/domain/entities/poster_detail.dart';
import 'package:posternung/features/poster/domain/entities/poster_status.dart';
import 'package:posternung/features/poster/domain/repositories/poster_repository.dart';
import 'package:posternung/features/poster/domain/usecases/get_poster_detail.dart';

class MockPosterRepository extends Mock implements PosterRepository {}

PosterDetail _poster({String id = 'p1'}) => PosterDetail(
  id: id,
  title: 'Blade Runner',
  price: '450.00',
  status: PosterStatus.available,
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
  createdAt: DateTime(2024),
  posterType: null,
  releaseRegion: null,
  releaseDateText: null,
  releaseDate: null,
  copyrightYear: null,
  sizeFormat: null,
  year: null,
  restorationStatus: null,
  restorationNote: null,
);

void main() {
  late MockPosterRepository repository;
  late GetPosterDetail usecase;

  setUp(() {
    repository = MockPosterRepository();
    usecase = GetPosterDetail(repository);
  });

  test(
    'calls repository.getPosterDetail with the given id and returns it',
    () async {
      final poster = _poster();
      when(
        () => repository.getPosterDetail('p1'),
      ).thenAnswer((_) async => poster);

      final result = await usecase('p1');

      expect(result, poster);
      verify(() => repository.getPosterDetail('p1')).called(1);
    },
  );

  test('propagates CatalogException thrown by the repository', () async {
    when(() => repository.getPosterDetail('missing')).thenThrow(
      const CatalogException(
        code: 'POSTER_NOT_FOUND',
        message: 'ไม่พบโปสเตอร์นี้',
      ),
    );

    expect(
      () => usecase('missing'),
      throwsA(
        isA<CatalogException>().having(
          (e) => e.code,
          'code',
          'POSTER_NOT_FOUND',
        ),
      ),
    );
  });
}
