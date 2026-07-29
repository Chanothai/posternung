import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/catalog/poster_condition_grade.dart';
import 'package:posternung/core/error/catalog_exception.dart';
import 'package:posternung/features/poster/data/models/poster_detail_model.dart';
import 'package:posternung/features/poster/domain/entities/poster_status.dart';

Map<String, dynamic> _fullJson() => {
  'id': 'p1',
  'title': 'Blade Runner',
  'price': '450.00',
  'status': 'available',
  'condition_grade': 'very_good',
  'era_decade': 1980,
  'studio': 'Warner Bros',
  'primary_image_url': 'https://example.com/blade-runner.jpg',
  'tmdb_id': 78,
  'size': '27x41',
  'description': 'US one-sheet, theatrical release.',
  'is_authenticated': true,
  'authenticity_note': 'Verified by in-house expert.',
  'provenance': 'Estate collection, Los Angeles.',
  'images': [
    {
      'id': 'img1',
      'url': 'https://example.com/1.jpg',
      'is_primary': true,
      'sort_order': 0,
    },
  ],
  'created_at': '2024-01-01T00:00:00Z',
};

// Every optional field genuinely null — this used to be the crash trap
// per add-feature-slice's "fromJson throws TypeError on null" note.
// `openapi.json`'s PosterDetailResponse marks all of these `anyOf: [...,
// null]` even though they're in the `required` list (present key, nullable
// value) — verified field-by-field per ADR-0005's Verification section.
Map<String, dynamic> _allNullableFieldsNullJson() => {
  'id': 'p2',
  'title': 'Untitled Import',
  'price': '0.00',
  'status': 'available',
  'condition_grade': null,
  'era_decade': null,
  'studio': null,
  'primary_image_url': null,
  'tmdb_id': null,
  'size': null,
  'description': null,
  'is_authenticated': false,
  'authenticity_note': null,
  'provenance': null,
  'images': <Map<String, dynamic>>[],
  'created_at': '2024-01-01T00:00:00Z',
};

void main() {
  group('fromJson / toEntity — every field populated', () {
    test('parses and maps every field correctly', () {
      final model = PosterDetailModel.fromJson(_fullJson());
      final entity = model.toEntity();

      expect(entity.id, 'p1');
      expect(entity.title, 'Blade Runner');
      expect(entity.price, '450.00');
      expect(entity.status, PosterStatus.available);
      expect(entity.conditionGrade, PosterConditionGrade.veryGood);
      expect(entity.eraDecade, 1980);
      expect(entity.studio, 'Warner Bros');
      expect(entity.primaryImageUrl, 'https://example.com/blade-runner.jpg');
      expect(entity.tmdbId, 78);
      expect(entity.size, '27x41');
      expect(entity.description, 'US one-sheet, theatrical release.');
      expect(entity.isAuthenticated, isTrue);
      expect(entity.authenticityNote, 'Verified by in-house expert.');
      expect(entity.provenance, 'Estate collection, Los Angeles.');
      expect(entity.images, hasLength(1));
      expect(entity.images.single.id, 'img1');
      expect(entity.images.single.isPrimary, isTrue);
      expect(entity.createdAt, DateTime.utc(2024, 1, 1));
    });
  });

  group('fromJson / toEntity — every nullable field null', () {
    test('does not throw and every nullable entity field is null', () {
      final model = PosterDetailModel.fromJson(_allNullableFieldsNullJson());
      final entity = model.toEntity();

      expect(entity.conditionGrade, isNull);
      expect(entity.eraDecade, isNull);
      expect(entity.studio, isNull);
      expect(entity.primaryImageUrl, isNull);
      expect(entity.tmdbId, isNull);
      expect(entity.size, isNull);
      expect(entity.description, isNull);
      expect(entity.authenticityNote, isNull);
      expect(entity.provenance, isNull);
      expect(entity.images, isEmpty);
      expect(entity.isAuthenticated, isFalse);
    });
  });

  test('an unrecognized status throws CatalogException, not a bare crash', () {
    final json = _fullJson()..['status'] = 'discontinued';
    final model = PosterDetailModel.fromJson(json);

    expect(
      model.toEntity,
      throwsA(
        isA<CatalogException>().having(
          (e) => e.code,
          'code',
          'unknown_poster_status',
        ),
      ),
    );
  });

  test('an unrecognized condition_grade degrades to null, not a crash', () {
    final json = _fullJson()..['condition_grade'] = 'mint_plus';
    final model = PosterDetailModel.fromJson(json);

    expect(model.toEntity().conditionGrade, isNull);
  });
}
