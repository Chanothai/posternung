import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/catalog/poster_condition_grade.dart';
import 'package:posternung/features/poster/data/models/paginated_posters_model.dart';
import 'package:posternung/features/poster/data/models/poster_summary_model.dart';
import 'package:posternung/features/poster/domain/entities/poster_status.dart';

Map<String, dynamic> _json({
  Object? price = '450.00',
  Object? status = 'available',
  Object? conditionGrade = 'very_good',
  Object? primaryImageUrl = 'https://cdn.example.com/p1.jpg',
}) => {
  'id': '0f1b2c3d-4e5f-6a7b-8c9d-0e1f2a3b4c5d',
  'title': 'Blade Runner',
  'price': price,
  'status': status,
  'condition_grade': conditionGrade,
  'era_decade': 1980,
  'studio': 'Warner Bros',
  'primary_image_url': primaryImageUrl,
};

void main() {
  group('PosterSummaryModel', () {
    test('decodes price as the String the backend actually sends — Pydantic '
        'serializes Decimal to a JSON string, not a number', () {
      final model = PosterSummaryModel.fromJson(_json(price: '1250.50'));

      expect(model.price, '1250.50');
      expect(model.toEntity().price, '1250.50');
    });

    test('maps every wire field onto the entity', () {
      final poster = PosterSummaryModel.fromJson(_json()).toEntity();

      expect(poster.id, '0f1b2c3d-4e5f-6a7b-8c9d-0e1f2a3b4c5d');
      expect(poster.title, 'Blade Runner');
      expect(poster.status, PosterStatus.available);
      expect(poster.conditionGrade, PosterConditionGrade.veryGood);
      expect(poster.eraDecade, 1980);
      expect(poster.studio, 'Warner Bros');
      expect(poster.primaryImageUrl, 'https://cdn.example.com/p1.jpg');
    });

    test('reserved and sold decode as themselves — the list is not filtered '
        'server-side (in_stock_only defaults to false)', () {
      expect(
        PosterSummaryModel.fromJson(
          _json(status: 'reserved'),
        ).toEntity().status,
        PosterStatus.reserved,
      );
      expect(
        PosterSummaryModel.fromJson(_json(status: 'sold')).toEntity().status,
        PosterStatus.sold,
      );
    });

    test('an unrecognized status degrades to null instead of throwing — one '
        'bad row must not take the whole page down', () {
      final poster = PosterSummaryModel.fromJson(
        _json(status: 'withdrawn_by_seller'),
      ).toEntity();

      expect(poster.status, isNull);
      expect(poster.title, 'Blade Runner');
    });

    test('an unrecognized condition_grade degrades to null', () {
      final poster = PosterSummaryModel.fromJson(
        _json(conditionGrade: 'pristine'),
      ).toEntity();

      expect(poster.conditionGrade, isNull);
    });

    test('a null condition_grade decodes as null (no backend guard exists — '
        'ADR-0003)', () {
      final poster = PosterSummaryModel.fromJson(
        _json(conditionGrade: null),
      ).toEntity();

      expect(poster.conditionGrade, isNull);
    });

    test('a null primary_image_url decodes without throwing', () {
      final poster = PosterSummaryModel.fromJson(
        _json(primaryImageUrl: null),
      ).toEntity();

      expect(poster.primaryImageUrl, isNull);
    });

    test('an absent primary_image_url key decodes without throwing — the '
        'field is not in the schema\'s required list', () {
      final json = _json()..remove('primary_image_url');

      expect(
        PosterSummaryModel.fromJson(json).toEntity().primaryImageUrl,
        isNull,
      );
    });

    test('null era_decade and studio decode without throwing', () {
      final json = _json()
        ..['era_decade'] = null
        ..['studio'] = null;

      final poster = PosterSummaryModel.fromJson(json).toEntity();

      expect(poster.eraDecade, isNull);
      expect(poster.studio, isNull);
    });
  });

  group('PaginatedPostersModel', () {
    test('decodes the envelope and maps each item', () {
      final model = PaginatedPostersModel.fromJson({
        'items': [_json(), _json(status: 'sold')],
        'total': 42,
        'limit': 20,
        'offset': 0,
      });

      final page = model.toEntity();

      expect(page.total, 42);
      expect(page.limit, 20);
      expect(page.offset, 0);
      expect(page.items, hasLength(2));
      expect(page.items.last.status, PosterStatus.sold);
    });

    test('preserves the server ordering — never re-sorted by price (BR-05: '
        'the default sort must not be cheapest-first)', () {
      final model = PaginatedPostersModel.fromJson({
        'items': [
          _json(price: '900.00'),
          _json(price: '100.00'),
          _json(price: '500.00'),
        ],
        'total': 3,
        'limit': 20,
        'offset': 0,
      });

      expect(model.toEntity().items.map((p) => p.price).toList(), [
        '900.00',
        '100.00',
        '500.00',
      ]);
    });

    test('an empty page decodes to total 0 with no items', () {
      final page = PaginatedPostersModel.fromJson({
        'items': <Map<String, dynamic>>[],
        'total': 0,
        'limit': 20,
        'offset': 0,
      }).toEntity();

      expect(page.items, isEmpty);
      expect(page.total, 0);
    });
  });
}
