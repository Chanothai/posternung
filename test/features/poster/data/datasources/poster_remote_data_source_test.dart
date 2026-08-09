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

// Built through Dio's own `.badResponse`/`.connectionError` factories, not
// the bare `DioException(...)` constructor — those factories are what
// production code actually goes through, and they're the only thing that
// sets `.message` to a realistic (non-null) SDK string. A bare constructor
// leaves `.message` at its default of `null`, which used to make every
// negative `displayMessage == null` assertion in this file vacuous: it
// would have passed even if a mutant piped `e.message` straight into
// `displayMessage`, because there was never a non-null `e.message` for that
// mutant to leak in the first place (code-critic, INF-20 round 1 — M9).
// Going through the real factory also means this fixture can't drift from
// what Dio actually sends when the SDK's own message wording changes across
// versions.
DioException _dioError(int status, {Object? data}) {
  final requestOptions = RequestOptions(path: '/');
  return DioException.badResponse(
    statusCode: status,
    requestOptions: requestOptions,
    response: Response(
      statusCode: status,
      data: data,
      requestOptions: requestOptions,
    ),
  );
}

DioException _dioNoResponse() => DioException.connectionError(
  requestOptions: RequestOptions(path: '/'),
  reason: 'Connection refused',
);

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

  // Closed-world check on the fixtures above (test-quality §4) — every
  // `displayMessage`/`debugDetail == null` negative assertion in this file
  // only has teeth because `_dioError`/`_dioNoResponse` carry a real,
  // non-null `.message` for a leaking mutant to actually leak. Nothing else
  // in this file re-verifies that; if `DioException.badResponse`/
  // `.connectionError` ever stopped setting `.message`, or someone reverted
  // either helper back to the bare `DioException(...)` constructor, every
  // negative assertion below would silently go vacuous again exactly like
  // the round-1 defect (code-critic, INF-20 round 2) — this is the one test
  // that would say so out loud instead of staying green by accident.
  test('fixture sanity: _dioError and _dioNoResponse both carry a non-null, '
      'non-empty .message, as real DioExceptions from these factories '
      'always do', () {
    expect(_dioError(404).message, isNotNull);
    expect(_dioError(404).message, isNotEmpty);
    expect(_dioNoResponse().message, isNotNull);
    expect(_dioNoResponse().message, isNotEmpty);
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
              .having(
                (e) => e.displayMessage,
                'displayMessage',
                'ไม่พบโปสเตอร์นี้',
              )
              // ADR-0017 Amendment 1 AC-10, third direction — an envelope
              // with no `details` key must give a null debugDetail, not
              // silently fall back to something else (e.g. `e.message`,
              // which is now realistic/non-null in this fixture and would
              // be an easy thing to leak in by accident).
              .having((e) => e.debugDetail, 'debugDetail', isNull),
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
          isA<CatalogException>()
              .having((e) => e.code, 'code', 'network_error')
              // ADR-0017 Amendment 1 A1-D6 — this branch never sees a
              // backend envelope at all, so displayMessage must stay null.
              .having((e) => e.displayMessage, 'displayMessage', isNull),
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
          isA<CatalogException>()
              .having((e) => e.code, 'code', 'server_error')
              .having((e) => e.displayMessage, 'displayMessage', isNull),
        ),
      );
    });

    test('maps a 4xx without an envelope to code unknown_error — this branch '
        'had no test at all before ADR-0017 Amendment 1 (BL-99)', () async {
      when(
        () => dio.get<Map<String, dynamic>>(any()),
      ).thenThrow(_dioError(400));

      expect(
        () => dataSource.getPosterDetail('p1'),
        throwsA(
          isA<CatalogException>()
              .having((e) => e.code, 'code', 'unknown_error')
              .having((e) => e.displayMessage, 'displayMessage', isNull),
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
          isA<CatalogException>()
              .having((e) => e.code, 'code', 'catalog_remote_guard_unexpected')
              .having((e) => e.displayMessage, 'displayMessage', isNull),
        ),
      );
    });

    test("the envelope's `details` reaches debugDetail, never displayMessage "
        '(ADR-0017 Amendment 1 AC-10) — the two must never collapse into the '
        'same value even when a single envelope carries both', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(
        _dioError(
          404,
          data: {
            'error_code': 'POSTER_NOT_FOUND',
            'message': 'ไม่พบโปสเตอร์นี้',
            'details': {'poster_id': 'missing'},
          },
        ),
      );

      try {
        await dataSource.getPosterDetail('missing');
        fail('expected a CatalogException');
      } on CatalogException catch (e) {
        expect(e.displayMessage, 'ไม่พบโปสเตอร์นี้');
        expect(e.debugDetail, isNotNull);
        expect(e.debugDetail, isNot(e.displayMessage));
        expect(e.debugDetail, contains('missing'));
      }
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
            'catalog_remote_guard_unexpected',
          ),
        ),
      );
    });
  });
}
