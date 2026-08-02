import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/catalog_exception.dart';
import 'package:posternung/features/poster/data/datasources/poster_remote_data_source.dart';

class MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _resp(Map<String, dynamic> data) => Response(
  data: data,
  requestOptions: RequestOptions(path: '/'),
);

DioException _dioError(int status, {Object? data}) => DioException(
  requestOptions: RequestOptions(path: '/'),
  response: Response(
    statusCode: status,
    data: data,
    requestOptions: RequestOptions(path: '/'),
  ),
);

DioException _dioNoResponse() =>
    DioException(requestOptions: RequestOptions(path: '/'));

Map<String, dynamic> _posterJson() => {
  'id': 'p1',
  'title': 'Blade Runner',
  'price': '450.00',
  'status': 'available',
  'condition_grade': 'mint',
  'era_decade': 1980,
  'studio': 'Warner Bros',
  'primary_image_url': null,
  'tmdb_id': null,
  'size': null,
  'description': null,
  'is_authenticated': true,
  'authenticity_note': null,
  'provenance': null,
  'images': <Map<String, dynamic>>[],
  'created_at': '2024-01-01T00:00:00Z',
};

void main() {
  late MockDio dio;
  late PosterRemoteDataSourceImpl dataSource;

  setUp(() {
    dio = MockDio();
    dataSource = PosterRemoteDataSourceImpl(dio);
  });

  group('getPosterDetail', () {
    test('GETs /api/v1/posters/{id} and parses the response', () async {
      when(
        () => dio.get<Map<String, dynamic>>(any()),
      ).thenAnswer((_) async => _resp(_posterJson()));

      final result = await dataSource.getPosterDetail('p1');

      expect(result.id, 'p1');
      expect(result.title, 'Blade Runner');
      final captured = verify(
        () => dio.get<Map<String, dynamic>>(captureAny()),
      ).captured;
      expect(captured.single, '/api/v1/posters/p1');
    });

    test('surfaces the 404 POSTER_NOT_FOUND envelope', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(
        _dioError(
          404,
          data: {
            'error_code': 'POSTER_NOT_FOUND',
            'message': 'ไม่พบโปสเตอร์นี้',
          },
        ),
      );

      expect(
        () => dataSource.getPosterDetail('missing'),
        throwsA(
          isA<CatalogException>()
              .having((e) => e.code, 'code', 'POSTER_NOT_FOUND')
              .having((e) => e.message, 'message', 'ไม่พบโปสเตอร์นี้'),
        ),
      );
    });

    test('maps a no-response failure to code network_error', () async {
      when(
        () => dio.get<Map<String, dynamic>>(any()),
      ).thenThrow(_dioNoResponse());

      expect(
        () => dataSource.getPosterDetail('p1'),
        throwsA(
          isA<CatalogException>().having(
            (e) => e.code,
            'code',
            'network_error',
          ),
        ),
      );
    });

    test('maps a 5xx without an envelope to code server_error', () async {
      when(
        () => dio.get<Map<String, dynamic>>(any()),
      ).thenThrow(_dioError(502));

      expect(
        () => dataSource.getPosterDetail('p1'),
        throwsA(
          isA<CatalogException>().having((e) => e.code, 'code', 'server_error'),
        ),
      );
    });

    test('a non-DioException failure (null response body) reaches the caller '
        'as a CatalogException, not a bare TypeError', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: null,
          requestOptions: RequestOptions(path: '/'),
        ),
      );

      expect(
        () => dataSource.getPosterDetail('p1'),
        throwsA(
          isA<CatalogException>().having(
            (e) => e.code,
            'code',
            startsWith('unexpected_'),
          ),
        ),
      );
    });
  });

  group('listPosters', () {
    Map<String, dynamic> pageJson() => {
      'items': [
        {
          'id': 'p1',
          'title': 'Blade Runner',
          'price': '450.00',
          'status': 'available',
          'condition_grade': 'mint',
          'era_decade': 1980,
          'studio': 'Warner Bros',
          'primary_image_url': null,
        },
      ],
      'total': 1,
      'limit': 20,
      'offset': 0,
    };

    test('GETs /api/v1/posters with limit/offset as query params and no '
        'others', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => _resp(pageJson()));

      final result = await dataSource.listPosters(limit: 20, offset: 40);

      expect(result.items.single.id, 'p1');
      expect(result.total, 1);
      final captured = verify(
        () => dio.get<Map<String, dynamic>>(
          captureAny(),
          queryParameters: captureAny(named: 'queryParameters'),
        ),
      ).captured;
      expect(captured[0], '/api/v1/posters');
      // No `sort` param exists in the contract; anything extra here would be
      // silently ignored by the backend and mislead the next reader.
      expect(captured[1], {'limit': 20, 'offset': 40});
    });

    test('maps a no-response failure to code network_error', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(_dioNoResponse());

      expect(
        () => dataSource.listPosters(limit: 20, offset: 0),
        throwsA(
          isA<CatalogException>().having(
            (e) => e.code,
            'code',
            'network_error',
          ),
        ),
      );
    });

    test('maps a 5xx to code server_error — the backend 500s the whole list '
        'when any one row has an internal-only image key', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenThrow(_dioError(500));

      expect(
        () => dataSource.listPosters(limit: 20, offset: 0),
        throwsA(
          isA<CatalogException>().having((e) => e.code, 'code', 'server_error'),
        ),
      );
    });

    test('a malformed body reaches the caller as a CatalogException, not a '
        'bare TypeError', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: null,
          requestOptions: RequestOptions(path: '/'),
        ),
      );

      expect(
        () => dataSource.listPosters(limit: 20, offset: 0),
        throwsA(
          isA<CatalogException>().having(
            (e) => e.code,
            'code',
            startsWith('unexpected_'),
          ),
        ),
      );
    });
  });
}
