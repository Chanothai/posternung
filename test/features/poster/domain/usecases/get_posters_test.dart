import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/catalog_exception.dart';
import 'package:posternung/features/poster/domain/entities/paginated_posters.dart';
import 'package:posternung/features/poster/domain/repositories/poster_repository.dart';
import 'package:posternung/features/poster/domain/usecases/get_posters.dart';

class MockPosterRepository extends Mock implements PosterRepository {}

PaginatedPosters _page() =>
    const PaginatedPosters(items: [], total: 0, limit: 20, offset: 0);

void main() {
  late MockPosterRepository repository;
  late GetPosters usecase;

  setUp(() {
    repository = MockPosterRepository();
    usecase = GetPosters(repository);
  });

  void stub() {
    when(
      () => repository.listPosters(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => _page());
  }

  test('defaults to the contract page size and the first page', () async {
    stub();

    await usecase();

    verify(() => repository.listPosters(limit: 20, offset: 0)).called(1);
  });

  test('passes through an explicit limit/offset', () async {
    stub();

    await usecase(limit: 50, offset: 100);

    verify(() => repository.listPosters(limit: 50, offset: 100)).called(1);
  });

  test('clamps limit to the contract maximum of 100 rather than letting the '
      'backend answer 422', () async {
    stub();

    await usecase(limit: 500);

    verify(() => repository.listPosters(limit: 100, offset: 0)).called(1);
  });

  test('clamps a non-positive limit and a negative offset', () async {
    stub();

    await usecase(limit: 0, offset: -5);

    verify(() => repository.listPosters(limit: 1, offset: 0)).called(1);
  });

  test('propagates a CatalogException thrown by the repository', () async {
    when(
      () => repository.listPosters(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenThrow(const CatalogException(code: 'server_error'));

    expect(
      () => usecase(),
      throwsA(
        isA<CatalogException>().having((e) => e.code, 'code', 'server_error'),
      ),
    );
  });
}
