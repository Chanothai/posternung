import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/features/poster/data/models/poster_image_model.dart';
import 'package:posternung/features/poster/domain/entities/poster_image_kind.dart';

Map<String, dynamic> _json({Object? kind = 'FRONT'}) => {
  'id': 'img-1',
  'url': 'https://cdn.example.com/img-1.jpg',
  'is_primary': true,
  'sort_order': 0,
  if (kind != _omit) 'kind': kind,
};

/// Sentinel so `_json` can express "the field is absent entirely", not just
/// "the field is present and null" — the two are different JSON shapes and
/// this DTO must tolerate both (ADR-0026 Amendment §A-D9 (3)).
const _omit = Object();

void main() {
  group('PosterImageModel.fromJson — kind', () {
    test('decodes all three known values and maps them via toEntity()', () {
      expect(
        PosterImageModel.fromJson(_json(kind: 'FRONT')).toEntity().kind,
        PosterImageKind.front,
      );
      expect(
        PosterImageModel.fromJson(_json(kind: 'BACK')).toEntity().kind,
        PosterImageKind.back,
      );
      expect(
        PosterImageModel.fromJson(_json(kind: 'DEFECT')).toEntity().kind,
        PosterImageKind.defect,
      );
    });

    test('an unrecognized future kind (RAKING, ADR-0026 §D1) degrades to '
        'null on the entity without fromJson throwing', () {
      expect(
        () => PosterImageModel.fromJson(_json(kind: 'RAKING')),
        returnsNormally,
      );
      expect(
        PosterImageModel.fromJson(_json(kind: 'RAKING')).toEntity().kind,
        isNull,
      );
    });

    test('lowercase "front" is rejected, not tolerated (§D2 casing rule)', () {
      expect(
        PosterImageModel.fromJson(_json(kind: 'front')).toEntity().kind,
        isNull,
      );
    });

    test('an empty-string kind degrades to null, no throw', () {
      expect(
        PosterImageModel.fromJson(_json(kind: '')).toEntity().kind,
        isNull,
      );
    });

    // 🔴 ADR-0026 Amendment §A-D9 (3): `kind` is `required` on the wire but
    // deliberately typed `String?` in this DTO. This is the trade-off
    // itself, spelled out as a test — a required backend field that this
    // client still tolerates missing, so a backend rollback degrades a
    // gallery ordering instead of crashing the whole poster-detail screen.
    // This is NOT accidental looseness; it must stay green even though the
    // contract says the field is required.
    test('kind missing from the payload entirely degrades to null — this is '
        'the documented trade-off (ADR-0026 §A-D9 (3)), not looseness', () {
      final json = _json(kind: _omit);
      expect(json.containsKey('kind'), isFalse);

      expect(() => PosterImageModel.fromJson(json), returnsNormally);
      expect(PosterImageModel.fromJson(json).toEntity().kind, isNull);
    });

    test(
      'a null kind value in the payload also degrades to null, no throw',
      () {
        expect(
          () => PosterImageModel.fromJson(_json(kind: null)),
          returnsNormally,
        );
        expect(
          PosterImageModel.fromJson(_json(kind: null)).toEntity().kind,
          isNull,
        );
      },
    );
  });

  test('toEntity() maps every other field unchanged', () {
    final entity = PosterImageModel.fromJson(_json()).toEntity();

    expect(entity.id, 'img-1');
    expect(entity.url, 'https://cdn.example.com/img-1.jpg');
    expect(entity.isPrimary, isTrue);
    expect(entity.sortOrder, 0);
  });
}
